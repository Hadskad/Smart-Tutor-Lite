import * as admin from 'firebase-admin';

// Initialize Firebase Admin SDK
// In production, this uses the default service account
// For local development, set GOOGLE_APPLICATION_CREDENTIALS environment variable
if (!admin.apps.length) {
  admin.initializeApp();
}

// Export Firestore and Storage instances
export const db = admin.firestore();
export const storage = admin.storage();
export const adminApp = admin.app();

// Export admin for use in other modules
export { admin };

