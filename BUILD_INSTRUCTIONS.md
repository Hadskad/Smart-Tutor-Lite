# Complete Build Instructions for ARM-Based Devices

This guide provides step-by-step instructions to build and run SmartTutor Lite on ARM-based mobile devices (Android ARM64 and iOS ARM64). Follow these instructions in order to ensure a successful build.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Verification](#verification)
3. [Step 1: Clone Repository](#step-1-clone-repository)
4. [Step 2: Download Missing Files](#step-2-download-missing-files)
5. [Step 3: Install Dependencies](#step-3-install-dependencies)
6. [Step 4: Setup Native Dependencies](#step-4-setup-native-dependencies)
7. [Step 5: Configure Firebase](#step-5-configure-firebase)
8. [Step 6: Generate Code](#step-6-generate-code)
9. [Step 7: Build for Android (ARM64)](#step-7-build-for-android-arm64)
10. [Step 8: Build for iOS (ARM64)](#step-8-build-for-ios-arm64)
11. [Troubleshooting](#troubleshooting)
12. [Verification Checklist](#verification-checklist)
13. [Files Required for Judges](#files-required-for-judges)

---

## Prerequisites

Before you begin, ensure you have the following installed:

### Required Software

- **Flutter SDK** (>=3.2.0)
  - Download: https://flutter.dev/docs/get-started/install
  - Add Flutter to your PATH
  - Verify installation: `flutter --version`

- **Dart SDK** (>=3.2.0)
  - Included with Flutter installation

- **Node.js** (>=20.0.0) (Optional - only needed if deploying your own Firebase Functions)
  - Download: https://nodejs.org/
  - Verify: `node --version`

- **Firebase CLI** (Optional - only needed if deploying your own Firebase Functions)
  - Install: `npm install -g firebase-tools`
  - Verify: `firebase --version`

- **Git**
  - Required for cloning repository
  - Verify: `git --version`

### Android Development (for Android builds)

- **Android Studio** (latest version)
  - Download: https://developer.android.com/studio
  
- **Android SDK**
  - Install via Android Studio SDK Manager
  - Required API levels: 21+ (minimum SDK)
  
- **Android NDK** (Required)
  - Required for native Whisper C++ integration
  - Install via Android Studio: Tools → SDK Manager → SDK Tools → NDK (Side by side)
  - Verify installation path: `$ANDROID_HOME/ndk/` or `$ANDROID_SDK_ROOT/ndk/`

- **CMake** (>=3.22.1, Required)
  - Required for building native libraries
  - Install via Android Studio: Tools → SDK Manager → SDK Tools → CMake
  - Verify: `cmake --version`

- **Java JDK** (11 or higher)
  - Required for Android builds
  - Verify: `java -version`

### iOS Development (for iOS builds - macOS only)

- **macOS** with Xcode (>=14.0)
  - Download from Mac App Store
  
- **CocoaPods**
  - Install: `sudo gem install cocoapods`
  - Verify: `pod --version`
  
- **Xcode Command Line Tools**
  - Install: `xcode-select --install`

---

## Verification

After installing prerequisites, verify your setup:

```bash
# Check Flutter installation and environment
flutter doctor -v

# Verify CocoaPods (macOS/iOS only)
pod --version

# Verify CMake (Android)
cmake --version  # Should be >=3.22.1
```

### Resolve Common Issues

**Flutter Doctor Issues:**
```bash
# Accept Android licenses
flutter doctor --android-licenses

# Fix missing Android SDK components
# Open Android Studio → SDK Manager → Install missing components
```

**CocoaPods Issues (macOS):**
```bash
# If CocoaPods not found, install:
sudo gem install cocoapods

# If permission errors, use:
sudo gem install -n /usr/local/bin cocoapods
```

**CMake/NDK Issues:**
- Open Android Studio
- Go to **Tools → SDK Manager → SDK Tools**
- Ensure **CMake** and **NDK (Side by side)** are checked
- Click **Apply** to install

---

## Step 1: Clone Repository

Clone the SmartTutor Lite repository:

```bash
git clone https://github.com/Hadskad/Smart-Tutor-Lite.git
cd smart_tutor_lite
```

Verify you're in the correct directory:
```bash
pwd  # Should show path ending in smart_tutor_lite
ls   # Should show project files
```

---

## Step 2: Download Missing Files

⚠️ **IMPORTANT**: Several required files are excluded from the repository (see `.gitignore`). You must download them before building.

### 2.1 Whisper Model Files (REQUIRED for Transcription)

**Location**: `assets/models/`

The app requires Whisper model files for on-device transcription. Download them using the setup script:

```bash
# Run the Whisper setup script (downloads models AND native sources)
bash scripts/setup_whisper.sh
```

This script automatically:
- Downloads whisper.cpp v1.6.2 sources to Android and iOS native directories
- Downloads quantized models:
  - `ggml-base.en.bin` (~140 MB) - Good balance of speed and accuracy
  - `ggml-tiny.en.bin` (~75 MB) - Faster, lower accuracy, good for testing
- Places models in `assets/models/`

**Alternative: Manual Download**

If the script fails, download models manually:

1. Create directory:
   ```bash
   mkdir -p assets/models
   ```

2. Download models from Hugging Face:
   - `ggml-base.en.bin`: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
   - `ggml-tiny.en.bin`: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin

3. Place downloaded `.bin` files in `assets/models/`

**Minimum Requirement**: At least one model file is required for transcription to work.

**Verify Installation:**
```bash
ls -lh assets/models/*.bin
# Should show ggml-base.en.bin and/or ggml-tiny.en.bin
```

### 2.2 Firebase Configuration Files ✅ ALREADY INCLUDED

Firebase config files are already included in the repository. No action needed!

Files included:
- `android/app/google-services.json` ✅
- `ios/GoogleService-Info.plist` ✅
- `lib/firebase_options.dart` ✅

Firebase Functions are pre-deployed and configured. You can build and run immediately!

---

## Step 3: Install Dependencies

### 3.1 Install Flutter Dependencies

```bash
flutter pub get
```

This installs all Flutter packages listed in `pubspec.yaml`.

**Verify Installation:**
```bash
# Check Flutter packages
flutter pub get  # Should complete without errors
```

---

## Step 4: Setup Native Dependencies

### 4.1 iOS CocoaPods Setup (macOS/iOS builds only)

Install CocoaPods dependencies:

```bash
cd ios
pod install
cd ..
```

**If you get errors:**

1. **CocoaPods not installed:**
   ```bash
   sudo gem install cocoapods
   ```

2. **Pod install fails:**
   ```bash
   # Clean and reinstall
   cd ios
   rm -rf Pods Podfile.lock
   pod install
   cd ..
   ```

3. **Flutter dependencies not found:**
   ```bash
   # Ensure flutter pub get ran first
   flutter pub get
   cd ios
   pod install
   cd ..
   ```

**Verify Installation:**
```bash
ls ios/Pods/  # Should show CocoaPods directory
```

### 4.2 Android NDK/CMake Verification

Ensure Android NDK and CMake are installed:

1. Open Android Studio
2. Go to **Tools → SDK Manager → SDK Tools**
3. Verify these are checked and installed:
   - ✅ **NDK (Side by side)** - Version 23.0 or higher
   - ✅ **CMake** - Version 3.22.1 or higher
4. Click **Apply** if changes needed

**Verify Installation:**
```bash
# Check NDK (path may vary)
ls $ANDROID_HOME/ndk/ 2>/dev/null || ls $ANDROID_SDK_ROOT/ndk/ 2>/dev/null

# Check CMake version
cmake --version  # Should show >=3.22.1
```

---

## Step 5: Firebase Configuration ✅ Pre-configured

Firebase is already configured and Functions are deployed. No setup required!

**What's included:**
- ✅ Client config files (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`) - Already in repository
- ✅ Firebase Functions - Pre-deployed with API keys configured
- ✅ All AI services (OpenAI, Google Cloud TTS, Soniox) - Already configured

**For Judges/Evaluators:** Just build and run - everything works out of the box!

**For Developers:** If you want to deploy your own Firebase Functions, see [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for detailed setup instructions.

---

## Step 6: Generate Code

Generate required code files:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates:
- `lib/injection_container.config.dart` - Dependency injection configuration
- Other generated files for Hive adapters, etc.

**If you get errors:**
```bash
# Clean and rebuild
flutter pub run build_runner clean
flutter pub run build_runner build --delete-conflicting-outputs
```

**Verify Generation:**
```bash
ls lib/injection_container.config.dart
```

---

## Step 7: Build for Android (ARM64)

### 7.1 Verify Android Configuration

The app is configured for ARM architectures in `android/app/build.gradle.kts`:
- `armeabi-v7a` (32-bit ARM)
- `arm64-v8a` (64-bit ARM)

### 7.2 Build Release APK

**Option A: Build for ARM64 only (recommended for testing):**
```bash
flutter build apk --release --target-platform android-arm64
```

**Option B: Build for all ARM architectures:**
```bash
flutter build apk --release
```

**Option C: Build separate APKs per architecture (smaller files):**
```bash
flutter build apk --release --split-per-abi
```

### 7.3 Build App Bundle (for Play Store)

```bash
flutter build appbundle --release
```

### 7.4 Output Locations

- APK: `build/app/outputs/flutter-apk/app-release.apk`
- Split APKs: `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk`, `app-arm64-v8a-release.apk`
- App Bundle: `build/app/outputs/bundle/release/app-release.aab`

### 7.5 Install on ARM Device

**Via USB:**
```bash
# Connect device via USB
# Enable USB debugging on device

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Or use Flutter
flutter install
```

**Via File Transfer:**
1. Copy APK to device
2. Enable "Install from Unknown Sources" in device settings
3. Tap APK file to install

---

## Step 8: Build for iOS (ARM64)

**Note**: iOS builds require macOS with Xcode.

### 8.1 Verify iOS Configuration

iOS builds target ARM64 by default on physical devices. Verify in Xcode:
- Open `ios/Runner.xcworkspace` (not `.xcodeproj`)
- Select your device as target
- Ensure "Any iOS Device (ARM64)" is selected

### 8.2 Configure Signing

1. Open `ios/Runner.xcworkspace` in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select "Runner" in project navigator
3. Go to **Signing & Capabilities** tab
4. Select your development team
5. Xcode will automatically manage provisioning profiles

### 8.3 Build iOS Release

**Option A: Using Flutter CLI:**
```bash
flutter build ios --release
```

**Option B: Using Xcode:**
1. Select your ARM-based iOS device (iPhone/iPad)
2. Product → Archive (for release build)
3. Or Product → Run (for development)

### 8.4 Install on Device

**Via Xcode:**
1. Connect iOS device via USB
2. Select device in Xcode
3. Click Run (▶️) button

**Via Flutter CLI:**
```bash
flutter run --release
```

**Note**: Requires valid Apple Developer account and device registered for development.

---

## Troubleshooting

### Common Build Errors

#### 1. "Whisper native library not found"

**Solution:**
```bash
# Re-run Whisper setup script
bash scripts/setup_whisper.sh

# Verify native sources exist
ls android/app/src/main/cpp/third_party/whisper.cpp/  # Android
ls ios/Runner/third_party/whisper.cpp/  # iOS
```

#### 2. "Firebase not configured" or "firebase_options.dart not found"

**Note:** Firebase config files are already included in the repository. If you see this error, verify the files exist:
```bash
ls lib/firebase_options.dart
ls android/app/google-services.json
ls ios/GoogleService-Info.plist
```

If files are missing, they should be in the repository. Check that you cloned the complete repository.

#### 3. "CMake not found" or "NDK not found" (Android)

**Solution:**
- Open Android Studio
- Tools → SDK Manager → SDK Tools
- Install: **CMake** (3.22.1+) and **NDK (Side by side)**
- Restart terminal/IDE

#### 4. "CocoaPods not found" (iOS)

**Solution:**
```bash
sudo gem install cocoapods
cd ios
pod install
cd ..
```

#### 5. "OpenAI API key not found" (Firebase Functions)

**Note:** Firebase Functions are pre-deployed with API keys configured. If you see this error, it means you're trying to run functions locally. For judges/evaluators, functions are already deployed - no action needed.

**For developers deploying their own functions:** See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for API key setup.

#### 6. Build fails with "MissingPluginException"

**Solution:**
```bash
# Clean build
flutter clean
flutter pub get

# Regenerate code
flutter pub run build_runner build --delete-conflicting-outputs

# Rebuild
flutter build apk --release
```

#### 7. iOS build fails - "Pod install required"

**Solution:**
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter clean
flutter build ios --release
```

#### 8. Models not found error

**Solution:**
```bash
# Verify models exist
ls assets/models/*.bin

# If missing, download:
bash scripts/setup_whisper.sh
```

#### 9. Android build fails - "local.properties not found"

**Solution:**
- This file is auto-generated by Flutter
- Open project in Android Studio once
- Or create manually: `echo "sdk.dir=$ANDROID_HOME" > android/local.properties`

#### 10. "Out of memory" during build

**Solution:**
- Close other applications
- Increase Gradle memory: Edit `android/gradle.properties`:
  ```
  org.gradle.jvmargs=-Xmx4096m
  ```

### Getting Help

If you encounter issues not covered here:
1. Check [README.md](README.md) for overview
2. Review [SETUP.md](SETUP.md) for missing files
3. See [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for Firebase issues
4. Run `flutter doctor -v` to diagnose environment issues

---

## Verification Checklist

Before considering setup complete, verify all items:

### Prerequisites
- [ ] Flutter SDK installed and in PATH
- [ ] Dart SDK included with Flutter
- [ ] Android Studio installed (for Android builds)
- [ ] Android NDK installed
- [ ] CMake (>=3.22.1) installed
- [ ] Xcode installed (for iOS builds, macOS only)
- [ ] CocoaPods installed (for iOS builds, macOS only)
- [ ] `flutter doctor` shows no critical issues

### Files and Dependencies
- [ ] Repository cloned
- [ ] Whisper models in `assets/models/` (at least one `.bin` file)
- [ ] Whisper native sources in Android/iOS directories
- [ ] `google-services.json` in `android/app/`
- [ ] `GoogleService-Info.plist` in `ios/` (iOS builds)
- [ ] `firebase_options.dart` in `lib/`
- [ ] Flutter dependencies installed (`flutter pub get` succeeded)
- [ ] Generated code files created (`injection_container.config.dart`)
- [ ] CocoaPods installed (iOS only, `ios/Pods/` exists)

### Configuration
- [ ] Firebase configuration files verified (already included)
- [ ] Android NDK and CMake verified
- [ ] iOS signing configured (iOS builds)

### Build Verification
- [ ] Android APK builds successfully
- [ ] iOS builds successfully (macOS/iOS only)
- [ ] App installs on ARM device
- [ ] App runs without crashes
- [ ] Transcription feature works (on-device)

---

## Files Required for Judges

If you're preparing the project for judges to test, provide the following:

### Essential Files

1. **Pre-built APK (Android ARM64)**
   - File: `build/app/outputs/flutter-apk/app-release.apk`
   - Or: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (if split build)
   - Size: ~50-100 MB (depending on features included)

2. **Source Code Repository**
   - Complete project repository (all files except those in `.gitignore`)
   - Ensure sensitive files (API keys, configs) are excluded

3. **Documentation**
   - This BUILD_INSTRUCTIONS.md file
   - README.md
   - SETUP.md

4. **Firebase Configuration** ✅ Already included
   - Firebase config files are already in the repository
   - Firebase Functions are pre-deployed

### Optional Files

5. **Pre-built IPA (iOS)**
   - If judges have iOS devices
   - Or TestFlight link

6. **Quick Start Package**
   Create a ZIP containing:
   ```
   smart_tutor_lite_judge_package/
   ├── app-release.apk              # Pre-built Android ARM64 APK
   ├── BUILD_INSTRUCTIONS.md        # This file
   ├── README.md                    # Project overview
   ├── SETUP.md                     # Missing files guide
   └── QUICK_START.md              # Simplified setup (optional)
   ```

### What Judges Need to Download

Judges will need to:
1. Clone the repository
2. Download Whisper models (via `bash scripts/setup_whisper.sh`)
3. Install Flutter dependencies (`flutter pub get`)
4. Generate code (`flutter pub run build_runner build --delete-conflicting-outputs`)
5. Build the app OR use pre-built APK

**For easiest testing, provide:**
- Pre-built APK they can install directly
- Firebase is already configured - no setup needed!
- Link to this BUILD_INSTRUCTIONS.md

---

## Quick Reference Commands

### Setup Commands (Run Once)
```bash
# Clone repository
git clone https://github.com/Hadskad/Smart-Tutor-Lite.git
cd smart_tutor_lite

# Download Whisper models and sources
bash scripts/setup_whisper.sh

# Install Flutter dependencies
flutter pub get

# Setup iOS (macOS only)
cd ios && pod install && cd ..

# Generate code
flutter pub run build_runner build --delete-conflicting-outputs
```

### Build Commands
```bash
# Android ARM64
flutter build apk --release --target-platform android-arm64

# Android all architectures
flutter build apk --release

# iOS (macOS only)
flutter build ios --release
```

### Verification Commands
```bash
# Check environment
flutter doctor -v

# Verify files
ls assets/models/*.bin
ls android/app/google-services.json
ls lib/firebase_options.dart

# Test run
flutter run
```

---

## Additional Resources

- [README.md](README.md) - Project overview and features
- [SETUP.md](SETUP.md) - Detailed guide for missing files
- [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) - Firebase Functions setup
- [HACKATHON_COMPLIANCE.md](HACKATHON_COMPLIANCE.md) - ARM AI Challenge compliance
- [docs/ARM_AI_OPTIMIZATION.md](docs/ARM_AI_OPTIMIZATION.md) - ARM optimization details

---

## Support

If you encounter issues not covered in this guide:
1. Review the Troubleshooting section above
2. Check `flutter doctor -v` output
3. Review project documentation
4. Check for build logs in `build/` directory

**Good luck building SmartTutor Lite!** 🚀

