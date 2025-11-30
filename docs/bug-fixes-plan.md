SmartTutor Lite Comprehensive Remediation Plan
Phase 1: Build & Dependency Baseline
1.1 Resolve Gradle Plugin Conflict
File: android/build.gradle.kts
Remove duplicate com.google.gms.google-services plugin block (lines 1-4). Plugin remains declared in android/settings.gradle.kts.
1.2 Update FlutterFire & Core Packages
File: pubspec.yaml
Bump Firebase packages to latest stable compatible versions (e.g., firebase_core, firebase_auth, cloud_firestore, firebase_storage).
Run flutter pub upgrade firebase_core firebase_auth cloud_firestore firebase_storage.
Re-run flutter pub get.
1.3 Regenerate DI & Clean Build
Run flutter clean, flutter pub get, flutter pub run build_runner build --delete-conflicting-outputs.
---

Phase 2: Security & Data Protection
2.1 Secure File Uploads
File: functions/src/utils/storage-helpers.ts
Modify uploadFile to stop calling makePublic() and instead return { storagePath, signedUrl } with getSignedUrl.
2.2 Persist Storage Paths
File: functions/src/api/transcriptions.ts, functions/src/api/tts.ts
Store storagePath alongside audioUrl in Firestore (transcription doc, TTS job doc).
Update DELETE handlers to read storagePath from Firestore and pass it to deleteFile.
2.3 Bucket via Environment Variable
File: functions/src/utils/storage-helpers.ts
Replace constant bucket string with process.env.FIREBASE_STORAGE_BUCKET ?? 'smart-tutor-lite-a66b5.appspot.com'.
2.4 Client-Side Caching Fallback Security
Add logic later (Phase 4) to fall back to cached data on server errors to avoid exposure of stale/missing data responses.
---

