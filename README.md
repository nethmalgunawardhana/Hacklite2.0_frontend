# WaveWords — Sign Language Learning & Translation (Flutter + Firebase)

WaveWords is a modern Flutter application that helps users learn and practice sign language with quizzes, daily goals, and a camera-based translation experience. It uses Firebase for Authentication and Firestore for data storage.

## Features

- **Authentication (Firebase Auth)**
  - Email/password sign up and sign in
  - User profiles persisted in Firestore (`users` collection)

- **Dashboard**
  - Quick actions: Camera, Quizzes, Practice Sign, Set Goals, Leaderboard
  - Daily goals progress: signs, practice time, quizzes with overall completion bar
  - Quiz performance: total taken, average, best score
  - Recent activity feed (quizzes, practice sessions, goals, signs learned)

- **Camera (Translate)**
  - Camera permission handling and live preview
  - Start/Stop controls and status text
  - Placeholder for future on-device sign recognition pipeline

- **Quizzes**
  - Quiz catalog fetched from Firestore (`quizzes` collection)
  - Per-question feedback and navigation with progress bar
  - Results screen and score persistence
  - Scores saved under `users/{uid}/quizScores` and global `leaderboard`

- **Sign Learning**
  - Curated set of common signs with images (`images/`)
  - Track per-sign status: Not Started, Learning, Practiced, Mastered
  - Practice session time logged as activities
  - Progress saved to `user_progress`

- **Daily Goals**
  - Configure daily targets: signs to learn, practice minutes, quiz count, target score
  - Goals saved to `user_goals` and logged to `activities`

- **History**
  - Search, filter (Today, Favorites), favorite, share, delete
  - Mock data in UI, ready for wiring to real translation logs

- **Profile**
  - Display and edit user details (name, username, age, gender)
  - Support & About entry points

## Tech Stack

- Flutter 3 (Dart SDK ^3.8.1)
- Firebase: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Camera: `camera`, permissions with `permission_handler`
- UI: `flutter_svg`, `intl`
- AI: `google_generative_ai` (Gemini 2.5 Flash), `flutter_dotenv`

## Environment Variables

The app uses environment variables for API keys and sensitive configuration. Create a `.env` file in the root directory:

```bash
# Copy the example file
cp .env.example .env
```

Then update `.env` with your actual API keys:

```env
# Gemini API Configuration
# Get your API key from: https://makersuite.google.com/app/apikey
GEMINI_API_KEY=your_actual_gemini_api_key_here
```

**Important:** Never commit the `.env` file to version control. It's already added to `.gitignore`.

## Project Structure

```
lib/
  main.dart                # App entry (Firebase init, navigation shell)
  firebase_options.dart    # Firebase platform configs
  auth_pages.dart          # Login & Sign Up (Firebase Auth + Firestore user)
  dashboard_page.dart      # Home dashboard (stats, goals, activities)
  camera_page.dart         # Camera-based translation screen (placeholder)
  quiz_selector_page.dart  # List active quizzes from Firestore
  quiz_page.dart           # Quiz runner, feedback, results, score save
  sign_learning_page.dart  # Learn signs, track progress & practice time
  goal_setting_page.dart   # Configure and save daily goals
  history_page.dart        # Translation history (mock data UI)
  profile_page.dart        # Profile details and settings
  about_page.dart          # In-app features overview
images/                    # Sign images used in lessons
assets/images/logo.svg     # App logo used on auth screens
```

## Firestore Collections

- `users/{uid}`: email, username, name, createdAt, lastLogin, etc.
- `users/{uid}/quizScores/{scoreId}`: per-quiz score details
- `leaderboard/{id}`: global list of quiz results for rankings
- `user_goals/{uid}`: daily goals (signs, practice minutes, quizzes, target score)
- `user_progress/{uid}`: `sign_progress` map of sign-name → status
- `activities/{id}`: activity feed items (quiz_completed, signs_learned, goals_set, practice_session)
- `quizzes/{quizId}/questions/{questionId}`: dynamic question bank

## Prerequisites

- Git
- Java 17+
- Flutter SDK (Windows PATH includes `C:\\flutter\\bin`)
- Android Studio with SDK, Platform-Tools, and an emulator or a USB-connected device

## Setup

1. Install Flutter (Windows): docs at https://docs.flutter.dev/get-started/install/windows
2. Install Android Studio and accept Android licenses.
3. Clone this repo and open a terminal in the project root.
4. Run:

```bash
flutter doctor
flutter doctor --android-licenses
flutter pub get
```

5. Ensure Firebase is configured:
   - `android/app/google-services.json` exists
   - `lib/firebase_options.dart` contains correct project values
   - Firebase Authentication enabled; Firestore rules permit your usage

## Running

```bash
# Android device/emulator
flutter run

# Web (for UI testing)
flutter run -d chrome
```

## Environment & Assets

- Assets configured in `pubspec.yaml`:
  - `assets/images/logo.svg`
  - `images/` directory for sign images

## Troubleshooting

- Flutter not recognized: restart terminal, verify PATH includes `C:\\flutter\\bin`.
- Android SDK issues: run `flutter doctor`, set `ANDROID_HOME` or use Android Studio SDK Manager.
- Build errors: `flutter clean && flutter pub get` then re-run.
- Firebase errors: verify `google-services.json`, project ID, and Firestore/Rules.

## Roadmap

- Real-time sign recognition pipeline integration
- ASL dictionary browser with search and categories
- Notifications and streaks for goals
- Export/share progress and history

---

MIT License © WaveWords
