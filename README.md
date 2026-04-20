# RunMate 🏃

A smart marathon running app built with Flutter + Firebase. Track your runs, compete on a live leaderboard with friends, browse events, and manage everything from a dedicated admin panel.

**Platforms:** Android · iOS · Web

---

## Requirements

| Tool | Version |
|------|---------|
| Flutter | 3.41.5+ |
| Dart | 3.11.3+ |
| Android Studio / Xcode | Latest stable |
| Firebase project | Configured (see setup) |

---

## Setup

### 1. Clone & install dependencies

```bash
git clone https://github.com/massumm/marathon-tracker.git
cd marathon-tracker
flutter pub get
```

### 2. Firebase

The app uses Firebase Auth, Realtime Database, and Cloud Storage. The `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are not committed to the repo.

- Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
- Add Android + iOS apps to the project
- Download and place:
  - `android/app/google-services.json`
  - `ios/Runner/GoogleService-Info.plist`
- Enable **Authentication** (Email/Password)
- Enable **Realtime Database**
- Enable **Cloud Storage**

---

## Running the App

### Mobile app (Android / iOS)

```bash
# Debug on connected device or emulator
flutter run

# Specific device
flutter run -d <device-id>

# List available devices
flutter devices
```

### Admin panel (Chrome)

```bash
flutter run -t lib/main_admin.dart -d chrome
```

### Admin panel (web server — shareable via ngrok)

```bash
# Terminal 1 — start web server on port 8080
flutter run -t lib/main_admin.dart -d web-server --web-port 8080 --web-hostname 0.0.0.0

# Terminal 2 — expose publicly
ngrok http 8080
```

### Main app in Chrome

```bash
flutter run -d chrome
```

---

## Building for Release

### Android APK

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Admin panel web (for cPanel deployment)

```bash
# Replace /admin/ with your actual subdirectory path
flutter build web --release --target lib/main_admin.dart --base-href /admin/

# Zip for upload
cd build/web && zip -r Archive.zip . --exclude "*.zip"
```

### Main app web

```bash
flutter build web --release
```

---

## Deploying Admin Panel to cPanel

1. Run the build command above with the correct `--base-href`
2. In cPanel **File Manager**, navigate to your subdomain folder (e.g. `public_html/admin/`)
3. Upload `Archive.zip` and click **Extract**
4. Create a `.htaccess` file in the same folder:

```apache
<IfModule mod_rewrite.c>
  RewriteEngine On
  RewriteBase /admin/
  RewriteCond %{REQUEST_FILENAME} !-f
  RewriteCond %{REQUEST_FILENAME} !-d
  RewriteRule ^ /admin/index.html [L]
</IfModule>
```

5. Visit `https://yourdomain.com/admin/`

---

## Firebase App Distribution

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "1:157462453434:android:fb87af59b08a4ec74c7683" \
  --testers "email@example.com" \
  --release-notes "Build notes here"
```

---

## Project Structure

```
lib/
├── main.dart              # Mobile app entry point
├── main_admin.dart        # Admin panel entry point
├── app/
│   ├── bindings/          # GetX dependency injection
│   └── routes/            # Named routes
├── controllers/           # GetX controllers (state management)
├── core/
│   ├── theme.dart         # Colors and theme
│   └── config.dart        # API keys, storage paths, defaults
├── l10n/
│   └── strings.dart       # EN + JA translations
├── models/                # Data models
├── screens/
│   ├── admin/             # Admin panel screens
│   └── ...                # App screens
├── services/              # Firebase, GPS, tracking services
└── widgets/               # Shared widgets
```

---

## Git Remotes

| Remote | Repository |
|--------|-----------|
| `origin` | XOR-Geek/marathon-map (private) |
| `massumm` | massumm/marathon-tracker (sharing) |

```bash
# Push to sharing repo
git push massumm <branch>
```

---

## Lint

```bash
flutter analyze
```
