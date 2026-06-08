# Marathon Map - Complete Architecture

## Project Overview
**Marathon Map** is a Flutter-based marathon running app that enables users to track marathon routes, manage groups, compete on leaderboards, and engage with a running community using Firebase backend and GetX state management.

**Technology Stack:**
- Frontend: Flutter + GetX (state management)
- Backend: Firebase (RTDB, Auth, Storage, Messaging)
- Maps: Google Maps + Roads API (snap-to-roads)
- Location: GPS + geofencing for route tracking
- Localization: English + Japanese

---

## 1. PROJECT STRUCTURE

```
lib/
├── main.dart                          # App entry point (staging)
├── main_live.dart                     # App entry point (production)
├── main_admin.dart                    # Admin panel (staging)
├── main_admin_live.dart               # Admin panel (production)
├── firebase_options.dart              # Firebase config (staging)
├── firebase_options_live.dart         # Firebase config (production)
│
├── app/
│   └── routes/
│       └── app_routes.dart            # GetX named routes
│
├── models/                            # Data models (82 total files)
│   ├── event_model.dart               # Event + RaceCategory
│   ├── comment_model.dart             # Comment + Reply + Like
│   ├── user_stats.dart                # User statistics
│   ├── friend_model.dart              # Friend relationships
│   ├── group_model.dart               # Group + Member
│   ├── kml_route.dart                 # KML polyline + marker
│   ├── runner_data.dart               # Live runner position
│   ├── tracked_route.dart             # Run history
│   ├── admin_user_model.dart          # Admin user data
│   └── ...
│
├── controllers/                       # GetX state management
│   ├── auth_controller.dart           # Auth state + login/signup
│   ├── home_controller.dart           # Home screen logic
│   ├── map_controller.dart            # Event list + category filter
│   ├── kml_map_controller.dart        # GPS tracking + finish detection
│   ├── group_controller.dart          # Group CRUD + member mgmt
│   ├── friends_controller.dart        # Friend search + add/remove
│   ├── my_page_controller.dart        # User profile + stats
│   └── ...
│
├── services/                          # Business logic + Firebase
│   ├── auth_service.dart              # Firebase Auth wrapper
│   ├── firebase_service.dart          # RTDB read/write
│   ├── location_service.dart          # GPS foreground service
│   ├── comment_service.dart           # Comments + replies + likes
│   ├── friends_service.dart           # Friend CRUD + search
│   ├── group_service.dart             # Group CRUD + invites
│   ├── user_stats_service.dart        # Stats + leaderboard
│   ├── kml_service.dart               # KML parsing + finish detection
│   ├── live_tracking_service.dart     # Live runner broadcast
│   ├── offline_storage_service.dart   # Local sync + retry
│   ├── admin_service.dart             # Admin event/route creation
│   ├── background_service.dart        # Background tasks
│   ├── deep_link_service.dart         # QR code + deep linking
│   └── ...
│
├── screens/                           # UI screens
│   ├── login_screen.dart              # Auth entry point
│   ├── home_screen.dart               # Tab navigation
│   ├── map_screen.dart                # Event list + countdown
│   ├── kml_map_screen.dart            # Live tracking map
│   ├── group_management_screen.dart   # Group CRUD + members
│   ├── group_detail_screen.dart       # Group info + leaderboard
│   ├── friends_screen.dart            # Friend list + add
│   ├── leaderboard_screen.dart        # Global + friend rankings
│   ├── my_page_screen.dart            # User profile
│   ├── my_routes_screen.dart          # Run history
│   ├── qr_scanner_screen.dart         # QR code scanner
│   ├── run_selfie_screen.dart         # Photo capture
│   ├── route_detail_screen.dart       # Event route details
│   ├── settings_screen.dart           # App preferences
│   ├── my_page_map_screen.dart        # Route playback map
│   └── admin/event_form_screen.dart   # Admin event creation
│
├── widgets/                           # Reusable UI components
│   ├── user_avatar.dart               # Profile photo/initial
│   ├── kml_map_widget.dart            # Google Maps widget
│   └── ...
│
├── core/
│   ├── theme.dart                     # Colors + typography
│   ├── config.dart                    # Firebase paths + API keys
│   ├── image_utils.dart               # Image processing
│   └── ...
│
└── l10n/
    └── strings.dart                   # EN + JA translations
```

---

## 2. STATE MANAGEMENT (GetX)

### Controllers (Singleton Pattern)
Each controller manages a specific feature domain:

