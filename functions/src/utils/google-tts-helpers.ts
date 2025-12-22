import {
  getTextToSpeechClient,
  DEFAULT_VOICE_NAME,
  VoiceId,
  getGCPProjectNumber,
  getServiceAccountCredentials,
} from '../config/google-tts';
import { GoogleAuth } from 'google-auth-library';
import { pollOperationUntilDone } from './operation-poller';

/* ---------------------------------- TYPES --------------------------------- */

export interface TextToSpeechOptions {
  text: string;
  voice?: VoiceId;
  languageCode?: string;
  speakingRate?: number; // 0.25 to 4.0, default 1.0
  pitch?: number; // -20.0 to 20.0, default 0.0
  volumeGainDb?: number; // -96.0 to 16.0, default 0.0
}

export interface LongAudioOptions {
  inputGcsUri: string;
  outputGcsUri: string;
  voice?: VoiceId;
  languageCode?: string;
  speakingRate?: number;
  pitch?: number;
  volumeGainDb?: number;
}

/* -------------------------- VALIDATION HELPERS ---------------------------- */

/**
 * Validate and normalize speaking rate (0.25 to 4.0)
 */
function validateSpeakingRate(rate?: number): number {
  if (rate === undefined) return 1.0;
  if (rate < 0.25 || rate > 4.0) {
    throw new Error(`Speaking rate must be between 0.25 and 4.0, got ${rate}`);
  }
  return rate;
}

/**
 * Validate and normalize pitch (-20.0 to 20.0)
 */
function validatePitch(pitch?: number): number {
  if (pitch === undefined) return 0.0;
  if (pitch < -20.0 || pitch > 20.0) {
    throw new Error(`Pitch must be between -20.0 and 20.0, got ${pitch}`);
  }
  return pitch;
}

/**
 * Validate and normalize volume gain (-96.0 to 16.0)
 */
function validateVolumeGain(volumeGainDb?: number): number {
  if (volumeGainDb === undefined) return 0.0;
  if (volumeGainDb < -96.0 || volumeGainDb > 16.0) {
    throw new Error(
      `Volume gain must be between -96.0 and 16.0, got ${volumeGainDb}`,
    );
  }
  return volumeGainDb;
}

/**
 * Validate text input
 */
function validateText(text: string): void {
  if (!text || typeof text !== 'string') {
    throw new Error('Text must be a non-empty string');
  }
  if (text.trim().length === 0) {
    throw new Error('Text cannot be empty or whitespace only');
  }
}

/* -------------------------- SHORT TEXT (SYNC) ------------------------------ */

/**
 * Convert text to speech using Google Cloud TTS API
 * @param options - Text-to-speech configuration options
 * @returns Audio content as Buffer (MP3 encoded)
 * @throws Error if text is invalid or API call fails
 */
