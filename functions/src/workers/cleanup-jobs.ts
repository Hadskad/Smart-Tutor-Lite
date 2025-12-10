import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import { deleteFile } from '../utils/storage-helpers';

const REGION = 'europe-west2';

// Configuration constants
const CLEANUP_GRACE_PERIOD_DAYS = 30; // For failed jobs' audio
const CLEANUP_DOCUMENT_RETENTION_DAYS = 90; // For job documents
const BATCH_SIZE = 100; // Process 100 jobs at a time to avoid timeout

type JobData = {
  id: string;
  status?: string;
  audioStoragePath?: string;
  updatedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  completedAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
  createdAt?: admin.firestore.Timestamp | admin.firestore.FieldValue;
};

/**
 * Scheduled function that runs daily at 2 AM UTC to clean up old transcription jobs
 */
export const cleanupOldTranscriptionJobs = functions
  .region(REGION)
  .runWith({
    timeoutSeconds: 540, // 9 minutes (max for background functions)
    memory: '512MB',
  })
  .pubsub.schedule('0 2 * * *') // Daily at 2 AM UTC (cron format)
  .timeZone('UTC')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    const gracePeriodMs = CLEANUP_GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000;
    const retentionPeriodMs = CLEANUP_DOCUMENT_RETENTION_DAYS * 24 * 60 * 60 * 1000;

    // Calculate cutoff timestamps
    const errorCutoffTimestamp = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - gracePeriodMs,
    );
    const completedCutoffTimestamp = admin.firestore.Timestamp.fromMillis(
      now.toMillis() - retentionPeriodMs,
    );

    functions.logger.info('Starting cleanup job', {
      errorCutoff: errorCutoffTimestamp.toDate().toISOString(),
      completedCutoff: completedCutoffTimestamp.toDate().toISOString(),
    });

    let totalProcessed = 0;
    let totalDeleted = 0;
    let totalErrors = 0;

    try {
      // Query 1: Failed jobs older than grace period (30 days)
      const failedJobsQuery = db
        .collection('transcription_jobs')
        .where('status', '==', 'error')
        .where('updatedAt', '<', errorCutoffTimestamp)
        .limit(BATCH_SIZE);

      await processBatch(
        failedJobsQuery,
        'error',
        errorCutoffTimestamp,
        completedCutoffTimestamp,
        (stats) => {
          totalProcessed += stats.processed;
          totalDeleted += stats.deleted;
          totalErrors += stats.errors;
        },
      );

      // Query 2: Completed jobs older than retention period (90 days)
      const completedJobsQuery = db
        .collection('transcription_jobs')
        .where('status', '==', 'completed')
        .where('completedAt', '<', completedCutoffTimestamp)
        .limit(BATCH_SIZE);

      await processBatch(
        completedJobsQuery,
        'completed',
        errorCutoffTimestamp,
        completedCutoffTimestamp,
        (stats) => {
          totalProcessed += stats.processed;
          totalDeleted += stats.deleted;
          totalErrors += stats.errors;
        },
      );

      functions.logger.info('Cleanup job completed', {
        totalProcessed,
        totalDeleted,
        totalErrors,
      });
    } catch (error) {
      functions.logger.error('Cleanup job failed', {
        error: error instanceof Error ? error.message : String(error),
        stack: error instanceof Error ? error.stack : undefined,
        totalProcessed,
        totalDeleted,
        totalErrors,
      });
      throw error;
    }
  });

/**
 * Process a batch of jobs for cleanup
 */
