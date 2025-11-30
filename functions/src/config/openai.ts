import OpenAI from 'openai';
import * as functions from 'firebase-functions';

// Get OpenAI API key from Firebase Functions config
const config = functions.config();
const apiKey = config.openai?.api_key || process.env.OPENAI_API_KEY;

if (!apiKey) {
  throw new Error('OpenAI API key not found. Set it using: firebase functions:config:set openai.api_key="YOUR_KEY"');
}

// Initialize OpenAI client
export const openai = new OpenAI({
  apiKey: apiKey,
});

// Helper function to get OpenAI client (for testing/mocking)
export const getOpenAIClient = () => openai;

