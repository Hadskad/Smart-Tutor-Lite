import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { summarizeText } from '../utils/openai-helpers';
import { extractTextFromPdf, downloadFile } from '../utils/storage-helpers';
import { saveSummary } from '../utils/firestore-helpers';

const MAX_PDF_BYTES = 25 * 1024 * 1024; // 25MB limit

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// POST /summaries - Generate summary from text or PDF
app.post('/', async (req: Request, res: Response) => {
  try {
    const { text, pdfUrl, maxLength = 200, sourceType } = req.body;

    if (!text && !pdfUrl) {
      res.status(400).json({ error: 'Either text or pdfUrl must be provided' });
      return;
    }

    let contentToSummarize = text;

    // If PDF URL provided, download and extract text
    if (pdfUrl && !text) {
      try {
        // Download PDF from Firebase Storage URL
        const pdfBuffer = await downloadFile(pdfUrl, {
          maxBytes: MAX_PDF_BYTES,
        });
        contentToSummarize = await extractTextFromPdf(pdfBuffer);
      } catch (error) {
        res.status(400).json({
          error: 'Failed to process PDF',
          message: error instanceof Error ? error.message : 'Unknown error',
        });
        return;
      }
    }

    if (!contentToSummarize) {
      res.status(400).json({ error: 'No content to summarize' });
      return;
    }

    // Generate summary using OpenAI
    const summaryText = await summarizeText({
      text: contentToSummarize,
      maxLength,
    });

    // Save to Firestore
    const id = uuidv4();
    const summary = {
      id,
      sourceType: sourceType || (pdfUrl ? 'pdf' : 'text'),
      sourceId: pdfUrl || undefined,
      summaryText,
      metadata: {
        originalLength: contentToSummarize.length,
        summaryLength: summaryText.length,
        maxLength,
      },
      createdAt: new Date().toISOString(),
    };

    await saveSummary(summary);

    res.status(201).json(summary);
  } catch (error) {
    console.error('Error in POST /summaries:', error);
    res.status(500).json({
      error: 'Failed to generate summary',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export const summaries = functions.https.onRequest(app);

