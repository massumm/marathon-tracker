# iOS Flavor Setup — RunMate

This guide covers the one-time Xcode setup required to run and archive the `staging` and `live` flavors on iOS.

## Overview

| Flavor | Firebase project | Dart entry point | Plist |
|--------|----------------|-----------------|-------|
| staging | `runmate-252e5` | `lib/main.dart` | `GoogleService-Info.plist` |
| live | `runmate-live` | `lib/main_live.dart` | `GoogleService-Info-Live.plist` |

---

## Step 1 — Install dependencies

```bash
flutter pub get
cd ios && pod install && cd ..
```

---

## Step 2 — Add build configurations in Xcode

Open the workspace (always `.xcworkspace`, never `.xcodeproj`):

```bash
open ios/Runner.xcworkspace
```

1. Click the **Runner project** in the file navigator (blue icon at the very top)
2. Select the **Info** tab
3. Under **Configurations**, click **+** → **Duplicate "Debug"** for each new config:
   - `Debug-staging`
   - `Debug-live`
   - `Profile-staging`
   - `Profile-live`
4. Click **+** → **Duplicate "Release"** for:
   - `Release-staging`
   - `Release-live`
5. For each new configuration, expand it by clicking the arrow, then click **None** next to Runner and assign the matching xcconfig file from `ios/`:

| Configuration | xcconfig file |
|---|---|
| Debug-staging | `Debug-Staging` |
| Release-staging | `Release-Staging` |
| Profile-staging | `Debug-Staging` |
| Debug-live | `Debug-Live` |
| Release-live | `Release-Live` |
| Profile-live | `Debug-Live` |

> The xcconfig files (`ios/Debug-Staging.xcconfig`, `ios/Debug-Live.xcconfig`, etc.) are already committed to the repo.

---

## Step 3 — Create Xcode schemes

**Product → Scheme → Manage Schemes...**

1. Click **+** (bottom left) OR duplicate the `Runner` scheme
2. Create a scheme named **`staging`** — tick **Shared**
   - Edit scheme → set each action's build configuration:
     - Run → `Debug-staging`
     - Test → `Debug-staging`
     - Profile → `Profile-staging`
     - Analyze → `Debug-staging`
     - Archive → `Release-staging`
   - Run → Info tab → **LLDB Init File**: `$(SRCROOT)/Flutter/ephemeral/flutter_lldbinit`
3. Create a scheme named **`live`** — tick **Shared**
   - Edit scheme → set each action's build configuration:
     - Run → `Debug-live`
     - Test → `Debug-live`
     - Profile → `Profile-live`
     - Analyze → `Debug-live`
     - Archive → `Release-live`
   - Run → Info tab → **LLDB Init File**: `$(SRCROOT)/Flutter/ephemeral/flutter_lldbinit`

> Both schemes are already committed to `xcshareddata/xcschemes/` — you may not need to create them manually if you cloned the repo.

---

## Step 4 — Regenerate CocoaPods xcfilelists

After adding the new build configurations, CocoaPods must regenerate its xcfilelist files. Run:

```bash
cd ios && pod install && cd ..
```

**Without this step you will see:**
```
Unable to load contents of file list: '...Pods-Runner-resources-Debug-staging-input-files.xcfilelist'
```

---

## Step 5 — Verify the plist copy script

A Run Script build phase named **"Copy GoogleService-Info.plist"** already exists in the Runner target. It copies the live plist when building a `-live` configuration:

```bash
if [[ "${CONFIGURATION}" == *"-live"* ]]; then
  cp "${SRCROOT}/Runner/GoogleService-Info-Live.plist" \
     "${SRCROOT}/Runner/GoogleService-Info.plist"
fi
```

To verify it is correct:
- Runner target → **Build Phases** → expand **"Copy GoogleService-Info.plist"**
- The script should match the above exactly
- "Based on dependency analysis" should be **unchecked** (so it always runs)

> After building a live configuration, `GoogleService-Info.plist` will appear modified in git. Restore it with:
> ```bash
> git checkout -- ios/Runner/GoogleService-Info.plist
> ```

---

## Step 6 — Add Sign In with Apple capability

In Xcode, Runner target → **Signing & Capabilities**:

1. Click **+ Capability**
2. Search for and add **Sign In with Apple**

Also verify in the [Apple Developer Portal](https://developer.apple.com):
- Certificates, IDs & Profiles → Identifiers → `com.xorgeek.runmate`
- Confirm **Sign In with Apple** is checked

---

## Run commands

```bash
# Staging (connects to runmate-252e5)
flutter run --flavor staging --target lib/main.dart

# Live (connects to runmate-live)
flutter run --flavor live --target lib/main_live.dart
```

Or select the scheme in Xcode's toolbar and press **▶**.

---

## Archive / Distribute

```bash
# Build release IPA
flutter build ipa --flavor live --target lib/main_live.dart

# Output: build/ios/ipa/RunMate.ipa
```

Then upload via **Transporter** (Mac App Store) or `xcrun altool`.

From Xcode: select the `live` scheme → destination **"Any iOS Device (arm64)"** → **Product → Archive**.

---

## Common errors

### `Unable to load contents of file list: '...xcfilelist'`
New build configurations were added but CocoaPods xcfilelists weren't regenerated.
```bash
cd ios && pod install && cd ..
```

### `could not find included file 'Debug.xcconfig' in search paths`
The xcconfig files at `ios/` root include `Flutter/Generated.xcconfig`. If this error appears, check that the xcconfig files contain:
```
#include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Flutter/Generated.xcconfig"
```

### `Command PhaseScriptExecution failed with a nonzero exit code`
1. Check disk space: `df -h /` — must have several GB free
2. Run `flutter pub get` to regenerate `Generated.xcconfig`
3. In Build Phases, verify the "Copy GoogleService-Info.plist" script is not corrupted (see Step 5)

### `An error occurred when adding LLDB Init File`
The scheme is not shared or the LLDB Init File field is empty.
- Edit scheme → Run → Info tab → set **LLDB Init File** to `$(SRCROOT)/Flutter/ephemeral/flutter_lldbinit`
- Make sure **Shared** is ticked in Manage Schemes

### `Validation failed — UISupportedInterfaceOrientations` (App Store upload)
Already fixed in `Info.plist` via `UIRequiresFullScreen = true`. No action needed.

### Apple Sign-In error 1000
- Device must be signed into iCloud: **Settings → tap your Apple ID name at the top**
- Sign In with Apple capability must be added in Xcode (see Step 6)
- Live Firebase project must have Apple enabled: Firebase Console → `runmate-live` → Authentication → Sign-in method → Apple