```dart
// Pattern used throughout
class MyController extends GetxController {
  static MyController get instance => Get.find<MyController>();
  
  // Observables for reactive UI updates
  final myData = RxValue<Data>(initialValue).obs;
  final isLoading = false.obs;
  
  @override
  void onInit() {
    super.onInit();
    // Listen to Firebase, setup streams
  }
  
  @override
  void onClose() {
    // Cleanup subscriptions
    super.onClose();
  }
}
```

### Key Controllers

| Controller | Responsibility |
|---|---|
| `auth_controller.dart` | User login/signup, auth state, token management |
| `home_controller.dart` | Tab navigation, global state |
| `map_controller.dart` | Event list, category filtering, event selection |
| `kml_map_controller.dart` | GPS tracking, polyline rendering, finish detection, offline handling |
| `group_controller.dart` | Group CRUD, member management, group selection |
| `friends_controller.dart` | Friend list, search, add/remove friends |
| `my_page_controller.dart` | User profile, personal stats, settings |

---

## 3. SERVICES ARCHITECTURE

### Service Layer (Singleton Pattern)
Services encapsulate business logic and Firebase/external API interactions:

```dart
class MyService {
  static final _instance = MyService._();
  
  MyService._();
  
  static MyService get instance => _instance;
  
  // Implementation
}
```

### Key Services

#### **Authentication & User**
- `auth_service.dart` - Firebase Auth wrapper (sign up, login, logout, password reset)
- Firebase Config: `users/{uid}` stores displayName, email, photoUrl

#### **Real-Time Database (RTDB)**
- `firebase_service.dart` - Generic RTDB read/write wrapper
- All database operations go through this service

#### **Location & Tracking**
- `location_service.dart` - GPS tracking with foreground service
  - Uses `bestForNavigation` accuracy
  - Filters positions with 15m accuracy threshold
  - Emits location updates every 10 meters or 10 seconds
  - Foreground notification for persistent service
  
- `kml_service.dart` - KML file parsing + geometry processing
  - Parses polylines and markers from KML
  - Detects finish position (explicit marker or last polyline point)
  - Snap-to-roads integration with Google Roads API
  
- `live_tracking_service.dart` - Live runner broadcast
  - Writes `live_runners/{uid}` with lat, lng, startedAt, displayName, photoUrl
  - Real-time listener for active runners

#### **Social Features**
- `friends_service.dart` - Friend management
  - RTDB: `friends/{uid}/{friendUid}` = true
  - Prefix search on displayNameLower
  - watchFriendUids() observable stream
  
- `comment_service.dart` - Event comments + replies + likes
  - RTDB: `event_comments/{eventId}/{commentId}/likes/{uid}` = true
  - RTDB: `event_comments/{eventId}/{commentId}/replies/{replyId}`
  - Real-time listeners for comments
  
- `user_stats_service.dart` - User statistics + leaderboards
  - RTDB: `user_stats/{uid}` stores distance, runs, seconds, displayName, photoUrl
  - Watches friend leaderboard stream
  - Calculates rankings by distance/time

#### **Group Management**
- `group_service.dart` - Group CRUD + member invitations
  - RTDB: `groups/{groupId}` = {name, createdBy, createdAt, members}
  - QR code generation for group invite links
  - Member add/remove/leave
  - Group leaderboard calculation

#### **Offline & Sync**
- `offline_storage_service.dart` - Local data persistence + cloud sync
  - SharedPreferences for offline run data
  - Detects connectivity changes
  - Auto-syncs pending runs when online
  - Conflict resolution (newer timestamp wins)

#### **Admin Functions**
- `admin_service.dart` - Event and route creation (admin panel only)
  - Creates events in RTDB
  - Uploads KML files to Firebase Storage
  - Storage path: `events/{eventId}/kml/{categoryId}.kml`

#### **Background & Deep Linking**
- `background_service.dart` - Background task scheduling
- `deep_link_service.dart` - QR code + URL deep linking

---

## 4. DATA MODEL & FIREBASE STRUCTURE

### Firebase Realtime Database (RTDB)

