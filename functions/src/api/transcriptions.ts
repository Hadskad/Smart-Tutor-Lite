import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import Busboy from 'busboy';
import { v4 as uuidv4 } from 'uuid';
import { uploadFile, deleteFile } from '../utils/storage-helpers';
import {
  saveTranscription,
  getTranscription,
  deleteTranscription,
  updateTranscriptionStatus,
} from '../utils/firestore-helpers';
import {
  SonioxError,
  transcribeWithSoniox,
} from '../utils/soniox-helpers';

const REGION = 'europe-west2';
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// POST /transcriptions - Upload audio and transcribe
app.post('/', async (req: Request, res: Response) => {
  try {
    const bb = Busboy({ headers: req.headers });
    let fileBuffer: Buffer | null = null;
    let fileName: string | null = null;

    bb.on('file', (name: string, file: NodeJS.ReadableStream, info: Busboy.FileInfo) => {
      const { filename } = info;
      fileName = filename || 'audio.wav';
      const chunks: Buffer[] = [];

      file.on('data', (data: Buffer) => {
        chunks.push(data);
      });

      file.on('end', () => {
        fileBuffer = Buffer.concat(chunks);
      });
    });

    bb.on('finish', async () => {
      if (!fileBuffer || !fileName) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      let storedPath: string | null = null;
      let transcriptionId: string | null = null;
      try {
        const id = uuidv4();
        transcriptionId = id;
        const storagePath = `transcriptions/${id}/${fileName}`;

        // Upload to Firebase Storage
        const { signedUrl, storagePath: uploadedPath } = await uploadFile(
          fileBuffer,
          storagePath,
          'audio/wav',
        );
        storedPath = uploadedPath;

        // Transcribe using storage path
        const sonioxResult = await transcribeWithSoniox(storedPath);

        const transcription = {
          id,
          text: sonioxResult.text,
          audioPath: signedUrl,
          storagePath: storedPath,
          durationMs: 0, // Calculate from audio file
          timestamp: new Date().toISOString(),
          confidence: sonioxResult.confidence ?? 0.8,
          status: 'completed' as const,
          metadata: {
            source: 'soniox',
            fileName,
            confidence: sonioxResult.confidence,
          },
        };

        // Save to Firestore
        await saveTranscription(transcription);

        res.status(201).json(transcription);
      } catch (error) {
        // Determine if error is permanent (should delete file) or transient (should preserve for retry)
        const isPermanentError =
          error instanceof SonioxError &&
          (error.code === 'bad_audio' ||
            error.code === 'quota_exceeded' ||
            error.code === 'too_long' ||
            error.code === 'unauthorized');

        const isTransientError =
          error instanceof SonioxError &&
          (error.code === 'provider_down' || error.code === 'timeout');

        const errorCode =
          error instanceof SonioxError ? error.code : 'unknown';
        const errorMessage =
          error instanceof Error ? error.message : 'Unknown error';
        // Only allow retry for transient errors (preserve file but don't auto-retry unknown errors)
        const canRetry = isTransientError;

        // Only delete file for permanent errors
        if (isPermanentError && storedPath) {
          try {
            await deleteFile(storedPath);
            functions.logger.info('Deleted uploaded file after permanent error', {
              transcriptionId,
              storagePath: storedPath,
              errorCode,
            });
          } catch (cleanupError) {
            functions.logger.error('Failed to cleanup uploaded file', {
              transcriptionId,
              storagePath: storedPath,
              error: cleanupError,
            });
          }
        }

        // Save transcription document with error status if we have an ID and storage path
        if (transcriptionId && storedPath) {
          try {
            await saveTranscription({
              id: transcriptionId,
              storagePath: storedPath,
              status: 'failed',
              errorCode,
              errorMessage,
              canRetry,
              retryCount: 0,
              timestamp: new Date().toISOString(),
              metadata: {
                source: 'soniox',
                fileName: fileName || 'audio.wav',
              },
            });
            functions.logger.info('Saved failed transcription document', {
              transcriptionId,
              errorCode,
              canRetry,
            });
          } catch (saveError) {
            functions.logger.error('Failed to save failed transcription document', {
              transcriptionId,
              error: saveError,
            });
          }
        }

        functions.logger.error('Error processing transcription', {
          transcriptionId,
          errorCode,
          errorMessage,
          canRetry,
          isPermanentError,
        });

        const status =
          error instanceof SonioxError && error.status ? error.status : 500;
        res.status(status).json({
          error: 'Failed to process transcription',
          message: errorMessage,
          transcriptionId: transcriptionId || undefined,
          canRetry,
          errorCode,
        });
      }
    });

    req.pipe(bb);
  } catch (error) {
    functions.logger.error('Error in POST /transcriptions:', {
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// GET /transcriptions/:id - Get transcription by ID
app.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const transcription = await getTranscription(id);

    if (!transcription) {
      res.status(404).json({ error: 'Transcription not found' });
      return;
    }

    res.json(transcription);
  } catch (error) {
    functions.logger.error('Error in GET /transcriptions/:id:', {
      transcriptionId: req.params.id,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// POST /transcriptions/:id/retry - Manually retry a failed transcription
app.post('/:id/retry', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const transcription = await getTranscription(id);

    if (!transcription) {
      res.status(404).json({ error: 'Transcription not found' });
      return;
    }

    // Verify transcription can be retried
    if (transcription.status !== 'failed' && !transcription.canRetry) {
      res.status(400).json({
        error: 'Transcription cannot be retried',
        message: 'Transcription is not in a failed state or does not allow retry',
      });
      return;
    }

    // Check retry limits
    const retryCount = transcription.retryCount ?? 0;
    const maxRetries = 5; // Default max retries
    if (retryCount >= maxRetries) {
      res.status(400).json({
        error: 'Max retries exceeded',
        message: `Transcription has already been retried ${retryCount} times (max: ${maxRetries})`,
      });
      return;
    }

    // Verify storage path exists
    if (!transcription.storagePath) {
      res.status(400).json({
        error: 'Cannot retry',
        message: 'Audio file storage path is missing',
      });
      return;
    }

    // Reset retry fields and update status to trigger processing
    await updateTranscriptionStatus(id, {
      status: 'processing',
      retryCount: retryCount + 1,
      lastRetryAt: new Date().toISOString(),
      errorCode: undefined,
      errorMessage: undefined,
    });

    // Trigger transcription by calling transcribeWithSoniox
    try {
      const sonioxResult = await transcribeWithSoniox(transcription.storagePath);

      // Update transcription with success
      await updateTranscriptionStatus(id, {
        status: 'completed',
        text: sonioxResult.text,
        confidence: sonioxResult.confidence ?? 0.8,
      });

      const updatedTranscription = await getTranscription(id);
      res.json({
        success: true,
        message: 'Transcription retry successful',
        transcription: updatedTranscription,
      });
    } catch (error) {
      // Update transcription with failure
      const errorCode =
        error instanceof Error && 'code' in error
          ? (error as any).code
          : 'unknown';
      const errorMessage =
        error instanceof Error ? error.message : 'Unknown error';
      const isTransientError =
        errorCode === 'provider_down' || errorCode === 'timeout';

      await updateTranscriptionStatus(id, {
        status: 'failed',
        errorCode,
        errorMessage,
        canRetry: isTransientError,
      });

      const transcription = await getTranscription(id);
      const retryCount = (transcription?.retryCount ?? 0) + 1;
      const maxRetries = 5;

      functions.logger.error('Transcription retry failed', {
        transcriptionId: id,
        errorCode,
        errorMessage,
        canRetry: isTransientError,
        retryCount,
        maxRetries,
        storagePath: transcription?.storagePath,
      });

      res.status(500).json({
        error: 'Transcription retry failed',
        message: errorMessage,
        transcriptionId: id,
        canRetry: isTransientError,
        errorCode,
        retryCount,
        maxRetries,
      });
    }
  } catch (error) {
    functions.logger.error('Error in POST /transcriptions/:id/retry:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// DELETE /transcriptions/:id - Delete transcription
app.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    // Get transcription to find audio path
    const transcription = await getTranscription(id);
    if (!transcription) {
      res.status(404).json({ error: 'Transcription not found' });
      return;
    }

    // Delete from Storage (if storagePath exists)
    if (transcription.storagePath) {
      await deleteFile(transcription.storagePath);
    } else if (transcription.audioPath) {
      // Fallback for legacy records without storagePath
      const urlParts = transcription.audioPath.split('/');
      const pathIndex = urlParts.indexOf('transcriptions');
      if (pathIndex !== -1) {
        const derivedPath = urlParts.slice(pathIndex).join('/');
        await deleteFile(derivedPath);
      }
    }

    // Delete from Firestore
    await deleteTranscription(id);

    res.json({ success: true });
  } catch (error) {
    functions.logger.error('Error in DELETE /transcriptions/:id:', {
      transcriptionId: req.params.id,
      error: error instanceof Error ? error.message : String(error),
      stack: error instanceof Error ? error.stack : undefined,
    });
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export const transcriptions = functions.region(REGION).https.onRequest(app);

