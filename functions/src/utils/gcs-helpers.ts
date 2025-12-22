import { storage } from '../config/firebase-admin';

/**
 * Get the default GCS bucket instance
 * Firebase Admin Storage IS Google Cloud Storage
 */
function getGCSBucket() {
  return storage.bucket();
}

/**
 * Get the bucket name for constructing GCS URIs
 */
export function getGCSBucketName(): string {
  const bucket = getGCSBucket();
  return bucket.name;
}

/**
 * Upload text content to GCS as a text file
 * @param text - Text content to upload
 * @param fileName - Name of the file (e.g., 'job-123.txt')
 * @returns GCS URI (gs://bucket-name/path/to/file)
 */
export async function uploadTextToGCS(
  text: string,
  fileName: string,
): Promise<string> {
  const bucket = getGCSBucket();
  const filePath = `tts-input/${fileName}`;
  const file = bucket.file(filePath);

  // Upload text as UTF-8 encoded buffer
  const buffer = Buffer.from(text, 'utf-8');
  
  await file.save(buffer, {
    metadata: {
      contentType: 'text/plain',
    },
  });

  // Return GCS URI format: gs://bucket-name/path
  return `gs://${bucket.name}/${filePath}`;
}

/**
 * Generate GCS URI for output audio file
 * @param jobId - Job ID to use in the file path
 * @returns GCS URI (gs://bucket-name/path/to/output.mp3)
 */
export function generateGCSOutputUri(jobId: string): string {
  const bucketName = getGCSBucketName();
  const filePath = `tts-output/${jobId}.mp3`;
  return `gs://${bucketName}/${filePath}`;
}

/**
 * Download audio file from GCS
 * @param gcsUri - GCS URI (gs://bucket-name/path/to/file)
 * @returns Audio file as Buffer
 */
export async function downloadAudioFromGCS(gcsUri: string): Promise<Buffer> {
  // Parse GCS URI: gs://bucket-name/path/to/file
  const uriMatch = gcsUri.match(/^gs:\/\/([^/]+)\/(.+)$/);
  if (!uriMatch) {
    throw new Error(`Invalid GCS URI format: ${gcsUri}`);
  }

  const [, bucketName, filePath] = uriMatch;
  const bucket = storage.bucket(bucketName);
  const file = bucket.file(filePath);

  // Check if file exists
  const [exists] = await file.exists();
  if (!exists) {
    throw new Error(`File does not exist at GCS URI: ${gcsUri}`);
  }

  // Download file as buffer
  const [buffer] = await file.download();
  return buffer as Buffer;
}

/**
 * Delete a file from GCS
 * @param gcsUri - GCS URI (gs://bucket-name/path/to/file)
 */
export async function deleteGCSFile(gcsUri: string): Promise<void> {
  // Parse GCS URI: gs://bucket-name/path/to/file
  const uriMatch = gcsUri.match(/^gs:\/\/([^/]+)\/(.+)$/);
  if (!uriMatch) {
    throw new Error(`Invalid GCS URI format: ${gcsUri}`);
  }

  const [, bucketName, filePath] = uriMatch;
  const bucket = storage.bucket(bucketName);
  const file = bucket.file(filePath);

  // Delete file, ignore 404 errors (file doesn't exist)
  try {
    await file.delete();
  } catch (error: any) {
    // Ignore 404 - file doesn't exist, which is fine
    if (error.code !== 404) {
      throw error;
    }
  }
}

/**
 * Delete multiple files from GCS
 * Useful for cleanup operations
 * @param gcsUris - Array of GCS URIs to delete
 */
export async function deleteGCSFiles(gcsUris: string[]): Promise<void> {
  // Delete files in parallel, but don't fail if some don't exist
  const deletePromises = gcsUris.map((uri) =>
    deleteGCSFile(uri).catch((error) => {
      // Log error but don't throw - cleanup should be resilient
      console.warn(`Failed to delete GCS file ${uri}:`, error);
    }),
  );

  await Promise.all(deletePromises);
}


