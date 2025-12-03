"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.tts = void 0;
const functions = __importStar(require("firebase-functions"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const uuid_1 = require("uuid");
const firebase_admin_1 = require("../config/firebase-admin");
const storage_helpers_1 = require("../utils/storage-helpers");
const tts_helpers_1 = require("../utils/tts-helpers");
const elevenlabs_tts_1 = require("../config/elevenlabs-tts");
const app = (0, express_1.default)();
const MAX_PDF_BYTES = 25 * 1024 * 1024; // 25MB limit
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json());
// POST /tts - Convert PDF or text to audio
app.post('/', async (req, res) => {
    try {
        const { sourceType, sourceId, voice = elevenlabs_tts_1.DEFAULT_VOICE_ID } = req.body;
        if (!sourceType || !sourceId) {
            res.status(400).json({
                error: 'sourceType and sourceId are required',
            });
            return;
        }
        const id = (0, uuid_1.v4)();
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
        await firebase_admin_1.db.collection('tts_jobs').doc(id).set({
            ...ttsJob,
            createdAt: firebase_admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
        // Process asynchronously
        processTextToSpeech(id, sourceType, sourceId, voice)
            .catch((error) => {
            console.error('TTS processing error:', error);
        });
        res.status(201).json(ttsJob);
    }
    catch (error) {
        console.error('Error in POST /tts:', error);
        res.status(500).json({
            error: 'Failed to process TTS request',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
// GET /tts/:id - Get TTS job status
app.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const doc = await firebase_admin_1.db.collection('tts_jobs').doc(id).get();
        if (!doc.exists) {
            res.status(404).json({ error: 'TTS job not found' });
            return;
        }
        res.json({ id: doc.id, ...doc.data() });
    }
    catch (error) {
        console.error('Error in GET /tts/:id:', error);
        res.status(500).json({
            error: 'Failed to get TTS job',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
// Background processing function
async function processTextToSpeech(jobId, sourceType, sourceId, voice) {
    try {
        let text = '';
        // Get text based on source type
        if (sourceType === 'pdf') {
            // Download PDF from URL and extract text
            const pdfBuffer = await (0, storage_helpers_1.downloadFile)(sourceId, {
                maxBytes: MAX_PDF_BYTES,
            });
            text = await (0, storage_helpers_1.extractTextFromPdf)(pdfBuffer);
        }
        else if (sourceType === 'text') {
            text = sourceId;
        }
        else {
            throw new Error(`Invalid sourceType: ${sourceType}`);
        }
        if (!text) {
            throw new Error('No text content to convert');
        }
        // Convert text to speech
        const audioBuffer = await (0, tts_helpers_1.textToSpeechLong)({ text, voice });
        // Upload to Firebase Storage
        const storagePath = `tts/${jobId}/audio.mp3`;
        const { signedUrl, storagePath: storedPath } = await (0, storage_helpers_1.uploadFile)(audioBuffer, storagePath, 'audio/mpeg');
        // Update job status
        await firebase_admin_1.db.collection('tts_jobs').doc(jobId).update({
            audioUrl: signedUrl,
            storagePath: storedPath,
            status: 'completed',
            updatedAt: firebase_admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        console.error('TTS processing failed:', error);
        await firebase_admin_1.db.collection('tts_jobs').doc(jobId).update({
            status: 'failed',
            errorMessage: error instanceof Error ? error.message : 'Unknown error',
            updatedAt: firebase_admin_1.admin.firestore.FieldValue.serverTimestamp(),
        });
    }
}
exports.tts = functions.https.onRequest(app);
//# sourceMappingURL=tts.js.map