```
events/
  {eventId}/
    name: string
    date: timestamp
    location: string
    bannerUrl: string (Firebase Storage path)
    categories: [RaceCategory]
      - categoryId: string
      - categoryName: string
      - distance: number (meters)

event_comments/
  {eventId}/
    {commentId}/
      uid: string (author)
      text: string
      timestamp: number
      likes/
        {uid}: true
      replies/
        {replyId}/
          uid: string
          text: string
          timestamp: number
          likes/
            {uid}: true

groups/
  {groupId}/
    name: string
    createdBy: string (uid)
    createdAt: timestamp
    members/
      {uid}/
        joinedAt: timestamp

user_stats/
  {uid}/
    distance: number (meters)
    runs: number
    seconds: number
    displayName: string
    photoUrl: string (Firebase Storage path)

users/
  {uid}/
    email: string
    displayName: string
    displayNameLower: string (for search)

friends/
  {uid}/
    {friendUid}: true

live_runners/
  {uid}/
    lat: number
    lng: number
    startedAt: timestamp
    displayName: string
    photoUrl: string

tracked_routes/
  {uid}/
    {routeId}/
      eventId: string
      groupId: string (optional)
      points: [lat, lng, timestamp]
      finishedAt: timestamp
      distance: number
```

### Firebase Storage

```
profile_images/{uid}.jpg
events/{eventId}/banner.jpg
events/{eventId}/kml/{categoryId}.kml
```

### Dart Models

Key models in `lib/models/`:
- `EventModel` - Event with categories
- `CommentModel` / `ReplyModel` - Comments with likes
- `UserStats` - User statistics
- `FriendModel` - Friend relationship
- `GroupModel` - Group with members
- `KMLRoute` - Parsed KML data
- `RunnerData` - Live runner position
- `TrackedRoute` - Completed run

---

## 5. SCREEN FLOW & NAVIGATION

### Authentication Flow
```
Login Screen
  ↓ (email + password, Apple/Google sign-in)
  ↓ (AuthService.login / register)
Auth Controller → Home Screen
```

### Main Navigation (GetX Routes)
```
Home Screen (Tab Navigation)
  ├── Map Screen (Events List)
  │   ├── Category Filter (map_controller.dart)
  │   ├── Event Countdown
  │   └── Start Run → KML Map Screen
  │
  ├── Groups Screen
  │   ├── Group List + Create
  │   ├── QR Invite Code
  │   └── Group Detail → Leaderboard
  │
  ├── Friends Screen
  │   ├── Friend List
  │   ├── Friend Search
  │   └── Add Friend
  │
  ├── Leaderboard Screen
  │   ├── Global Rankings
  │   └── Friend Rankings
  │
  ├── My Page Screen
  │   ├── User Profile
  │   ├── Personal Stats
  │   ├── My Routes (Route History)
  │   └── Settings
  │
KML Map Screen (Run Tracking)
  ├── GPS Tracking + Polyline Rendering
  ├── Live Runners Display
  ├── Countdown Overlay
  ├── Finish Line Detection
  └── Stop Run → Summary
```

---

## 6. CORE FLOWS

### Flow 1: Event Tracking (Main Feature)

```
1. User sees Event in Map Screen
   └─ map_controller.dart filters by selected category
   └─ Displays countdown to event start
   
2. User taps "Start Run"
   └─ kml_map_controller.dart initializes
   └─ location_service.dart starts GPS tracking (foreground service)
   └─ Displays live map with polyline
   
3. GPS Updates (every 10m or 10 sec)
   └─ location_service.dart emits LocationData
   └─ kml_map_controller.dart snaps to roads (Google Roads API)
   └─ Renders polyline on map
   └─ Updates live_runners/{uid} for other users to see
   
4. User nears finish
   └─ kml_map_controller.dart detects ≤50m to finish marker
   └─ Triggers _onFinishLineReached()
   └─ Stops tracking immediately (1s delay for UI)
   └─ Saves run to tracked_routes/{uid}/{routeId}
   └─ Updates user_stats/{uid} (distance, seconds, runs++)
   
5. Post-Run
   └─ Shows run summary (distance, time, pace)
   └─ Allows photo capture (run_selfie_screen.dart)
   └─ Option to add comment/compete in group
```

### Flow 2: Group Management

```
1. User creates group
   └─ group_management_screen.dart → group_controller.dart
   └─ Creates groups/{groupId} with creator as first member
   └─ Generates QR code with deep link: /join-group/{groupId}
   
2. User shares QR code
   └─ Other user scans QR (qr_scanner_screen.dart)
   └─ Deep link triggers group join
   └─ group_service.dart adds uid to groups/{groupId}/members
   
3. Run within group
   └─ User starts tracked run (same as Flow 1)
   └─ Also sets groupId in tracked_routes
   └─ Run counts toward group leaderboard
   
4. Group leaderboard
   └─ group_detail_screen.dart queries all runs in group
   └─ Sums distances by uid
   └─ Renders podium with top 3
```