export async function textToSpeech(
  options: TextToSpeechOptions,
): Promise<Buffer> {
  const {
    text,
    voice = DEFAULT_VOICE_NAME,
    languageCode = 'en-US',
    speakingRate = 1.0,
    pitch = 0.0,
    volumeGainDb = 0.0,
  } = options;

  // Validate inputs
  validateText(text);
  const normalizedSpeakingRate = validateSpeakingRate(speakingRate);
  const normalizedPitch = validatePitch(pitch);
  const normalizedVolumeGain = validateVolumeGain(volumeGainDb);

  const client = getTextToSpeechClient();
  const finalLanguageCode =
    languageCode || voice.split('-').slice(0, 2).join('-');

  const request = {
    input: { text },
    voice: {
      languageCode: finalLanguageCode,
      name: voice,
    },
    audioConfig: {
      audioEncoding: 'MP3' as const,
      speakingRate: normalizedSpeakingRate,
      pitch: normalizedPitch,
      volumeGainDb: normalizedVolumeGain,
    },
  };

  try {
    const [response] = await client.synthesizeSpeech(request);

    if (!response.audioContent) {
      throw new Error('Google TTS returned empty audio content');
    }

    return Buffer.from(response.audioContent);
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Google TTS API error: ${error.message}`);
    }
    throw new Error('Google TTS API error: Unknown error occurred');
  }
}

/* -------------------------- LONG TEXT (CHUNKED) ----------------------------- */

/**
 * Convert long text to speech with intelligent chunking
 * Google TTS has a 5000 character limit per request, but we use 4500 as safe limit
 * to account for SSML markup and edge cases
 * @param options - Text-to-speech configuration options
 * @returns Concatenated audio content as Buffer (MP3 encoded)
 * @throws Error if text is invalid or API call fails
 */
export async function textToSpeechLong(
  options: TextToSpeechOptions,
): Promise<Buffer> {
  const MAX_CHARS = 4500; // Safe limit (5000 - 500 headroom for SSML/edge cases)
  const { text } = options;

  // Validate input
  validateText(text);

  // If text fits in one request, use simple API
  if (text.length <= MAX_CHARS) {
    return textToSpeech(options);
  }

  // Split text into chunks at sentence boundaries
  const chunks: string[] = [];
  const sentences = text.split(/(?<=[.!?])\s+/);
  let currentChunk = '';

  for (const sentence of sentences) {
    const potentialChunk = currentChunk ? `${currentChunk} ${sentence}` : sentence;

    if (potentialChunk.length > MAX_CHARS) {
      // Current chunk would exceed limit
      if (currentChunk) {
        // Save current chunk and start new one
        chunks.push(currentChunk.trim());
        currentChunk = sentence;
      } else {
        // Single sentence too long, force split at word boundaries
        const remaining = sentence;
        let remainingText = remaining;

        while (remainingText.length > MAX_CHARS) {
          // Find a good break point (space, comma, etc.) near MAX_CHARS
          let breakPoint = MAX_CHARS;
          const searchStart = Math.max(0, MAX_CHARS - 200); // Look back up to 200 chars

          // Try to find a word boundary
          for (let i = MAX_CHARS; i >= searchStart; i--) {
            if (/\s/.test(remainingText[i])) {
              breakPoint = i + 1;
              break;
            }
          }

          // If no word boundary found, try punctuation
          if (breakPoint === MAX_CHARS) {
            for (let i = MAX_CHARS; i >= searchStart; i--) {
              if (/[,;:]/.test(remainingText[i])) {
                breakPoint = i + 1;
                break;
              }
            }
          }

          chunks.push(remainingText.substring(0, breakPoint).trim());
          remainingText = remainingText.substring(breakPoint).trim();
        }

        if (remainingText.trim()) {
          currentChunk = remainingText;
        }
      }
    } else {
      // Add sentence to current chunk
      currentChunk = potentialChunk;
    }
  }

  // Add remaining chunk
  if (currentChunk.trim()) {
    chunks.push(currentChunk.trim());
  }

  // Validate we have chunks
  if (chunks.length === 0) {
    throw new Error('Failed to split text into chunks');
  }

  // Generate audio for each chunk
  const buffers: Buffer[] = [];

  for (const chunk of chunks) {
    if (!chunk.trim()) continue; // Skip empty chunks

    const audioBuffer = await textToSpeech({ ...options, text: chunk });
    buffers.push(audioBuffer);
  }

  if (buffers.length === 0) {
    throw new Error('No audio chunks generated');
  }

  // Concatenate MP3 buffers
  // Note: Simple concatenation works for MP3 files generated from the same source
  return Buffer.concat(buffers);
}

/* ------------------------- LIST VOICES ------------------------------------- */

/**
 * List available voices from Google Cloud TTS
 * @param languageCode - Optional language code filter (e.g., 'en-US')
 * @returns Array of available voice objects
 * @throws Error if API call fails
 */
export async function listVoices(languageCode?: string): Promise<any[]> {
  const client = getTextToSpeechClient();

  try {
    const [result] = await client.listVoices({
      languageCode: languageCode || undefined,
    });

    return result.voices || [];
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Failed to fetch voices: ${error.message}`);
    }
    throw new Error('Failed to fetch voices: Unknown error occurred');
  }
}

/**
 * Get Neural2 voices for a specific language
 * Filters the list to only return Neural2 voices
 * @param languageCode - Language code (default: 'en-US')
 * @returns Array of Neural2 voice objects
 * @throws Error if API call fails
 */
export async function listNeural2Voices(
  languageCode: string = 'en-US',
): Promise<any[]> {
  const voices = await listVoices(languageCode);
  return voices.filter((v) => v.name?.includes('Neural2'));
}

/* -------------------- ASYNC LONG AUDIO (BATCH) ------------------------------ */

