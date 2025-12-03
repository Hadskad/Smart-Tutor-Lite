"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.uploadFile = uploadFile;
exports.getSignedUrl = getSignedUrl;
exports.deleteFile = deleteFile;
exports.downloadFile = downloadFile;
exports.extractTextFromPdf = extractTextFromPdf;
const firebase_admin_1 = require("../config/firebase-admin");
const BUCKET_NAME = process.env.FIREBASE_STORAGE_BUCKET ?? 'smart-tutor-lite-a66b5.appspot.com';
/**
 * Upload file to Firebase Storage
 */
async function uploadFile(buffer, path, contentType, expiresInSeconds = 24 * 3600) {
    const bucket = firebase_admin_1.storage.bucket(BUCKET_NAME);
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
/**
 * Get signed URL for file (for private files)
 */
async function getSignedUrl(path, expiresIn = 3600) {
    const bucket = firebase_admin_1.storage.bucket(BUCKET_NAME);
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
async function deleteFile(path) {
    const bucket = firebase_admin_1.storage.bucket(BUCKET_NAME);
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
async function downloadFile(url, options = {}) {
    const https = require('https');
    const http = require('http');
    const maxBytes = options.maxBytes ?? Infinity;
    return new Promise((resolve, reject) => {
        const protocol = url.startsWith('https') ? https : http;
        const request = protocol.get(url, (response) => {
            if (response.statusCode !== 200) {
                reject(new Error(`Failed to download file: ${response.statusCode}`));
                return;
            }
            const contentLengthHeader = response.headers?.['content-length'];
            if (contentLengthHeader) {
                const contentLength = parseInt(contentLengthHeader, 10);
                if (!Number.isNaN(contentLength) && contentLength > maxBytes) {
                    response.destroy();
                    reject(new Error(`File is too large (${contentLength} bytes). Max allowed is ${maxBytes} bytes.`));
                    return;
                }
            }
            const chunks = [];
            let downloadedBytes = 0;
            response.on('data', (chunk) => {
                downloadedBytes += chunk.length;
                if (downloadedBytes > maxBytes) {
                    response.destroy();
                    reject(new Error(`File exceeded maximum size of ${maxBytes} bytes during download.`));
                    return;
                }
                chunks.push(chunk);
            });
            response.on('end', () => resolve(Buffer.concat(chunks)));
            response.on('error', (err) => reject(err));
        });
        request.on('error', (err) => reject(err));
    });
}
/**
 * Extract text from PDF buffer
 */
async function extractTextFromPdf(pdfBuffer) {
    const pdfParse = require('pdf-parse');
    const data = await pdfParse(pdfBuffer);
    return data.text;
}
//# sourceMappingURL=storage-helpers.js.map