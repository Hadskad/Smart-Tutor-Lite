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
exports.transcriptions = void 0;
const functions = __importStar(require("firebase-functions"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const busboy_1 = __importDefault(require("busboy"));
const uuid_1 = require("uuid");
const storage_helpers_1 = require("../utils/storage-helpers");
const firestore_helpers_1 = require("../utils/firestore-helpers");
const soniox_helpers_1 = require("../utils/soniox-helpers");
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json());
// POST /transcriptions - Upload audio and transcribe
app.post('/', async (req, res) => {
    try {
        const bb = (0, busboy_1.default)({ headers: req.headers });
        let fileBuffer = null;
        let fileName = null;
        bb.on('file', (name, file, info) => {
            const { filename } = info;
            fileName = filename || 'audio.wav';
            const chunks = [];
            file.on('data', (data) => {
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
                const id = (0, uuid_1.v4)();
                const storagePath = `transcriptions/${id}/${fileName}`;
                // Upload to Firebase Storage
                const { signedUrl, storagePath: storedPath } = await (0, storage_helpers_1.uploadFile)(fileBuffer, storagePath, 'audio/wav');
                const sonioxResult = await (0, soniox_helpers_1.transcribeWithSoniox)(fileBuffer);
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
                await (0, firestore_helpers_1.saveTranscription)(transcription);
                res.status(201).json(transcription);
            }
            catch (error) {
                console.error('Error processing transcription:', error);
                const status = error instanceof soniox_helpers_1.SonioxError && error.status ? error.status : 500;
                res.status(status).json({
                    error: 'Failed to process transcription',
                    message: error instanceof Error ? error.message : 'Unknown error',
                });
            }
        });
        req.pipe(bb);
    }
    catch (error) {
        console.error('Error in POST /transcriptions:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
// GET /transcriptions/:id - Get transcription by ID
app.get('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        const transcription = await (0, firestore_helpers_1.getTranscription)(id);
        if (!transcription) {
            res.status(404).json({ error: 'Transcription not found' });
            return;
        }
        res.json(transcription);
    }
    catch (error) {
        console.error('Error in GET /transcriptions/:id:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
// DELETE /transcriptions/:id - Delete transcription
app.delete('/:id', async (req, res) => {
    try {
        const { id } = req.params;
        // Get transcription to find audio path
        const transcription = await (0, firestore_helpers_1.getTranscription)(id);
        if (!transcription) {
            res.status(404).json({ error: 'Transcription not found' });
            return;
        }
        // Delete from Storage (if storagePath exists)
        if (transcription.storagePath) {
            await (0, storage_helpers_1.deleteFile)(transcription.storagePath);
        }
        else if (transcription.audioPath) {
            // Fallback for legacy records without storagePath
            const urlParts = transcription.audioPath.split('/');
            const pathIndex = urlParts.indexOf('transcriptions');
            if (pathIndex !== -1) {
                const derivedPath = urlParts.slice(pathIndex).join('/');
                await (0, storage_helpers_1.deleteFile)(derivedPath);
            }
        }
        // Delete from Firestore
        await (0, firestore_helpers_1.deleteTranscription)(id);
        res.json({ success: true });
    }
    catch (error) {
        console.error('Error in DELETE /transcriptions/:id:', error);
        res.status(500).json({
            error: 'Internal server error',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
exports.transcriptions = functions.https.onRequest(app);
//# sourceMappingURL=transcriptions.js.map