/**
 * Synthesize long audio using Google Cloud TTS synthesizeLongAudio API
 * This is an async batch processing method for very large text inputs
 * Uses REST API to call synthesizeLongAudio endpoint
 * @param options - Configuration options for long audio synthesis
 * @returns Operation object with name and done status
 * @throws Error if API call fails or operation submission fails
 */
export async function synthesizeLongAudio(
  options: LongAudioOptions,
): Promise<{ name: string; done: boolean }> {
  const {
    inputGcsUri,
    outputGcsUri,
    voice = DEFAULT_VOICE_NAME,
    languageCode = 'en-US',
    speakingRate = 1.0,
    pitch = 0.0,
    volumeGainDb = 0.0,
  } = options;

  // Validate GCS URIs
  if (!inputGcsUri || !inputGcsUri.startsWith('gs://')) {
    throw new Error(
      `Invalid inputGcsUri: must be a valid GCS URI (gs://bucket/path), got ${inputGcsUri}`,
    );
  }
  if (!outputGcsUri || !outputGcsUri.startsWith('gs://')) {
    throw new Error(
      `Invalid outputGcsUri: must be a valid GCS URI (gs://bucket/path), got ${outputGcsUri}`,
    );
  }

  // Validate and normalize parameters
  const normalizedSpeakingRate = validateSpeakingRate(speakingRate);
  const normalizedPitch = validatePitch(pitch);
  const normalizedVolumeGain = validateVolumeGain(volumeGainDb);

  const projectNumber = getGCPProjectNumber();
  const finalLanguageCode =
    languageCode || voice.split('-').slice(0, 2).join('-');

  const apiUrl = `https://texttospeech.googleapis.com/v1beta1/projects/${projectNumber}/locations/global:synthesizeLongAudio`;

  const credentials = getServiceAccountCredentials();
  const auth = new GoogleAuth({
    credentials: Object.keys(credentials).length ? credentials : undefined,
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });

  const client = await auth.getClient();
  const accessToken = await client.getAccessToken();

  if (!accessToken) {
    throw new Error('Failed to obtain access token for Google Cloud TTS API');
  }

  const body = {
    input: { gcsInput: { uri: inputGcsUri } },
    voice: { languageCode: finalLanguageCode, name: voice },
    audioConfig: {
      audioEncoding: 'MP3',
      speakingRate: normalizedSpeakingRate,
      pitch: normalizedPitch,
      volumeGainDb: normalizedVolumeGain,
    },
    outputGcsUri,
  };

  try {
    const res = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    });

    if (!res.ok) {
      const errorText = await res.text();
      throw new Error(
        `Google TTS synthesizeLongAudio API error: ${res.status} ${res.statusText}. ${errorText}`,
      );
    }

    const operation = await res.json();

    if (!operation || !operation.name) {
      throw new Error(
        'Google TTS synthesizeLongAudio API did not return a valid operation',
      );
    }

    return {
      name: operation.name,
      done: operation.done ?? false,
    };
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(
        `Google TTS synthesizeLongAudio API error: ${error.message}`,
      );
    }
    throw new Error(
      'Google TTS synthesizeLongAudio API error: Unknown error occurred',
    );
  }
}

/* ------------------ CONVENIENCE HELPER (OPTIONAL) --------------------------- */

/**
 * Synthesize long audio and wait for completion
 * Convenience function that combines synthesizeLongAudio and polling
 * @param options - Configuration options for long audio synthesis
 * @param maxWaitTimeMs - Maximum time to wait for completion in milliseconds (default: 24 hours)
 * @param jobId - Optional job ID for logging context
 * @returns Operation result when done or failed
 * @throws Error if operation fails or times out
 */
export async function synthesizeLongAudioAndWait(
  options: LongAudioOptions,
  maxWaitTimeMs: number = 24 * 60 * 60 * 1000, // 24 hours default
  jobId?: string,
): Promise<void> {
  const operation = await synthesizeLongAudio(options);
  const result = await pollOperationUntilDone(
    operation.name,
    maxWaitTimeMs,
    jobId,
  );

  if (result.error) {
    throw new Error(
      `Operation failed: ${result.error.message} (Code: ${result.error.code})`,
    );
  }

  if (!result.done) {
    throw new Error('Operation did not complete successfully');
  }
}