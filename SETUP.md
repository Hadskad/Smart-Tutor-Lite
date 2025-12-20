                     Obtaining Files Not in Repository (.gitignore Files)

⚠️ **NOTE FOR JUDGES**: Firebase configuration files are already included in this repository. 
You do NOT need to download or configure Firebase - just proceed with the Whisper model setup below.

Many required files are excluded by .gitignore and need to be obtained separately. Do this after cloning repo(Check README.md)

               Download Missing Files (Not in Repository)
The following files are excluded from the repository and must be obtained separately:


1. Whisper Model Files (REQUIRED for Transcription)
Location: assets/models/

Download options:

Option A: Use Setup Script (Recommended)
# This script downloads whisper.cpp sources AND the model files 

bash scripts/setup_whisper.sh

The script automatically downloads:
ggml-base.en.bin (~140 MB) - Good balance of speed and accuracy
ggml-tiny.en.bin (~75 MB) - Faster, lower accuracy, good for testing


Option B: Manual Download
Download from Hugging Face:
ggml-base.en.bin: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin
ggml-tiny.en.bin: https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin
Create directory: mkdir -p assets/models
Place downloaded .bin files in assets/models/
Minimum: At least one model file is required for transcription.



2. Firebase Configuration Files ✅ ALREADY INCLUDED

Firebase config files are already included in the repository. No action needed!

Files included:
- `android/app/google-services.json` ✅
- `ios/GoogleService-Info.plist` ✅
- `lib/firebase_options.dart` ✅

Firebase Functions are pre-deployed and configured with API keys. You can build and run immediately!






3. Firebase Options Dart File ✅ ALREADY INCLUDED

File: lib/firebase_options.dart

This file is already included in the repository. No generation needed!










4. Node Modules (Firebase Functions) - NOT NEEDED

Firebase Functions are pre-deployed. You don't need to install dependencies or build functions.















5. Android Local Properties - Auto-generated
File: android/local.properties

This file is generated when you build the Android app. It contains your Android SDK path. Flutter/Android Studio creates it automatically. No manual action needed.






6. Firebase Functions Environment Variables ✅ NOT NEEDED


Firebase Functions are pre-deployed with API keys already configured. Judges/evaluators do not need to set environment variables.


If you're deploying your own Firebase Functions, see [docs/FIREBASE_SETUP.md](docs/FIREBASE_SETUP.md) for instructions on setting API keys.


7. Generated Code Files - Auto-generated
Location: lib/injection_container.config.dart
Excluded by: Build process (auto-generated)


Generate:
flutter pub run build_runner build --delete-conflicting-outputs


Summary Checklist for Missing Files
Before building, ensure you have:
[ ] Whisper models in assets/models/ (at least one .bin file)
Use: bash scripts/setup_whisper.sh OR manual download
[ ] Generated code files
Run: flutter pub run build_runner build --delete-conflicting-outputs

Already included (no action needed):
✅ android/app/google-services.json - Already in repository
✅ ios/GoogleService-Info.plist - Already in repository (if building for iOS)
✅ lib/firebase_options.dart - Already in repository
✅ Firebase Functions - Pre-deployed and configured
✅ android/local.properties - Created automatically on build