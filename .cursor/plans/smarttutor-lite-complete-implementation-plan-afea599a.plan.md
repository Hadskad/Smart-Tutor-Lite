<!-- afea599a-6082-4dfc-9a56-2fa0bc8e2733 7c0eb795-2a7d-4ed3-ae6c-2dc0dbb1184f -->
# Add Missing Roboto Font Assets

## Overview

The app declares `fonts/Roboto-Regular.ttf` and `fonts/Roboto-Bold.ttf` in the `pubspec.yaml` file under the `fonts:` section, but these files are missing in the `fonts/` directory. This results in asset bundle build failures. We will source and add the Roboto font files into the expected location, then verify the asset build step.

## Steps

1. **Download Official Roboto Fonts**

            - Obtain `Roboto-Regular.ttf` and `Roboto-Bold.ttf` from the official [Google Fonts](https://fonts.google.com/specimen/Roboto) repository or safely from https://github.com/google/fonts/tree/main/apache/roboto.

2. **Add Fonts to the Project**

            - Place `Roboto-Regular.ttf` and `Roboto-Bold.ttf` in `fonts/` at the root of the repo (`fonts/Roboto-Regular.ttf`, `fonts/Roboto-Bold.ttf`).
            - Ensure correct file names and no subfolders (must be direct children of `fonts/`).

3. **Verify pubspec.yaml Configuration**

            - Ensure the `pubspec.yaml` `fonts:` block is as follows:
     ```yaml
     fonts:
       - family: Roboto
         fonts:
           - asset: fonts/Roboto-Regular.ttf
           - asset: fonts/Roboto-Bold.ttf
             weight: 700
     ```

            - Ensure there are no typos and that asset paths match actual files.

4. **Run Flutter Build Tools**

            - Run `flutter pub get` to update the asset manifest.
            - Run `flutter run` or `flutter build` to verify the error is resolved and the app builds with custom fonts enabled.

## Files Involved

- `pubspec.yaml`
- `fonts/Roboto-Regular.ttf`
- `fonts/Roboto-Bold.ttf`

## Result

User should see no asset errors related to Roboto. If the files are missing, a visible error/warning will occur at build time.

### To-dos

- [ ] Phase 5: Text-to-Speech (TTS) Feature
- [ ] Integrate Google Cloud TTS with Neural2/WaveNet voices
- [ ] Add voice selection UI to Flutter TTS page
- [ ] Phase 6: Study Mode Feature
- [ ] Phase 7: Performance & Arm AI Challenge
- [ ] Phase 8: Testing
- [ ] Phase 9: CI/CD
- [ ] Phase 10: Documentation & Scripts