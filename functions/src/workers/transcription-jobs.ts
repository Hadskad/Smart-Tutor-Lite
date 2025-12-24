import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { v4 as uuidv4 } from 'uuid';
import * as os from 'os';
import * as path from 'path';
import { promises as fs } from 'fs';
import ffmpeg from 'fluent-ffmpeg';
import ffmpegInstaller from '@ffmpeg-installer/ffmpeg';


import {
  downloadStorageObjectWithRetry,
  getSignedUrl,
  uploadFile,
  deleteFile,
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
import { generateStudyNotes as generateStudyNotesGPT } from '../utils/openai-helpers';
import { generateStudyNotes as generateStudyNotesGemini } from '../utils/gemini-helpers';

ffmpeg.setFfmpegPath(ffmpegInstaller.path);

const REGION = 'europe-west2';


const CHUNK_SECONDS = 360; // 6 minutes
const SONIOX_TIMEOUT_PER_CHUNK_MS = 600_000; // 10 minutes (was 120_000 = 2 minutes)
const CHUNK_CONCURRENCY = 3;
const BASE_JOB_TIMEOUT_MS = 600_000;


const NOTE_STATUS = {
  pending: 'pending',
  processing: 'processing',
  ready: 'ready',
  error: 'error',
} as const;

const MAX_NOTE_RETRIES = 3;

interface NoteGenerationResult {
  note: Awaited<ReturnType<typeof generateStudyNotesGPT>>;
  model: 'gpt' | 'gemini';
  attempts: number;
}

/**
 * Generate study notes with resilient fallback strategy:
 * 1. Try GPT first with MAX_NOTE_RETRIES attempts
 * 2. If GPT fails, try Gemini as fallback with MAX_NOTE_RETRIES attempts
 * 3. Only throw if both providers fail
 */
async function generateStudyNotesWithFallback(
  transcriptText: string,
  jobId: string,
): Promise<NoteGenerationResult> {
  let gptAttempts = 0;
  let lastGptError: Error | null = null;

  // Try GPT first with retries
  for (let i = 0; i < MAX_NOTE_RETRIES; i++) {
    gptAttempts++;
    try {
      functions.logger.info('Attempting GPT note generation', {
        jobId,
        attempt: gptAttempts,
        maxAttempts: MAX_NOTE_RETRIES,
      });
      const note = await generateStudyNotesGPT(transcriptText);
      return { note, model: 'gpt', attempts: gptAttempts };
    } catch (error) {
      lastGptError = error instanceof Error ? error : new Error(String(error));
      functions.logger.warn('GPT note generation attempt failed', {
        jobId,
        attempt: gptAttempts,
        error: lastGptError.message,
      });
      // Wait briefly before retry (exponential backoff)
      if (i < MAX_NOTE_RETRIES - 1) {
        await new Promise((resolve) =>
          setTimeout(resolve, Math.pow(2, i) * 1000),
        );
      }
    }
  }

  // GPT failed all attempts, try Gemini as fallback
  functions.logger.info('GPT exhausted retries, falling back to Gemini', {
    jobId,
    gptAttempts,
    gptError: lastGptError?.message,
  });

  let geminiAttempts = 0;
  let lastGeminiError: Error | null = null;

  for (let i = 0; i < MAX_NOTE_RETRIES; i++) {
    geminiAttempts++;
    try {
      functions.logger.info('Attempting Gemini note generation', {
        jobId,
        attempt: geminiAttempts,
        maxAttempts: MAX_NOTE_RETRIES,
      });
      const note = await generateStudyNotesGemini(transcriptText);
      return {
        note,
        model: 'gemini',
        attempts: gptAttempts + geminiAttempts,
      };
    } catch (error) {
      lastGeminiError =
        error instanceof Error ? error : new Error(String(error));
      functions.logger.warn('Gemini note generation attempt failed', {
        jobId,
        attempt: geminiAttempts,
        error: lastGeminiError.message,
      });
      // Wait briefly before retry (exponential backoff)
      if (i < MAX_NOTE_RETRIES - 1) {
        await new Promise((resolve) =>
          setTimeout(resolve, Math.pow(2, i) * 1000),
        );
      }
    }
  }

  // Both providers failed
  const totalAttempts = gptAttempts + geminiAttempts;
  const errorMessage = `Note generation failed after ${totalAttempts} total attempts. GPT: ${lastGptError?.message || 'N/A'}. Gemini: ${lastGeminiError?.message || 'N/A'}`;
  functions.logger.error('Both note generation providers failed', {
    jobId,
    gptAttempts,
    geminiAttempts,
    gptError: lastGptError?.message,
    geminiError: lastGeminiError?.message,
  });
  throw new Error(errorMessage);
}

export const processTranscriptionJob = functions
  .region(REGION)
  .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
  })
  .firestore.document('transcription_jobs/{jobId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as JobData;
    const after = change.after.data() as JobData;
    const jobId = context.params.jobId;

    // Only process when status changes to 'uploaded'
    if (before.status !== 'uploaded' && after.status === 'uploaded') {
      // Idempotency: Skip if already processing or failed
      if (
        after.workerStatus === 'running' ||
        after.workerStatus === 'failed'
      ) {
        functions.logger.debug('Skipping job - already processing or failed', {
          jobId,
          workerStatus: after.workerStatus,
        });
        return;
      }

      // Verify audio is uploaded
      if (!after.audioStoragePath) {
        await markJobError(
          change.after,
          'bad_audio',
          'Audio storage path is missing.',
          false, // canRetry = false for missing audio
        );
        return;
      }

      try {
        await processJob(change.after);
      } catch (error) {
        // Catch any errors that weren't handled by processJob
        functions.logger.error('processTranscriptionJob trigger failed', {
          jobId,
          error: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : undefined,
        });
        
        // Mark job as error if processJob didn't already do so
        const currentData = (await change.after.ref.get()).data() as JobData;
        if (currentData.status === 'uploaded' && currentData.workerStatus !== 'failed') {
          const normalized = normalizeError(error);
          await markJobError(
            change.after,
            normalized.code,
            normalized.message,
            normalized.canRetry,
          );
        }
      }
    }
  });

