import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import Busboy from 'busboy';
import { v4 as uuidv4 } from 'uuid';
import { uploadFile, deleteFile } from '../utils/storage-helpers';
import {
  saveTranscription,
  getTranscription,
  deleteTranscription,
} from '../utils/firestore-helpers';
import {
  SonioxError,
  transcribeWithSoniox,
} from '../utils/soniox-helpers';

const app = express();
app.use(cors({ origin: true }));
app.use(express.json());

// POST /transcriptions - Upload audio and transcribe
app.post('/', async (req: Request, res: Response) => {
  try {
    const bb = Busboy({ headers: req.headers });
    let fileBuffer: Buffer | null = null;
    let fileName: string | null = null;

    bb.on('file', (name: string, file: NodeJS.ReadableStream, info: Busboy.FileInfo) => {
      const { filename } = info;
      fileName = filename || 'audio.wav';
      const chunks: Buffer[] = [];

      file.on('data', (data: Buffer) => {
        chunks.push(data);
      });

      file.on('end', () => {
        fileBuffer = Buffer.concat(chunks);
      });
    });

    bb.on('finish', async () => {
      if (!fileBuffer || !fileName) {
        res.status(400).json({ error: 'No file uploaded' });
        return;
      }

      try {
        const id = uuidv4();
        const storagePath = `transcriptions/${id}/${fileName}`;

        // Upload to Firebase Storage
        const { signedUrl, storagePath: storedPath } = await uploadFile(
          fileBuffer,
          storagePath,
          'audio/wav',
        );

        const sonioxResult = await transcribeWithSoniox(fileBuffer);

        const transcription = {
          id,
          text: sonioxResult.text,
          audioPath: signedUrl,
          storagePath: storedPath,
          durationMs: 0, // Calculate from audio file
          timestamp: new Date().toISOString(),
          confidence: sonioxResult.confidence ?? 0.8,
          metadata: {
            source: 'soniox',
            fileName,
            confidence: sonioxResult.confidence,
          },
        };

        // Save to Firestore
        await saveTranscription(transcription);

        res.status(201).json(transcription);
      } catch (error) {
        console.error('Error processing transcription:', error);
        const status =
          error instanceof SonioxError && error.status ? error.status : 500;
        res.status(status).json({
          error: 'Failed to process transcription',
          message: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    });

    req.pipe(bb);
  } catch (error) {
    console.error('Error in POST /transcriptions:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// GET /transcriptions/:id - Get transcription by ID
app.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const transcription = await getTranscription(id);

    if (!transcription) {
      res.status(404).json({ error: 'Transcription not found' });
      return;
    }

    res.json(transcription);
  } catch (error) {
    console.error('Error in GET /transcriptions/:id:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// DELETE /transcriptions/:id - Delete transcription
app.delete('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;

    // Get transcription to find audio path
    const transcription = await getTranscription(id);
    if (!transcription) {
      res.status(404).json({ error: 'Transcription not found' });
      return;
    }

    // Delete from Storage (if storagePath exists)
    if (transcription.storagePath) {
      await deleteFile(transcription.storagePath);
    } else if (transcription.audioPath) {
      // Fallback for legacy records without storagePath
      const urlParts = transcription.audioPath.split('/');
      const pathIndex = urlParts.indexOf('transcriptions');
      if (pathIndex !== -1) {
        const derivedPath = urlParts.slice(pathIndex).join('/');
        await deleteFile(derivedPath);
      }
    }

    // Delete from Firestore
    await deleteTranscription(id);

    res.json({ success: true });
  } catch (error) {
    console.error('Error in DELETE /transcriptions/:id:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

export const transcriptions = functions.https.onRequest(app);