Phase 3: Backend Robustness & Performance
3.1 Consolidate downloadFile
File: functions/src/api/summaries.ts
Remove local downloadFile; import from ../utils/storage-helpers to avoid inconsistent HTTP handling.
3.2 Add CORS Middleware
Files: All Express apps in functions/src/api/*
import cors from 'cors'; and app.use(cors({ origin: true })); before request handlers.
Add dependency cors and @types/cors in functions/package.json.
3.3 OpenAI Response Validation
File: functions/src/utils/openai-helpers.ts
Introduce schema validation (e.g., with simple manual checks or zod) to ensure generateQuiz/generateFlashcards/summarizeText parse valid JSON; throw explicit errors otherwise.
3.4 PDF Size Guardrails
File: functions/src/utils/storage-helpers.ts
Before downloading/processing PDFs, check content-length header; reject files > e.g., 25MB to prevent memory pressure.
3.5 Backend Quiz Scoring Endpoint (Optional but recommended)
Outline future endpoint under /quiz-results that accepts quiz answers and computes scores server-side (documented for later release).

Endpoint blueprint:
- **Route:** `POST /quiz-results`
- **Request Body:** `{ quizId: string, userId?: string, answers: Array<{ questionId: string, selectedIndex: number }> }`
- **Processing:** Fetch quiz definition from Firestore, compare answers server-side, compute score, accuracy per question, and persist attempt history.
- **Response:** `{ quizId, totalQuestions, correct, incorrect, percentage, breakdown: [{ questionId, correctAnswer, selectedIndex, isCorrect }] }`
- **Security:** Validate that the quiz exists and only expose correct answers in the response payload, not to the client before submission.
---

Phase 4: Flutter Offline & Error Handling Improvements
4.1 StudyMode Offline Fallback
File: lib/features/study_mode/data/repositories/study_mode_repository_impl.dart
Wrap remote call in try/catch; on error (including 500), load cached flashcards via _localDataSource.getFlashcardsBySource before returning failure.
Extract helper _fallbackToLocalFlashcards to keep code clean.
4.2 NetworkInfo API Compatibility
File: lib/core/network/network_info.dart
Update for new connectivity_plus API returning List<ConnectivityResult>.
4.3 ApiClient Timeouts & Retry Hooks
File: lib/core/network/api_client.dart
Reduce timeouts (e.g., 15s connect, 20s receive) and optionally plug simple retry logic for idempotent GET requests.
---

Phase 5: Native Whisper Implementation (Critical Feature)
5.1 Android Whisper Integration
File: android/app/src/main/cpp/whisper_jni.cpp
Replace placeholder comment with actual whisper_full_default_params, load model context, run inference using whisper_full / whisper_full_parallel. Convert result segments into final string and return through JNI.
Ensure libwhisper.so and models are bundled (update Gradle/CMake if needed).
5.2 iOS Whisper Integration
File: ios/Runner/whisper_wrapper.mm
Implement inference using whisper_full_default_params against floatSamples. Return transcripts rather than placeholder text.
Ensure Whisper framework is linked via Xcode project.
5.3 Whisper Model Asset Management
Files: pubspec.yaml, scripts/setup_whisper.sh, asset folders under assets/models/
Confirm default .ggml model is included or documented for download. Provide setup script.
5.4 Dispose Whisper Contexts Properly
Ensure WhisperFfi.dispose() is called when not needed (e.g., on app shutdown) to free native memory.
---

Phase 6: Flutter Application Logic
6.1 TranscriptionBloc Repository Integration
File: lib/features/transcription/presentation/bloc/transcription_bloc.dart
Inject TranscriptionRepository via constructor.
Update _onLoad to fetch from repository and populate _history.
6.2 AudioRecorder Resource Cleanup
Same file: call await _recorder.dispose() inside close().
6.3 StudyMode FlipCard Event Refactor
Files:
lib/features/study_mode/presentation/bloc/study_mode_event.dart
lib/features/study_mode/presentation/bloc/study_mode_bloc.dart
Add FlipCardEvent; register handler on<FlipCardEvent>(_onFlipCard); remove direct emit call from flipCard().
6.4 TTS Default Voice Alignment
File: lib/features/text_to_speech/data/repositories/tts_repository_impl.dart
Change default voice parameter to ElevenLabs DEFAULT_VOICE_ID.
6.5 Navigation Setup Cleanup
File: lib/app/app.dart
Remove initialRoute when home: MainNavigation is set.
Remove unused import 'routes.dart'; if no longer necessary.
6.6 PerformanceBridge Logging
File: lib/native_bridge/performance_bridge.dart
Add debugPrint in catch blocks for both startSegment and endSegment so native failures are visible during dev/testing.
6.7 Hive Box Access Consistency
Audit data sources (quiz, flashcards, study sessions) to ensure boxes are opened once and reused; refactor to shared helper methods as needed.
---

Phase 7: Testing & Verification
7.1 Automated Tests
Add unit tests for repositories (summary, quiz, study mode, transcription) verifying offline fallback behavior.
Add widget tests for TranscriptionPage (history loads), StudyMode (flip card event), TTS page (voice dropdown default).
7.2 Integration / E2E Tests
Expand integration tests to simulate recording → transcription → quiz/flashcards generation.
7.3 Backend Tests
Add Vitest/Jest tests for Firebase Functions (summaries, quizzes, flashcards, tts) using mocked OpenAI responses.
7.4 Manual QA Checklist
Document manual regression steps across all features (record audio, summary, quiz, study, TTS) on emulator and physical device.
---

Phase 8: Documentation & Deployment Readiness
8.1 Update Documentation
docs/ELEVENLABS_TTS_SETUP.md: mention signed URL usage.
docs/PHASE_5_COMPLETION_SUMMARY.md: update with Whisper integration proof.
Add new doc docs/TESTING_GUIDE.md describing test suites.
8.2 CI Enhancements (optional but recommended)
Add GitHub Actions workflow for Flutter analyze/test and Firebase Functions lint/test.
---

Todos
gradle-fix – Remove duplicate Google Services plugin from android/build.gradle.kts.
deps-update – Upgrade Firebase & related packages in pubspec.yaml.
secure-upload – Update uploadFile to return signed URLs and remove makePublic().
storage-path – Store storagePath fields in Firestore (transcriptions, TTS jobs).
env-bucket – Use env var for bucket name.
dedupe-download – Remove duplicate downloadFile implementation in summaries.ts.
add-cors – Apply CORS middleware to all backend Express apps.
openai-validate – Add schema validation for OpenAI responses.
pdf-guard – Enforce PDF size limits before processing.
fallback-study – Add reliable offline/remote fallback logic in StudyModeRepositoryImpl.
networkinfo-api – Update NetworkInfo to handle new connectivity_plus API.
api-client-timeouts – Adjust timeouts and optional retries.
whisper-android – Implement real whisper.cpp inference on Android.
whisper-ios – Implement real whisper.cpp inference on iOS.
whisper-assets – Ensure Whisper model assets/scripts are in repo.
transcription-history – Inject repo & load history in TranscriptionBloc.
recorder-dispose – Call _recorder.dispose() on close().
studymode-emit – Replace direct emit with FlipCardEvent handler.
tts-voice-default – Switch default voice to ElevenLabs ID.
navigation-cleanup – Remove conflicting initialRoute/unused imports.
perf-logging – Add debug logging to PerformanceBridge catches.
hive-consistency – Audit and refactor Hive box usage.
automated-tests – Expand unit/widget/integration test coverage.
backend-tests – Add tests for Firebase Functions.
docs-update – Refresh docs with new security/testing info.
manual-qa – Capture manual regression checklist.