export const processNoteGeneration = functions
  .region(REGION)
  .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
  })
  .firestore.document('transcription_jobs/{jobId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data() as JobData;
    const after = change.after.data() as JobData;
    const jobId = context.params.jobId;

    // Trigger when status changes to 'generating_note' and transcriptId exists
    if (
      before.status !== 'generating_note' &&
      after.status === 'generating_note' &&
      after.transcriptId
    ) {
      // Idempotency check
      if (after.workerStatus === 'running' || after.noteStatus === 'ready') {
        functions.logger.debug('Skipping note generation - already processing or ready', {
          jobId,
        });
        return;
      }

      const transcriptText = await loadStoredTranscript(after.transcriptId);
      if (!transcriptText) {
        await markJobError(
          change.after,
          'bad_audio',
          'Transcription not found.',
        );
        return;
      }

      try {
        await runNoteStage(change.after, after.transcriptId, transcriptText);
      } catch (error) {
        // Catch any errors that weren't handled by runNoteStage
        functions.logger.error('processNoteGeneration trigger failed', {
          jobId,
          error: error instanceof Error ? error.message : String(error),
          stack: error instanceof Error ? error.stack : undefined,
        });

        // Mark job as error if runNoteStage didn't already do so
        const currentData = (await change.after.ref.get()).data() as JobData;
        if (
          currentData.status === 'generating_note' &&
          currentData.noteStatus !== 'error'
        ) {
          const normalized = normalizeError(error);
          await change.after.ref.update({
            status: 'completed',
            noteStatus: NOTE_STATUS.error,
            noteError: normalized.message,
            noteCanRetry: normalized.canRetry,
            workerStatus: 'note_failed',
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }
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
  canRetry?: boolean;
  retryCount?: number;
  retryScheduledAt?: admin.firestore.Timestamp | admin.firestore.FieldValue | null;
  lastRetryAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  maxRetries?: number;
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
  
  // Handle note-only retries (when status is generating_note and transcriptId exists)
  if (jobStatus === 'generating_note' && data.transcriptId) {
    await doc.ref.update({
      workerStatus: 'running',
      workerId: uuidv4(),
      workerStartedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    try {
      const transcriptText = await loadStoredTranscript(data.transcriptId);
      if (!transcriptText) {
        throw new Error('Stored transcription text is unavailable.');
      }
      await runNoteStage(doc, data.transcriptId, transcriptText);
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
      const jobData = doc.data() as JobData;
      functions.logger.error('Note generation retry failed', {
        jobId: doc.id,
        transcriptId: data.transcriptId,
        errorCode: normalized.code,
        errorMessage: normalized.message,
        canRetry: normalized.canRetry,
        retryCount: jobData.retryCount ?? 0,
      });
    }
    return;
  }

  if (
    (jobStatus === 'processing' || jobStatus === 'uploaded') &&
    !data.audioStoragePath
  ) {
    await markJobError(doc, 'bad_audio', 'Audio storage path is missing.');
    return;
  }

  await doc.ref.update({
    status: 'processing',
    workerStatus: 'running',
    workerId: uuidv4(),
    workerStartedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let tempDir: string | null = null;

  try {
    let transcriptId = data.transcriptId ?? null;
    let transcriptText: string | null = null;

    if (jobStatus === 'processing' || jobStatus === 'uploaded') {
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
    const jobData = doc.data() as JobData;
    functions.logger.error('Transcription job failed', {
      jobId: doc.id,
      transcriptId: jobData.transcriptId,
      errorCode: normalized.code,
      errorMessage: normalized.message,
      canRetry: normalized.canRetry,
      retryCount: jobData.retryCount ?? 0,
      audioStoragePath: jobData.audioStoragePath,
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
  await downloadStorageObjectWithRetry(data.audioStoragePath!, sourcePath);
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

  // Build transcription payload without any undefined fields
  const baseTranscriptionData = {
    id: transcriptId,
    text,
    audioPath: audioSignedUrl,
    durationMs: (data.durationSeconds ?? 0) * 1000,
    timestamp: new Date().toISOString(),
    metadata: {
      source: 'soniox',
      jobId: doc.id,
      approxSizeBytes: data.approxSizeBytes,
    },
  };

  const avgConfidence =
    confidenceSamples > 0 ? confidenceAccumulator / confidenceSamples : null;

  await saveTranscription({
    ...baseTranscriptionData,
    ...(avgConfidence !== null ? { confidence: avgConfidence } : {}),
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
  const jobId = doc.id;
  try {
    await doc.ref.update({
      status: 'generating_note',
      noteStatus: NOTE_STATUS.processing,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Use resilient note generation with GPT -> Gemini fallback and 3x retries
    const { note: studyNote, model, attempts } =
      await generateStudyNotesWithFallback(transcriptText, jobId);

    functions.logger.info('Note generation succeeded', {
      jobId,
      model,
      attempts,
      transcriptId,
    });

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
        jobId,
        model,
        attempts,
      },
    });

    await doc.ref.update({
      status: 'completed',
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
      status: 'completed',
      noteStatus: NOTE_STATUS.error,
      noteError: message,
      noteCanRetry: true,
      workerStatus: 'note_failed',
      progress: 100,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    const normalized = normalizeError(error);
    const jobData = doc.data() as JobData;
    functions.logger.error('Note generation failed (all providers exhausted)', {
      jobId,
      transcriptId,
      errorCode: normalized.code,
      errorMessage: normalized.message,
      canRetry: normalized.canRetry,
      retryCount: jobData.retryCount ?? 0,
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
  const jobId = doc.id;
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
        const chunkStoragePath = `transcription_jobs/${jobId}/chunks/${index}.wav`;
        let chunkUploaded = false;

        try {
          // Read chunk file as buffer
          const buffer = await fs.readFile(chunkPath);

          // Upload chunk to Storage temporarily
          functions.logger.debug('Uploading chunk to Storage', {
            jobId,
            chunkIndex: index,
            chunkStoragePath,
          });
          await uploadFile(buffer, chunkStoragePath, 'audio/wav');
          chunkUploaded = true;

          // Transcribe using storage path
          functions.logger.debug('Starting transcription for chunk', {
            jobId,
            chunkIndex: index,
          });
          const result = await transcribeWithSoniox(chunkStoragePath, {
            timeoutMs: timeoutMsPerChunk,
          });

          functions.logger.debug('Transcription completed for chunk', {
            jobId,
            chunkIndex: index,
          });

          results[index] = {
            text: result.text.trim(),
            confidence: result.confidence,
          };

          // Delete temporary chunk from Storage
          await deleteFile(chunkStoragePath);
          chunkUploaded = false;
          functions.logger.debug('Deleted temporary chunk from Storage', {
            jobId,
            chunkIndex: index,
          });

          processed += 1;
          const progress =
            15 + Math.round((processed / total) * 70); // 15% for uploaded, 70% for processing chunks (15-85%)
          await doc.ref.update({
            progress,
            workerHeartbeat: admin.firestore.FieldValue.serverTimestamp(),
          });
        } catch (error) {
          // Cleanup: Delete chunk from Storage if it was uploaded
          if (chunkUploaded) {
            try {
              await deleteFile(chunkStoragePath);
              functions.logger.debug('Cleaned up chunk from Storage after error', {
                jobId,
                chunkIndex: index,
              });
            } catch (cleanupError) {
              functions.logger.error('Failed to cleanup chunk from Storage', {
                jobId,
                chunkIndex: index,
                error: cleanupError,
              });
            }
          }

          // Re-throw error to be handled by caller
          throw error;
        }
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
    // Check for Firebase Storage errors
    const errorMessage = error.message.toLowerCase();
    const errorCode = (error as any).code;
    
    // Firebase Storage network errors (retryable)
    if (
      errorCode === 'ECONNRESET' ||
      errorCode === 'ETIMEDOUT' ||
      errorCode === 'ENOTFOUND' ||
      errorCode === 'ECONNREFUSED' ||
      errorCode === 'EAI_AGAIN' ||
      errorMessage.includes('timeout') ||
      errorMessage.includes('econnreset') ||
      errorMessage.includes('etimedout') ||
      errorMessage.includes('network') ||
      errorMessage.includes('connection')
    ) {
      return {
        message: error.message,
        code: 'timeout',
        canRetry: true,
      };
    }

    // Firebase Storage 5xx server errors (retryable)
    const httpStatus = errorCode || (error as any).status || (error as any).statusCode;
    if (typeof httpStatus === 'number' && httpStatus >= 500 && httpStatus < 600) {
      return {
        message: error.message,
        code: 'provider_down',
        canRetry: true,
      };
    }

    // Firebase Storage 4xx client errors (non-retryable)
    if (httpStatus === 400 || httpStatus === 403 || httpStatus === 404) {
      return {
        message: error.message,
        code: 'bad_audio',
        canRetry: false,
      };
    }

    // Generic error (non-retryable)
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
  canRetry: boolean = false,
) {
  await doc.ref.update({
    status: 'error',
    workerStatus: 'failed',
    errorCode,
    errorMessage: message,
    canRetry,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

// Configuration constants for retry mechanism
const DEFAULT_MAX_RETRIES = 5;
const RETRY_DELAYS_MS = [
  5 * 60 * 1000, // Retry 1: 5 minutes
  15 * 60 * 1000, // Retry 2: 15 minutes
  60 * 60 * 1000, // Retry 3: 1 hour
  4 * 60 * 60 * 1000, // Retry 4: 4 hours
  24 * 60 * 60 * 1000, // Retry 5: 24 hours
];

/**
 * Scheduled function that runs every 5 minutes to manage retries for failed jobs.
 *
 * Invariants:
 * - retryCount is incremented only when a future retry is scheduled (setting retryScheduledAt).
 * - When a scheduled retry time has passed, we trigger the retry by setting status to 'uploaded'
 *   and clearing retryScheduledAt, without changing retryCount.
 */
export const scheduleRetryJobs = functions
  .region(REGION)
  .runWith({
    timeoutSeconds: 540,
    memory: '512MB',
  })
  .pubsub.schedule('*/5 * * * *') // Every 5 minutes
  .timeZone('UTC')
  .onRun(async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    functions.logger.info('Starting retry job scheduler', {
      timestamp: now.toDate().toISOString(),
    });

    try {
      // Query jobs that are eligible for retry
      const retryableJobsQuery = db
        .collection('transcription_jobs')
        .where('status', '==', 'error')
        .where('canRetry', '==', true)
        .limit(100); // Process up to 100 jobs at a time

      const snapshot = await retryableJobsQuery.get();

      if (snapshot.empty) {
        functions.logger.info('No jobs need retry scheduling');
        return;
      }

      let scheduled = 0;
      let skipped = 0;

      const updatePromises = snapshot.docs.map(async (doc) => {
        const jobData = { id: doc.id, ...doc.data() } as JobData;

        const retryCount = jobData.retryCount ?? 0;
        const maxRetries = jobData.maxRetries ?? DEFAULT_MAX_RETRIES;

        // Respect max retry limit
        if (retryCount >= maxRetries) {
          skipped++;
          functions.logger.debug('Job exceeded max retries', {
            jobId: doc.id,
            retryCount,
            maxRetries,
          });
          return;
        }

        const retryScheduledAt = jobData.retryScheduledAt;

        // Case 1: no retry scheduled yet -> schedule the first/next retry
        if (!retryScheduledAt) {
          const delayIndex = Math.min(retryCount, RETRY_DELAYS_MS.length - 1);
          const delayMs = RETRY_DELAYS_MS[delayIndex];
          const nextRetryTime = admin.firestore.Timestamp.fromMillis(
            now.toMillis() + delayMs,
          );

          try {
            await doc.ref.update({
              retryScheduledAt: nextRetryTime,
              retryCount: retryCount + 1,
              lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            });

            functions.logger.info('Scheduled retry for job', {
              jobId: doc.id,
              retryCount: retryCount + 1,
              nextRetryTime: nextRetryTime.toDate().toISOString(),
            });
            scheduled++;
          } catch (updateError) {
            functions.logger.error('Failed to schedule retry for job', {
              jobId: doc.id,
              error:
                updateError instanceof Error
                  ? updateError.message
                  : String(updateError),
            });
          }

          return;
        }

        // Case 2: retryScheduledAt exists -> check if it's time to trigger
        const scheduledTime =
          retryScheduledAt instanceof admin.firestore.Timestamp
            ? retryScheduledAt
            : null;

        if (!scheduledTime) {
          skipped++;
          return;
        }

        if (scheduledTime.toMillis() > now.toMillis()) {
          // Not yet time to retry
          skipped++;
          return;
        }

        // Time has passed -> trigger retry by setting status to 'uploaded'
        try {
          await doc.ref.update({
            status: 'uploaded',
            retryScheduledAt: admin.firestore.FieldValue.delete(),
            lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          functions.logger.info('Triggered retry for job', {
            jobId: doc.id,
            retryCount,
          });
          scheduled++;
        } catch (updateError) {
          functions.logger.error('Failed to trigger retry for job', {
            jobId: doc.id,
            error:
              updateError instanceof Error
                ? updateError.message
                : String(updateError),
          });
        }
      });

      await Promise.all(updatePromises);

      functions.logger.info('Retry job scheduler completed', {
        totalJobs: snapshot.docs.length,
        scheduled,
        skipped,
      });
    } catch (error) {
      functions.logger.error('Retry job scheduler failed', {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
      });
      throw error;
    }
  });


