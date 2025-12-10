import { storage } from '../config/firebase-admin';

// Use default bucket - automatically configured by Firebase Admin SDK
// This will use the project's default storage bucket
const getBucket = () => storage.bucket();

interface DownloadOptions {
  maxBytes?: number;
}

/**
 * Upload file to Firebase Storage
 */
export async function uploadFile(
  buffer: Buffer,
  path: string,
  contentType: string,
  expiresInSeconds: number = 24 * 3600,
): Promise<{ storagePath: string; signedUrl: string }> {
  const bucket = getBucket();
  const file = bucket.file(path);

  await file.save(buffer, {
    metadata: {
      contentType,
    },
  });

  const [signedUrl] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + expiresInSeconds * 1000,
  });

  return {
    storagePath: path,
    signedUrl,
  };
}

export async function downloadStorageObject(
  storagePath: string,
  destination: string,
): Promise<void> {
  const bucket = getBucket();
  await bucket.file(storagePath).download({ destination });
}

/**
 * Check if an error is retryable (network errors, 5xx server errors, timeouts)
 */
function isRetryableError(error: any): boolean {
  // Network errors
  if (error.code === 'ECONNRESET' || 
      error.code === 'ETIMEDOUT' || 
      error.code === 'ENOTFOUND' || 
      error.code === 'ECONNREFUSED' ||
      error.code === 'EAI_AGAIN' ||
      error.message?.includes('timeout') ||
      error.message?.includes('ECONNRESET') ||
      error.message?.includes('ETIMEDOUT')) {
    return true;
  }

  // HTTP 5xx server errors (retryable)
  const httpStatus = error.code || error.status || error.statusCode;
  if (typeof httpStatus === 'number' && httpStatus >= 500 && httpStatus < 600) {
    return true;
  }

  // Non-retryable errors
  if (httpStatus === 400 || httpStatus === 403 || httpStatus === 404) {
    return false;
  }

  // For unknown errors, don't retry (safer)
  return false;
}

/**
 * Download storage object with retry logic and exponential backoff
 * Max 3 retries with delays: 1s, 2s, 4s
 * Only retries on network errors, 5xx server errors, and timeouts
 */
export async function downloadStorageObjectWithRetry(
  storagePath: string,
  destination: string,
  maxRetries: number = 3,
): Promise<void> {
  const retryDelays = [1000, 2000, 4000]; // 1s, 2s, 4s

  let lastError: any = null;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      await downloadStorageObject(storagePath, destination);
      // Success - return immediately
      return;
    } catch (error) {
      lastError = error;

      // Don't retry on last attempt
      if (attempt >= maxRetries) {
        break;
      }

      // Check if error is retryable
      if (!isRetryableError(error)) {
        // Non-retryable error - throw immediately
        throw error;
      }

      // Wait before retrying (exponential backoff)
      const delay = retryDelays[attempt] || retryDelays[retryDelays.length - 1];
      await new Promise((resolve) => setTimeout(resolve, delay));
    }
  }

  // All retries exhausted - throw last error
  throw lastError;
}

/**
 * Get signed URL for file (for private files)
 */
export async function getSignedUrl(
  storagePath: string,
  expirySeconds?: number
): Promise<string> {
  const bucket = getBucket();
  const file = bucket.file(storagePath);

  // Verify file exists before generating URL
  const [exists] = await file.exists();
  if (!exists) {
    throw new Error(`File does not exist at path: ${storagePath}`);
  }

  // Verify file metadata
  const [metadata] = await file.getMetadata();
  if (!metadata) {
    throw new Error(`Cannot access file metadata at path: ${storagePath}`);
  }

  const expiry = expirySeconds ?? 18000; // Default 5 hours (18000 seconds)

  // Generate signed URL with proper configuration
  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + expiry * 1000,
    version: 'v4', // Explicitly use v4 signing
  });

  // Validate URL format
  if (!url || !url.startsWith('https://')) {
    throw new Error(`Invalid signed URL format generated for: ${storagePath}`);
  }

  return url;
}

/**
 * Delete file from Firebase Storage
 */
export async function deleteFile(path: string): Promise<void> {
  const bucket = getBucket();
  const file = bucket.file(path);

  await file.delete().catch((error) => {
    // Ignore if file doesn't exist
    if (error.code !== 404) {
      throw error;
    }
  });
}

/**
 * Download file from URL with optional size guard
 */
export async function downloadFile(
  url: string,
  options: DownloadOptions = {},
): Promise<Buffer> {
  const https = require('https');
  const http = require('http');
  const maxBytes = options.maxBytes ?? Infinity;

  return new Promise((resolve, reject) => {
    const protocol = url.startsWith('https') ? https : http;

    const request = protocol.get(url, (response: any) => {
      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download file: ${response.statusCode}`));
        return;
      }

      const contentLengthHeader = response.headers?.['content-length'];
      if (contentLengthHeader) {
        const contentLength = parseInt(contentLengthHeader, 10);
        if (!Number.isNaN(contentLength) && contentLength > maxBytes) {
          response.destroy();
          reject(
            new Error(
              `File is too large (${contentLength} bytes). Max allowed is ${maxBytes} bytes.`,
            ),
          );
          return;
        }
      }

      const chunks: Buffer[] = [];
      let downloadedBytes = 0;

      response.on('data', (chunk: Buffer) => {
        downloadedBytes += chunk.length;
        if (downloadedBytes > maxBytes) {
          response.destroy();
          reject(
            new Error(
              `File exceeded maximum size of ${maxBytes} bytes during download.`,
            ),
          );
          return;
        }
        chunks.push(chunk);
      });

      response.on('end', () => resolve(Buffer.concat(chunks)));
      response.on('error', (err: Error) => reject(err));
    });

    request.on('error', (err: Error) => reject(err));
  });
}

/**
 * Extract text from PDF buffer
 */
export async function extractTextFromPdf(pdfBuffer: Buffer): Promise<string> {
  const pdfParse = require('pdf-parse');
  const data = await pdfParse(pdfBuffer);
  return data.text;
}

// Alternative function to get public URL
export async function getPublicUrl(
  storagePath: string,
  makePublic: boolean = false
): Promise<string> {
  const bucket = getBucket();
  const file = bucket.file(storagePath);

  // Verify file exists
  const [exists] = await file.exists();
  if (!exists) {
    throw new Error(`File does not exist at path: ${storagePath}`);
  }

  // Option 1: Make file public temporarily
  if (makePublic) {
    await file.makePublic();
    // Get public URL
    return `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
  }

  // Option 2: Use signed URL (preferred)
  return getSignedUrl(storagePath);
}