### Flow 3: Social Interaction

```
1. User comments on event
   └─ map_screen.dart → comment_service.dart
   └─ Writes to event_comments/{eventId}/{commentId}
   └─ Other users see real-time via listener
   
2. User likes comment
   └─ comment_service.dart writes event_comments/{eventId}/{commentId}/likes/{uid}=true
   └─ Listener updates UI
   
3. User adds friend
   └─ friends_screen.dart → friends_service.dart
   └─ Writes friends/{uid}/{friendUid}=true
   └─ friend_controller.dart watches watchFriendUids() stream
```

### Flow 4: Offline Sync

```
1. Device offline (no internet)
   └─ location_service.dart still records GPS
   └─ kml_map_controller.dart saves to local storage (offline_storage_service.dart)
   └─ Run data queued in SharedPreferences
   
2. Device comes online
   └─ offline_storage_service.dart detects connectivity via Firebase
   └─ Calls _syncPending() + syncPendingRuns()
   └─ Uploads queued tracked_routes to RTDB
   └─ Updates user_stats/{uid}
   └─ Clears local queue on success
```

---

## 7. EXTERNAL INTEGRATIONS

### Google Maps API
- Embedded in `kml_map_screen.dart`
- Display polylines, markers, runner positions
- Camera animations on location updates

### Google Roads API (Snap-to-Roads)
- Called every 10 GPS points from `kml_map_controller.dart`
- Endpoint: `https://roads.googleapis.com/v1/snapToRoads`
- Input: raw GPS points
- Output: snappedPoints (latitude, longitude, placeId)
- Timeout: 8 seconds (falls back to raw GPS if slow)
- Improves accuracy, prevents polyline crossing buildings

### Firebase Cloud Messaging
- Receives push notifications for:
  - Event reminders (upcoming marathons)
  - Live runner alerts (friend started a run)
  - Comment mentions

### Firebase Authentication
- Email + password
- Google Sign-In
- Apple Sign-In

### Firebase Storage
- Profile images: `profile_images/{uid}.jpg`
- Event banners: `events/{eventId}/banner.jpg`
- KML files: `events/{eventId}/kml/{categoryId}.kml`

---

## 8. ADMIN PANEL ARCHITECTURE

**Separate entry points:**
- `main_admin.dart` (staging)
- `main_admin_live.dart` (production)

### Admin Features
- `admin/event_form_screen.dart` - Create/edit events
  - Form inputs: event name, date, location, banner upload
  - Category inputs: name, distance, KML upload
  - Calls `admin_service.dart` to save to RTDB + Storage
  
- Admin leaderboard view
  - Queries all user_stats in real-time
  - Shows live updating rankings

---

## 9. LOCALIZATION (i18n)

**Translation system:** GetX Translations

```dart
// Pattern used throughout
Text('event_list'.tr)  // Looks up in strings.dart
```

**File:** `lib/l10n/strings.dart`

Languages supported:
- English (en_US)
- Japanese (ja_JP)

**Key translations:**
```
'event_list' → "Events" / "イベント"
'start_run' → "Start Run" / "ランを開始"
'finish_reached' → "You've finished! Run stopped automatically." / "ゴール！ランが自動停止しました。"
'keep_app_alive' → "⚠ Keep the app open. Do not close." / "⚠ アプリを開いたままにしてください。"
```

---

## 10. CONFIGURATION & ENVIRONMENT

### Config File: `lib/core/config.dart`
```dart
class StoragePaths {
  static const profileImages = 'profile_images';
  static const eventBanners = 'events';
  static const kmlFiles = 'kml';
}

class Config {
  static const googleMapsApiKey = '...';
  static const googleRoadsApiKey = '...';
  static const maxAccuracyMetres = 15; // GPS filter
  static const finishDetectionRadius = 50; // meters
  static const startDetectionRadius = 150; // meters
}
```

### Build Variants
- **Staging:** `main.dart` + `firebase_options.dart`
- **Production:** `main_live.dart` + `firebase_options_live.dart`
- **Admin Staging:** `main_admin.dart` + `firebase_options.dart`
- **Admin Production:** `main_admin_live.dart` + `firebase_options_live.dart`

### Version Management (pubspec.yaml)
```
version: 1.0.0+8  # Major.minor.patch+buildNumber
```

---

## 11. DEPENDENCIES

