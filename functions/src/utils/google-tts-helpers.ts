import { getTextToSpeechClient, DEFAULT_VOICE_NAME, VoiceId } from '../config/google-tts';

export interface TextToSpeechOptions {
  text: string;
  voice?: VoiceId;
  languageCode?: string; // e.g., 'en-US'
  speakingRate?: number; // 0.25 to 4.0, default 1.0
  pitch?: number; // -20.0 to 20.0, default 0.0
  volumeGainDb?: number; // -96.0 to 16.0, default 0.0
}

/**
 * Convert text to speech using Google Cloud TTS API
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

  const client = getTextToSpeechClient();

  // Extract language code from voice name if not provided
  // Voice format: 'en-US-Neural2-D' -> language code: 'en-US'
  const finalLanguageCode = languageCode || voice.split('-').slice(0, 2).join('-');

  const request = {
    input: { text },
    voice: {
      languageCode: finalLanguageCode,
      name: voice,
    },
    audioConfig: {
      audioEncoding: 'MP3' as const,
      speakingRate,
      pitch,
      volumeGainDb,
    },
  };

  try {
    const [response] = await client.synthesizeSpeech(request);
    
    if (!response.audioContent) {
      throw new Error('Google TTS API returned empty audio content');
    }

    // audioContent is a Uint8Array, convert to Buffer
    return Buffer.from(response.audioContent);
  } catch (error) {
    if (error instanceof Error) {
      throw new Error(`Google TTS API error: ${error.message}`);
    }
    throw new Error('Google TTS API error: Unknown error occurred');
  }
}

/**
 * Convert long text to speech with chunking (for text > 4500 chars)
 * Google TTS has a 5000 character limit per request, but we use 4500 as safe limit
 * to account for SSML markup and off-by-one counts
 */
export async function textToSpeechLong(
  options: TextToSpeechOptions,
): Promise<Buffer> {
  const { text, voice, languageCode, speakingRate, pitch, volumeGainDb } = options;
  const MAX_CHARS = 4500; // Safe limit (5000 - 500 headroom for SSML/edge cases)

  if (text.length <= MAX_CHARS) {
    return textToSpeech({
      text,
      voice,
      languageCode,
      speakingRate,
      pitch,
      volumeGainDb,
    });
  }

  // Split text into chunks at sentence boundaries
  const chunks: string[] = [];
  let currentChunk = '';
  
  // Split by sentence endings (., !, ?) followed by whitespace
  const sentences = text.split(/(?<=[.!?])\s+/);

  for (const sentence of sentences) {
    const potentialChunk = currentChunk 
      ? `${currentChunk} ${sentence}` 
      : sentence;

    if (potentialChunk.length > MAX_CHARS) {
      // Current chunk would exceed limit
      if (currentChunk) {
        // Save current chunk and start new one
        chunks.push(currentChunk.trim());
        currentChunk = sentence;
      } else {
        // Single sentence too long, force split at MAX_CHARS
        const remaining = sentence;
        let remainingText = remaining;
        
        while (remainingText.length > MAX_CHARS) {
          // Find a good break point (space, comma, etc.) near MAX_CHARS
          let breakPoint = MAX_CHARS;
          const searchStart = Math.max(0, MAX_CHARS - 200); // Look back up to 200 chars
          
          for (let i = MAX_CHARS; i >= searchStart; i--) {
            if (/\s/.test(remainingText[i])) {
              breakPoint = i + 1;
              break;
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

  // Generate audio for each chunk
  const audioBuffers: Buffer[] = [];
  for (const chunk of chunks) {
    if (!chunk.trim()) continue; // Skip empty chunks
    
    const audioBuffer = await textToSpeech({
      text: chunk,
      voice,
      languageCode,
      speakingRate,
      pitch,
      volumeGainDb,
    });
    audioBuffers.push(audioBuffer);
  }

  if (audioBuffers.length === 0) {
    throw new Error('No audio chunks generated');
  }

  // Concatenate MP3 buffers
  // Note: Simple concatenation works for MP3 files generated from the same source
  return Buffer.concat(audioBuffers);
}

/**
 * List available voices from Google Cloud TTS
 * Returns all available voices, including Neural2 voices
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
 */
export async function listNeural2Voices(
  languageCode: string = 'en-US',
): Promise<any[]> {
  const allVoices = await listVoices(languageCode);
  
  // Filter for Neural2 voices (voice name contains 'Neural2')
  return allVoices.filter((voice: any) => {
    return voice.name && voice.name.includes('Neural2');
  });
}

