import * as functions from 'firebase-functions';

// ElevenLabs API Configuration
export const ELEVENLABS_API_URL = 'https://api.elevenlabs.io/v1';

// Popular premade voices from ElevenLabs
export const PREMADE_VOICES = {
  '21m00Tcm4TlvDq8ikWAM': {
    name: 'Rachel',
    description: 'Professional female voice',
    category: 'premade',
  },
  'pNInz6obpgDQGcFmaJgB': {
    name: 'Adam',
    description: 'Professional male voice',
    category: 'premade',
  },
  'EXAVITQu4vr4xnSDxMaL': {
    name: 'Bella',
    description: 'Casual female voice',
    category: 'premade',
  },
  'ErXwobaYiN019PkySvjV': {
    name: 'Antoni',
    description: 'Casual male voice',
    category: 'premade',
  },
};

// Default voice ID (Rachel)
export const DEFAULT_VOICE_ID = '21m00Tcm4TlvDq8ikWAM';

// Voice ID type - string to support custom voice IDs from user's account
export type VoiceId = string;

/**
 * Get ElevenLabs API key from Firebase Functions config or environment variables
 */
export function getElevenLabsApiKey(): string {
  const apiKey =
    functions.config().elevenlabs?.api_key || process.env.ELEVENLABS_API_KEY;

  if (!apiKey) {
    throw new Error(
      'ELEVENLABS_API_KEY is not set in Firebase Functions config or environment variables.',
    );
  }

  return apiKey;
}

/**
 * Check if a voice ID is a known premade voice
 */
export function isPremadeVoice(voiceId: string): boolean {
  return voiceId in PREMADE_VOICES;
}

