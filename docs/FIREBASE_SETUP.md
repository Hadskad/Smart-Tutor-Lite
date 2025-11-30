# Firebase Setup Guide

This guide covers setting up and deploying Firebase Functions for SmartTutor Lite.

## Prerequisites

- Node.js (>=18.0.0)
- Firebase CLI installed globally: `npm install -g firebase-tools`
- Firebase project created at [Firebase Console](https://console.firebase.google.com)
- Firebase project ID: `smart-tutor-lite-a66b5` (or your project ID)

## Initial Setup

### 1. Install Firebase CLI

```bash
npm install -g firebase-tools
```

### 2. Login to Firebase

```bash
firebase login
```

### 3. Initialize Firebase in Project

```bash
firebase init functions
```

Select:
- Use TypeScript: Yes
- ESLint: Yes
- Install dependencies: Yes

## Project Structure

```
functions/
├── src/
│   ├── index.ts              # Main entry point
│   ├── config/               # Configuration files
│   │   ├── firebase-admin.ts
│   │   └── openai.ts
│   ├── api/                  # API endpoints
│   │   ├── transcriptions.ts
│   │   ├── summaries.ts
│   │   ├── quizzes.ts
│   │   ├── flashcards.ts
│   │   └── tts.ts
│   └── utils/                # Helper functions
│       ├── openai-helpers.ts
│       ├── storage-helpers.ts
│       └── firestore-helpers.ts
├── package.json
├── tsconfig.json
└── .gitignore
```

## Environment Variables

### Set OpenAI API Key

```bash
firebase functions:config:set openai.api_key="YOUR_OPENAI_API_KEY"
```

### View Current Config

```bash
firebase functions:config:get
```

### Local Development

For local development, create `.env` file in `functions/` directory:

```env
OPENAI_API_KEY=your_openai_api_key_here
```

## Firebase Admin SDK Setup

### 1. Generate Service Account Key

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Project Settings → Service Accounts
3. Click "Generate New Private Key"
4. Save the JSON file securely (do NOT commit to git)

### 2. Set Environment Variable

For local development, set:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

For production, Firebase Functions automatically use the service account.

## Local Development

### Install Dependencies

```bash
cd functions
npm install
```

### Run Functions Locally

```bash
firebase emulators:start --only functions
```

Functions will be available at:
- `http://localhost:5001/smart-tutor-lite-a66b5/us-central1/api`

### Test Locally

```bash
curl http://localhost:5001/smart-tutor-lite-a66b5/us-central1/api/transcriptions \
  -X POST \
  -F "file=@audio.wav"
```

## Deployment

### Deploy All Functions

```bash
firebase deploy --only functions
```

### Deploy Specific Function

```bash
firebase deploy --only functions:transcriptions
```

### Deploy with Environment Variables

Environment variables set via `firebase functions:config:set` are automatically included in deployment.

## Function Endpoints

After deployment, functions are available at:

```
https://us-central1-smart-tutor-lite-a66b5.cloudfunctions.net/api/transcriptions
https://us-central1-smart-tutor-lite-a66b5.cloudfunctions.net/api/summaries
https://us-central1-smart-tutor-lite-a66b5.cloudfunctions.net/api/quizzes
https://us-central1-smart-tutor-lite-a66b5.cloudfunctions.net/api/flashcards
https://us-central1-smart-tutor-lite-a66b5.cloudfunctions.net/api/tts
```

## Firestore Security Rules

Set up Firestore security rules in `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write for authenticated users only
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
    
    // Or allow public read, authenticated write
    match /transcriptions/{transcriptionId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only firestore:rules
```

## Firebase Storage Rules

Set up Storage security rules in `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /{allPaths=**} {
      allow read: if true;
      allow write: if request.auth != null;
    }
  }
}
```

Deploy rules:
```bash
firebase deploy --only storage
```

## Monitoring

### View Function Logs

```bash
firebase functions:log
```

### View in Firebase Console

1. Go to Firebase Console
2. Functions → Logs
3. View real-time logs and errors

## Troubleshooting

### Common Issues

1. **"Permission denied" errors**
   - Ensure service account has proper permissions
   - Check Firestore/Storage security rules

2. **"Module not found" errors**
   - Run `npm install` in `functions/` directory
   - Check `package.json` dependencies

3. **Environment variables not working**
   - Use `firebase functions:config:get` to verify
   - Restart emulator after setting config

4. **Deployment failures**
   - Check Node.js version (>=18.0.0)
   - Verify TypeScript compilation: `npm run build`
   - Check Firebase CLI version: `firebase --version`

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Deploy Functions
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: actions/setup-node@v2
        with:
          node-version: '18'
      - run: npm install -g firebase-tools
      - run: cd functions && npm install
      - run: firebase deploy --only functions --token ${{ secrets.FIREBASE_TOKEN }}
```

## Next Steps

- Implement API endpoints in `functions/src/api/`
- Set up Firestore collections and indexes
- Configure Firebase Storage buckets
- Set up monitoring and alerts

For API endpoint documentation, see [API_DOCUMENTATION.md](API_DOCUMENTATION.md).

