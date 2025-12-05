# Firebase Functions for SmartTutor Lite

## Setup

1. Install dependencies:
```bash
npm install
```

2. Set OpenAI API key:
```bash
firebase functions:config:set openai.api_key="YOUR_OPENAI_API_KEY"
```

**Important**: Replace `YOUR_OPENAI_API_KEY` with your actual OpenAI API key. Never commit API keys to version control.

3. Build TypeScript:
```bash
npm run build
```

## Local Development

Run Firebase emulators:
```bash
npm run serve
```

Functions will be available at:
- `http://localhost:5001/smart-tutor-lite-a66b5/europe-west2/transcriptions`
- `http://localhost:5001/smart-tutor-lite-a66b5/europe-west2/summaries`
- etc.

## Deployment

Deploy all functions:
```bash
npm run deploy
```

Or deploy specific function:
```bash
firebase deploy --only functions:transcriptions
```

## Environment Variables

Set via Firebase CLI:
```bash
firebase functions:config:set openai.api_key="YOUR_KEY"
```

View current config:
```bash
firebase functions:config:get
```

## Project Structure

- `src/config/` - Firebase Admin and OpenAI initialization
- `src/api/` - API endpoint handlers
- `src/utils/` - Helper functions (OpenAI, Storage, Firestore)

