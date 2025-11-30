import * as functions from 'firebase-functions';
import express, { Request, Response } from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';
import { db, admin } from '../config/firebase-admin';
import { uploadFile, extractTextFromPdf, downloadFile } from '../utils/storage-helpers';
import { textToSpeechLong } from '../utils/tts-helpers';
import { VoiceId, DEFAULT_VOICE_ID } from '../config/elevenlabs-tts';

const app = express();
const MAX_PDF_BYTES = 25 * 1024 * 1024; // 25MB limit
app.use(cors({ origin: true }));
app.use(express.json());

// POST /tts - Convert PDF or text to audio
app.post('/', async (req: Request, res: Response) => {
  try {
    const { sourceType, sourceId, voice = DEFAULT_VOICE_ID } = req.body;

    if (!sourceType || !sourceId) {
      res.status(400).json({
        error: 'sourceType and sourceId are required',
      });
      return;
    }

    const id = uuidv4();

    // Create initial job record
    const ttsJob = {
      id,
      sourceType,
      sourceId,
      audioUrl: '',
      storagePath: '',
      status: 'processing',
      voice,
      createdAt: new Date().toISOString(),
    };

    await db.collection('tts_jobs').doc(id).set({
      ...ttsJob,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Process asynchronously
    processTextToSpeech(id, sourceType, sourceId, voice as VoiceId)
        .catch((error) => {
          console.error('TTS processing error:', error);
        });

    res.status(201).json(ttsJob);
  } catch (error) {
    console.error('Error in POST /tts:', error);
    res.status(500).json({
      error: 'Failed to process TTS request',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// GET /tts/:id - Get TTS job status
app.get('/:id', async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const doc = await db.collection('tts_jobs').doc(id).get();

    if (!doc.exists) {
      res.status(404).json({ error: 'TTS job not found' });
      return;
    }

    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    console.error('Error in GET /tts/:id:', error);
    res.status(500).json({
      error: 'Failed to get TTS job',
      message: error instanceof Error ? error.message : 'Unknown error',
    });
  }
});

// Background processing function
async function processTextToSpeech(
  jobId: string,
  sourceType: string,
  sourceId: string,
  voice: VoiceId,
): Promise<void> {
  try {
    let text = '';

    // Get text based on source type
    if (sourceType === 'pdf') {
      // Download PDF from URL and extract text
      const pdfBuffer = await downloadFile(sourceId, {
        maxBytes: MAX_PDF_BYTES,
      });
      text = await extractTextFromPdf(pdfBuffer);
    } else if (sourceType === 'text') {
      text = sourceId;
    } else {
      throw new Error(`Invalid sourceType: ${sourceType}`);
    }

    if (!text) {
      throw new Error('No text content to convert');
    }

    // Convert text to speech
    const audioBuffer = await textToSpeechLong({ text, voice });

    // Upload to Firebase Storage
    const storagePath = `tts/${jobId}/audio.mp3`;
    const { signedUrl, storagePath: storedPath } = await uploadFile(
      audioBuffer,
      storagePath,
      'audio/mpeg',
    );

    // Update job status
    await db.collection('tts_jobs').doc(jobId).update({
      audioUrl: signedUrl,
      storagePath: storedPath,
      status: 'completed',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('TTS processing failed:', error);
    await db.collection('tts_jobs').doc(jobId).update({
      status: 'failed',
      errorMessage: error instanceof Error ? error.message : 'Unknown error',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }
}

export const tts = functions.https.onRequest(app);
