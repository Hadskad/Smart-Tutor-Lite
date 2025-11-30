# SmartTutor Lite

An offline-first, AI-powered study assistant for mobile devices. Transcribe lectures, summarize notes & PDFs, generate quizzes, convert PDFs to audio, and support study mode - all optimized for ARM architecture.

## Features

- 🎤 **On-Device Transcription**: Record and transcribe lectures using Whisper.cpp (runs entirely offline)
- 📝 **Smart Summarization**: Generate concise summaries from text or PDF documents
- 📚 **Quiz Generation**: Create quizzes from transcriptions or summaries
- 🔊 **Text-to-Speech**: Convert PDFs to audio for listening on-the-go
- 🎯 **Study Mode**: Generate flashcards and track your study progress
- 🔄 **Offline-First**: Works completely offline, syncs to cloud when online

## Architecture

### Frontend (Flutter)
- **Framework**: Flutter (Dart)
- **Architecture**: Clean Architecture (Domain, Data, Presentation layers)
- **State Management**: BLoC pattern
- **Local Storage**: Hive (cache) + SQFlite (structured data)
- **Native Integration**: FFI for Whisper C++ library

### Backend (Firebase)
- **Functions**: Firebase Functions (Node.js/TypeScript) for AI processing
- **Database**: Firestore for cloud data storage
- **Storage**: Firebase Storage for file uploads
- **AI Services**: 
  - OpenAI GPT for summarization, quiz generation, flashcards
  - ElevenLabs Text-to-Speech for high-quality, natural-sounding audio conversion

### Native Components
- **Android**: C++/JNI bridge for Whisper transcription
- **iOS**: Objective-C++ bridge for Whisper transcription
- **Models**: Quantized Whisper models (ggml-base.en.bin, ggml-tiny.en.bin)

## Getting Started

### Prerequisites

- Flutter SDK (>=3.2.0)
- Dart SDK (>=3.2.0)
- Node.js (>=18.0.0) for Firebase Functions
- Firebase CLI
- Android Studio / Xcode for native development

### Flutter App Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd smart_tutor_lite
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Configure Firebase**
   - Firebase is already configured with `firebase_options.dart`
   - Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in place

5. **Run the app**
   ```bash
   flutter run
   ```

### Whisper Native Setup

On-device transcription depends on the upstream [whisper.cpp](https://github.com/ggerganov/whisper.cpp) sources and quantized `.ggml` models. Run the helper script whenever you set up a new machine or bump the Whisper version:

```bash
bash scripts/setup_whisper.sh
```

The script downloads the requested whisper.cpp release into both the Android (CMake) and iOS (Objective-C++) toolchains, and ensures the default models (`ggml-base.en.bin`, `ggml-tiny.en.bin`) live under `assets/models/`. Set `WHISPER_MODELS="ggml-small.en.bin ggml-base.en.bin"` to pull additional models when needed.

### Firebase Functions Setup

See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for detailed Firebase Functions setup and deployment instructions.

Quick setup:
```bash
cd functions
npm install
firebase deploy --only functions
```

## Project Structure

```
smart_tutor_lite/
├── lib/
│   ├── app/                    # App configuration, routing
│   ├── core/                   # Core utilities, network, errors
│   ├── features/               # Feature modules
│   │   ├── transcription/      # Transcription feature (complete)
│   │   ├── summarization/      # Summarization feature
│   │   ├── quiz/               # Quiz generation feature
│   │   ├── text_to_speech/     # TTS feature
│   │   └── study_mode/         # Study mode feature
│   ├── native_bridge/          # Native code bridges
│   └── injection_container.dart
├── functions/                  # Firebase Functions backend
│   └── src/
│       ├── api/                # API endpoints
│       ├── config/              # Firebase/OpenAI config
│       └── utils/               # Helper functions
├── android/                    # Android native code
├── ios/                        # iOS native code
└── docs/                       # Documentation
```

## Features Status

- ✅ **Transcription**: Fully implemented with on-device Whisper
- ✅ **Summarization**: Domain and data layers complete, presentation in progress
- ⏳ **Quiz Generation**: In progress
- ⏳ **Text-to-Speech**: In progress
- ⏳ **Study Mode**: In progress

## Offline-First Architecture

SmartTutor Lite is designed to work completely offline:

1. **Local Storage**: All data is stored locally using Hive and SQFlite
2. **On-Device AI**: Transcription uses on-device Whisper (no internet required)
3. **Background Sync**: When online, data syncs to Firestore automatically
4. **Queue System**: AI tasks (summarization, quizzes) are queued when offline and processed when online

## ARM Architecture Optimization

The app is optimized for ARM-based mobile devices:

- Native C++/JNI (Android) and Objective-C++ (iOS) for Whisper integration
- Quantized Whisper models for efficient inference
- ARM NEON optimizations for SIMD operations
- Performance monitoring for CPU, memory, and battery usage

See [docs/ARM_AI_OPTIMIZATION.md](docs/ARM_AI_OPTIMIZATION.md) for details.

## Testing

Run tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter test integration_test/
```

## Documentation

- [API Documentation](docs/API_DOCUMENTATION.md) - Firebase Functions API reference
- [Firebase Setup](docs/FIREBASE_SETUP.md) - Firebase Functions deployment guide
- [ARM Optimization](docs/ARM_AI_OPTIMIZATION.md) - ARM architecture optimization details
- [Performance Benchmarks](docs/PERFORMANCE_BENCHMARKS.md) - Performance metrics and benchmarks

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

See [LICENSE](LICENSE) file for details.

## Acknowledgments

- Whisper.cpp for on-device transcription
- OpenAI for cloud AI services
- Firebase for backend infrastructure
