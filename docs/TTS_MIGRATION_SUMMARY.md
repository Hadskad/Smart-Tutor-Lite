# TTS Migration Summary: Google Cloud to ElevenLabs

## Migration Date
Completed: [Current Date]

## Overview
Successfully migrated Text-to-Speech service from Google Cloud TTS to ElevenLabs API.

## Changes Made

### Backend (Firebase Functions)

#### Files Created
- `functions/src/config/elevenlabs-tts.ts` - ElevenLabs API configuration and voice definitions
- `docs/ELEVENLABS_TTS_SETUP.md` - Complete setup and usage documentation

#### Files Modified
- `functions/src/utils/tts-helpers.ts` - Replaced Google Cloud client with ElevenLabs REST API calls
- `functions/src/api/tts.ts` - Updated imports and default voice to use ElevenLabs
- `functions/package.json` - Removed `@google-cloud/text-to-speech` dependency

#### Files Deleted
- `functions/src/config/google-tts.ts` - No longer needed

### Frontend (Flutter)

#### Files Modified
- `lib/features/text_to_speech/presentation/pages/tts_page.dart` - Updated voice options to ElevenLabs voices
- `lib/features/text_to_speech/presentation/bloc/tts_event.dart` - Updated default voices to ElevenLabs

### Documentation

#### Files Created
- `docs/ELEVENLABS_TTS_SETUP.md` - New setup guide for ElevenLabs

#### Files Modified
- `README.md` - Updated AI Services section to mention ElevenLabs instead of Google Cloud

#### Files Retained (for reference)
- `docs/GOOGLE_TTS_SETUP.md` - Kept for historical reference

## Voice Mapping

### Old (Google Cloud) → New (ElevenLabs)

| Old Voice ID | Old Name | New Voice ID | New Name |
|--------------|----------|-------------|----------|
| `en-US-Neural2-C` | Female Neural2 | `21m00Tcm4TlvDq8ikWAM` | Rachel |
| `en-US-Neural2-A` | Male Neural2 | `pNInz6obpgDQGcFmaJgB` | Adam |
| `en-US-Wavenet-C` | Female WaveNet | `EXAVITQu4vr4xnSDxMaL` | Bella |
| `en-US-Wavenet-A` | Male WaveNet | `ErXwobaYiN019PkySvjV` | Antoni |

## Configuration Changes

### Before (Google Cloud)
- Required: Google Cloud service account with TTS permissions
- Setup: Enable Cloud Text-to-Speech API
- Authentication: Service account credentials

### After (ElevenLabs)
- Required: ElevenLabs API key
- Setup: Sign up at elevenlabs.io and get API key
- Authentication: Simple API key in Firebase Functions config

## API Changes

### Request Format
No changes - API contract remains the same:
```json
{
  "sourceType": "text",
  "sourceId": "text content",
  "voice": "voice-id"
}
```

### Response Format
No changes - Response format remains the same.

### Breaking Changes
- Old Google Cloud voice IDs will no longer work
- Existing TTS jobs in Firestore with old voice IDs will fail if reprocessed
- No automatic migration of existing jobs (they remain in database but won't work)

## Testing Checklist

- [x] TypeScript compilation successful
- [x] No linting errors
- [x] Dependencies updated
- [ ] Set ElevenLabs API key in Firebase Functions config
- [ ] Test text-to-speech conversion locally
- [ ] Test PDF-to-audio conversion locally
- [ ] Test with each premade voice
- [ ] Test long text chunking (>5000 chars)
- [ ] Test error handling (invalid API key, invalid voice ID)
- [ ] Deploy to production
- [ ] Test in production environment

## Next Steps

1. **Set API Key**: Configure ElevenLabs API key in Firebase Functions
   ```bash
   firebase functions:config:set elevenlabs.api_key="YOUR_API_KEY"
   ```

2. **Local Testing**: Test with Firebase emulators
   ```bash
   cd functions
   npm run serve
   ```

3. **Production Deployment**: Deploy updated functions
   ```bash
   cd functions
   npm run deploy
   ```

4. **Monitor**: Watch for any errors in Firebase Functions logs

5. **User Communication**: If users have existing TTS jobs, they may need to regenerate them with new voice IDs

## Rollback Plan

If issues arise, rollback steps:

1. Restore `functions/src/config/google-tts.ts` from git history
2. Restore `functions/src/utils/tts-helpers.ts` to use Google Cloud client
3. Update `functions/src/api/tts.ts` imports
4. Add back `@google-cloud/text-to-speech` to `package.json`
5. Revert Flutter voice options
6. Redeploy functions

## Benefits of Migration

1. **Better Voice Quality**: ElevenLabs provides more natural-sounding voices
2. **Simpler Setup**: No service account configuration needed
3. **More Flexible**: Support for custom voice IDs from user accounts
4. **Better Pricing**: Free tier available for testing
5. **Voice Cloning**: Potential for future voice cloning features

## Notes

- Old TTS jobs in Firestore will remain but won't work with new system
- Users will need to regenerate TTS jobs with new voice IDs
- Custom voice IDs from ElevenLabs accounts are supported
- API contract unchanged - no breaking changes for clients

