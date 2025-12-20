# Google Cloud Neural2 Text-to-Speech Integration Guide

This guide explains how to set up and use Google Cloud Neural2 Text-to-Speech (TTS) with SmartTutor Lite.

## Overview

SmartTutor Lite uses Google Cloud Text-to-Speech API with Neural2 voices to convert text and PDF documents to natural-sounding audio files. The integration is implemented in Firebase Functions and provides asynchronous processing with job status tracking.

## Features

- **Natural-Sounding Voices**: Google Cloud Neural2 voices for human-like speech
- **Multiple Voice Options**: 10 Neural2 voices (A-J) with different genders and characteristics
- **Long Text Support**: Automatic chunking for texts longer than 4,500 characters
- **PDF Support**: Extract text from PDFs and convert to audio
- **Asynchronous Processing**: Background processing with job status tracking
- **Firebase Storage Integration**: Audio files stored in Firebase Storage
- **High Quality**: Neural2 voices provide superior quality compared to standard voices

## Prerequisites

- Google Cloud Platform account
- Firebase project (same as your app project or linked)
- Billing enabled on Google Cloud project (required for TTS API)

## Setup Instructions

### 1. Enable Text-to-Speech API

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Select your project (or create a new one)
3. Navigate to **APIs & Services** → **Library**
4. Search for "Text-to-Speech API"
5. Click **Enable**
6. Ensure billing is enabled for your project

**Note**: The Text-to-Speech API requires billing to be enabled, even for free tier usage.

### 2. Create Service Account

1. In Google Cloud Console, go to **IAM & Admin** → **Service Accounts**
2. Click **Create Service Account**
3. Enter a name (e.g., `tts-service`)
4. Click **Create and Continue**
5. Grant the service account the **Cloud Text-to-Speech User** role:
   - Click **Add Another Role**
   - Select **Cloud Text-to-Speech User**
   - Click **Continue**
6. Click **Done** (skip optional steps)

### 3. Create and Download Service Account Key

1. In the Service Accounts list, click on the service account you just created
2. Go to the **Keys** tab
3. Click **Add Key** → **Create new key**
4. Select **JSON** format
5. Click **Create**
6. The JSON key file will be downloaded automatically
7. **Important**: Keep this file secure and do not commit it to version control

### 4. Configure Firebase Secret



#### For Local Development

You have two options:

**Option A: Use Application Default Credentials (Recommended)**

Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable:

```bash
# On macOS/Linux
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/service-account-key.json"

# On Windows PowerShell
$env:GOOGLE_APPLICATION_CREDENTIALS="C:\path\to\your\service-account-key.json"

# On Windows Command Prompt
set GOOGLE_APPLICATION_CREDENTIALS=C:\path\to\your\service-account-key.json
```

**Option B: Use Environment Variable**

Create a `.env` file in the `functions/` directory:

```bash
GOOGLE_TTS_SERVICE_ACCOUNT='{"type":"service_account","project_id":"...","private_key_id":"...","private_key":"...","client_email":"...","client_id":"...","auth_uri":"...","token_uri":"...","auth_provider_x509_cert_url":"...","client_x509_cert_url":"..."}'
```

**Note**: The entire JSON must be on a single line when using `.env` file.

### 5. Deploy Firebase Functions

After setting up the secret, deploy your functions:

```bash
cd functions
npm install
npm run build
firebase deploy --only functions
```

## Available Voices

### Neural2 Voices (English - US)

The following Neural2 voices are available and supported in the app:

| Voice Name | Gender | Description |
|------------|--------|-------------|
| `en-US-Neural2-A` | Female | Professional female voice |
| `en-US-Neural2-B` | Male | Professional male voice |
| `en-US-Neural2-C` | Female | Professional female voice |
| `en-US-Neural2-D` | Male | Professional male voice (Default) |
| `en-US-Neural2-E` | Female | Professional female voice |
| `en-US-Neural2-F` | Female | Professional female voice |
| `en-US-Neural2-G` | Female | Professional female voice |
| `en-US-Neural2-H` | Female | Professional female voice |
| `en-US-Neural2-I` | Male | Professional male voice |
| `en-US-Neural2-J` | Male | Professional male voice |

**Default Voice**: `en-US-Neural2-D` (Male)

