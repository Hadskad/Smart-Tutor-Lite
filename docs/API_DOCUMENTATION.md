# API Documentation

## Overview

SmartTutor Lite uses Firebase Functions as its backend API. All endpoints are HTTP-based and follow RESTful conventions.

## Base URL

```
https://europe-west2-smart-tutor-lite-a66b5.cloudfunctions.net
```

## Authentication

Currently, endpoints are publicly accessible. Future versions may implement Firebase Authentication for user-specific data.

## Endpoints

### Transcriptions

#### POST /transcriptions
Upload audio file for transcription.

**Request:**
- Method: `POST`
- Content-Type: `multipart/form-data`
- Body:
  - `file`: Audio file (WAV format, 16kHz, mono)

**Response:**
```json
{
  "id": "uuid-string",
  "text": "Transcribed text here",
  "audioPath": "gs://bucket/path/to/audio.wav",
  "durationMs": 5000,
  "timestamp": "2024-01-01T00:00:00Z",
  "confidence": 0.95,
  "metadata": {
    "source": "cloud_whisper"
  }
}
```

#### GET /transcriptions/:id
Retrieve a transcription by ID.

**Response:**
```json
{
  "id": "uuid-string",
  "text": "Transcribed text here",
  "audioPath": "gs://bucket/path/to/audio.wav",
  "durationMs": 5000,
  "timestamp": "2024-01-01T00:00:00Z",
  "confidence": 0.95,
  "metadata": {}
}
```

#### DELETE /transcriptions/:id
Delete a transcription and its associated audio file.

**Response:**
```json
{
  "success": true
}
```

### Summaries

#### POST /summaries
Generate a summary from text or PDF.

**Request:**
```json
{
  "text": "Text to summarize...",
  "sourceType": "text"
}
```

OR

```json
{
  "pdfUrl": "gs://bucket/path/to/document.pdf",
  "sourceType": "pdf"
}
```

**Response:**
```json
{
  "id": "uuid-string",
  "sourceType": "text",
  "sourceId": "source-id",
  "summaryText": "Summary text here...",
  "metadata": {
    "originalLength": 1000,
    "summaryLength": 200
  },
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Quizzes

#### POST /quizzes
Generate a quiz from source content (transcription or summary).

**Request:**
```json
{
  "sourceId": "transcription-or-summary-id",
  "sourceType": "transcription",
  "numQuestions": 5,
  "difficulty": "medium"
}
```

**Response:**
```json
{
  "id": "uuid-string",
  "title": "Quiz Title",
  "sourceId": "source-id",
  "sourceType": "transcription",
  "questions": [
    {
      "id": "question-id",
      "question": "What is the main topic?",
      "options": ["Option A", "Option B", "Option C", "Option D"],
      "correctAnswer": 0,
      "explanation": "Explanation here..."
    }
  ],
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Flashcards

#### POST /flashcards
Generate flashcards from content.

**Request:**
```json
{
  "sourceId": "transcription-or-summary-id",
  "sourceType": "transcription",
  "numFlashcards": 10
}
```

**Response:**
```json
{
  "id": "uuid-string",
  "flashcards": [
    {
      "id": "flashcard-id",
      "front": "Question or term",
      "back": "Answer or definition",
      "sourceId": "source-id",
      "sourceType": "transcription"
    }
  ],
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### Text-to-Speech

#### POST /tts
Convert PDF or text to audio.

**Request:**
```json
{
  "sourceType": "pdf",
  "sourceId": "gs://bucket/path/to/document.pdf",
  "voice": "en-US-Neural2-D"
}
```

OR

```json
{
  "sourceType": "text",
  "sourceId": "Text content to convert to speech",
  "voice": "en-US-Neural2-D"
}
```

**Note**: 
- When `sourceType` is `"text"`, `sourceId` should contain the actual text content.
- When `sourceType` is `"pdf"`, `sourceId` should be a Firebase Storage URL (gs://) or HTTP URL to the PDF file.
- `voice` is optional and defaults to `"en-US-Neural2-D"` (Neural2-D). See [GOOGLE_TTS_SETUP.md](GOOGLE_TTS_SETUP.md) for available voices.

**Response:**
```json
{
  "id": "uuid-string",
  "sourceType": "pdf",
  "sourceId": "gs://bucket/path/to/document.pdf",
  "audioUrl": "",
  "storagePath": "",
  "status": "processing",
  "voice": "en-US-Neural2-D",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Note**: The response initially returns with `status: "processing"` and empty `audioUrl`. Use `GET /tts/:id` to check the job status. When complete, `audioUrl` will contain the signed URL to the audio file.

#### GET /tts/:id
Get TTS job status by ID.

**Response (Processing):**
```json
{
  "id": "uuid-string",
  "sourceType": "pdf",
  "sourceId": "gs://bucket/path/to/document.pdf",
  "audioUrl": "",
  "storagePath": "",
  "status": "processing",
  "voice": "en-US-Neural2-D",
  "createdAt": "2024-01-01T00:00:00Z"
}
```

**Response (Completed):**
```json
{
  "id": "uuid-string",
  "sourceType": "pdf",
  "sourceId": "gs://bucket/path/to/document.pdf",
  "audioUrl": "https://storage.googleapis.com/bucket/tts/uuid-string/audio.mp3",
  "storagePath": "tts/uuid-string/audio.mp3",
  "status": "completed",
  "voice": "en-US-Neural2-D",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:05Z"
}
```

**Response (Failed):**
```json
{
  "id": "uuid-string",
  "sourceType": "pdf",
  "sourceId": "gs://bucket/path/to/document.pdf",
  "audioUrl": "",
  "storagePath": "",
  "status": "failed",
  "voice": "en-US-Neural2-D",
  "errorMessage": "Error details here",
  "createdAt": "2024-01-01T00:00:00Z",
  "updatedAt": "2024-01-01T00:00:05Z"
}
```

## Error Responses

All endpoints may return error responses in the following format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {}
  }
}
```

### Common Error Codes

- `INVALID_REQUEST`: Invalid request parameters
- `NOT_FOUND`: Resource not found
- `INTERNAL_ERROR`: Server-side error
- `RATE_LIMIT_EXCEEDED`: Too many requests
- `FILE_TOO_LARGE`: Uploaded file exceeds size limit

## Rate Limits

Rate limits may be applied in future versions. Current limits:
- 100 requests per minute per IP address

## Notes

- All timestamps are in ISO 8601 format (UTC)
- File uploads are limited to 50MB
- Audio files should be in WAV format, 16kHz, mono for best compatibility
- PDF files should be text-based (not scanned images) for optimal processing

