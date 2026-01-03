import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { db, admin } from '../config/firebase-admin';
import {
  uploadFile,
  extractTextFromPdf,
  downloadFile,
} from '../utils/storage-helpers';
import { textToSpeechLong, synthesizeLongAudio } from '../utils/google-tts-helpers';
import { VoiceId, DEFAULT_VOICE_NAME } from '../config/google-tts';
import { pollOperationUntilDone, cancelOperation } from '../utils/operation-poller';
import {
  uploadTextToGCS,
  generateGCSOutputUri,
  downloadAudioFromGCS,
  deleteGCSFile,
} from '../utils/gcs-helpers';

const app = express();
const MAX_PDF_BYTES = 25 * 1024 * 1024; // 25MB limit
const REGION = 'europe-west2';
// Threshold for using async batch processing (synthesizeLongAudio)
// For texts > 100K characters, use async batch processing
const ASYNC_BATCH_THRESHOLD = 100000; // 100K characters
const MAX_RETRIES = 3; // Maximum retries for transient failures
app.use(cors({ origin: true }));
app.use(express.json());

// POST /tts - Convert PDF or text to audio
app.post('/', async (req: Request, res: Response) => {
  try {
    const { sourceType, sourceId, voice = DEFAULT_VOICE_NAME } = req.body;

    if (!sourceType || !sourceId) {
      res.status(400).json({
        error: 'sourceType and sourceId are required',
      });
      return;
    }

    const id = uuidv4();

    // Create initial job record
    const ttsJob = {
      id,
      sourceType,
      sourceId,
      audioUrl: '',
      storagePath: '',
      status: 'processing',
      voice,
      createdAt: new Date().toISOString(),
    };

    await db.collection('tts_jobs').doc(id).set({
      ...ttsJob,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Process asynchronously
    processTextToSpeech(id, sourceType, sourceId, voice as VoiceId)
        .catch((error) => {
          console.error('TTS processing error:', error);
        });

    res.status(201).json(ttsJob);
  } catch (error) {
    console.error('Error in POST /tts:', error);
    res.status(500).json({
      error: 'Failed to process TTS request',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// GET /tts/:id - Get TTS job status
app.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const doc = await db.collection('tts_jobs').doc(id).get();

    if (!doc.exists) {
      res.status(404).json({ error: 'TTS job not found' });
      return;
    }

    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    console.error('Error in GET /tts/:id:', error);
    res.status(500).json({
      error: 'Failed to get TTS job',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// DELETE /tts/:id - Delete TTS job and associated audio file
app.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    
    // Get job document first to check for storagePath
    const docRef = db.collection('tts_jobs').doc(id);
    const doc = await docRef.get();

    if (!doc.exists) {
      res.status(404).json({ error: 'Audio file not found' });
      return;
    }

    const jobData = doc.data();
    
    // Delete audio file from Firebase Storage if exists
    if (jobData?.storagePath) {
      try {
        const bucket = admin.storage().bucket();
        await bucket.file(jobData.storagePath).delete();
        console.log(`[Job ${id}] Deleted audio file: ${jobData.storagePath}`);
      } catch (storageError) {
        // Log but don't fail if storage deletion fails
        // File may have already been deleted or path may be invalid
        console.warn(
          `[Job ${id}] Failed to delete audio file from storage:`,
          storageError,
        );
      }
    }

    // Clean up GCS temporary files if async batch processing was used
    // These files are only created for large texts (> 100K chars)
    if (jobData?.operationName) {
      console.log(
        `[Job ${id}] Async batch processing detected (operationName: ${jobData.operationName}). ` +
        `Cancelling operation and cleaning up GCS temporary files...`,
      );
      
      // Cancel the running operation to free up resources
      // This is best-effort - operation may already be completed or failed
      if (jobData.status === 'processing') {
        await cancelOperation(jobData.operationName).catch((error) => {
          console.warn(`[Job ${id}] Failed to cancel operation:`, error);
        });
      }
      
      try {
        const inputGcsUri = `gs://${admin.storage().bucket().name}/tts-input/${id}-input.txt`;
        const outputGcsUri = generateGCSOutputUri(id);
        
        // Delete GCS files in parallel
        await Promise.allSettled([
          deleteGCSFile(inputGcsUri).catch((error) => {
            console.warn(`[Job ${id}] Failed to delete input GCS file:`, error);
          }),
          deleteGCSFile(outputGcsUri).catch((error) => {
            console.warn(`[Job ${id}] Failed to delete output GCS file:`, error);
          }),
        ]);
        
        console.log(`[Job ${id}] GCS temporary files cleanup completed`);
      } catch (gcsError) {
        // Log but don't fail - GCS cleanup is best-effort
        console.warn(
          `[Job ${id}] Error during GCS cleanup:`,
          gcsError,
        );
      }
    }

    // Delete the Firestore document
    await docRef.delete();
    console.log(`[Job ${id}] Deleted TTS job document`);

    res.status(200).json({ 
      success: true, 
      message: 'TTS job deleted successfully',
      id,
    });
  } catch (error) {
    console.error('Error in DELETE /tts/:id:', error);
    res.status(500).json({
      error: 'Failed to delete TTS job',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

/**
 * Check if an error is retryable (network errors, 5xx server errors, timeouts)
 */
function isRetryableError(error: any): boolean {
  // Network errors
  if (
    error.code === 'ECONNRESET' ||
    error.code === 'ETIMEDOUT' ||
    error.code === 'ENOTFOUND' ||
    error.code === 'ECONNREFUSED' ||
    error.code === 'EAI_AGAIN' ||
    error.message?.includes('timeout') ||
    error.message?.includes('ECONNRESET') ||
    error.message?.includes('ETIMEDOUT') ||
    error.message?.includes('503') ||
    error.message?.includes('502') ||
    error.message?.includes('504')
  ) {
    return true;
  }

  // HTTP 5xx server errors (retryable)
  const httpStatus = error.code || error.status || error.statusCode;
  if (typeof httpStatus === 'number' && httpStatus >= 500 && httpStatus < 600) {
    return true;
  }

  return false;
}

/**
 * Update job status with error handling
 */
async function updateJobStatus(
  jobId: string,
  updates: {
    status?: string;
    errorMessage?: string;
    audioUrl?: string;
    storagePath?: string;
    operationName?: string;
  },
): Promise<void> {
  try {
    await db.collection('tts_jobs').doc(jobId).update({
      ...updates,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error(`[Job ${jobId}] Failed to update job status:`, error);
    // Don't throw - job status update failure shouldn't crash processing
  }
}

// Background processing function
async function processTextToSpeech(
  jobId: string,
  sourceType: string,
  sourceId: string,
  voice: VoiceId,
): Promise<void> {
  const processingStartTime = Date.now();
  let inputGcsUri: string | null = null;
  let outputGcsUri: string | null = null;
  let operationName: string | null = null;

  try {
    console.log(`[Job ${jobId}] Starting TTS processing. Source type: ${sourceType}`);
    let text = '';

    // Get text based on source type
    if (sourceType === 'pdf') {
      console.log(`[Job ${jobId}] Downloading PDF from: ${sourceId}`);
      // Download PDF from URL and extract text
      const pdfBuffer = await downloadFile(sourceId, {
        maxBytes: MAX_PDF_BYTES,
      });
      text = await extractTextFromPdf(pdfBuffer);
      console.log(`[Job ${jobId}] Extracted ${text.length} characters from PDF`);
    } else if (sourceType === 'text') {
      text = sourceId;
      console.log(`[Job ${jobId}] Processing text input (${text.length} characters)`);
    } else {
      throw new Error(`Invalid sourceType: ${sourceType}`);
    }

    if (!text) {
      throw new Error('No text content to convert');
    }

    // Determine processing method based on text length
    const useAsyncBatch = text.length > ASYNC_BATCH_THRESHOLD;

    if (useAsyncBatch) {
      console.log(
        `[Job ${jobId}] Text length (${text.length}) exceeds threshold ` +
        `(${ASYNC_BATCH_THRESHOLD}). Using async batch processing (synthesizeLongAudio).`,
      );

      // Update job with processing status
      await updateJobStatus(jobId, {
        status: 'processing',
      });

      // Upload text to GCS
      const inputFileName = `${jobId}-input.txt`;
      inputGcsUri = await uploadTextToGCS(text, inputFileName);
      console.log(`[Job ${jobId}] Uploaded input text to GCS: ${inputGcsUri}`);

      // Generate output GCS URI
      outputGcsUri = generateGCSOutputUri(jobId);
      console.log(`[Job ${jobId}] Output will be saved to: ${outputGcsUri}`);

      // Submit async batch job with retry logic
      let operation;
      let lastError: any = null;

      for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
        try {
          operation = await synthesizeLongAudio({
            inputGcsUri,
            outputGcsUri,
            voice,
          });
          break; // Success - exit retry loop
        } catch (error) {
          lastError = error;
          if (attempt < MAX_RETRIES && isRetryableError(error)) {
            const delay = Math.pow(2, attempt) * 1000; // Exponential backoff: 1s, 2s, 4s
            console.warn(
              `[Job ${jobId}] Retryable error on attempt ${attempt + 1}/${MAX_RETRIES + 1}: ` +
              `${error instanceof Error ? error.message : 'Unknown error'}. ` +
              `Retrying after ${delay}ms...`,
            );
            await new Promise((resolve) => setTimeout(resolve, delay));
            continue;
          }
          throw error; // Non-retryable or max retries exceeded
        }
      }

      if (!operation) {
        throw lastError || new Error('Failed to submit synthesizeLongAudio operation');
      }

      operationName = operation.name;
      console.log(`[Job ${jobId}] Submitted async batch operation: ${operationName}`);

      // Update job with operation name
      await updateJobStatus(jobId, {
        status: 'processing',
        operationName,
      });

      // Poll operation until completion
      console.log(`[Job ${jobId}] Starting to poll operation for completion...`);
      const operationResult = await pollOperationUntilDone(
        operationName,
        24 * 60 * 60 * 1000, // 24 hours max wait
        jobId,
      );

      // Check if operation failed
      if (operationResult.error) {
        throw new Error(
          `Operation failed: ${operationResult.error.message} (Code: ${operationResult.error.code})`,
        );
      }

      if (!operationResult.done) {
        throw new Error('Operation did not complete successfully');
      }

      console.log(`[Job ${jobId}] Operation completed. Downloading audio from GCS...`);

      // Download audio from GCS
      const audioBuffer = await downloadAudioFromGCS(outputGcsUri);
      console.log(
        `[Job ${jobId}] Downloaded audio (${audioBuffer.length} bytes) from GCS. ` +
        `Uploading to Firebase Storage...`,
      );

      // Upload to Firebase Storage
      const storagePath = `tts/${jobId}/audio.mp3`;
      const { signedUrl, storagePath: storedPath } = await uploadFile(
        audioBuffer,
        storagePath,
        'audio/mpeg',
      );

      const processingDuration = Date.now() - processingStartTime;
      console.log(
        `[Job ${jobId}] TTS processing completed successfully in ${Math.round(processingDuration / 1000)}s. ` +
        `Audio URL: ${signedUrl}`,
      );

      // Update job status
      await updateJobStatus(jobId, {
        status: 'completed',
        audioUrl: signedUrl,
        storagePath: storedPath,
        operationName,
      });

      // Cleanup GCS files (input and output)
      try {
        await Promise.all([
          deleteGCSFile(inputGcsUri),
          deleteGCSFile(outputGcsUri),
        ]);
        console.log(`[Job ${jobId}] Cleaned up GCS input and output files`);
      } catch (cleanupError) {
        // Log but don't fail the job if cleanup fails
        console.warn(`[Job ${jobId}] Failed to cleanup GCS files:`, cleanupError);
      }
    } else {
      // Use synchronous processing for smaller texts
      console.log(
        `[Job ${jobId}] Text length (${text.length}) within threshold. ` +
        `Using synchronous processing (textToSpeechLong).`,
      );

      await updateJobStatus(jobId, {
        status: 'processing',
      });

      // Convert text to speech
      const audioBuffer = await textToSpeechLong({ text, voice });
      console.log(`[Job ${jobId}] Generated audio (${audioBuffer.length} bytes)`);

      // Upload to Firebase Storage
      const storagePath = `tts/${jobId}/audio.mp3`;
      const { signedUrl, storagePath: storedPath } = await uploadFile(
        audioBuffer,
        storagePath,
        'audio/mpeg',
      );

      const processingDuration = Date.now() - processingStartTime;
      console.log(
        `[Job ${jobId}] TTS processing completed successfully in ${Math.round(processingDuration / 1000)}s. ` +
        `Audio URL: ${signedUrl}`,
      );

      // Update job status
      await updateJobStatus(jobId, {
        status: 'completed',
        audioUrl: signedUrl,
        storagePath: storedPath,
      });
    }
  } catch (error) {
    const processingDuration = Date.now() - processingStartTime;
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    
    console.error(
      `[Job ${jobId}] TTS processing failed after ${Math.round(processingDuration / 1000)}s:`,
      error,
    );

    // Cleanup GCS files on error
    const cleanupPromises: Promise<void>[] = [];
    if (inputGcsUri) {
      cleanupPromises.push(
        deleteGCSFile(inputGcsUri).catch((cleanupError) => {
          console.warn(`[Job ${jobId}] Failed to cleanup input GCS file:`, cleanupError);
        }),
      );
    }
    if (outputGcsUri) {
      cleanupPromises.push(
        deleteGCSFile(outputGcsUri).catch((cleanupError) => {
          console.warn(`[Job ${jobId}] Failed to cleanup output GCS file:`, cleanupError);
        }),
      );
    }

    // Wait for cleanup to complete (but don't fail if cleanup fails)
    await Promise.allSettled(cleanupPromises);

    // Update job status to failed
    await updateJobStatus(jobId, {
      status: 'failed',
      errorMessage: errorMessage,
      operationName: operationName || undefined,
    });
  }
}

export const tts = functions.region(REGION).https.onRequest(app);
