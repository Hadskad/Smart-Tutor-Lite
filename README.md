# SmartTutor Lite

An offline-first, AI-powered study assistant for mobile devices. Transcribe lectures, summarize notes & PDFs, generate quizzes, convert PDFs to audio, and support study mode - all optimized for ARM architecture.

## Features

- **On-Device Transcription**: Record and transcribe lectures using Whisper.cpp (runs entirely offline), or optionally with the online mode, for better structured notes.
-  **Smart Summarization**: Generate concise summaries from generated notes or PDF documents
-  **Quiz Generation**: Create quizzes from transcriptions or summaries
-  **Text-to-Speech**: Convert PDFs to audio for listening on-the-go
-  **Study Mode**: Generate flashcards and track your study progress
-  **Offline-First**

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
  - Soniox for Transcription
  - OpenAI GPT for summarization, quiz generation, flashcards
  - ElevenLabs Text-to-Speech for high-quality, natural-sounding audio conversion

### Native Components
- **Android**: C++/JNI bridge for Whisper transcription
- **iOS**: Objective-C++ bridge for Whisper transcription
- **Models**: Quantized Whisper models (ggml-base.en.bin, ggml-tiny.en.bin)

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (>=3.2.0) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (>=3.2.0) - Included with Flutter
- **Node.js** (>=20.0.0) - Required for Firebase Functions - [Download Node.js](https://nodejs.org/)
- **Firebase CLI** - Install via `npm install -g firebase-tools`
- **Android Studio** (for Android development)
  - Android SDK
  - Android NDK (required for native Whisper integration)
  - CMake (>=3.22.1, required for native builds)
- **Xcode** (>=14.0, for iOS development on macOS only)
  - CocoaPods - Install via `sudo gem install cocoapods`
- **Git** - For cloning the repository

#### Verify Prerequisites

After installing the prerequisites, verify your setup:

```bash
# Check Flutter installation and environment
flutter doctor -v

# Verify Node.js version
node --version  # Should be >=20.0.0

# Verify Firebase CLI
firebase --version

# Verify CocoaPods (macOS/iOS only)
pod --version
```

**Important**: Resolve any issues reported by `flutter doctor` before proceeding. Common fixes:
- Accept Android licenses: `flutter doctor --android-licenses`
- Install missing Xcode components (macOS only)
- Install missing Android SDK components via Android Studio

### Quick Start Guide

For a comprehensive build guide with detailed ARM device instructions, see [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md).

### Flutter App Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Hadskad/Smart-Tutor-Lite.git
   cd smart_tutor_lite
   ```

2. **Download Missing Files**
   
   ⚠️ **Important**: Several required files are excluded from the repository (see `.gitignore`). You must download them separately before building.
   
   **See [SETUP.md](SETUP.md) for complete instructions on obtaining:**
   - Whisper model files (required for transcription)
   - Firebase configuration files
   - Generated code files
   - Environment variables
   
   Quick reference:
   ```bash
   # Download Whisper models and native sources
   bash scripts/setup_whisper.sh
   
   # Generate Firebase configuration files
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

3. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

4. **Generate code**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Configure Firebase**
   
   If you haven't already, set up Firebase:
   - Install FlutterFire CLI: `dart pub global activate flutterfire_cli`
   - Configure Firebase: `flutterfire configure`
   - This generates `firebase_options.dart` and downloads config files
   - Ensure `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are in place
   
   For detailed Firebase setup, see [SETUP.md](SETUP.md) and [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md)

6. **Setup iOS Dependencies (iOS/macOS only)**
   
   Install CocoaPods dependencies:
   ```bash
   cd ios
   pod install
   cd ..
   ```
   
   **Note**: CocoaPods must be installed first. If you get errors:
   ```bash
   # Install CocoaPods (macOS only)
   sudo gem install cocoapods
   ```

7. **Setup Android Native Build Tools**
   
   Ensure Android NDK and CMake are installed:
   - Open Android Studio
   - Go to **Tools → SDK Manager → SDK Tools**
   - Check and install:
     - **NDK (Side by side)** - Required for native Whisper C++ builds
     - **CMake** - Required for building native libraries (version 3.22.1+)
   - Click **Apply** to install
   
   Verify installation:
   ```bash
   # Check if NDK is installed (path may vary)
   ls $ANDROID_HOME/ndk/  # or $ANDROID_SDK_ROOT/ndk/
   
   # Check CMake version
   cmake --version  # Should be >=3.22.1
   ```

8. **Run the app**
   ```bash
   flutter run
   ```

### Building for Production

#### Build Android APK (ARM64)

```bash
# Build release APK for ARM64 devices
flutter build apk --release --target-platform android-arm64

# Or build for all ARM architectures (recommended)
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

Output location: `build/app/outputs/flutter-apk/app-release.apk`

#### Build iOS (ARM64 - Physical Devices Only)

```bash
# Build for iOS device (ARM64)
flutter build ios --release

# Or use Xcode for more control
open ios/Runner.xcworkspace
```

**Note**: 
- iOS builds target ARM64 by default on physical devices
- Requires macOS with Xcode installed
- Requires valid signing certificates for device deployment

#### Build Commands Reference

```bash
# Development builds
flutter run                    # Run in debug mode
flutter run --release          # Run in release mode

# Android builds
flutter build apk              # APK for all architectures
flutter build apk --split-per-abi  # Separate APKs per architecture
flutter build appbundle        # App Bundle for Play Store

# iOS builds (macOS only)
flutter build ios              # iOS release build
flutter build ios --debug      # iOS debug build

# Verify ARM architecture
flutter build apk --release --target-platform android-arm64
```

For detailed build instructions including ARM-specific optimizations, troubleshooting, and deployment guides, see [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md).

### Firebase Functions Setup

See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for detailed Firebase Functions setup and deployment instructions.

Quick setup:
```bash
cd functions
npm install
firebase deploy --only functions
```

**Important**: Don't forget to set API keys:
```bash
firebase functions:config:set openai.api_key="YOUR_OPENAI_API_KEY"
firebase functions:config:set elevenlabs.api_key="YOUR_ELEVENLABS_API_KEY"
firebase functions:config:set soniox.api_key="YOUR_SONIOX_API_KEY"
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

SmartTutor Lite is designed to work offline:

1. **Local Storage**: All data is stored locally using Hive and SQFlite
2. **On-Device AI**: Transcription uses on-device Whisper (no internet required)
3. **Background Sync**: When online, data syncs to Firestore automatically
4. **Queue System**: AI tasks (summarization, quiz generation, text-to-speech) are automatically queued when offline and processed when connectivity is restored
   - Requests are stored locally in Hive when offline
   - Queue sync service monitors network connectivity
   - When online, queued tasks are processed automatically in the background
   - Failed tasks are retried up to 3 times before being marked as failed
   - Users receive feedback when requests are queued vs. processed immediately

## ARM Architecture Optimization

SmartTutor Lite is optimized for ARM-based mobile devices as part of the **ARM AI Challenge**:

- Native C++/JNI (Android) and Objective-C++ (iOS) for Whisper integration
- Quantized Whisper models for efficient inference
- ARM NEON optimizations for SIMD operations
- Performance monitoring for CPU, memory, and battery usage
- On-device AI processing with minimal battery impact

See [HACKATHON_COMPLIANCE.md](HACKATHON_COMPLIANCE.md) for detailed compliance information and [docs/ARM_AI_OPTIMIZATION.md](docs/ARM_AI_OPTIMIZATION.md) for technical details.

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

- **[BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md)** - Comprehensive step-by-step build guide for ARM devices
- **[SETUP.md](SETUP.md)** - Guide to obtain missing files not in repository
- [Hackathon Compliance](HACKATHON_COMPLIANCE.md) - ARM AI Challenge compliance details
- [Firebase Setup](docs/FIREBASE_SETUP.md) - Firebase Functions deployment guide



## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## Acknowledgments

- [Whisper.cpp](https://github.com/ggerganov/whisper.cpp) for on-device transcription
- OpenAI for cloud AI services (summarization, quiz generation, flashcards)
- ElevenLabs for high-quality text-to-speech
- Firebase for backend infrastructure
- Built for the ARM AI Challenge

## License

See [LICENSE](LICENSE) file for details.
