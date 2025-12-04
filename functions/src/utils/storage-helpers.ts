import { storage } from '../config/firebase-admin';

const BUCKET_NAME =
  process.env.FIREBASE_STORAGE_BUCKET ?? 'smart-tutor-lite-a66b5.appspot.com';

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
  const bucket = storage.bucket(BUCKET_NAME);
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
  const bucket = storage.bucket(BUCKET_NAME);
  await bucket.file(storagePath).download({ destination });
}

/**
 * Get signed URL for file (for private files)
 */
export async function getSignedUrl(
  path: string,
  expiresIn: number = 3600
): Promise<string> {
  const bucket = storage.bucket(BUCKET_NAME);
  const file = bucket.file(path);

  const [url] = await file.getSignedUrl({
    action: 'read',
    expires: Date.now() + expiresIn * 1000,
  });

  return url;
}

/**
 * Delete file from Firebase Storage
 */
export async function deleteFile(path: string): Promise<void> {
  const bucket = storage.bucket(BUCKET_NAME);
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

