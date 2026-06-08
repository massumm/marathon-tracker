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

### Flavors Overview

| Entry Point | Type | Environment | Firebase Project | Used For |
|---|---|---|---|---|
| `lib/main.dart` | User App | **Staging** (Default) | Development | Testing, development |
| `lib/main_live.dart` | User App | **Production** | Production | Live release |
| `lib/main_admin.dart` | Admin Panel | **Staging** | Development | Admin testing, event creation (test) |
| `lib/main_admin_live.dart` | Admin Panel | **Production** | Production | Event management in production |

### Flavors
The app supports 4 flavors (2 apps × 2 environments):
- **Staging** (Default) - Development Firebase project + staging admin panel
- **Live/Production** - Production Firebase project + production admin panel

### User App - Staging (Default)

```bash
# Android/iOS device or emulator
flutter run

# Specific device
flutter run -d <device-id>

# Chrome (web)
flutter run -d chrome
```

### User App - Production (Live)

```bash
# Android/iOS device or emulator
flutter run -t lib/main_live.dart

# Specific device
flutter run -t lib/main_live.dart -d <device-id>

# Chrome (web)
flutter run -t lib/main_live.dart -d chrome
```

### Admin Panel - Staging

```bash
# Chrome browser
flutter run -t lib/main_admin.dart -d chrome

# Web server (shareable via ngrok)
flutter run -t lib/main_admin.dart -d web-server --web-port 8080 --web-hostname 0.0.0.0

# Then in another terminal, expose publicly
ngrok http 8080
```

### Admin Panel - Production (Live)

```bash
# Chrome browser
flutter run -t lib/main_admin_live.dart -d chrome

# Web server (shareable via ngrok)
flutter run -t lib/main_admin_live.dart -d web-server --web-port 8080 --web-hostname 0.0.0.0

# Then in another terminal, expose publicly
ngrok http 8080
```

### Utility Commands

```bash
# List available devices
flutter devices

# List available emulators/simulators
flutter emulators
```

---

## Building for Release

### User App - Android APK

#### Staging
```bash
flutter build apk --release -t lib/main.dart
# Output: build/app/outputs/flutter-apk/app-release.apk → rename to app-stage-release.apk
```

#### Production (Live)
```bash
flutter build apk --release -t lib/main_live.dart
# Output: build/app/outputs/flutter-apk/app-release.apk → rename to app-live-release.apk
```

### User App - Android App Bundle (for Google Play Console)

#### Staging
```bash
flutter build appbundle --release -t lib/main.dart
# Output: build/app/outputs/bundle/release/app-release.aab → rename to app-stage-release.aab
```

#### Production (Live)
```bash
flutter build appbundle --release -t lib/main_live.dart
# Output: build/app/outputs/bundle/release/app-release.aab → rename to app-live-release.aab
```

### User App - Web

#### Staging
```bash
flutter build web --release -t lib/main.dart
# Output: build/web/
```

#### Production (Live)
```bash
flutter build web --release -t lib/main_live.dart
# Output: build/web/
```

### Admin Panel - Web (for cPanel deployment)

#### Staging
```bash
# Replace /admin/ with your actual subdomain path
flutter build web --release -t lib/main_admin.dart --base-href /admin/

# Zip for upload
cd build/web && zip -r archive-stage.zip . --exclude "*.zip"
```

#### Production (Live)
```bash
flutter build web --release -t lib/main_admin_live.dart --base-href /admin/

# Zip for upload
cd build/web && zip -r archive-live.zip . --exclude "*.zip"
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

### Staging Build

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-stage-release.apk \
  --app "1:157462453434:android:fb87af59b08a4ec74c7683" \
  --testers "email@example.com" \
  --release-notes "Staging release notes here"
```

### Production (Live) Build

```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-live-release.apk \
  --app "1:157462453434:android:fb87af59b08a4ec74c7683" \
  --testers "email@example.com" \
  --release-notes "Live release notes here"
```

### Deploy Web Build to Firebase Hosting

```bash
firebase deploy --only hosting
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

## Quick Reference

### Development (Staging)
```bash
# Run user app on device
flutter run

# Run admin panel in Chrome
flutter run -t lib/main_admin.dart -d chrome

# Build staging APK
flutter build apk --release -t lib/main.dart
```

### Production (Live)
```bash
# Run user app on device
flutter run -t lib/main_live.dart

# Run admin panel in Chrome
flutter run -t lib/main_admin_live.dart -d chrome

# Build live APK + AAB
flutter build apk --release -t lib/main_live.dart
flutter build appbundle --release -t lib/main_live.dart

# Deploy to Firebase Hosting
firebase deploy --only hosting
```

### Version Management
Update `pubspec.yaml` before each release:
```yaml
version: 1.0.0+N  # Major.minor.patch+buildNumber
```

### Post-Build Steps
1. APK/AAB output location: `build/app/outputs/`
2. For Google Play Console: Upload `.aab` (Android App Bundle)
3. For Firebase App Distribution: Use `.apk`
4. Update app version in pubspec.yaml (increment build number)

---

## Lint

```bash
flutter analyze
```
