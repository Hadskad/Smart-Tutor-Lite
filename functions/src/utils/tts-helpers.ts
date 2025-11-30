import {
  VoiceId,
  DEFAULT_VOICE_ID,
  ELEVENLABS_API_URL,
  getElevenLabsApiKey,
} from '../config/elevenlabs-tts';

export interface TextToSpeechOptions {
  text: string;
  voice?: VoiceId;
  stability?: number; // 0.0 to 1.0
  similarityBoost?: number; // 0.0 to 1.0
  style?: number; // 0.0 to 1.0
  useSpeakerBoost?: boolean;
}

/**
 * Convert text to speech using ElevenLabs API
 */
export async function textToSpeech(
  options: TextToSpeechOptions,
): Promise<Buffer> {
  const {
    text,
    voice = DEFAULT_VOICE_ID,
    stability = 0.5,
    similarityBoost = 0.75,
    style = 0.0,
    useSpeakerBoost = true,
  } = options;

  const apiKey = getElevenLabsApiKey();

  const response = await fetch(`${ELEVENLABS_API_URL}/text-to-speech/${voice}`, {
    method: 'POST',
    headers: {
      'Accept': 'audio/mpeg',
      'Content-Type': 'application/json',
      'xi-api-key': apiKey,
    },
    body: JSON.stringify({
      text,
      model_id: 'eleven_monolingual_v1', // Use multilingual_v1 for non-English
      voice_settings: {
        stability,
        similarity_boost: similarityBoost,
        style,
        use_speaker_boost: useSpeakerBoost,
      },
    }),
  });

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`ElevenLabs API error: ${response.status} - ${errorText}`);
  }

  const audioBuffer = await response.arrayBuffer();
  return Buffer.from(audioBuffer);
}

/**
 * Convert long text to speech with chunking (for text > 5000 chars)
 * ElevenLabs has a 5000 character limit per request
 */
export async function textToSpeechLong(
  options: TextToSpeechOptions,
): Promise<Buffer> {
  const { text, voice, stability, similarityBoost, style, useSpeakerBoost } =
    options;
  const MAX_CHARS = 5000; // ElevenLabs limit

  if (text.length <= MAX_CHARS) {
    return textToSpeech({
      text,
      voice,
      stability,
      similarityBoost,
      style,
      useSpeakerBoost,
    });
  }

  // Split text into chunks at sentence boundaries
  const chunks: string[] = [];
  let currentChunk = '';
  const sentences = text.split(/(?<=[.!?])\s+/);

  for (const sentence of sentences) {
    if ((currentChunk + sentence).length > MAX_CHARS) {
      if (currentChunk) {
        chunks.push(currentChunk.trim());
        currentChunk = sentence;
      } else {
        // Single sentence too long, force split
        chunks.push(sentence.substring(0, MAX_CHARS));
        currentChunk = sentence.substring(MAX_CHARS);
      }
    } else {
      currentChunk += (currentChunk ? ' ' : '') + sentence;
    }
  }
  if (currentChunk.trim()) {
    chunks.push(currentChunk.trim());
  }

  // Generate audio for each chunk
  const audioBuffers: Buffer[] = [];
  for (const chunk of chunks) {
    const audioBuffer = await textToSpeech({
      text: chunk,
      voice,
      stability,
      similarityBoost,
      style,
      useSpeakerBoost,
    });
    audioBuffers.push(audioBuffer);
  }

  // Concatenate MP3 buffers
  return Buffer.concat(audioBuffers);
}

/**
 * List available voices from ElevenLabs
 * Useful for discovering custom voices from user's account
 */
export async function listVoices(): Promise<any[]> {
  const apiKey = getElevenLabsApiKey();

  const response = await fetch(`${ELEVENLABS_API_URL}/voices`, {
    method: 'GET',
    headers: {
      'xi-api-key': apiKey,
    },
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch voices: ${response.status}`);
  }

  const data = await response.json();
  return data.voices || [];
}