### Discovering Additional Voices

To see all available voices (including other languages and voice types):

1. Use the Google Cloud Console API Explorer
2. Or call the `listVoices()` function in the code
3. Or use the REST API directly:

```bash
curl -H "Authorization: Bearer $(gcloud auth application-default print-access-token)" \
  "https://texttospeech.googleapis.com/v1/voices"
```

## API Usage

### Convert Text to Audio

**Endpoint**: `POST /tts`

**Request Body**:
```json
{
  "sourceType": "text",
  "sourceId": "Your text content here",
  "voice": "en-US-Neural2-D"
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
  "voice": "en-US-Neural2-D",
  "createdAt": "2024-01-01T00:00:00.000Z"
}
```

### Convert PDF to Audio

**Request Body**:
```json
{
  "sourceType": "pdf",
  "sourceId": "https://storage.googleapis.com/bucket/path/to/file.pdf",
  "voice": "en-US-Neural2-C"
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
  "voice": "en-US-Neural2-D",
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
  "voice": "en-US-Neural2-D",
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
  "voice": "en-US-Neural2-D",
  "errorMessage": "Error details here",
  "createdAt": "2024-01-01T00:00:00.000Z",
  "updatedAt": "2024-01-01T00:00:05.000Z"
}
```

## Flutter Integration

The Flutter app includes a voice selector dropdown in the TTS page with all 10 Neural2 voices:

```dart
// Available voices
final List<Map<String, String>> _voices = [
  {'value': 'en-US-Neural2-A', 'label': 'Neural2-A (Female)'},
  {'value': 'en-US-Neural2-B', 'label': 'Neural2-B (Male)'},
  {'value': 'en-US-Neural2-C', 'label': 'Neural2-C (Female)'},
  {'value': 'en-US-Neural2-D', 'label': 'Neural2-D (Male) - Default'},
  {'value': 'en-US-Neural2-E', 'label': 'Neural2-E (Female)'},
  {'value': 'en-US-Neural2-F', 'label': 'Neural2-F (Female)'},
  {'value': 'en-US-Neural2-G', 'label': 'Neural2-G (Female)'},
  {'value': 'en-US-Neural2-H', 'label': 'Neural2-H (Female)'},
  {'value': 'en-US-Neural2-I', 'label': 'Neural2-I (Male)'},
  {'value': 'en-US-Neural2-J', 'label': 'Neural2-J (Male)'},
];

// Convert text with selected voice
_bloc.add(ConvertTextToAudioEvent(
  text: text,
  voice: _selectedVoice,
));
```

## Cost Considerations

Google Cloud Text-to-Speech pricing (as of 2024):

- **Free Tier**: 0-4 million characters/month (free)
- **Standard Voices**: $4.00 per 1 million characters
- **WaveNet Voices**: $16.00 per 1 million characters
- **Neural2 Voices**: $16.00 per 1 million characters

### Cost Optimization Tips

1. **Use Caching**: The app caches generated audio files in Firebase Storage and Firestore
2. **Set Character Limits**: Consider limiting the maximum text length per conversion
3. **Monitor Usage**: Track character usage in Google Cloud Console → Billing
4. **Use Free Tier**: First 4 million characters per month are free

### Example Cost Calculation

- Average lecture transcription: ~5,000 words = ~30,000 characters
- Free tier: ~133 lectures/month (4M characters)
- After free tier: ~$0.48 per 30 lectures (1M characters = $16)

## Technical Details

### Text Chunking

For texts longer than 4,500 characters (safe limit with headroom), the system automatically:

1. Splits text into sentences at sentence boundaries (`.`, `!`, `?`)
2. Groups sentences into chunks under 4,500 characters
3. Generates audio for each chunk separately
4. Concatenates the MP3 audio files

This is handled by the `textToSpeechLong` function in `functions/src/utils/google-tts-helpers.ts`.

**Note**: The limit is set to 4,500 characters (instead of 5,000) to account for:
- SSML markup overhead
- Off-by-one edge cases
- Safe buffer for API variations

### Audio Format

- **Format**: MP3
- **Encoding**: MPEG Audio Layer 3
- **Sample Rate**: 24kHz (default, high quality)
- **Bitrate**: Variable (optimized by Google Cloud)

