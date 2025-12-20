---
name: Robust Transcription Reliability Plan
overview: ""
todos:
  - id: 798d5228-4517-4422-92b0-ec29c6598eb0
    content: "Phase 5: Text-to-Speech (TTS) Feature"
    status: pending
  - id: 662b7e2a-a282-4d6b-883f-030706e22787
    content: Integrate Google Cloud TTS with Neural2/WaveNet voices
    status: pending
  - id: 1ec80029-9aa6-4e8d-8023-b472be1dbe25
    content: Add voice selection UI to Flutter TTS page
    status: pending
  - id: eae366f8-d4cf-4f30-800b-e0e257a1e2cd
    content: Design the TranscriptionJob Firestore schema and end-to-end state machine for transcription jobs.
    status: pending
  - id: 305c6a86-8bc9-4d2d-a3f4-2567859b82c0
    content: Implement the online Soniox transcription pipeline using Storage uploads, job workers, chunking/async processing, and structured error handling.
    status: pending
  - id: ff76e23b-9389-48cd-a8c2-571878c45cd2
    content: Harden the offline Whisper path with model integrity checks, single-context reuse, robust error mapping, and background processing.
    status: pending
  - id: a297ef49-74bb-40ac-83c8-e8d981f92619
    content: Implement mode selection, fallback logic, and long-job UX in the Flutter BLoC and UI, including clear states and retry actions.
    status: pending
  - id: c63bfeca-41c0-498d-93f0-45bc4396f631
    content: Add structured logging, basic metrics, retention policies, and cost guards for Storage, Functions, and Firestore.
    status: pending
  - id: 65f5a99e-fae3-47a7-8978-9ffe61374849
    content: Create and execute a test plan (unit, integration, manual) covering short, medium, and long recordings, noisy environments, and network edge cases.
    status: pending
---

# Robust Transcription Reliability Plan

## 1. Goals & Constraints

- **Goal**: Make transcription (offline Whisper + online Soniox) *rarely fail* for real student lectures, including long sessions (up to ~3 hours), with clear UX and predictable behavior.
- **Constraints & assumptions**:
- Flutter mobile app with existing offline Whisper FFI and Firebase Functions backend using Soniox + OpenAI.
- Lectures can be very long; we must support multi-hour audio without fragile single long HTTP calls.
- Costs must remain reasonable; Firebase should act as a reliable pipeline/orchestrator, not the main cost driver.

## 2. End-to-End Architecture Overview

- **2.1 Unified transcription flow (conceptual)**
- User records lecture in app → audio stored as a **compressed file** on device.
- On stop:
- App creates a **Transcription Job** (in Firestore) and **uploads audio to Firebase Storage**.
- Cloud Functions pick up the job, orchestrate **online Soniox transcription** (with chunking/async patterns) and **note generation**.
- Offline Whisper remains a separate **local-only path** that can be chosen explicitly or used as fallback.
- App listens to **job status updates** and presents progress + final transcript/note.

- **2.2 Two distinct engines, one orchestration layer**
- **Offline path**: Whisper.cpp via FFI; uses locally recorded file, processes in background, saves result in local storage (Hive) and/or Firestore when online.
- **Online path**: Firebase Functions (`/transcriptions`) with Soniox; note generation via OpenAI.
- BLoC in Flutter coordinates **mode selection**, error handling, retries, and UX.

## 3. Input Recording & Precondition Best Practices

- **3.1 Recording format & storage (Flutter)**
- Record to a **compressed, streaming-friendly format** (e.g. AAC or Opus in `m4a` / `webm`) instead of raw PCM/WAV to keep file sizes modest for multi-hour recordings.
- Use a **single recording file per session**; show elapsed time and approximate size as feedback.
- Ensure audio is **mono** where possible to halve size and processing load without hurting intelligibility.

- **3.2 Robust precondition checks before transcription**
- Verify **microphone permission** before recording; surface a clear, actionable dialog if denied.
- After recording stops:
- Check **minimum duration** (e.g. ≥ 2–3 seconds) and **minimum size**; if too short, treat as “no content” and show a helpful message instead of calling STT.
- Estimate **duration and size** from metadata; if extreme (e.g. > 4–5 hours or multiple GB), warn user about potential time/cost and suggest trimming if appropriate.
- For **online** path, verify **network connectivity** (via `connectivity_plus`) and show a specific “No internet” or “Weak connection” message rather than letting upload/transcription fail in a confusing way.

