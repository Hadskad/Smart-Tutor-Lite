# Transcription Performance Benchmarks

## Targets

- Short recordings (≤30 min):
  - Online (Soniox) completes in 90 seconds or less.
  - Offline (Whisper) completes in 120 seconds or less.
- Medium recordings (30–60 min):
  - Online completes in 3 minutes or less.
  - Offline completes in 5 minutes or less.
- Long recordings (60–120 min):
  - Online completes in 6 minutes or less.
  - Offline completes in 8 minutes or less.
- Failure tolerance:
  - Keep end-to-end job failures under 2% of all attempts.
  - When failures are transient (provider down, timeout), set `canRetry = true`
    so the app can offer a one-tap retry.

## Mode Priorities

1. Online Soniox is preferred when:
   - Network is connected and stable.
   - Recording length is below roughly 90 minutes.
   - The user has not enabled “Always use offline mode”.
2. Offline Whisper is used when:
   - The device is offline or on a weak / flaky connection.
   - The user has explicitly enabled “Always use offline mode”.
3. Automatic fallback:
   - If an online job fails and offline mode is available, the app should offer
     to fall back to on-device Whisper.
   - If offline transcription fails and network is available, the app should
     suggest switching to online mode.

## Measurement Strategy

- Log timestamps for:
  - Recording stop → upload start and completion.
  - Upload completion → transcription start and completion.
  - Transcription completion → note generation completion (when enabled).
- For each transcription job, record:
  - Mode (`online_soniox` vs `offline_whisper`).
  - Duration buckets (short / medium / long).
  - Error codes and whether `canRetry` was set.
- Use these logs and metrics to regularly compute:
  - Median and 95th percentile times for each duration bucket and mode.
  - Failure rate per mode and per error code.
- Update this document with real benchmark numbers after running manual tests
  on short, medium, and long recordings on at least one mid-range device.


