# Marathon Map — Claude Code Guide

## Project Overview
Flutter marathon running app using Firebase (Auth, RTDB, Storage), Google Maps, and GetX for state management.

## Architecture
- **State management**: GetX (`lib/controllers/`)
- **Routing**: GetX named routes (`lib/app/routes/app_routes.dart`)
- **Services**: Singleton pattern `Service._()` with `static final instance` (`lib/services/`)
- **Localization**: GetX translations in `lib/l10n/strings.dart` — all user-facing strings must use `.tr` keys, never hardcoded

## Key Files
| Path | Purpose |
|---|---|
| `lib/main.dart` | App entry, Firebase init (duplicate-app safe try/catch) |
| `lib/l10n/strings.dart` | All EN + JA strings |
| `lib/core/theme.dart` | Colors, `AppTheme.primary`, `AppTheme.textSecondary` |
| `lib/core/config.dart` | Firebase Storage paths, Google Maps API key, defaults |
| `lib/models/event_model.dart` | `EventModel`, `RaceCategory` |
| `lib/models/comment_model.dart` | `CommentModel`, `ReplyModel` (likes + replies) |
| `lib/screens/map_screen.dart` | Events list with countdown, comments, category picker |
| `lib/screens/kml_map_screen.dart` | Run tracker map — GPS check, road-snap, live runners |
| `lib/controllers/kml_map_controller.dart` | Tracking logic, snap-to-roads, runner icons |
| `lib/services/location_service.dart` | GPS — foreground service, `bestForNavigation`, 20 m accuracy filter |
| `lib/services/comment_service.dart` | RTDB comments/replies/likes keyed by `eventId` |
| `lib/services/friends_service.dart` | Friends CRUD, prefix search, `watchFriendUids()` stream |
| `lib/services/user_stats_service.dart` | Stats, `watchFriendLeaderboard()` |
| `lib/widgets/user_avatar.dart` | Shared avatar — photo or initial fallback |
| `lib/screens/leaderboard_screen.dart` | Friends-only leaderboard with podium UI |

## Firebase Structure
```
user_stats/{uid}          — distance, runs, seconds, displayName, photoUrl
users/{uid}               — email, displayName, displayNameLower (for search)
friends/{uid}/{friendUid} — true
event_comments/{eventId}/{commentId}/likes/{uid} — true
event_comments/{eventId}/{commentId}/replies/{replyId}
events/{eventId}          — name, date, location, bannerUrl, categories
live_runners/{uid}        — lat, lng, startedAt, displayName, photoUrl
```

## Important Conventions
- **No hardcoded JP text** — all strings go in `lib/l10n/strings.dart` under both `en_US` and `ja_JP`
- **KML storage path**: `events/{eventId}/kml/{categoryId}.kml`
- **Profile images**: `profile_images/{uid}.jpg`
- **Firebase init**: Always use try/catch catching `duplicate-app` code — never check `Firebase.apps.isEmpty`
- **Async tap handlers**: Always wrap as `() => myAsyncFn()` not `onTap: myAsyncFn` to avoid discarded futures
- **Stats panel / overlays on map**: Use `BackdropFilter` + semi-transparent container, never opaque `Material`
- **Runner markers**: Custom 64×64 px circular bitmap with profile photo or initial — cached in `_iconCache`
- **Road snapping**: Every 10 GPS points → Google Roads Snap-to-Roads API → `snappedPoints` observable
- **Location checks on start**: order is GPS off → permission denied → proximity check

## Build
```bash
flutter build apk --release          # Android APK
flutter analyze                      # Lint check before committing
```

## Distribute (Firebase App Distribution)
```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "1:157462453434:android:fb87af59b08a4ec74c7683" \
  --testers "email@example.com" \
  --release-notes "release notes here"
```

## Git Remotes
- `origin` → XOR-Geek/marathon-map (private)
- `massumm` → massumm/marathon-tracker (push here for sharing)
