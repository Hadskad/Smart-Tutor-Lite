                     Obtaining Files Not in Repository (.gitignore Files)


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



2. Firebase Configuration Files (REQUIRED)
Firebase config files are not in the repository for security reasons.

For Android:
File: android/app/google-services.json

Download:
-Go to Firebase Console
-Select your project (or create one)
-Project Settings → Your apps → Android app
-If no Android app exists, click "Add app" → Android
Package name: com.example.smart_tutor_lite
-Download google-services.json
-Place in android/app/google-services.json



For iOS:
File: ios/GoogleService-Info.plist

Download:
Go to Firebase Console

-Select your project
-Project Settings → Your apps → iOS app
-If no iOS app exists, click "Add app" → iOS
Bundle ID: com.example.smartTutorLite (or your bundle ID)
-Download GoogleService-Info.plist
-Place in ios/GoogleService-Info.plist



Alternative: Generate using FlutterFire CLI:
# Install FlutterFire CLI
dart pub global activate flutterfire_cli




# Generate Firebase config files
flutterfire configure



This generates:
android/app/google-services.json
ios/GoogleService-Info.plist
lib/firebase_options.dart






3. Firebase Options Dart File (REQUIRED)
File: lib/firebase_options.dart
Generate:


Option A: Using FlutterFire CLI (Recommended)


# Install FlutterFire CLI (if not already installed)
dart pub global activate flutterfire_cli


# Configure Firebase for all platforms
flutterfire configure



This generates lib/firebase_options.dart automatically.




Option B: Manual Generation
Go to Firebase Console → Project Settings
In the "Your apps" section, note your app IDs
Run:
flutterfire configure --project=your-project-id


Option C: Use Existing Configuration
If using the same Firebase project as configured in firebase.json, you can copy the configuration. However, FlutterFire CLI is recommended.










4. Node Modules (Firebase Functions) - Auto-generated
Location: functions/node_modules/

Install:



cd functions
npm install



This downloads all dependencies listed in functions/package.json. No manual downloads needed.









5. Android Local Properties - Auto-generated
File: android/local.properties

This file is generated when you build the Android app. It contains your Android SDK path. Flutter/Android Studio creates it automatically. No manual action needed.






6. Environment Variables for Firebase Functions (REQUIRED for Deployment)


Files: functions/.env (optional, for local development)

These are not downloaded; you must set them manually.


For Local Development:
Create functions/.env:

OPENAI_API_KEY=your_openai_api_key_here
ELEVENLABS_API_KEY=your_elevenlabs_api_key_here
SONIOX_API_KEY=your_soniox_api_key_here


For Production Deployment:
Set via Firebase CLI (recommended):


# Set OpenAI API key
firebase functions:config:set openai.api_key="YOUR_OPENAI_API_KEY"


# Set ElevenLabs API key (for TTS)
firebase functions:config:set elevenlabs.api_key="YOUR_ELEVENLABS_API_KEY"



# Set Soniox API key (for online transcription)
firebase functions:config:set soniox.api_key="YOUR_SONIOX_API_KEY"



Where to get API keys:
OpenAI: https://platform.openai.com/api-keys
ElevenLabs: https://elevenlabs.io/app/settings/api-keys
Soniox: https://www.soniox.com/ 









7. Generated Code Files - Auto-generated
Location: lib/injection_container.config.dart
Excluded by: Build process (auto-generated)


Generate:
flutter pub run build_runner build --delete-conflicting-outputs


Location: functions/lib/ (compiled TypeScript)


Compile:
cd functions
npm run build






Summary Checklist for Missing Files
Before building, ensure you have:
[ ] Whisper models in assets/models/ (at least one .bin file)
Use: bash scripts/setup_whisper.sh OR manual download
[ ] android/app/google-services.json
Download from Firebase Console OR use flutterfire configure
[ ] ios/GoogleService-Info.plist (if building for iOS)
Download from Firebase Console OR use flutterfire configure
[ ] lib/firebase_options.dart
Generate with: flutterfire configure
[ ] Firebase Functions environment variables set
Use: firebase functions:config:set for production
OR create functions/.env for local development
[ ] Generated code files
Run: flutter pub run build_runner build --delete-conflicting-outputs
Run: cd functions && npm run build
Auto-generated (no action needed):
✅ functions/node_modules/ - Install with npm install
✅ android/local.properties - Created automatically on build
✅ functions/lib/ - Compiled with npm run build