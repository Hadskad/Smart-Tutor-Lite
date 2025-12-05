# ElevenLabs Text-to-Speech Integration Guide

This guide explains how to set up and use ElevenLabs Text-to-Speech (TTS) with SmartTutor Lite.

## Overview

SmartTutor Lite uses ElevenLabs API with high-quality neural voices to convert text and PDF documents to natural-sounding audio files. The integration is implemented in Firebase Functions and provides asynchronous processing with job status tracking.

## Features

- **Natural-Sounding Voices**: ElevenLabs neural voices for human-like speech
- **Multiple Voice Options**: Premade voices (Rachel, Adam, Bella, Antoni) and support for custom voice IDs
- **Long Text Support**: Automatic chunking for texts longer than 5000 characters
- **PDF Support**: Extract text from PDFs and convert to audio
- **Asynchronous Processing**: Background processing with job status tracking
- **Firebase Storage Integration**: Audio files stored in Firebase Storage
- **Voice Customization**: Adjustable stability, similarity boost, style, and speaker boost settings

## Setup Instructions

### 1. Create ElevenLabs Account

1. Go to [ElevenLabs](https://elevenlabs.io)
2. Sign up for an account (free tier available)
3. Navigate to **Profile** → **API Key**
4. Copy your API key

### 2. Configure Firebase Functions

#### For Production (Firebase Functions)

Set the API key in Firebase Functions config:

```bash
firebase functions:config:set elevenlabs.api_key="YOUR_ELEVENLABS_API_KEY"
```

#### For Local Development

Create a `.env` file in the `functions/` directory:

```bash
ELEVENLABS_API_KEY=your_api_key_here
```

Or set as environment variable:

```bash
# On macOS/Linux
export ELEVENLABS_API_KEY="your_api_key_here"

# On Windows PowerShell
$env:ELEVENLABS_API_KEY="your_api_key_here"
```

### 3. Start Firebase Emulators (Local Development)

```bash
cd functions
npm install
npm run serve
```

The functions will automatically use the `ELEVENLABS_API_KEY` environment variable when running locally.

### 4. Deploy to Production

```bash
cd functions
npm run deploy
```

## Available Voices

### Premade Voices (Included by Default)

| Voice ID | Name | Gender | Description |
|----------|------|--------|-------------|
| `21m00Tcm4TlvDq8ikWAM` | Rachel | Female | Professional female voice (default) |
| `pNInz6obpgDQGcFmaJgB` | Adam | Male | Professional male voice |
| `EXAVITQu4vr4xnSDxMaL` | Bella | Female | Casual female voice |
| `ErXwobaYiN019PkySvjV` | Antoni | Male | Casual male voice |

### Custom Voices

You can use any voice ID from your ElevenLabs account. To discover available voices:

1. Log into your ElevenLabs account
2. Go to **Voices** section
3. Copy the voice ID from any voice you want to use
4. Use it directly in the API (no additional configuration needed)

## API Usage

### Convert Text to Audio

**Endpoint**: `POST /tts`

**Request Body**:
```json
{
  "sourceType": "text",
  "sourceId": "Your text content here",
  "voice": "21m00Tcm4TlvDq8ikWAM"
}
```

**Note**: When `sourceType` is `"text"`, `sourceId` should contain the actual text content to convert. When `sourceType` is `"pdf"`, `sourceId` should be a Firebase Storage URL (gs://) or HTTP URL to the PDF file.

**Response**:
```json
{
  "id": "uuid-v4",
  "sourceType": "text",
  "sourceId": "Your text content here",
  "audioUrl": "",
  "status": "processing",
  "voice": "21m00Tcm4TlvDq8ikWAM",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

### Convert PDF to Audio

**Request Body**:
```json
{
  "sourceType": "pdf",
  "sourceId": "https://storage.googleapis.com/bucket/path/to/file.pdf",
  "voice": "pNInz6obpgDQGcFmaJgB"
}
```

**Note**: The `sourceId` must be a valid URL to a PDF file. Supported formats:
- Firebase Storage URLs: `gs://bucket-name/path/to/file.pdf`
- HTTP/HTTPS URLs: `https://storage.googleapis.com/bucket/path/to/file.pdf`

### Check Job Status

**Endpoint**: `GET /tts/:id`

**Response (Processing)**:
```json
{
  "id": "uuid-v4",
  "sourceType": "text",
  "sourceId": "...",
  "audioUrl": "",
  "status": "processing",
  "voice": "21m00Tcm4TlvDq8ikWAM",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

**Response (Completed)**:
```json
{
  "id": "uuid-v4",
  "sourceType": "text",
  "sourceId": "...",
  "audioUrl": "https://storage.googleapis.com/bucket/tts/uuid-v4/audio.mp3",
  "status": "completed",
  "voice": "21m00Tcm4TlvDq8ikWAM",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:05.000Z"
}
```

**Response (Failed)**:
```json
{
  "id": "uuid-v4",
  "sourceType": "text",
  "sourceId": "...",
  "audioUrl": "",
  "status": "failed",
  "voice": "21m00Tcm4TlvDq8ikWAM",
  "errorMessage": "Error details here",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:05.000Z"
}
```

## Flutter Integration

The Flutter app includes a voice selector dropdown in the TTS page:

```dart
// Available voices
final List<Map<String, String>> _voices = [
  {'value': '21m00Tcm4TlvDq8ikWAM', 'label': 'Rachel (Female)'},
  {'value': 'pNInz6obpgDQGcFmaJgB', 'label': 'Adam (Male)'},
  {'value': 'EXAVITQu4vr4xnSDxMaL', 'label': 'Bella (Female)'},
  {'value': 'ErXwobaYiN019PkySvjV', 'label': 'Antoni (Male)'},
];

// Convert text with selected voice
_bloc.add(ConvertTextToAudioEvent(
  text: text,
  voice: _selectedVoice,
));
```

## Cost Considerations

ElevenLabs pricing (as of 2024):

- **Free Tier**: 10,000 characters/month
- **Starter** ($5/month): 30,000 characters/month
- **Creator** ($22/month): 100,000 characters/month
- **Pro** ($99/month): 500,000 characters/month
- **Enterprise**: Custom pricing

### Cost Optimization Tips

1. **Use Caching**: The app caches generated audio files in Firebase Storage and Firestore
2. **Set Character Limits**: Consider limiting the maximum text length per conversion
3. **Monitor Usage**: Track character usage in your ElevenLabs dashboard
4. **Use Free Tier**: Perfect for testing and small-scale usage

### Example Cost Calculation

- Average lecture transcription: ~5,000 words = ~30,000 characters
- Free tier: ~3 lectures/month
- Starter tier ($5/month): ~10 lectures/month
- Creator tier ($22/month): ~33 lectures/month

## Technical Details

### Text Chunking

For texts longer than 5,000 characters (ElevenLabs limit), the system automatically:

1. Splits text into sentences
2. Groups sentences into chunks under 5,000 characters
3. Generates audio for each chunk separately
4. Concatenates the audio files

This is handled by the `textToSpeechLong` function in `functions/src/utils/tts-helpers.ts`.

### Audio Format

- **Format**: MP3
- **Encoding**: MPEG Audio Layer 3
- **Model**: `eleven_monolingual_v1` (English) or `eleven_multilingual_v1` (multilingual)

### Voice Settings

The API supports customizable voice settings (currently using defaults):

- **Stability** (0.0-1.0): Controls consistency, default 0.5
- **Similarity Boost** (0.0-1.0): Controls similarity to original voice, default 0.75
- **Style** (0.0-1.0): Controls expressiveness, default 0.0
- **Use Speaker Boost**: Enhances clarity, default true

These can be customized in `functions/src/utils/tts-helpers.ts` if needed.

### Asynchronous Processing

The TTS conversion is processed asynchronously:

1. Client sends request to `/tts`
2. Server creates a job record in Firestore with status "processing"
3. Server immediately returns the job ID to the client
4. Background function processes the conversion
5. Client polls `/tts/:id` to check status
6. When complete, client downloads audio from Firebase Storage

## Troubleshooting

### Error: "ELEVENLABS_API_KEY is not set"

**Solution**: Ensure the API key is set in Firebase Functions config or environment variables.

```bash
# Check config
firebase functions:config:get

# Set config
firebase functions:config:set elevenlabs.api_key="YOUR_KEY"
```

### Error: "ElevenLabs API error: 401"

**Solution**: Invalid API key. Verify your API key is correct in ElevenLabs dashboard.

### Error: "ElevenLabs API error: 429"

**Solution**: Rate limit exceeded. Check your ElevenLabs plan limits and usage.

### Error: "Invalid voice ID"

**Solution**: Ensure the voice ID exists in your ElevenLabs account. Use premade voice IDs or verify custom voice IDs.

### Local Development: "API key not found"

**Solution**: Set the `ELEVENLABS_API_KEY` environment variable before running emulators.

### Audio Quality Issues

**Solution**: 
- Try different voices
- Adjust voice settings (stability, similarity boost) in the code
- Ensure text is properly formatted (punctuation, capitalization)

## Migration from Google Cloud TTS

If you're migrating from Google Cloud TTS:

1. **Old voice IDs**: Google Cloud voice IDs (e.g., `en-US-Neural2-C`) will no longer work
2. **API key**: Replace Google Cloud service account with ElevenLabs API key
3. **No service account setup**: ElevenLabs uses simple API key authentication
4. **Voice mapping**: Update Flutter app to use ElevenLabs voice IDs

## Adding More Voices

To add more premade voices:

1. Browse available voices: https://elevenlabs.io/app/voices
2. Update `functions/src/config/elevenlabs-tts.ts`:
   ```typescript
   export const PREMADE_VOICES = {
     // ... existing voices
     'your-voice-id': {
       name: 'VoiceName',
       description: 'Description',
       category: 'premade',
     },
   };
   ```
3. Update the Flutter voice selector in `lib/features/text_to_speech/presentation/pages/tts_page.dart`

## References

- [ElevenLabs Documentation](https://docs.elevenlabs.io/)
- [ElevenLabs API Reference](https://docs.elevenlabs.io/api-reference)
- [Available Voices](https://elevenlabs.io/app/voices)
- [Pricing](https://elevenlabs.io/pricing)