### Core
- `flutter` - UI framework
- `get: ^4.7.2` - State management + routing
- `firebase_core`, `firebase_auth`, `firebase_database`, `firebase_storage` - Backend

### Maps & Location
- `google_maps_flutter: ^2.3.0` - Interactive maps
- `geolocator: ^14.0.2` - GPS access
- `http: ^1.6.0` - HTTP requests (Google Roads API)

### UI/UX
- `cached_network_image: ^3.4.1` - Image caching
- `qr_flutter: ^4.1.0` - QR code generation
- `mobile_scanner: ^7.0.0` - QR scanning
- `camera: ^0.11.1` - Camera (photo capture)
- `shimmer: ^3.0.0` - Loading shimmer

### Data & Storage
- `xml: ^6.3.0` - KML parsing
- `shared_preferences: ^2.3.2` - Local storage
- `crypto: ^3.0.3` - Hashing for user data

### Utilities
- `permission_handler: ^11.4.0` - Runtime permissions
- `url_launcher: ^6.3.1` - Deep linking
- `share_plus: ^10.1.4` - Share functionality
- `timezone: ^0.9.4` - Timezone handling
- `flutter_foreground_task: ^8.14.0` - Background service
- `wakelock_plus: ^1.3.2` - Keep screen on during tracking

---

## 12. BUILD & DEPLOYMENT

### Build Commands
```bash
# Release APK
flutter build apk --release

# Release App Bundle (Google Play)
flutter build appbundle --release

# Release Web
flutter build web --release

# Lint check
flutter analyze
```

### Deployment
```bash
# Firebase Hosting (Web)
firebase deploy --only hosting

# Firebase App Distribution (Android)
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "1:157462453434:android:fb87af59b08a4ec74c7683" \
  --testers "email@example.com"

# Google Play Console
# Upload app-live-release.aab (built via appbundle)
```

---

## 13. KEY ARCHITECTURAL DECISIONS

| Decision | Rationale |
|---|---|
| **GetX for state management** | Lightweight, built-in routing, reactive programming (observables) |
| **Singleton services** | Single source of truth, easy testing, access from anywhere via `get instance` |
| **RTDB over Firestore** | Real-time listeners, simpler data structure for this use case, lower cost at scale |
| **Foreground service** | Keeps GPS tracking alive even with screen off during marathon run |
| **Offline persistence** | Users can track even without internet; syncs automatically when online |
| **Road snapping via Google Roads API** | Improves polyline accuracy, prevents drawing over buildings |
| **Firebase Storage for assets** | Scalable image/KML hosting, CDN included, easy access from mobile |
| **QR codes for group invite** | Frictionless sharing, doesn't require manual typing of group ID |

---

## 14. PERFORMANCE & OPTIMIZATION

### GPS Tracking Optimization
- **Accuracy filter:** 15m threshold (filters noisy points)
- **Distance filter:** 10m between points (prevents too-frequent updates)
- **Time filter:** 10 seconds max between updates
- **Road snapping:** Every 10 points (reduces API calls)

### Data Fetching
- **Pagination:** Event list loads in batches
- **Lazy loading:** Comments only fetched on event detail open
- **Caching:** User profile image cached via `cached_network_image`
- **Listeners:** Only active on visible screens (cleanup in onClose)

### Firebase Cost Optimization
- Avoid querying all 40k events at once
- Aggregate stats instead of real-time calculations
- Archive old events to separate collection
- Batch GPS writes every 10 seconds

---

## 15. SECURITY CONSIDERATIONS

- **Firebase Rules:** Restrict user_stats writes to own uid
- **API Keys:** Google Maps + Roads API keys in config.dart (could use backend proxy in production)
- **Auth:** All data access requires valid Firebase UID
- **Storage paths:** User IDs in storage paths prevent unauthorized access
- **QR codes:** Group IDs are UUIDs (not guessable)

---

## 16. TESTING STRATEGY

Current state: Primarily manual testing on devices

Suggested additions:
- **Unit tests:** Service business logic (comment CRUD, stats calculation)
- **Widget tests:** Reusable components (user avatar, QR code display)
- **Integration tests:** GPS tracking flow, offline sync, group management

---

## 17. FUTURE ENHANCEMENTS

1. **Caching strategy** - Reduce Firebase reads for event list
2. **Batch GPS writes** - Further optimize live tracking data
3. **Notifications** - Push alerts for upcoming events, friend activity
4. **Social features** - Follow users, share runs
5. **Analytics** - Track app usage, route popularity
6. **Offline maps** - Cached map tiles for area with no internet
