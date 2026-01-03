# SmartTutor Lite

An offline-first, AI-powered study assistant for mobile devices. Record and convert recorded lectures to well structured notes, summarize notes & PDFs, generate quizzes, convert PDFs to audio, and support study mode - all optimized for ARM architecture.


Note, This application is still in development. Some screens and functionalities are not fully setup. The main aim is for the judges to see that all the proposed features are working.

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
  - Google Cloud Neural2 Text-to-Speech for high-quality, natural-sounding audio conversion

### Native Components
- **Android**: C++/JNI bridge for Whisper transcription
- **iOS**: Objective-C++ bridge for Whisper transcription
- **Models**: Quantized Whisper models (ggml-base.en.bin, ggml-tiny.en.bin)

## Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (>=3.2.0) - [Install Flutter](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (>=3.2.0) - Included with Flutter
- **Node.js** (>=20.0.0) - [Download Node.js](https://nodejs.org/) (optional, firebase functions already deployed)
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

# Verify CocoaPods (macOS/iOS only)
pod --version
```

**Important**: Resolve any issues reported by `flutter doctor` before proceeding. Common fixes:
- Accept Android licenses: `flutter doctor --android-licenses`
- Install missing Xcode components (macOS only)
- Install missing Android SDK components via Android Studio

### Quick Start Guide



### Flutter App Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/Hadskad/Smart-Tutor-Lite.git
   cd smart_tutor_lite
   ```

2. **Download Missing Files**
   
   ⚠️ **Important**: Whisper model files are excluded from the repository and must be downloaded separately.
   
    Download Whisper model files to assets/models/:
     Run: bash scripts/setup_whisper.sh (this downloads models and whisper.cpp sources) use Git Bash or WSL if on windows
      Or manually download ggml-base.en.bin and/or ggml-tiny.en.bin from Hugging Face

   **See [SETUP.md](SETUP.md) for complete instructions on obtaining Whisper model files.**
   
   
   ✅ **Firebase Configuration**: Already included in the repository. No setup needed!

3. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

4. **Generate code files**
   ```bash 
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

5. **Firebase Configuration** ✅ Pre-configured
   
   Firebase is already configured for this project. All config files are included in the repository:
   - `lib/firebase_options.dart` ✅
   - `android/app/google-services.json` ✅
   - `ios/GoogleService-Info.plist` ✅
   
   Firebase Functions are pre-deployed and configured. No setup needed!

6. **Setup iOS Dependencies (iOS/macOS only)**
   
   Install CocoaPods dependencies:
   ```bash               Run the below commands one after the other
   cd ios
   pod install
   cd ..
   ```
   
   **Note**: CocoaPods must be installed first. If you get errors:
   ```bash
   # Install CocoaPods (macOS only)
   sudo gem install cocoapods
   ```

7. **Setup Android Native Build Tools(for android)**
   
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
   in the project root folder (smart_tutor_lite), run the below command.
   flutter run
   ```

   For a comprehensive build guide with detailed ARM device instructions, see [BUILD_INSTRUCTIONS.md](BUILD_INSTRUCTIONS.md).

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

### Firebase Functions

Firebase Functions are pre-deployed and configured. The backend API keys are already set up, so judges/evaluators can use the app immediately without any Firebase setup.

For developers who want to deploy their own Firebase Functions, see [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md).

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
- ✅ **Summarization**: Fully implemented with offline queue support
- ✅ **Quiz Generation**: Fully implemented with offline queue support
- ✅ **Text-to-Speech**: Fully implemented with offline queue support
- ✅ **Study Mode**: Fully implemented with flashcards and progress tracking

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

SmartTutor Lite is optimized for ARM-based mobile devices.

- Native C++/JNI (Android) and Objective-C++ (iOS) for Whisper integration
- Quantized Whisper models for efficient inference
- ARM NEON optimizations for SIMD operations
- Performance monitoring for CPU, memory, and battery usage
- On-device AI processing with minimal battery impact


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
- Google Cloud for high-quality Neural2 text-to-speech
- Firebase for backend infrastructure


## License

See [LICENSE](LICENSE) file for details.