- **3.3 Audio quality guidance in UI**
- Display concise tips near the record button: speak clearly, near the mic, avoid loud background noise.
- Optionally, detect **very low input level** (silence) during recording and prompt the user if the mic seems covered or muted.

## 4. Transcription Job Model (Backend & Frontend)

- **4.1 Firestore `TranscriptionJob` document design**
- Collection: `transcription_jobs` with fields such as:
- `userId`, `createdAt`, `updatedAt`.
- `status`: `pending | uploading | processing | generating_note | done | error`.
- `mode`: `online_soniox | offline_whisper` (for diagnostic clarity).
- `audioStoragePath`: path to audio file in Firebase Storage (for online mode).
- `localAudioPath`: optional local path (for offline mode / debug, never synced as PII if not desired).
- `durationSeconds`, `approxSizeBytes`.
- `progress`: 0–100 (coarse increments).
- `transcriptId` / `noteId`: references to stored text artifacts.
- `errorCode`, `errorMessage`, `canRetry`: for robust error surfacing.

- **4.2 Job lifecycle best practices**
- App creates job with status `pending` **before** upload starts.
- As upload begins, status → `uploading`; once Storage upload is finalized, status → `processing`.
- Worker functions update status through `processing` → `generating_note` → `done` or `error`.
- Avoid **high-frequency updates**; use coarse steps to minimize Firestore write/read volume (e.g. only update when moving between major states or when progress jumps by ≥10–20%).

- **4.3 Flutter integration**
- BLoC subscribes to the job doc stream and maps job states into UI states (Loading, Uploading, Transcribing, Generating Note, Completed, Error).
- Provide **one-tap retry** actions when `canRetry` is true (e.g. retry Soniox call without re-uploading audio if still present in Storage).

## 5. Online Path: Soniox via Firebase Functions

- **5.1 Storage upload pattern**
- In Flutter, upload the recorded file to Firebase Storage using a **resumable upload** API.
- Use a **single region** for Storage, Functions, and Firestore (e.g. `us-central1`) to keep internal traffic low-latency and cheap.
- After upload completion, set `audioStoragePath` and move job status to `processing`.

- **5.2 Worker function design (Soniox integration)**
- Implement either:
- A **Storage-triggered** worker that reacts to new/updated lecture audio uploads and corresponding jobs, or
- A **job-polling** HTTP/cron worker that scans `pending`/`processing` jobs.
- Best practices:
- Read audio from Storage in **streaming fashion** when possible; avoid loading multi-hour files fully into memory.
- Use **provider-recommended encoding and sample rate**; re-encode server-side if necessary.
- Set a **finite but generous timeout** per Soniox request (e.g. 60–120 seconds per chunk) rather than disabling timeouts.

- **5.3 Handling long audio with chunking / async APIs**
- Prefer Soniox’s **long-form/async/batch API** if available; otherwise, implement **server-side chunking**:
- Split audio into chunks of e.g. 10–15 minutes on the server (or via Soniox options if supported).
- For each chunk:
- Make a separate Soniox call with normal timeouts.
- Aggregate transcripts and confidences, preserving order.
- Save intermediate results so partial work isn’t lost if the function restarts.
- Once all chunks are processed, **merge** them into a single transcript and update the job status and references.

- **5.4 Error handling & resilience (Soniox)**
- Standardize a **`SonioxError`** type with:
- `status` (HTTP),
- `code` (e.g. `bad_audio`, `too_long`, `quota_exceeded`, `provider_down`, `timeout`),
- user-safe `message`.
- Do **not** save empty or placeholder transcripts on failure.
- Log errors to Functions logs with **minimal PII**: include job ID, status code, and high-level reason, but not full transcript/audio.

## 6. Offline Path: Whisper FFI Best Practices

- **6.1 Model asset integrity & loading**
- Keep Whisper models under `assets/models/` and validate that:
- They are correctly listed in `pubspec.yaml` assets.
- `rootBundle.load()` succeeds at startup (optional self-check).
- On first use:
- Copy the model from assets to a **private app directory** (e.g. cache or app data).
- Compute a **checksum** and cache it; if checksum fails later, re-copy from assets.
- Initialize Whisper context **once per app session** and reuse it for all offline transcriptions to avoid repeated heavy init.

- **6.2 Resource management**
- Use a **background isolate or dedicated async execution** for Whisper processing to keep UI responsive.
- For very long audio:
- Consider chunking to avoid huge memory spikes and to provide incremental progress.
- Show a persistent notification or foreground service on Android if processing is long-running, to avoid OS killing the process.