### Voice Settings

The API supports customizable voice settings:

- **Speaking Rate** (0.25-4.0): Controls speech speed, default 1.0
- **Pitch** (-20.0 to 20.0): Controls voice pitch, default 0.0
- **Volume Gain** (-96.0 to 16.0 dB): Controls volume, default 0.0

These can be customized in `functions/src/utils/google-tts-helpers.ts` if needed.

### Asynchronous Processing

The TTS conversion is processed asynchronously:

1. Client sends request to `/tts`
2. Server creates a job record in Firestore with status "processing"
3. Server immediately returns the job ID to the client
4. Background function processes the conversion
5. Client polls `/tts/:id` to check status
6. When complete, client downloads audio from Firebase Storage

## Troubleshooting

### Error: "Google TTS service account credentials not found"

**Solution**: Ensure the service account credentials are set up correctly.

```bash
# Check if secret exists
firebase functions:secrets:access GOOGLE_TTS_SERVICE_ACCOUNT

# If missing, set it
firebase functions:secrets:set GOOGLE_TTS_SERVICE_ACCOUNT
# Paste entire JSON when prompted
```

For local development:
```bash
# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

### Error: "Failed to parse GOOGLE_TTS_SERVICE_ACCOUNT"

**Solution**: Ensure the secret contains valid JSON. The entire service account JSON must be stored as a single string.

```bash
# Re-set the secret with correct JSON
firebase functions:secrets:set GOOGLE_TTS_SERVICE_ACCOUNT
# Paste the entire JSON file contents
```

### Error: "Google TTS API error: 403"

**Solution**: 
- Verify the service account has the **Cloud Text-to-Speech User** role
- Ensure the Text-to-Speech API is enabled in your project
- Check that billing is enabled

### Error: "Google TTS API error: 401"

**Solution**: Invalid or expired service account credentials. Regenerate the service account key and update the secret.

### Error: "Text-to-Speech API has not been used"

**Solution**: Enable the Text-to-Speech API in Google Cloud Console:
1. Go to APIs & Services → Library
2. Search for "Text-to-Speech API"
3. Click Enable

### Error: "Billing account required"

**Solution**: Enable billing on your Google Cloud project. The Text-to-Speech API requires billing to be enabled, even for free tier usage.

### Local Development: "Credentials not found"

**Solution**: Set the `GOOGLE_APPLICATION_CREDENTIALS` environment variable:

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

### Audio Quality Issues

**Solution**: 
- Try different Neural2 voices (they have different characteristics)
- Ensure text is properly formatted (punctuation, capitalization)
- Check that you're using Neural2 voices (not standard voices)

### Character Limit Errors

**Solution**: The system automatically chunks long texts. If you encounter issues:
- Check that chunking logic is working correctly
- Verify text length is reasonable (very long texts may take time)
- Check Firebase Functions logs for detailed error messages

## Migration from ElevenLabs

If you're migrating from ElevenLabs:

1. **Voice IDs**: ElevenLabs voice IDs (e.g., `21m00Tcm4TlvDq8ikWAM`) will no longer work
2. **Authentication**: Replace ElevenLabs API key with Google Cloud service account
3. **Voice Format**: Use Google Cloud voice names (e.g., `en-US-Neural2-D`)
4. **Character Limits**: Google Cloud has a 5,000 character limit (we use 4,500 for safety)
5. **Cost Structure**: Different pricing model (per million characters vs. monthly tiers)

## Adding More Voices

To add more voices or languages:

1. Browse available voices in Google Cloud Console or use the API
2. Update `functions/src/config/google-tts.ts` to add voice definitions
3. Update the Flutter voice selector in `lib/features/text_to_speech/presentation/pages/tts_page.dart`

## References

- [Google Cloud Text-to-Speech Documentation](https://cloud.google.com/text-to-speech/docs)
- [Text-to-Speech API Reference](https://cloud.google.com/text-to-speech/docs/reference/rest)
- [Available Voices](https://cloud.google.com/text-to-speech/docs/voices)
- [Pricing](https://cloud.google.com/text-to-speech/pricing)
- [Neural2 Voices](https://cloud.google.com/text-to-speech/docs/voices#neural2_voices)

