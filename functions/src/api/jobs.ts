import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import * as admin from 'firebase-admin';

const REGION = 'europe-west2';
const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

const DEFAULT_MAX_RETRIES = 5;

type JobData = {
  id: string;
  status?: string;
  audioStoragePath?: string;
  canRetry?: boolean;
  retryCount?: number;
  maxRetries?: number;
};

// POST /jobs/:jobId/retry - Manually retry a failed transcription job
app.post('/:jobId/retry', async (req: Request, res: Response) => {
  try {
    const { jobId } = req.params;
    const db = admin.firestore();
    const jobRef = db.collection('transcription_jobs').doc(jobId);
    const jobDoc = await jobRef.get();

    if (!jobDoc.exists) {
      res.status(404).json({ error: 'Job not found' });
      return;
    }

    const jobData = { id: jobDoc.id, ...jobDoc.data() } as JobData;

    // Verify job can be retried
    if (jobData.status !== 'error' || !jobData.canRetry) {
      res.status(400).json({
        error: 'Job cannot be retried',
        message: 'Job is not in an error state or does not allow retry',
      });
      return;
    }

    // Check retry limits
    const retryCount = jobData.retryCount ?? 0;
    const maxRetries = jobData.maxRetries ?? DEFAULT_MAX_RETRIES;
    if (retryCount >= maxRetries) {
      res.status(400).json({
        error: 'Max retries exceeded',
        message: `Job has already been retried ${retryCount} times (max: ${maxRetries})`,
      });
      return;
    }

    // Verify audio storage path exists
    if (!jobData.audioStoragePath) {
      res.status(400).json({
        error: 'Cannot retry',
        message: 'Audio storage path is missing',
      });
      return;
    }

    // Reset retry fields and update status to 'uploaded' to trigger processTranscriptionJob
    await jobRef.update({
      status: 'uploaded',
      retryCount: (retryCount + 1),
      lastRetryAt: admin.firestore.FieldValue.serverTimestamp(),
      retryScheduledAt: admin.firestore.FieldValue.delete(),
      workerStatus: admin.firestore.FieldValue.delete(),
      errorCode: admin.firestore.FieldValue.delete(),
      errorMessage: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info('Manually triggered retry for job', {
      jobId,
      retryCount: retryCount + 1,
    });

    res.json({
      success: true,
      message: 'Job retry triggered successfully',
      jobId,
      retryCount: retryCount + 1,
    });
  } catch (error) {
    functions.logger.error('Error in POST /jobs/:jobId/retry:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export const jobs = functions.region(REGION).https.onRequest(app);

