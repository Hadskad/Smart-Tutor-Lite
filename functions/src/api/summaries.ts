import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { summarizeText } from '../utils/openai-helpers';
import { extractTextFromPdf, downloadFile } from '../utils/storage-helpers';
import { saveSummary } from '../utils/firestore-helpers';

const MAX_PDF_BYTES = 30 * 1024 * 1024; // 30MB limit (matches client)
const MIN_CONTENT_LENGTH = 50; // Minimum characters to summarize
const REGION = 'europe-west2';

// Error types for specific handling
enum SummaryErrorType {
  INVALID_INPUT = 'INVALID_INPUT',
  PDF_TOO_LARGE = 'PDF_TOO_LARGE',
  PDF_PROCESSING_FAILED = 'PDF_PROCESSING_FAILED',
  PDF_EMPTY = 'PDF_EMPTY',
  CONTENT_TOO_SHORT = 'CONTENT_TOO_SHORT',
  AI_GENERATION_FAILED = 'AI_GENERATION_FAILED',
  AI_TIMEOUT = 'AI_TIMEOUT',
  STORAGE_ERROR = 'STORAGE_ERROR',
  SERVER_ERROR = 'SERVER_ERROR',
}

interface SummaryError {
  type: SummaryErrorType;
  message: string;
  details?: string;
}

function createErrorResponse(error: SummaryError, statusCode: number, res: Response): void {
  res.status(statusCode).json({
    error: error.type,
    message: error.message,
    ...(error.details && { details: error.details }),
  });
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ limit: '35mb' })); // Allow slightly larger than max for overhead

// POST /summaries - Generate summary from text or PDF
app.post('/', async (req: Request, res: Response) => {
  try {
    const { text, pdfUrl, sourceType } = req.body;

    // Validate input
    if (!text && !pdfUrl) {
      createErrorResponse(
        {
          type: SummaryErrorType.INVALID_INPUT,
          message: 'Please provide either text content or a PDF file to summarize.',
        },
        400,
        res
      );
      return;
    }

    let contentToSummarize = text;
    let extractedFromPdf = false;

    // If PDF URL provided, download and extract text
    if (pdfUrl && !text) {
      try {
        // Download PDF from Firebase Storage URL
        const pdfBuffer = await downloadFile(pdfUrl, {
          maxBytes: MAX_PDF_BYTES,
        });
        
        contentToSummarize = await extractTextFromPdf(pdfBuffer);
        extractedFromPdf = true;
      } catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        
        // Check for specific error types
        if (errorMessage.includes('too large') || errorMessage.includes('exceeded')) {
          createErrorResponse(
            {
              type: SummaryErrorType.PDF_TOO_LARGE,
              message: `PDF file is too large. Maximum size is ${MAX_PDF_BYTES / (1024 * 1024)}MB.`,
            },
            413,
            res
          );
          return;
        }
        
        if (errorMessage.includes('404') || errorMessage.includes('not found')) {
          createErrorResponse(
            {
              type: SummaryErrorType.STORAGE_ERROR,
              message: 'PDF file not found. It may have been deleted or the link expired.',
            },
            404,
            res
          );
          return;
        }
        
        createErrorResponse(
          {
            type: SummaryErrorType.PDF_PROCESSING_FAILED,
            message: 'Failed to process the PDF file. Please ensure it is a valid PDF document.',
            details: errorMessage,
          },
          400,
          res
        );
        return;
      }
    }

    // Validate extracted/provided content
    if (!contentToSummarize || !contentToSummarize.trim()) {
      createErrorResponse(
        {
          type: extractedFromPdf ? SummaryErrorType.PDF_EMPTY : SummaryErrorType.INVALID_INPUT,
          message: extractedFromPdf 
            ? 'The PDF appears to be empty or contains only images/scanned content that cannot be read.'
            : 'No text content provided to summarize.',
        },
        400,
        res
      );
      return;
    }

    // Trim and validate content length
    contentToSummarize = contentToSummarize.trim();
    
    if (contentToSummarize.length < MIN_CONTENT_LENGTH) {
      createErrorResponse(
        {
          type: SummaryErrorType.CONTENT_TOO_SHORT,
          message: `Content is too short to generate a meaningful summary. Please provide at least ${MIN_CONTENT_LENGTH} characters.`,
        },
        400,
        res
      );
      return;
    }

    // Determine if this is a PDF summary
    const isPdf = (pdfUrl && !text) || sourceType === 'pdf';
    
    // Generate summary using Gemini
    let summaryText: string;
    try {
      summaryText = await summarizeText({
        text: contentToSummarize,
        isPdf: isPdf,
      });
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      
      // Check for timeout errors
      if (errorMessage.includes('timeout') || errorMessage.includes('DEADLINE_EXCEEDED')) {
        createErrorResponse(
          {
            type: SummaryErrorType.AI_TIMEOUT,
            message: 'Summary generation timed out. This may happen with very large documents. Please try again or use a smaller document.',
          },
          504,
          res
        );
        return;
      }
      
      // Check for rate limiting
      if (errorMessage.includes('429') || errorMessage.includes('rate limit')) {
        createErrorResponse(
          {
            type: SummaryErrorType.AI_GENERATION_FAILED,
            message: 'Service is temporarily busy. Please wait a moment and try again.',
          },
          429,
          res
        );
        return;
      }
      
      createErrorResponse(
        {
          type: SummaryErrorType.AI_GENERATION_FAILED,
          message: 'Failed to generate summary. Please try again.',
          details: errorMessage,
        },
        500,
        res
      );
      return;
    }

    // Validate summary was generated
    if (!summaryText || !summaryText.trim()) {
      createErrorResponse(
        {
          type: SummaryErrorType.AI_GENERATION_FAILED,
          message: 'Summary generation returned empty content. Please try again.',
        },
        500,
        res
      );
      return;
    }

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
        compressionRatio: (summaryText.length / contentToSummarize.length * 100).toFixed(1) + '%',
      },
      createdAt: new Date().toISOString(),
    };

    await saveSummary(summary);

    res.status(201).json(summary);
  } catch (error) {
    console.error('Error in POST /summaries:', error);
    createErrorResponse(
      {
        type: SummaryErrorType.SERVER_ERROR,
        message: 'An unexpected error occurred. Please try again later.',
        details: error instanceof Error ? error.message : 'Unknown error',
      },
      500,
      res
    );
  }
});

// Configure function with extended timeout for AI processing
export const summaries = functions
  .region(REGION)
  .runWith({
    timeoutSeconds: 540, // 9 minutes (max for 1st gen functions)
    memory: '1GB',
  })
  .https.onRequest(app);
