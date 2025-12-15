import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { generateQuiz } from '../utils/gemini-helpers';
import { saveQuiz } from '../utils/firestore-helpers';
import { getTranscription } from '../utils/firestore-helpers';
import { db } from '../config/firebase-admin';

const REGION = 'europe-west2';

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// POST /quizzes - Generate quiz from source content
app.post('/', async (req: Request, res: Response) => {
  try {
    const { sourceId, sourceType, numQuestions = 5, difficulty = 'medium' } =
      req.body;

    if (!sourceId || !sourceType) {
      res.status(400).json({
        error: 'sourceId and sourceType are required',
      });
      return;
    }

    // Get source content based on type
    let content = '';
    if (sourceType === 'transcription') {
      const transcription = await getTranscription(sourceId);
      if (!transcription) {
        res.status(404).json({ error: 'Transcription not found' });
        return;
      }
      content = transcription.text;
    } else if (sourceType === 'summary') {
      const summaryDoc = await db.collection('summaries').doc(sourceId).get();
      if (!summaryDoc.exists) {
        res.status(404).json({ error: 'Summary not found' });
        return;
      }
      const summary = summaryDoc.data();
      content = summary?.summaryText || '';
    } else {
      res.status(400).json({
        error: 'Invalid sourceType. Must be "transcription" or "summary"',
      });
      return;
    }

    if (!content) {
      res.status(400).json({ error: 'Source content is empty' });
      return;
    }

    // Generate quiz using Gemini
    const quizData = await generateQuiz({
      content,
      numQuestions,
      difficulty: difficulty as 'easy' | 'medium' | 'hard',
    });

    // Save to Firestore
    const id = uuidv4();
    const quiz = {
      id,
      title: `Quiz from ${sourceType}`,
      sourceId,
      sourceType,
      questions: quizData.questions.map((q: any, index: number) => ({
        id: `${id}-q${index}`,
        ...q,
      })),
      createdAt: new Date().toISOString(),
    };

    await saveQuiz(quiz);

    res.status(201).json(quiz);
  } catch (error) {
    console.error('Error in POST /quizzes:', error);
    res.status(500).json({
      error: 'Failed to generate quiz',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export const quizzes = functions.region(REGION).https.onRequest(app);