async function processBatch(
  query: admin.firestore.Query,
  jobType: 'error' | 'completed',
  errorCutoff: admin.firestore.Timestamp,
  completedCutoff: admin.firestore.Timestamp,
  onProgress: (stats: { processed: number; deleted: number; errors: number }) => void,
): Promise<void> {
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;
  let hasMore = true;
  let batchProcessed = 0;
  let batchDeleted = 0;
  let batchErrors = 0;

  while (hasMore) {
    let currentQuery = query;

    // Use cursor for pagination
    if (lastDoc) {
      currentQuery = query.startAfter(lastDoc);
    }

    const snapshot = await currentQuery.get();

    if (snapshot.empty) {
      hasMore = false;
      break;
    }

    // Process each job in the batch
    const deletePromises = snapshot.docs.map(async (doc) => {
      try {
        const jobData = { id: doc.id, ...doc.data() } as JobData;
        await cleanupJob(jobData, errorCutoff, completedCutoff, jobType);
        batchDeleted++;
        return { success: true, jobId: doc.id };
      } catch (error) {
        batchErrors++;
        functions.logger.error('Failed to cleanup job', {
          jobId: doc.id,
          error: error instanceof Error ? error.message : String(error),
        });
        return { success: false, jobId: doc.id, error };
      }
    });

    await Promise.all(deletePromises);
    batchProcessed += snapshot.docs.length;

    // Update progress
    onProgress({
      processed: batchProcessed,
      deleted: batchDeleted,
      errors: batchErrors,
    });

    // Check if we have more documents to process
    if (snapshot.docs.length < BATCH_SIZE) {
      hasMore = false;
    } else {
      lastDoc = snapshot.docs[snapshot.docs.length - 1];
    }

    // Log progress
    functions.logger.info(`Processed batch of ${jobType} jobs`, {
      batchProcessed,
      batchDeleted,
      batchErrors,
    });
  }
}

/**
 * Cleanup a single job: delete audio file and optionally the document
 */
async function cleanupJob(
  jobData: JobData,
  errorCutoff: admin.firestore.Timestamp,
  completedCutoff: admin.firestore.Timestamp,
  jobType: 'error' | 'completed',
): Promise<void> {
  const db = admin.firestore();
  const jobRef = db.collection('transcription_jobs').doc(jobData.id);

  // Determine if we should delete the document (older than 90 days)
  // For completed jobs: all are already > 90 days (from query filter), so always delete
  // For error jobs: only delete if updatedAt < 90 days (completedCutoff)
  const shouldDeleteDocument = (() => {
    if (jobType === 'completed') {
      // All completed jobs in this batch are already > 90 days old (from query filter)
      return true;
    }

    if (jobType === 'error' && jobData.updatedAt) {
      const updatedAt =
        jobData.updatedAt instanceof admin.firestore.Timestamp
          ? jobData.updatedAt
          : null;
      if (updatedAt && updatedAt.toMillis() < completedCutoff.toMillis()) {
        return true;
      }
    }

    return false;
  })();

  // Delete audio file from Storage if it exists
  if (jobData.audioStoragePath) {
    try {
      await deleteFile(jobData.audioStoragePath);
      functions.logger.info('Deleted audio file', {
        jobId: jobData.id,
        storagePath: jobData.audioStoragePath,
      });
    } catch (error) {
      // Log error but continue (file might already be deleted)
      functions.logger.warn('Failed to delete audio file (may not exist)', {
        jobId: jobData.id,
        storagePath: jobData.audioStoragePath,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }

  // Delete Firestore document if it's older than retention period
  if (shouldDeleteDocument) {
    try {
      await jobRef.delete();
      functions.logger.info('Deleted job document', {
        jobId: jobData.id,
        jobType,
      });
    } catch (error) {
      functions.logger.error('Failed to delete job document', {
        jobId: jobData.id,
        error: error instanceof Error ? error.message : String(error),
      });
      throw error; // Re-throw document deletion errors as they're more critical
    }
  } else {
    // Just update the document to mark that cleanup was attempted
    try {
      await jobRef.update({
        cleanupAttemptedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      functions.logger.debug('Marked job for cleanup (document retained)', {
        jobId: jobData.id,
        jobType,
      });
    } catch (error) {
      // Non-critical, just log
      functions.logger.warn('Failed to update cleanup timestamp', {
        jobId: jobData.id,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}

