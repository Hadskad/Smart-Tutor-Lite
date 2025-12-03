"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.textToSpeech = textToSpeech;
exports.textToSpeechLong = textToSpeechLong;
exports.listVoices = listVoices;
const elevenlabs_tts_1 = require("../config/elevenlabs-tts");
/**
 * Convert text to speech using ElevenLabs API
 */
async function textToSpeech(options) {
    const { text, voice = elevenlabs_tts_1.DEFAULT_VOICE_ID, stability = 0.5, similarityBoost = 0.75, style = 0.0, useSpeakerBoost = true, } = options;
    const apiKey = (0, elevenlabs_tts_1.getElevenLabsApiKey)();
    const response = await fetch(`${elevenlabs_tts_1.ELEVENLABS_API_URL}/text-to-speech/${voice}`, {
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
async function textToSpeechLong(options) {
    const { text, voice, stability, similarityBoost, style, useSpeakerBoost } = options;
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
    const chunks = [];
    let currentChunk = '';
    const sentences = text.split(/(?<=[.!?])\s+/);
    for (const sentence of sentences) {
        if ((currentChunk + sentence).length > MAX_CHARS) {
            if (currentChunk) {
                chunks.push(currentChunk.trim());
                currentChunk = sentence;
            }
            else {
                // Single sentence too long, force split
                chunks.push(sentence.substring(0, MAX_CHARS));
                currentChunk = sentence.substring(MAX_CHARS);
            }
        }
        else {
            currentChunk += (currentChunk ? ' ' : '') + sentence;
        }
    }
    if (currentChunk.trim()) {
        chunks.push(currentChunk.trim());
    }
    // Generate audio for each chunk
    const audioBuffers = [];
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
async function listVoices() {
    const apiKey = (0, elevenlabs_tts_1.getElevenLabsApiKey)();
    const response = await fetch(`${elevenlabs_tts_1.ELEVENLABS_API_URL}/voices`, {
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
//# sourceMappingURL=tts-helpers.js.map