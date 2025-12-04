import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as os from 'os';
import * as path from 'path';
import { promises as fs } from 'fs';
import ffmpeg from 'fluent-ffmpeg';
import ffmpegInstaller from '@ffmpeg-installer/ffmpeg';

import { db } from '../config/firebase-admin';
import {
  downloadStorageObject,
  getSignedUrl,
} from '../utils/storage-helpers';
import {
  getTranscription,
  saveStudyNote,
  saveTranscription,
} from '../utils/firestore-helpers';
import {
  SonioxError,
  SonioxErrorCode,
  transcribeWithSoniox,
} from '../utils/soniox-helpers';
import { generateStudyNotes } from '../utils/openai-helpers';

ffmpeg.setFfmpegPath(ffmpegInstaller.path);

const REGION = 'europe-west2';
const JOB_COLLECTION = 'transcription_jobs';
const MAX_JOBS_PER_RUN = 2;
const CHUNK_SECONDS = 360; // 6 minutes
const SONIOX_TIMEOUT_PER_CHUNK_MS = 120_000;
const CHUNK_CONCURRENCY = 3;
const BASE_JOB_TIMEOUT_MS = 180_000;
const PROCESSABLE_STATUSES = ['processing', 'generating_note'];

const NOTE_STATUS = {
  pending: 'pending',
  processing: 'processing',
  ready: 'ready',
  error: 'error',
} as const;

export const processTranscriptionJobs = functions
  .region(REGION)
  .pubsub.schedule('every 2 minutes')
  .onRun(async () => {
    const snapshot = await db
      .collection(JOB_COLLECTION)
      .where('status', 'in', PROCESSABLE_STATUSES)
      .limit(MAX_JOBS_PER_RUN)
      .get();

    if (snapshot.empty) {
      return;
    }

    for (const doc of snapshot.docs) {
      await processJob(doc);
    }
  });

type JobData = {
  status?: string;
  audioStoragePath?: string;
  durationSeconds?: number;
  approxSizeBytes?: number;
  metadata?: Record<string, unknown>;
  workerStatus?: string;
  mode?: string;
  localAudioPath?: string;
  transcriptId?: string;
  noteStatus?: string;
  noteId?: string;
};

