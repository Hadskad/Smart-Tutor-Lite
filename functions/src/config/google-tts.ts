import { TextToSpeechClient } from '@google-cloud/text-to-speech';

// Google Cloud TTS Configuration
export const DEFAULT_VOICE_NAME = 'en-US-Neural2-D';

// Voice ID type - string to support voice names like 'en-US-Neural2-D'
export type VoiceId = string;

// Popular Neural2 voices
export const NEURAL2_VOICES = {
  'en-US-Neural2-A': {
    name: 'Neural2-A',
    description: 'Female voice',
    gender: 'FEMALE',
  },
  'en-US-Neural2-B': {
    name: 'Neural2-B',
    description: 'Male voice',
    gender: 'MALE',
  },
  'en-US-Neural2-C': {
    name: 'Neural2-C',
    description: 'Female voice',
    gender: 'FEMALE',
  },
  'en-US-Neural2-D': {
    name: 'Neural2-D',
    description: 'Male voice (Default)',
    gender: 'MALE',
  },
  'en-US-Neural2-E': {
    name: 'Neural2-E',
    description: 'Female voice',
    gender: 'FEMALE',
  },
  'en-US-Neural2-F': {
    name: 'Neural2-F',
    description: 'Female voice',
    gender: 'FEMALE',
  },
  'en-US-Neural2-G': {
    name: 'Neural2-G',
    description: 'Female voice',
    gender: 'FEMALE',
  },
  'en-US-Neural2-H': {
    name: 'Neural2-H',
    description: 'Female voice',
    gender: 'FEMALE',
  },
  'en-US-Neural2-I': {
    name: 'Neural2-I',
    description: 'Male voice',
    gender: 'MALE',
  },
  'en-US-Neural2-J': {
    name: 'Neural2-J',
    description: 'Male voice',
    gender: 'MALE',
  },
};

/**
 * Get Google Cloud TTS service account credentials
 * Supports Firebase Secrets and environment variables
 */
export function getServiceAccountCredentials(): object {
  // Try Firebase Secret first (for production)
  let credentialsString: string | undefined;
  
  try {
    // Access secret via environment variable (Firebase Functions automatically
    // injects secrets as environment variables)
    credentialsString = process.env.GOOGLE_TTS_SERVICE_ACCOUNT;
  } catch (error) {
    // Secret not available, try fallback
  }

  // Fallback to GOOGLE_APPLICATION_CREDENTIALS for local development
  if (!credentialsString) {
    const credentialsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (credentialsPath) {
      // If GOOGLE_APPLICATION_CREDENTIALS is set, the client library will use it automatically
      // Return empty object to let ADC handle it
      return {};
    }
  }

  if (!credentialsString) {
    throw new Error(
      'Google TTS service account credentials not found. ' +
      'Set GOOGLE_TTS_SERVICE_ACCOUNT secret or GOOGLE_APPLICATION_CREDENTIALS environment variable.',
    );
  }

  // Parse JSON credentials
  try {
    return JSON.parse(credentialsString);
  } catch (error) {
    throw new Error(
      'Failed to parse GOOGLE_TTS_SERVICE_ACCOUNT. Ensure it contains valid JSON.',
    );
  }
}

/**
 * Initialize and return a TextToSpeechClient
 * Uses service account credentials from Firebase Secrets or environment variables
 */
export function getTextToSpeechClient(): TextToSpeechClient {
  const credentials = getServiceAccountCredentials();
  
  // If credentials is empty object, use Application Default Credentials
  if (Object.keys(credentials).length === 0) {
    return new TextToSpeechClient();
  }
  
  // Otherwise, use the provided credentials
  return new TextToSpeechClient({
    credentials: credentials as any,
  });
}

/**
 * Check if a voice name is a known Neural2 voice
 */
export function isNeural2Voice(voiceName: string): boolean {
  return voiceName in NEURAL2_VOICES;
}

