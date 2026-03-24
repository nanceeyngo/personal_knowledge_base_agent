# RAG Knowledge Agent — Flutter App

The mobile frontend for the RAG Knowledge Agent. Built with Flutter for Android using Riverpod state management and Dio for API communication.

---

## Prerequisites

Before running this app you must have:

1. **Flutter SDK 3.0+** installed — [installation guide](https://docs.flutter.dev/get-started/install/windows)
2. **Android Studio** installed with an Android emulator configured, OR a physical Android device with USB debugging enabled
3. **The backend running** — see the main `README.md` at the repo root for backend setup instructions. The Flutter app is useless without a running backend.

Verify Flutter is installed correctly:
```bash
flutter doctor
```
All items should show a green checkmark. Fix any issues before continuing.

---

## Setup

### 1. Navigate to the Flutter project
```bash
cd frontend/flutter_app
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Configure the backend URL

Open `lib/core/config.dart` and set `defaultBaseUrl` to match your setup:

```dart
// Android emulator connecting to backend on the same machine (DEFAULT)
static const String defaultBaseUrl = 'http://10.0.2.2:8000';

// Physical Android device on the same WiFi as your backend machine
// Replace with your actual machine IP (run `ipconfig` on Windows, `ifconfig` on Mac/Linux)
static const String defaultBaseUrl = 'http://192.168.1.45:8000';

// Production Railway deployment
static const String defaultBaseUrl = 'https://your-app.railway.app';
```

> **Why `10.0.2.2` and not `localhost`?** Inside an Android emulator, `localhost` refers to the emulator itself, not your computer. Android emulators use `10.0.2.2` as a special alias to reach the host machine's localhost.

---

## Running the App

### Start your emulator or connect your device

**Emulator:**
```bash
# List available emulators
flutter emulators

# Launch one
flutter emulators --launch <emulator_id>
```
Or open Android Studio → Device Manager → press the play button on any emulator.

**Physical device:**
1. Connect via USB
2. Accept the "Allow USB debugging" prompt on the device

**Verify device is detected:**
```bash
flutter devices
```

### Run the app
```bash
flutter run
```

### Run in release mode (faster, no debug overlay)
```bash
flutter run --release
```

### Build an installable APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Project Structure

```
lib/
├── main.dart                          ← App entry point, theme, ProviderScope
├── core/
│   ├── config.dart                    ← Backend URL and app constants
│   ├── dio_client.dart                ← HTTP client with SSE streaming support
│   ├── exceptions.dart                ← Typed error classes
│   └── theme.dart                     ← Light and dark theme definitions
├── models/
│   ├── collection.dart                ← Knowledge base collection model
│   ├── document.dart                  ← Document model
│   ├── conversation.dart              ← Conversation model
│   └── message.dart                   ← Chat message + source reference models
├── repositories/
│   ├── collection_repository.dart     ← Collections API calls
│   ├── document_repository.dart       ← Documents API calls (upload, delete, reindex)
│   └── chat_repository.dart           ← Chat API calls + SSE stream
├── providers/
│   ├── collection_provider.dart       ← Collections Riverpod state
│   ├── document_provider.dart         ← Documents Riverpod state + upload progress
│   └── chat_provider.dart             ← Chat messages + streaming state
├── screens/
│   ├── home/
│   │   └── home_screen.dart           ← Root screen, switches between list and chat
│   ├── collection/
│   │   ├── collections_screen.dart    ← Knowledge base list, create, settings
│   │   └── collection_detail_screen.dart ← Document upload and management
│   └── chat/
│       └── chat_screen.dart           ← Streaming chat UI with suggestions
└── widgets/
    ├── collection_card.dart           ← Collection list item
    ├── message_bubble.dart            ← Chat message bubble (user + assistant)
    ├── source_card.dart               ← Source reference card (horizontal scroll)
    ├── document_tile.dart             ← Document list item
    └── typing_indicator.dart          ← Animated three-dot loading indicator
```

---

## Features

- **Collections screen** — lists all knowledge bases, create new ones, pull-to-refresh
- **Document management** — upload multiple files (PDF, TXT, MD, PNG, JPG), view indexed documents, delete, re-index
- **Streaming chat** — answers stream token by token in real time using SSE
- **Source references** — every answer shows which document pages grounded it, with relevance scores
- **Conversation history** — all conversations persist and can be resumed from the history sheet
- **Suggested questions** — empty chat screen shows 5 starter questions
- **Light / dark theme** — toggle from the collections screen (sun/moon icon) or settings sheet
- **Backend URL setting** — change the backend URL at runtime without rebuilding (settings ⚙ icon)
- **Enter to send** — press Enter to send a message; Shift+Enter inserts a new line

---

## Key Dependencies

| Package | Version | Purpose |
|---|---|---|
| `flutter_riverpod` | ^2.5.1 | State management |
| `dio` | ^5.4.3 | HTTP client + SSE streaming |
| `file_picker` | ^8.0.3 | File selection for uploads |
| `flutter_markdown` | ^0.6.22 | Render markdown in assistant responses |
| `google_fonts` | ^6.2.1 | Inter font family |
| `shared_preferences` | ^2.2.3 | Persist backend URL setting |
| `gap` | ^3.0.1 | Spacing utility |
| `timeago` | ^3.6.1 | Human-readable timestamps |
| `shimmer` | ^3.0.0 | Loading skeleton animations |

---

## Changing the Theme

The app ships with both light and dark themes. To change which theme loads by default, open `lib/main.dart`:

```dart
// Default theme on app launch
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
//                                                         ^^^^^^^^^^^^^^^^
// Change to ThemeMode.light to default to light theme
// Or ThemeMode.system to follow the device system theme
```

At runtime, tap the sun/moon icon on the collections screen to toggle without rebuilding.

---

## Troubleshooting

**`flutter pub get` fails with version conflicts**
```bash
flutter clean
flutter pub cache repair
flutter pub get
```

**App builds but shows "Connection refused" or network error**
- Confirm the backend is running: open a browser on your computer and visit `http://localhost:8000/health`
- Check that `config.dart` has the correct URL for your setup (see Configuration section above)
- If using an emulator, the URL must start with `http://10.0.2.2:8000`, not `http://localhost:8000`
- You can also change the URL at runtime: tap ⚙ on the collections screen

**`Gradle build failed` on first run**
This usually means the Android SDK is missing a component. In Android Studio:
1. Go to `SDK Manager` (Tools menu)
2. Install the latest `Android SDK Build-Tools`
3. Install `Android SDK Platform` for API level 33 or higher
4. Re-run `flutter run`

**App crashes immediately on launch**
Run with verbose logging to see the error:
```bash
flutter run -v
```

**File picker shows no files or crashes**
Ensure the AndroidManifest.xml has the required permissions and the `<queries>` block. These are already included in this project. If you modified AndroidManifest.xml, restore the original from the repository.

**Uploaded file shows "Upload failed"**
- Check the file size is under 50MB
- Check the file extension is one of: `pdf, txt, md, png, jpg, jpeg, tiff, bmp, webp`
- Check the backend terminal for the detailed error message