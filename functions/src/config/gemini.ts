import { GoogleGenerativeAI } from '@google/generative-ai';
import * as functions from 'firebase-functions';

// Get Gemini API key from Firebase Functions config
const config = functions.config();
const apiKey = config.gemini?.api_key || process.env.GEMINI_API_KEY;

if (!apiKey) {
  throw new Error('Gemini API key not found. Set it using: firebase functions:config:set gemini.api_key="YOUR_KEY"');
}

// Initialize Gemini client
export const genAI = new GoogleGenerativeAI(apiKey);

// Helper function to get Gemini client (for testing/mocking)
export const getGeminiClient = () => genAI;

