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
exports.quizzes = void 0;
const functions = __importStar(require("firebase-functions"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const uuid_1 = require("uuid");
const openai_helpers_1 = require("../utils/openai-helpers");
const firestore_helpers_1 = require("../utils/firestore-helpers");
const firestore_helpers_2 = require("../utils/firestore-helpers");
const firebase_admin_1 = require("../config/firebase-admin");
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json());
// POST /quizzes - Generate quiz from source content
app.post('/', async (req, res) => {
    try {
        const { sourceId, sourceType, numQuestions = 5, difficulty = 'medium' } = req.body;
        if (!sourceId || !sourceType) {
            res.status(400).json({
                error: 'sourceId and sourceType are required',
            });
            return;
        }
        // Get source content based on type
        let content = '';
        if (sourceType === 'transcription') {
            const transcription = await (0, firestore_helpers_2.getTranscription)(sourceId);
            if (!transcription) {
                res.status(404).json({ error: 'Transcription not found' });
                return;
            }
            content = transcription.text;
        }
        else if (sourceType === 'summary') {
            const summaryDoc = await firebase_admin_1.db.collection('summaries').doc(sourceId).get();
            if (!summaryDoc.exists) {
                res.status(404).json({ error: 'Summary not found' });
                return;
            }
            const summary = summaryDoc.data();
            content = summary?.summaryText || '';
        }
        else {
            res.status(400).json({
                error: 'Invalid sourceType. Must be "transcription" or "summary"',
            });
            return;
        }
        if (!content) {
            res.status(400).json({ error: 'Source content is empty' });
            return;
        }
        // Generate quiz using OpenAI
        const quizData = await (0, openai_helpers_1.generateQuiz)({
            content,
            numQuestions,
            difficulty: difficulty,
        });
        // Save to Firestore
        const id = (0, uuid_1.v4)();
        const quiz = {
            id,
            title: `Quiz from ${sourceType}`,
            sourceId,
            sourceType,
            questions: quizData.questions.map((q, index) => ({
                id: `${id}-q${index}`,
                ...q,
            })),
            createdAt: new Date().toISOString(),
        };
        await (0, firestore_helpers_1.saveQuiz)(quiz);
        res.status(201).json(quiz);
    }
    catch (error) {
        console.error('Error in POST /quizzes:', error);
        res.status(500).json({
            error: 'Failed to generate quiz',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
exports.quizzes = functions.https.onRequest(app);
//# sourceMappingURL=quizzes.js.map