# Google Cloud Text-to-Speech Integration Guide

This guide explains how to set up and use Google Cloud Text-to-Speech (TTS) with SmartTutor Lite.

## Overview

SmartTutor Lite uses Google Cloud Text-to-Speech API with WaveNet and Neural2 voices to convert text and PDF documents to high-quality audio files. The integration is implemented in Firebase Functions and provides asynchronous processing with job status tracking.

## Features

- **High-Quality Voices**: Neural2 and WaveNet voices for natural-sounding speech
- **Multiple Voice Options**: Male and female voices in US English
- **Long Text Support**: Automatic chunking for texts longer than 5000 characters
- **PDF Support**: Extract text from PDFs and convert to audio
- **Asynchronous Processing**: Background processing with job status tracking
- **Firebase Storage Integration**: Audio files stored in Firebase Storage

## Setup Instructions

### 1. Enable Google Cloud Text-to-Speech API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your Firebase project (or create a new one)
3. Navigate to **APIs & Services** > **Library**
4. Search for "Cloud Text-to-Speech API"
5. Click **Enable**

### 2. Service Account Permissions

Firebase Functions automatically use the default service account. Ensure it has the necessary permissions:

1. Go to **IAM & Admin** > **IAM**
2. Find the service account: `[PROJECT_ID]@appspot.gserviceaccount.com`
3. Ensure it has the **Cloud Text-to-Speech User** role
4. If not, click **Edit** and add the role

### 3. Local Development Setup

For local testing with Firebase emulators:

1. Create a service account key:
   ```bash
   gcloud iam service-accounts keys create service-account-key.json \
     --iam-account=[PROJECT_ID]@appspot.gserviceaccount.com
   ```

2. Set the environment variable:
   ```bash
   # On macOS/Linux
   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
   
   # On Windows PowerShell
   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\service-account-key.json"
   ```

3. Start the Firebase emulators:
   ```bash
   cd functions
   npm run serve
   ```

### 4. Deploy to Production

Deploy the functions to Firebase:

```bash
cd functions
npm run deploy
```

Firebase Functions will automatically use the default service account in production.

## Available Voices

The integration supports the following voices:

| Voice ID | Type | Gender | Description |
|----------|------|--------|-------------|
| `en-US-Neural2-C` | Neural2 | Female | High-quality, natural-sounding female voice (default) |
| `en-US-Neural2-A` | Neural2 | Male | High-quality, natural-sounding male voice |
| `en-US-Wavenet-C` | WaveNet | Female | Premium female voice with excellent prosody |
| `en-US-Wavenet-A` | WaveNet | Male | Premium male voice with excellent prosody |

You can add more voices by updating `functions/src/config/google-tts.ts`.

## API Usage

### Convert Text to Audio

**Endpoint**: `POST /tts`

**Request Body**:
```json
{
  "sourceType": "text",
  "sourceId": "Your text content here",
  "voice": "en-US-Neural2-C"
}
```

**Response**:
```json
{
  "id": "uuid-v4",
  "sourceType": "text",
  "sourceId": "Your text content here",
  "audioUrl": "",
  "status": "processing",
  "voice": "en-US-Neural2-C",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

### Convert PDF to Audio

**Request Body**:
```json
{
  "sourceType": "pdf",
  "sourceId": "https://storage.googleapis.com/bucket/path/to/file.pdf",
  "voice": "en-US-Wavenet-A"
}
```

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
  "voice": "en-US-Neural2-C",
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
  "voice": "en-US-Neural2-C",
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
  "voice": "en-US-Neural2-C",
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
  {'value': 'en-US-Neural2-C', 'label': 'Female (Neural2)'},
  {'value': 'en-US-Neural2-A', 'label': 'Male (Neural2)'},
  {'value': 'en-US-Wavenet-C', 'label': 'Female (WaveNet)'},
  {'value': 'en-US-Wavenet-A', 'label': 'Male (WaveNet)'},
];

// Convert text with selected voice
_bloc.add(ConvertTextToAudioEvent(
  text: text,
  voice: _selectedVoice,
));
```

## Cost Considerations

Google Cloud TTS pricing (as of 2024):

- **WaveNet voices**: ~$16 per 1 million characters
- **Neural2 voices**: ~$16 per 1 million characters
- **Standard voices**: ~$4 per 1 million characters

### Cost Optimization Tips

1. **Use Caching**: The app caches generated audio files in Firebase Storage and Firestore
2. **Set Character Limits**: Consider limiting the maximum text length per conversion
3. **Use Standard Voices**: For less critical content, consider using Standard voices instead of Neural2/WaveNet
4. **Monitor Usage**: Set up billing alerts in Google Cloud Console

### Example Cost Calculation

- Average lecture transcription: ~5,000 words = ~30,000 characters
- Cost per lecture (Neural2): $0.48
- 100 lectures per month: $48/month

## Technical Details

### Text Chunking

For texts longer than 5,000 characters (Google's limit), the system automatically:

1. Splits text into sentences
2. Groups sentences into chunks under 5,000 characters
3. Generates audio for each chunk
4. Concatenates the audio files

This is handled by the `textToSpeechLong` function in `functions/src/utils/tts-helpers.ts`.

### Audio Format

- **Format**: MP3
- **Encoding**: MPEG Audio Layer 3
- **Speaking Rate**: 1.0 (normal)
- **Pitch**: 0.0 (neutral)

You can customize these settings in `functions/src/utils/tts-helpers.ts`.

### Asynchronous Processing

The TTS conversion is processed asynchronously:

1. Client sends request to `/tts`
2. Server creates a job record in Firestore with status "processing"
3. Server immediately returns the job ID to the client
4. Background function processes the conversion
5. Client polls `/tts/:id` to check status
6. When complete, client downloads audio from Firebase Storage

## Troubleshooting

### Error: "Permission denied"

**Solution**: Ensure the service account has the "Cloud Text-to-Speech User" role.

### Error: "API not enabled"

**Solution**: Enable the Cloud Text-to-Speech API in Google Cloud Console.

### Error: "Quota exceeded"

**Solution**: Check your Google Cloud quotas and request an increase if needed.

### Local Development: "Application Default Credentials not found"

**Solution**: Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to your service account key JSON file.

### Audio Quality Issues

**Solution**: Try different voices. Neural2 and WaveNet voices generally provide better quality than Standard voices.

## Adding More Voices

To add more voices:

1. Browse available voices: https://cloud.google.com/text-to-speech/docs/voices
2. Update `functions/src/config/google-tts.ts`:
   ```typescript
   export const VOICE_CONFIGS = {
     // ... existing voices
     'en-GB-Neural2-A': {
       languageCode: 'en-GB',
       name: 'en-GB-Neural2-A',
       ssmlGender: 'FEMALE' as const,
     },
   };
   ```
3. Update the Flutter voice selector in `lib/features/text_to_speech/presentation/pages/tts_page.dart`

## References

- [Google Cloud Text-to-Speech Documentation](https://cloud.google.com/text-to-speech/docs)
- [Available Voices](https://cloud.google.com/text-to-speech/docs/voices)
- [Pricing](https://cloud.google.com/text-to-speech/pricing)
- [Node.js Client Library](https://googleapis.dev/nodejs/text-to-speech/latest/)