async function processJob(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
) {
  const data = doc.data() as JobData;
  if (data.workerStatus === 'running') {
    functions.logger.debug('Job already running, skipping', { jobId: doc.id });
    return;
  }

  const jobStatus = (data.status as string) ?? 'processing';
  if (jobStatus === 'processing' && !data.audioStoragePath) {
    await markJobError(doc, 'bad_audio', 'Audio storage path is missing.');
    return;
  }

  await doc.ref.update({
    workerStatus: 'running',
    workerId: uuidv4(),
    workerStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let tempDir: string | null = null;

  try {
    let transcriptId = data.transcriptId ?? null;
    let transcriptText: string | null = null;

    if (jobStatus === 'processing') {
      tempDir = await fs.mkdtemp(path.join(os.tmpdir(), `job_${doc.id}_`));
      const sourcePath = path.join(
        tempDir,
        path.basename(data.audioStoragePath ?? `${doc.id}.audio`),
      );
      const chunkDir = path.join(tempDir, 'chunks');
      await fs.mkdir(chunkDir, { recursive: true });

      const result = await runTranscriptionStage(
        doc,
        data,
        sourcePath,
        chunkDir,
      );
      transcriptId = result.transcriptId;
      transcriptText = result.text;
    } else {
      transcriptText = await loadStoredTranscript(data.transcriptId);
    }

    if (!transcriptId || !transcriptText) {
      throw new Error('Missing transcription data for note generation.');
    }

    await runNoteStage(doc, transcriptId, transcriptText);
  } catch (error) {
    const normalized = normalizeError(error);
    await doc.ref.update({
      status: 'error',
      workerStatus: 'failed',
      errorCode: normalized.code,
      errorMessage: normalized.message,
      canRetry: normalized.canRetry,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    functions.logger.error('Transcription job failed', {
      jobId: doc.id,
      error: normalized,
    });
  } finally {
    if (tempDir) {
      await cleanupDirectory(tempDir);
    }
  }
}

async function runTranscriptionStage(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
  data: JobData,
  sourcePath: string,
  chunkDir: string,
): Promise<{ transcriptId: string; text: string }> {
  await downloadStorageObject(data.audioStoragePath!, sourcePath);
  const normalizedSourcePath = await ensureMono16kWav(sourcePath);
  const chunkPaths = await splitIntoChunks(normalizedSourcePath, chunkDir);
  if (!chunkPaths.length) {
    throw new SonioxError('Audio chunking failed.', {
      code: 'bad_audio',
    });
  }

  const transcripts: string[] = [];
  let confidenceAccumulator = 0;
  let confidenceSamples = 0;

  const chunkResults = await processChunks(
    doc,
    chunkPaths,
    SONIOX_TIMEOUT_PER_CHUNK_MS,
  );
  chunkResults.forEach((result) => {
    transcripts.push(result.text);
    if (typeof result.confidence === 'number') {
      confidenceAccumulator += result.confidence;
      confidenceSamples += 1;
    }
  });

  const text = transcripts.join(' ').replace(/\s+/g, ' ').trim();
  if (!text) {
    throw new SonioxError('Transcription produced empty text.', {
      code: 'bad_audio',
    });
  }

  const transcriptId = uuidv4();
  const audioSignedUrl = await getSignedUrl(data.audioStoragePath!);
  await saveTranscription({
    id: transcriptId,
    text,
    audioPath: audioSignedUrl,
    durationMs: (data.durationSeconds ?? 0) * 1000,
    timestamp: new Date().toISOString(),
    confidence:
      confidenceSamples > 0
        ? confidenceAccumulator / confidenceSamples
        : undefined,
    metadata: {
      source: 'soniox',
      jobId: doc.id,
      approxSizeBytes: data.approxSizeBytes,
    },
  });

  await doc.ref.update({
    status: 'generating_note',
    transcriptId,
    noteStatus: NOTE_STATUS.processing,
    noteError: admin.firestore.FieldValue.delete(),
    noteCanRetry: false,
    progress: 85,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { transcriptId, text };
}

async function runNoteStage(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
  transcriptId: string,
  transcriptText: string,
) {
  try {
    await doc.ref.update({
      status: 'generating_note',
      noteStatus: NOTE_STATUS.processing,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const studyNote = await generateStudyNotes(transcriptText);
    const noteId = uuidv4();
    await saveStudyNote({
      id: noteId,
      transcriptionId: transcriptId,
      title: studyNote.title,
      summary: studyNote.summary,
      keyPoints: studyNote.keyPoints,
      actionItems: studyNote.actionItems,
      studyQuestions: studyNote.studyQuestions,
      metadata: {
        jobId: doc.id,
        model: 'gpt-4.1-mini',
      },
    });

    await doc.ref.update({
      status: 'done',
      noteStatus: NOTE_STATUS.ready,
      noteId,
      progress: 100,
      workerStatus: 'finished',
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      noteError: admin.firestore.FieldValue.delete(),
      noteCanRetry: false,
      canRetry: false,
    });
  } catch (error) {
    const message =
      error instanceof Error ? error.message : 'Failed to generate notes.';
    await doc.ref.update({
      status: 'done',
      noteStatus: NOTE_STATUS.error,
      noteError: message,
      noteCanRetry: true,
      workerStatus: 'note_failed',
      progress: 100,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    functions.logger.error('Note generation failed', {
      jobId: doc.id,
      error: message,
    });
  }
}

async function loadStoredTranscript(transcriptId?: string | null) {
  if (!transcriptId) {
    return null;
  }
  const transcription = await getTranscription(transcriptId);
  const text = transcription?.text;
  if (!text || typeof text !== 'string') {
    throw new Error('Stored transcription text is unavailable.');
  }
  return text;
}

async function splitIntoChunks(
  sourcePath: string,
  chunkDir: string,
): Promise<string[]> {
  const pattern = path.join(chunkDir, 'chunk_%03d.wav');
  await new Promise<void>((resolve, reject) => {
    ffmpeg(sourcePath)
      .audioChannels(1)
      .audioFrequency(16000)
      .format('wav')
      .outputOptions([
        '-f segment',
        `-segment_time ${CHUNK_SECONDS}`,
        '-reset_timestamps 1',
      ])
      .on('error', reject)
      .on('end', () => resolve())
      .save(pattern);
  });

  const files = await fs.readdir(chunkDir);
  const chunks = files
    .filter((file) => file.startsWith('chunk_') && file.endsWith('.wav'))
    .sort()
    .map((file) => path.join(chunkDir, file));

  // If the audio is shorter than the segment length, fall back to a single chunk.
  if (!chunks.length) {
    const fallbackPath = path.join(chunkDir, 'chunk_000.wav');
    await new Promise<void>((resolve, reject) => {
      ffmpeg(sourcePath)
        .audioChannels(1)
        .audioFrequency(16000)
        .format('wav')
        .on('error', reject)
        .on('end', () => resolve())
        .save(fallbackPath);
    });
    return [fallbackPath];
  }

  return chunks;
}

async function processChunks(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
  chunkPaths: string[],
  timeoutMsPerChunk: number,
): Promise<Array<{ text: string; confidence?: number }>> {
  const total = chunkPaths.length;
  const results: Array<{ text: string; confidence?: number }> = new Array(total);
  let processed = 0;
  let nextIndex = 0;
  const jobDeadline =
    Date.now() +
    Math.max(
      BASE_JOB_TIMEOUT_MS + total * timeoutMsPerChunk,
      total * timeoutMsPerChunk * 1.2,
    );

  const workers = Array.from({ length: Math.min(CHUNK_CONCURRENCY, total) }, () =>
    (async () => {
      while (true) {
        const index = nextIndex++;
        if (index >= total) {
          return;
        }
        if (Date.now() > jobDeadline) {
          throw new SonioxError('Transcription job timed out.', {
            code: 'timeout',
          });
        }

        const chunkPath = chunkPaths[index];
        const buffer = await fs.readFile(chunkPath);
        const result = await transcribeWithSoniox(buffer, {
          timeoutMs: timeoutMsPerChunk,
        });

        results[index] = {
          text: result.text.trim(),
          confidence: result.confidence,
        };

        processed += 1;
        const progress =
          15 + Math.round((processed / total) * 70); // 15% for upload, 15% for notes
        await doc.ref.update({
          progress,
          workerHeartbeat: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    })(),
  );

  await Promise.all(workers);
  return results;
}

async function ensureMono16kWav(sourcePath: string): Promise<string> {
  const metadata = await probeAudio(sourcePath);
  const stream = metadata.streams?.[0];
  const sampleRate = stream?.sample_rate
    ? Number(stream.sample_rate)
    : undefined;
  const channels = stream?.channels;
  const format = metadata.format?.format_name || '';

  if (
    sampleRate === 16000 &&
    channels === 1 &&
    format.toLowerCase().includes('wav')
  ) {
    return sourcePath;
  }

  const convertedPath = path.join(
    path.dirname(sourcePath),
    `${uuidv4()}_mono16k.wav`,
  );
  await new Promise<void>((resolve, reject) => {
    ffmpeg(sourcePath)
      .audioChannels(1)
      .audioFrequency(16000)
      .format('wav')
      .on('error', reject)
      .on('end', () => resolve())
      .save(convertedPath);
  });
  return convertedPath;
}

function probeAudio(filePath: string): Promise<ffmpeg.FfprobeData> {
  return new Promise((resolve, reject) => {
    ffmpeg.ffprobe(filePath, (error, data) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(data);
    });
  });
}

async function cleanupDirectory(dirPath: string) {
  try {
    await fs.rm(dirPath, { recursive: true, force: true });
  } catch (error) {
    functions.logger.warn('Failed to cleanup temp directory', {
      dirPath,
      error: (error as Error).message,
    });
  }
}

function normalizeError(error: unknown): {
  message: string;
  code: SonioxErrorCode;
  canRetry: boolean;
} {
  if (error instanceof SonioxError) {
    return {
      message: error.message,
      code: error.code,
      canRetry: error.code === 'provider_down' || error.code === 'timeout',
    };
  }

  if (error instanceof Error) {
    return {
      message: error.message,
      code: 'unknown',
      canRetry: false,
    };
  }

  return {
    message: 'Unknown transcription error.',
    code: 'unknown',
    canRetry: false,
  };
}

async function markJobError(
  doc: FirebaseFirestore.QueryDocumentSnapshot<FirebaseFirestore.DocumentData>,
  errorCode: SonioxErrorCode,
  message: string,
) {
  await doc.ref.update({
    status: 'error',
    errorCode,
    errorMessage: message,
    canRetry: false,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}


