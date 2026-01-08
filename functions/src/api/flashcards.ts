import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { generateFlashcards } from '../utils/openai-helpers';
import { saveFlashcards } from '../utils/firestore-helpers';
import { getTranscription } from '../utils/firestore-helpers';
import { db } from '../config/firebase-admin';

const REGION = 'europe-west2';

// Retry configuration
const FLASHCARDS_MAX_RETRIES = 3;
const FLASHCARDS_RETRY_BASE_DELAY_MS = 1000; // 1 second base delay

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// Helper function to check if an error is retryable
function isRetryableError(error: unknown): boolean {
  if (!(error instanceof Error)) {
    return false;
  }
  
  // Don't retry on abort
  if (error.message === 'Operation aborted') {
    return false;
  }
  
  // Retry on network errors, timeouts, rate limits, and server errors
  const retryablePatterns = [
    /timeout/i,
    /network/i,
    /ECONNRESET/i,
    /ETIMEDOUT/i,
    /rate limit/i,
    /429/i,
    /5\d{2}/, // 5xx server errors
    /503/i, // Service unavailable
    /502/i, // Bad gateway
  ];
  
  return retryablePatterns.some(pattern => 
    pattern.test(error.message) || pattern.test(error.stack || '')
  );
}

// POST /flashcards - Generate flashcards from content
app.post('/', async (req: Request, res: Response) => {
  // Create AbortController for request cancellation
  const abortController = new AbortController();
  const { signal } = abortController;
  let isAborted = false;

  // Set timeout for the request (5 minutes for Gemini generation)
  const timeout = setTimeout(() => {
    if (!res.headersSent) {
      isAborted = true;
      abortController.abort();
      res.status(504).json({
        error: 'Request timeout',
        message: 'Flashcard generation took too long. Please try again.',
      });
    }
  }, 300000); // 5 minutes

  try {
    const { sourceId, sourceType, numFlashcards = 10 } = req.body;

    if (!sourceId || !sourceType) {
      clearTimeout(timeout);
      if (!res.headersSent) {
        res.status(400).json({
          error: 'sourceId and sourceType are required',
        });
      }
      return;
    }

    // Get source content based on type
    let content = '';
    if (sourceType === 'transcription' || sourceType === 'note') {
      const transcription = await getTranscription(sourceId);
      if (!transcription) {
        clearTimeout(timeout);
        if (!res.headersSent) {
          res.status(404).json({ error: 'Transcription not found' });
        }
        return;
      }
      // For notes, prefer structured note content if available
      if (sourceType === 'note' && transcription.structuredNote) {
        const note = transcription.structuredNote;
        // Build content from structured note, validating each part
        const parts: string[] = [];
        
        if (note.title && note.title.trim()) {
          parts.push(`Title: ${note.title.trim()}`);
        }
        
        if (note.summary && note.summary.trim()) {
          parts.push(`Summary: ${note.summary.trim()}`);
        }
        
        const keyPoints = note.keyPoints || [];
        if (keyPoints.length > 0) {
          const validKeyPoints = keyPoints
            .filter((kp: any) => kp && String(kp).trim())
            .map((kp: any) => `• ${String(kp).trim()}`);
          if (validKeyPoints.length > 0) {
            parts.push(`Key Points:\n${validKeyPoints.join('\n')}`);
          }
        }
        
        const actionItems = note.actionItems || [];
        if (actionItems.length > 0) {
          const validActionItems = actionItems
            .filter((ai: any) => ai && String(ai).trim())
            .map((ai: any) => `• ${String(ai).trim()}`);
          if (validActionItems.length > 0) {
            parts.push(`Action Items:\n${validActionItems.join('\n')}`);
          }
        }
        
        const studyQuestions = note.studyQuestions || [];
        if (studyQuestions.length > 0) {
          const validQuestions = studyQuestions
            .filter((sq: any) => sq && String(sq).trim())
            .map((sq: any) => `• ${String(sq).trim()}`);
          if (validQuestions.length > 0) {
            parts.push(`Study Questions:\n${validQuestions.join('\n')}`);
          }
        }
        
        content = parts.join('\n\n');
        
        // If structured note has no valid content, fall back to raw text
        if (!content.trim() && transcription.text && transcription.text.trim()) {
          content = transcription.text.trim();
        }
      } else {
        content = transcription.text || '';
      }
    } else if (sourceType === 'summary') {
      const summaryDoc = await db.collection('summaries').doc(sourceId).get();
      if (!summaryDoc.exists) {
        clearTimeout(timeout);
        if (!res.headersSent) {
          res.status(404).json({ error: 'Summary not found' });
        }
        return;
      }
      const summary = summaryDoc.data();
      content = summary?.summaryText || '';
    } else {
      clearTimeout(timeout);
      if (!res.headersSent) {
        res.status(400).json({
          error: 'Invalid sourceType. Must be "transcription", "note", or "summary"',
        });
      }
      return;
    }

    // Trim and validate content
    content = content.trim();
    if (!content) {
      clearTimeout(timeout);
      if (!res.headersSent) {
        res.status(400).json({ 
          error: 'Source content is empty. Please ensure the source has valid content.',
        });
      }
      return;
    }
    
    // Minimum content length check
    if (content.length < 20) {
      clearTimeout(timeout);
      if (!res.headersSent) {
        res.status(400).json({ 
          error: 'Source content is too short to generate meaningful flashcards. Minimum 20 characters required.',
        });
      }
      return;
    }

    // Generate flashcards using Gemini with retry logic and abort signal
    let flashcardsData;
    let lastError: unknown = null;
    
    for (let attempt = 1; attempt <= FLASHCARDS_MAX_RETRIES; attempt++) {
      // Check if aborted before each attempt
      if (signal.aborted || isAborted) {
        // Already sent timeout response, just return
        return;
      }

      try {
        flashcardsData = await generateFlashcards({
          content,
          numFlashcards,
        });
        // Success - break out of retry loop
        break;
      } catch (error) {
        lastError = error;
        
        // Check if the error is due to abort
        if (signal.aborted || isAborted || (error instanceof Error && error.message === 'Operation aborted')) {
          // Already sent timeout response, just return
          return;
        }

        // Check if error is retryable and we have attempts left
        const isLastAttempt = attempt === FLASHCARDS_MAX_RETRIES;
        if (!isRetryableError(error) || isLastAttempt) {
          // Not retryable or out of attempts - throw the error
          throw error;
        }

        // Calculate exponential backoff delay
        const backoffDelay = Math.pow(2, attempt - 1) * FLASHCARDS_RETRY_BASE_DELAY_MS;
        console.log(
          `Flashcard generation attempt ${attempt} failed, retrying in ${backoffDelay}ms...`,
          error instanceof Error ? error.message : String(error)
        );

        // Wait before retrying, but check for abort during wait
        await new Promise<void>((resolve, reject) => {
          const delayTimeout = setTimeout(() => {
            if (signal.aborted || isAborted) {
              reject(new Error('Operation aborted'));
            } else {
              resolve();
            }
          }, backoffDelay);

          // If aborted during wait, clear timeout and reject
          signal.addEventListener('abort', () => {
            clearTimeout(delayTimeout);
            reject(new Error('Operation aborted'));
          }, { once: true });
        });
      }
    }

    // If we exhausted all retries without success, throw the last error
    if (!flashcardsData) {
      throw lastError || new Error('Failed to generate flashcards after all retry attempts');
    }

    // Clear timeout on successful generation
    clearTimeout(timeout);

    // Check if response was already sent (timeout) or operation was aborted before saving
    if (res.headersSent || signal.aborted || isAborted) {
      return;
    }

    // Save to Firestore
    const id = uuidv4();
    const flashcards = {
      id,
      sourceId,
      sourceType,
      flashcards: flashcardsData.map((fc: any, index: number) => ({
        id: `${id}-fc${index}`,
        ...fc,
        sourceId,
        sourceType,
      })),
      createdAt: new Date().toISOString(),
    };

    await saveFlashcards(flashcards);

    if (!res.headersSent) {
      res.status(201).json(flashcards);
    }
  } catch (error) {
    clearTimeout(timeout);
    console.error('Error in POST /flashcards:', error);
    
    // Don't send error response if already aborted or headers sent
    if (signal.aborted || isAborted || res.headersSent) {
      return;
    }
    
    res.status(500).json({
      error: 'Failed to generate flashcards',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export const flashcards = functions.region(REGION).https.onRequest(app);

