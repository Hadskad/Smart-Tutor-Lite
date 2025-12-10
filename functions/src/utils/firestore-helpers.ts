import * as admin from 'firebase-admin';
import { db } from '../config/firebase-admin';

/**
 * Save transcription to Firestore
 */
export async function saveTranscription(data: {
  id: string;
  text?: string;
  audioPath?: string;
  storagePath?: string;
  durationMs?: number;
  timestamp?: string;
  confidence?: number;
  metadata?: Record<string, any>;
  status?: 'completed' | 'failed' | 'processing';
  errorCode?: string;
  errorMessage?: string;
  canRetry?: boolean;
  retryCount?: number;
  lastRetryAt?: string;
}): Promise<void> {
  await db.collection('transcriptions').doc(data.id).set({
    ...data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Update transcription status and retry fields
 */
export async function updateTranscriptionStatus(
  id: string,
  updates: {
    status?: 'completed' | 'failed' | 'processing';
    errorCode?: string;
    errorMessage?: string;
    canRetry?: boolean;
    retryCount?: number;
    lastRetryAt?: string;
    text?: string;
    confidence?: number;
  },
): Promise<void> {
  await db.collection('transcriptions').doc(id).update({
    ...updates,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Get transcription from Firestore
 */
export async function getTranscription(id: string): Promise<any | null> {
  const doc = await db.collection('transcriptions').doc(id).get();
  if (!doc.exists) {
    return null;
  }
  return { id: doc.id, ...doc.data() };
}

/**
 * Delete transcription from Firestore
 */
export async function deleteTranscription(id: string): Promise<void> {
  await db.collection('transcriptions').doc(id).delete();
}

/**
 * Save summary to Firestore
 */
export async function saveSummary(data: {
  id: string;
  sourceType: string;
  sourceId?: string;
  summaryText: string;
  metadata?: Record<string, any>;
}): Promise<void> {
  await db.collection('summaries').doc(data.id).set({
    ...data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Save quiz to Firestore
 */
export async function saveQuiz(data: {
  id: string;
  title: string;
  sourceId: string;
  sourceType: string;
  questions: Array<any>;
}): Promise<void> {
  await db.collection('quizzes').doc(data.id).set({
    ...data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

/**
 * Save flashcards to Firestore
 */
export async function saveFlashcards(data: {
  id: string;
  sourceId: string;
  sourceType: string;
  flashcards: Array<any>;
}): Promise<void> {
  await db.collection('flashcards').doc(data.id).set({
    ...data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export async function saveStudyNote(data: {
  id: string;
  transcriptionId: string;
  title: string;
  summary: string;
  keyPoints: string[];
  actionItems: string[];
  studyQuestions?: string[];
  metadata?: Record<string, any>;
}): Promise<void> {
  await db.collection('study_notes').doc(data.id).set({
    ...data,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}


