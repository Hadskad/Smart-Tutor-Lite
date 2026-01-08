# Offline Capabilities

This document explains the offline functionality implemented in SmartTutor Lite.

## Overview

SmartTutor Lite is designed as an **offline-first application** that provides full functionality without an internet connection once the user is authenticated and has generated study materials.

## Authentication Offline Support

### How It Works

When a user successfully logs in (via email/password or Google Sign-In), their authentication state is cached locally using SharedPreferences. This allows the app to:

1. **Persist Login State**: Users remain logged in even after closing and reopening the app while offline
2. **Access User Data**: Profile information (name, email, photo) is available offline
3. **Seamless Experience**: No jarring login screen when restarting the app without internet

### Implementation Details

- **Storage**: User data cached in SharedPreferences as JSON
- **Cache Keys**:
  - `cached_auth_user`: Stores user profile data
  - `is_authenticated`: Boolean flag for quick auth check
- **Cache Update**: Automatically updated on login, signup, profile updates
- **Cache Clear**: Automatically cleared on logout or account deletion

### Behavior

**When Online:**
- App checks Firebase Auth for current user
- Refreshes cached data with latest from server
- Proceeds normally

**When Offline:**
- App attempts Firebase Auth check (will fail)
- Falls back to cached user data
- User stays logged in and can access the app
- Profile data displayed from cache

**Limitations:**
- Cannot verify email while offline
- Cannot update profile (photo/name) while offline
- Cannot reset password while offline
- Email verification status not updated until online

## Study Materials Offline Support

All generated study materials are **fully available offline** once created:

### 1. Notes (Transcriptions)
- ✅ **Audio recordings** stored in local filesystem
- ✅ **Transcription text** stored in Hive database (`transcription_cache`)
- ✅ **Metadata** (timestamp, confidence, audio path) cached locally
- ✅ **Lifecycle management** prevents orphaned audio files

### 2. Summaries
- ✅ **Summary text** stored in Hive (`summary_cache`)
- ✅ **Source metadata** (type, ID, creation date) cached
- ✅ **Offline generation queued** when no internet
- ✅ **Auto-sync** processes queue when online

### 3. Quizzes
- ✅ **Questions & answers** stored in Hive (`quiz_cache`)
- ✅ **Quiz results** stored separately (`quiz_result_cache`)
- ✅ **Scores & completion data** persisted locally
- ✅ **Offline generation queued** for background processing

### 4. Flashcards
- ✅ **Card content** (front/back) stored in Hive (`flashcards`)
- ✅ **Study progress** tracked locally (`study_sessions`)
- ✅ **Review data** (count, difficulty, known status) persisted
- ✅ **Fully local** - no remote sync required

### 5. Audio Notes (TTS)
- ✅ **Audio files** downloaded and cached locally
- ✅ **Job metadata** stored in Hive (`tts_job_cache`)
- ✅ **Storage path**: `{app_documents}/tts_audio_cache/{jobId}.mp3`
- ✅ **Offline generation queued** when no connection

### 6. Folders
- ✅ **Folder structure** stored in Hive (`study_folders`)
- ✅ **Material relationships** tracked (`folder_materials`)
- ✅ **100% local** - no remote persistence
- ✅ **Supports all material types** (notes, summaries, quizzes, flashcards, audio)

## Queue-Based Sync System

When operations require internet (AI generation), the app uses an intelligent queue system:

### Queue Behavior

**When Offline:**
1. Request added to local queue (Hive)
2. User notified that request is queued
3. App continues functioning normally

**When Online:**
1. `QueueSyncService` monitors network status
2. Automatically processes all pending queued items
3. Updates cache with generated content
4. Retries failed items (max 3 attempts)

### Queue Types

- **Summary Queue** (`summary_queue`): Queued summary generation requests
- **Quiz Queue** (`quiz_queue`): Queued quiz generation requests
- **TTS Queue** (`tts_queue`): Queued text-to-speech conversion requests
- **Transcription Queue** (SharedPreferences): Queued audio transcription jobs

### Queue Status Lifecycle

```
pending → processing → completed (removed from queue)
                    ↓
                   failed (retry count incremented)
```

## Data Persistence Architecture

### Storage Technologies

- **Hive**: Primary local database for structured data
- **SharedPreferences**: Auth state and simple key-value storage
- **Filesystem**: Audio files (transcriptions, TTS output)
- **Firebase**: Remote storage when online (auth, Firestore, Storage)

### Cache Strategy

```
Read Operation:
1. Check local cache first (Hive)
2. If not found and online → fetch from remote
3. Cache remote data locally
4. Return to user

Write Operation:
1. If online → write to remote + update cache
2. If offline → queue request + notify user
3. Background sync processes queue when online
```

## Network Status Monitoring

The app continuously monitors network connectivity:

- Uses `connectivity_plus` package
- `QueueSyncService` listens for network changes
- Automatically triggers queue processing when online
- Gracefully handles network errors with user-friendly messages

## Testing Offline Functionality

### To Test Authentication Offline:

1. **Login while online**: Sign in with email/password or Google
2. **Close app completely**: Swipe away from recent apps
3. **Enable airplane mode**: Turn off all network connections
4. **Reopen app**: Should load directly to main navigation
5. **Verify user data**: Profile should show cached name and email

### To Test Study Materials Offline:

1. **Generate materials while online**: Create notes, summaries, quizzes, etc.
2. **Enable airplane mode**: Turn off internet
3. **Restart app**: Close and reopen
4. **Access materials**: All previously generated content should be available
5. **Try generating new content**: Should queue for later processing
6. **Disable airplane mode**: Queued items should process automatically

## Files Modified for Offline Support

### Authentication Caching:
- `lib/features/auth/data/datasources/auth_local_datasource.dart` (NEW)
- `lib/features/auth/data/repositories/auth_repository_impl.dart` (UPDATED)

### Already Implemented (Study Materials):
- Queue sync: `lib/core/sync/queue_sync_service.dart`
- Audio management: `lib/core/services/audio_file_manager.dart`
- Local data sources: `lib/features/*/data/datasources/*_local_datasource.dart`
- Queue data sources: `lib/features/*/data/datasources/*_queue_local_datasource.dart`
- Repositories: `lib/features/*/data/repositories/*_repository_impl.dart`

## Best Practices

### For Users:
- Generate study materials while online for immediate availability
- App will queue requests made offline for automatic processing later
- Check queue status after reconnecting to internet

### For Developers:
- Always update cache after successful remote operations
- Clear cache on logout/account deletion
- Handle network errors gracefully with fallback to cache
- Use queue system for operations requiring internet
- Test both online and offline scenarios thoroughly

## Limitations

### What Works Offline:
✅ Stay logged in (auth state persisted)
✅ View all generated study materials
✅ Create folders and organize materials
✅ Study flashcards and take quizzes
✅ Play audio notes
✅ Read summaries

### What Requires Internet:
❌ Initial login/signup
❌ Email verification
❌ Profile photo/name updates
❌ Password reset
❌ Generating new AI content (queued for later)
❌ Syncing data across devices (no remote sync implemented)

## Future Enhancements

Potential improvements for offline functionality:

1. **Background Sync**: Auto-process queues in the background without user opening app
2. **Conflict Resolution**: Handle data conflicts when same material edited on different devices
3. **Selective Sync**: Allow users to choose which materials to keep offline
4. **Storage Management**: UI to view and clear cached data
5. **Sync Status Indicators**: Show sync progress for queued items
6. **Pre-caching**: Download materials for offline use before going offline
