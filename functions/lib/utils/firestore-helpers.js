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
Object.defineProperty(exports, "__esModule", { value: true });
exports.saveTranscription = saveTranscription;
exports.getTranscription = getTranscription;
exports.deleteTranscription = deleteTranscription;
exports.saveSummary = saveSummary;
exports.saveQuiz = saveQuiz;
exports.saveFlashcards = saveFlashcards;
const admin = __importStar(require("firebase-admin"));
const firebase_admin_1 = require("../config/firebase-admin");
/**
 * Save transcription to Firestore
 */
async function saveTranscription(data) {
    await firebase_admin_1.db.collection('transcriptions').doc(data.id).set({
        ...data,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
/**
 * Get transcription from Firestore
 */
async function getTranscription(id) {
    const doc = await firebase_admin_1.db.collection('transcriptions').doc(id).get();
    if (!doc.exists) {
        return null;
    }
    return { id: doc.id, ...doc.data() };
}
/**
 * Delete transcription from Firestore
 */
async function deleteTranscription(id) {
    await firebase_admin_1.db.collection('transcriptions').doc(id).delete();
}
/**
 * Save summary to Firestore
 */
async function saveSummary(data) {
    await firebase_admin_1.db.collection('summaries').doc(data.id).set({
        ...data,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
/**
 * Save quiz to Firestore
 */
async function saveQuiz(data) {
    await firebase_admin_1.db.collection('quizzes').doc(data.id).set({
        ...data,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
/**
 * Save flashcards to Firestore
 */
async function saveFlashcards(data) {
    await firebase_admin_1.db.collection('flashcards').doc(data.id).set({
        ...data,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}
//# sourceMappingURL=firestore-helpers.js.map