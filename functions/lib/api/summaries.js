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
exports.summaries = void 0;
const functions = __importStar(require("firebase-functions"));
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const uuid_1 = require("uuid");
const openai_helpers_1 = require("../utils/openai-helpers");
const storage_helpers_1 = require("../utils/storage-helpers");
const firestore_helpers_1 = require("../utils/firestore-helpers");
const MAX_PDF_BYTES = 25 * 1024 * 1024; // 25MB limit
const app = (0, express_1.default)();
app.use((0, cors_1.default)({ origin: true }));
app.use(express_1.default.json());
// POST /summaries - Generate summary from text or PDF
app.post('/', async (req, res) => {
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
                const pdfBuffer = await (0, storage_helpers_1.downloadFile)(pdfUrl, {
                    maxBytes: MAX_PDF_BYTES,
                });
                contentToSummarize = await (0, storage_helpers_1.extractTextFromPdf)(pdfBuffer);
            }
            catch (error) {
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
        const summaryText = await (0, openai_helpers_1.summarizeText)({
            text: contentToSummarize,
            maxLength,
        });
        // Save to Firestore
        const id = (0, uuid_1.v4)();
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
        await (0, firestore_helpers_1.saveSummary)(summary);
        res.status(201).json(summary);
    }
    catch (error) {
        console.error('Error in POST /summaries:', error);
        res.status(500).json({
            error: 'Failed to generate summary',
            message: error instanceof Error ? error.message : 'Unknown error',
        });
    }
});
exports.summaries = functions.https.onRequest(app);
//# sourceMappingURL=summaries.js.map