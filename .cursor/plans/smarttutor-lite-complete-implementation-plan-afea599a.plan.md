<!-- afea599a-6082-4dfc-9a56-2fa0bc8e2733 43ee0edd-0e37-42db-bcca-5fe88f3b242d -->
# Smart Tutor Lite Homepage & Shell Redesign

## Phase 1 – Logo-Aligned Design System

- **1.1 Update color palette in `AppTheme`**
- Adjust `AppTheme` in [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart) to use colors sampled from the logo:
- Primary: deep navy for key accents (buttons, icons, selected nav items).
- Secondary: warm gold for highlights and success accents.
- Background: soft cream (similar to logo background) for scaffolds.
- Keep typography and component radii as already defined, only swap core palette values.
- **1.2 Sanity check existing screens**
- Run the app and confirm Summarization, Quiz, TTS, and Transcription screens are still readable and visually consistent with the new palette.

## Phase 2 – New Homepage Dashboard

- **2.1 Create `HomeDashboardPage`**
- Add a new page at [`lib/features/home/presentation/pages/home_dashboard_page.dart`](lib/features/home/presentation/pages/home_dashboard_page.dart).
- Layout structure (following the reference image):
- Top area: greeting text ("Hi, [user]!" + "Let’s Learn Something Awesome!") with avatar circle on the right.
- Below: search bar with rounded pill container, search icon, and text field; **omit** audio/mic button inside the search bar.
- Main body: a 2×2 grid of feature cards with generous padding and rounded corners.
- Card content & behavior:
- **Smart Capture**: mic icon, highlighted card; on tap → `Navigator.pushNamed(context, AppRoutes.transcription)`.
- **Summary Bot**: robot icon; on tap → `AppRoutes.summarization`.
- **Practice Mode**: quiz icon; on tap → `AppRoutes.quiz`.
- **Audio Note**: volume icon; on tap → `AppRoutes.tts`.
- Visual details:
- Use a subtle vertical gradient background from cream to white.
- First card uses solid primary background + white text; others are white with soft border and shadow.

## Phase 3 – Bottom Navigation Refactor

- **3.1 Convert `MainNavigation` to 4-tab shell**
- Update [`lib/app/main_navigation.dart`](lib/app/main_navigation.dart) so that:
- Body

### To-dos

- [ ] Phase 5: Text-to-Speech (TTS) Feature
- [ ] Integrate Google Cloud TTS with Neural2/WaveNet voices
- [ ] Add voice selection UI to Flutter TTS page