- **6.3 Error mapping & fallback**
- Wrap all FFI calls in try–catch and map them into structured failures:
- `WhisperInitFailure` (model issues),
- `WhisperRuntimeFailure` (internal error),
- `WhisperNoSpeechDetected` (silence / too noisy).
- BLoC maps these into clear messages and (when relevant) offers to switch to **cloud mode** if available.

## 7. Mode Selection & Fallback Logic (Flutter)

- **7.1 Configuration of default mode**
- Define a single configuration point (e.g. in a repository or use case) that decides:
- **Preferred mode**: `online_soniox` (for best accuracy and offloading) or `offline_whisper` (for maximum privacy / offline support).
- Conditions: network availability, user preference toggle (“Always use offline mode”), device performance hints.

- **7.2 Flow when user requests transcription**
- Step 1: Validate recording (duration, size, permissions).
- Step 2: Determine mode:
- If **online** is preferred and **network OK** → go through Storage + `TranscriptionJob` creation.
- If **network not OK** or online mode disabled/overloaded → use **offline Whisper**.
- Step 3: Error/fallback handling:
- If online path fails with `canRetry = true` and offline is available → offer to **fall back to offline**.
- If offline fails due to model/init issues and network is available → suggest switching to **online**.

- **7.3 UX best practices for long jobs**
- Show clear states: `Recording`, `Uploading`, `Transcribing`, `Generating Note`, `Completed`.
- For long lectures, allow the user to **leave the screen / app** and receive a notification or in-app banner when transcription is ready.
- Avoid blocking UI with indefinite spinners; always show contextual text, e.g. “This may take a few minutes for long lectures, but you can safely close the app.”

## 8. Note Generation & Post-processing

- **8.1 Decouple STT from note generation**
- Once the transcript is ready, **store it first** (e.g. in Firestore and/or Hive) before generating notes, summaries, quizzes, flashcards.
- Treat note generation as a **second stage** with its own status (`generating_note`) and error handling.

- **8.2 Robust note generation with GPT-4.1 mini**
- Use explicit, deterministic prompts for note structure to minimize parsing errors.
- Implement timeouts and retries for OpenAI calls separately from Soniox; failures in note generation should not invalidate the transcript itself.
- Surface partial results when possible (e.g. transcript available even if note generation failed) with an option to “Retry note generation only.”

## 9. Observability, Monitoring & Cost Controls

- **9.1 Minimal but structured logging**
- Log per job:
- Job ID, user ID (or hashed), duration, mode.
- Key events: job created, upload done, transcription started, transcription finished, note generated, errors.
- Avoid logging full text/audio; log only high-level metadata and error codes.

- **9.2 Metrics for reliability**
- Track (even if only via logs initially):
- Number of jobs by status (`done`, `error`),
- Error breakdown by `mode` and `errorCode`,
- Average/percentile time from stop-recording → transcript ready → note ready.
- Use these metrics to identify weak spots (e.g. Soniox timeouts, offline OOM, very long uploads).

- **9.3 Cost-conscious policies**
- Use compressed audio and **delete or downsample** raw audio after successful transcription and note generation, or after a retention period.
- Keep Functions, Firestore, and Storage in the **same region**.
- Implement a simple **retention policy** for old jobs and artifacts (e.g. archive or delete jobs older than N months that have transcripts/notes safely stored).
- Set up **budget alerts** in Google Cloud to detect unexpected spikes.

## 10. Testing & QA Strategy

- **10.1 Automated tests (where practical)**
- Unit tests for:
- `TranscriptionJob` state transitions.
- Error mapping logic (Soniox/Whisper errors → user-facing messages).
- Mode selection (online vs offline) given various conditions.
- Integration tests (with mocks) for:
- Successful Soniox transcription job.
- Soniox timeout / error with graceful failure.
- Whisper offline processing of short and long samples.

- **10.2 Manual test matrix**
- Short (30s), medium (10–15min), and long (1–3h) recordings.
- Good vs noisy environments.
- Strong vs weak / flaky networks.
- Offline-only scenarios (no network during and after recording).

- **10.3 Regression and usability checks**
- Verify that users are **never left with no feedback**: every failure path must have a clear explanation and at least one actionable next step (retry, switch mode, check connection).
- Confirm that existing flows (e.g. accessing past notes, summaries, quizzes) still work seamlessly with the new job-based transcription pipeline.