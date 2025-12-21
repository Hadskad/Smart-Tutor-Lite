import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { generateFlashcards } from '../utils/gemini-helpers';
import { saveFlashcards } from '../utils/firestore-helpers';
import { getTranscription } from '../utils/firestore-helpers';
import { db } from '../config/firebase-admin';

const REGION = 'europe-west2';

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// POST /flashcards - Generate flashcards from content
app.post('/', async (req: Request, res: Response) => {
  // Set timeout for the request (60 seconds for Gemini generation)
  const timeout = setTimeout(() => {
    if (!res.headersSent) {
      res.status(504).json({
        error: 'Request timeout',
        message: 'Flashcard generation took too long. Please try again with shorter content.',
      });
    }
  }, 300000); // 5 minutes

  try {
    const { sourceId, sourceType, numFlashcards = 10 } = req.body;

    if (!sourceId || !sourceType) {
      clearTimeout(timeout);
      res.status(400).json({
        error: 'sourceId and sourceType are required',
      });
      return;
    }

    // Get source content based on type
    let content = '';
    if (sourceType === 'transcription' || sourceType === 'note') {
      const transcription = await getTranscription(sourceId);
      if (!transcription) {
        clearTimeout(timeout);
        res.status(404).json({ error: 'Transcription not found' });
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
        res.status(404).json({ error: 'Summary not found' });
        return;
      }
      const summary = summaryDoc.data();
      content = summary?.summaryText || '';
    } else {
      clearTimeout(timeout);
      res.status(400).json({
        error: 'Invalid sourceType. Must be "transcription", "note", or "summary"',
      });
      return;
    }

    // Trim and validate content
    content = content.trim();
    if (!content) {
      clearTimeout(timeout);
      res.status(400).json({ 
        error: 'Source content is empty. Please ensure the source has valid content.',
      });
      return;
    }
    
    // Minimum content length check
    if (content.length < 20) {
      clearTimeout(timeout);
      res.status(400).json({ 
        error: 'Source content is too short to generate meaningful flashcards. Minimum 20 characters required.',
      });
      return;
    }

    // Generate flashcards using Gemini
    const flashcardsData = await generateFlashcards({
      content,
      numFlashcards,
    });

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

    clearTimeout(timeout);
    if (!res.headersSent) {
      res.status(201).json(flashcards);
    }
  } catch (error) {
    clearTimeout(timeout);
    console.error('Error in POST /flashcards:', error);
    if (!res.headersSent) {
      res.status(500).json({
        error: 'Failed to generate flashcards',
        message: error instanceof Error ? error.message : 'Unknown error',
      });
    }
  }
});

export const flashcards = functions.region(REGION).https.onRequest(app);

