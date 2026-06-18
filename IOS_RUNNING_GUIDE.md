# iOS Running Guide — RunMate

## Prerequisites

| Tool | Required Version | Check |
|------|-----------------|-------|
| Flutter | 3.x stable | `flutter --version` |
| Xcode | 15+ (26.x tested) | `xcodebuild -version` |
| CocoaPods | 1.14+ | `pod --version` |
| Apple Developer Account | Enrolled | developer.apple.com |

Bundle ID: `com.xor.runmate`  
Team IDs in project: `3YRPP5KTT5`, `2TCRW7HYCR`

---

## Fix: "Unable to load contents of file list" Error

This error means the CocoaPods-generated `.xcfilelist` files are missing or stale. Run the full reset sequence:

```bash
# 1. Clean Flutter build artifacts
flutter clean

# 2. Get packages fresh
flutter pub get

# 3. Remove stale Pods
cd ios
rm -rf Pods
rm -f Podfile.lock

# 4. Reinstall pods
pod install --repo-update

# 5. Go back to project root and run
cd ..
flutter run
```

If `pod install` fails with a Ruby/gem error:
```bash
sudo gem install cocoapods
pod install --repo-update
```

---

## First-Time Setup

### 1. Install dependencies
```bash
flutter pub get
cd ios && pod install && cd ..
```

### 2. Open in Xcode (for signing setup)
```bash
open ios/Runner.xcworkspace   # Always open .xcworkspace, NOT .xcodeproj
```

In Xcode:
- Select **Runner** in the project navigator
- Go to **Signing & Capabilities** tab
- Set **Team** to your Apple Developer account
- Confirm **Bundle Identifier** is `com.xor.runmate`

### 3. Trust the device
On your iPhone: **Settings → General → VPN & Device Management → Trust [your Mac]**

---

## Running on a Physical iPhone

```bash
# List connected devices
flutter devices

# Run on connected iPhone (debug)
flutter run -d <device-id>

# Run on the first connected iPhone automatically
flutter run
```

### With a specific scheme
```bash
flutter run --flavor Runner    # default scheme
```

---

## Build Configurations

| Configuration | Command | Use For |
|--------------|---------|---------|
| Debug | `flutter run` | Development on device |
| Profile | `flutter run --profile` | Performance testing |
| Release | `flutter build ios --release` | App Store / TestFlight |

### Build a release IPA
```bash
flutter build ipa --release
# Output: build/ios/ipa/RunMate.ipa
```

---

## Staging vs Live (Flavors)

The app has two Firebase environments:

| Flavor | Firebase project | Dart entry point | iOS plist |
|--------|-----------------|-----------------|-----------|
| staging | `runmate-252e5` | `lib/main.dart` | `GoogleService-Info.plist` |
| live | `runmate-live` | `lib/main_live.dart` | `GoogleService-Info-Live.plist` |

### Run commands

```bash
# Staging
flutter run --flavor staging --target lib/main.dart

# Live
flutter run --flavor live --target lib/main_live.dart

# Build release IPA
flutter build ipa --flavor staging --target lib/main.dart
flutter build ipa --flavor live --target lib/main_live.dart
```

### One-time Xcode setup

This only needs to be done once per machine/clone.

#### 1. xcconfig files

Four xcconfig files already exist at `ios/`:

| File | Content |
|------|---------|
| `Debug-Staging.xcconfig` | Pods debug + Generated.xcconfig |
| `Release-Staging.xcconfig` | Pods release + Generated.xcconfig |
| `Debug-Live.xcconfig` | Pods debug + Generated.xcconfig |
| `Release-Live.xcconfig` | Pods release + Generated.xcconfig |

#### 2. Add build configurations in Xcode

Open `ios/Runner.xcworkspace`:
1. Click the **Runner project** (blue icon, top of navigator)
2. Select the **Info** tab
3. Under **Configurations**, duplicate each default config and name them:
   - `Debug-staging`, `Release-staging`, `Profile-staging`
   - `Debug-live`, `Release-live`, `Profile-live`
4. For each new config, expand it and assign the matching xcconfig to Runner:

| Configuration | xcconfig |
|---|---|
| Debug-staging | `Debug-Staging` |
| Release-staging | `Release-Staging` |
| Debug-live | `Debug-Live` |
| Release-live | `Release-Live` |

#### 3. Create two Xcode schemes

**Product → Scheme → Manage Schemes...**

1. Duplicate `Runner` → rename to **`staging`** → tick **Shared**
   - Edit: Run=`Debug-staging`, Archive=`Release-staging`, Profile=`Profile-staging`
2. Duplicate `Runner` → rename to **`live`** → tick **Shared**
   - Edit: Run=`Debug-live`, Archive=`Release-live`, Profile=`Profile-live`

#### 4. Regenerate CocoaPods xcfilelists

After adding the new build configurations, run:

```bash
cd ios && pod install && cd ..
```

This generates the required `.xcfilelist` files for each new configuration. Without this step you'll get:

```
Unable to load contents of file list: '...Pods-Runner-resources-Debug-staging-input-files.xcfilelist'
```

#### 5. Plist swap (already configured)

A Run Script build phase in the Runner target handles this automatically:

```bash
if [[ "${CONFIGURATION}" == *"-live"* ]]; then
  cp "${SRCROOT}/Runner/GoogleService-Info-Live.plist" \
     "${SRCROOT}/Runner/GoogleService-Info.plist"
fi
```

> After a live build, `GoogleService-Info.plist` will be modified in git. Restore it with:
> `git checkout -- ios/Runner/GoogleService-Info.plist`

---

## Common Errors & Fixes

### `pod install` fails — platform version mismatch
```
# ios/Podfile first line should be:
platform :ios, '15.0'
```

### Signing error — no matching provisioning profile
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner target → Signing & Capabilities
- Enable **Automatically manage signing**
- Select your team

### `flutter run` can't find device
```bash
# Check device is trusted and connected
flutter devices
idevice_id -l    # requires libimobiledevice: brew install libimobiledevice
```

### Xcode DerivedData cache issues
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
```

### Disk space errors during build
```bash
flutter clean
rm -rf ~/.gradle/caches     # Android caches also eat space
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## Quick Reference

```bash
# Full clean + reinstall (fixes most issues)
flutter clean && flutter pub get && cd ios && rm -rf Pods Podfile.lock && pod install && cd .. && flutter run

# Check everything is set up correctly
flutter doctor -v
```
