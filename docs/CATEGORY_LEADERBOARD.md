# Category-Wise & Gender Leaderboard Implementation

## Overview
Live leaderboards in the admin panel support two layers of filtering:
1. **Race category** (e.g., 1km, 7km) — via tabs, one per category
2. **Gender** (All / Male / Female) — via filter chips inside each category tab

## Changes Made

### 1. **RunnerData Model** (`lib/models/runner_data.dart`)
- Added `categoryId` field to track which category the runner is participating in
- Added `gender` field (int?, 0=male, 1=female, null=not set) to enable gender-based filtering
- Updated `fromMap()` and `toMap()` to serialize/deserialize both fields; `gender` is omitted from `toMap()` when null

```dart
class RunnerData {
  ...
  final String categoryId;  // race category (e.g. 'cat_0')
  final int? gender;        // 0 = male, 1 = female, null = not set
  ...
}
```

### 2. **Navigation - Map Screen** (`lib/screens/map_screen.dart`)
- Updated route navigation to KML map to pass `categoryId` in arguments
- When user selects a category, the categoryId is now sent with other event data

```dart
Get.toNamed(
  AppRoutes.kmlMap,
  arguments: {
    ...
    'categoryId': cat.id,  // NEW
    ...
  },
);
```

### 3. **KML Map Controller** (`lib/controllers/kml_map_controller.dart`)
- Added `selectedCategoryId` field to store the selected category ID
- Updated `prepareRoute()` to extract and store categoryId from navigation arguments
- Updated both `startBroadcasting()` calls to include categoryId parameter
- Added debug logging for troubleshooting

```dart
String selectedCategoryId = '';  // NEW

void prepareRoute(dynamic args) {
  if (args is Map) {
    selectedCategoryId = args['categoryId'] as String? ?? '';
    ...
  } else if (args is String) {
    selectedCategoryId = '';  // Reset in fallback path
    ...
  }
}
```

### 4. **Live Tracking Service** (`lib/services/live_tracking_service.dart`)
- `startBroadcasting()` reads `user_stats/{uid}/gender` from RTDB and includes it in the broadcast — no changes needed at call sites
- Stores `categoryId` and `gender` in Firebase `live_runners/{uid}` node

```dart
Future<void> startBroadcasting(double lat, double lng,
    {String eventId = '', String categoryId = ''}) async {
  final genderSnap = await _db.ref('user_stats/${user.uid}/gender').get();
  final gender = (genderSnap.value as num?)?.toInt();
  final data = RunnerData(
    ...
    categoryId: categoryId,
    gender: gender,          // NEW — read from user_stats at run start
    ...
  ).toMap();
  ...
}
```

### 5. **Admin Live Leaderboard** (`lib/screens/admin/admin_live_leaderboard_screen.dart`)
- `TabController` manages one tab per race category
- Added `_genderFilter` state (null=all, 0=male, 1=female)
- `_GenderFilterBar` widget (All / Male / Female `ChoiceChip`s) renders inside each category tab
- `_buildCategoryLeaderboard()` filters first by `categoryId`, then by `gender` if a filter is active

**UI Changes:**
```
┌─────────────────────────────┐
│ [1km] [7km] [21km] ...      │  ← Category Tabs
├─────────────────────────────┤
│ [All] [Male] [Female]       │  ← Gender Filter Chips
├─────────────────────────────┤
│ #1 Runner1  2.3km  |  11m   │  ← Filtered by cat + gender
│ #2 Runner2  1.8km  |  9m    │
└─────────────────────────────┘
```

### 6. **Organizer Live Leaderboard** (`lib/screens/admin/organizer_live_leaderboard_screen.dart`)
- Applied same gender filter logic as admin view
- `_genderFilter` state and `_GenderFilterBar` added to `_buildLeaderboard()`
- Gender filter is applied on top of the existing category filter

## Data Flow

### Scenario: User Starts Run

```
1. User taps "Start Run" on event with categories
   ↓
2. Category picker dialog shows (if multiple categories)
   ↓
3. User selects "1km" category
   ↓
4. Map Screen calls Get.toNamed() with arguments:
   {
     'categoryId': 'cat_0',  ← NEW
     'eventId': 'event002',
     ...
   }
   ↓
5. KML Map Controller receives args
   selectedCategoryId = 'cat_0'
   ↓
6. Tracking starts, LiveTrackingService.startBroadcasting() called:
   startBroadcasting(lat, lng, 
     eventId: 'event002', 
     categoryId: 'cat_0'
   )
   ↓
   startBroadcasting() reads user_stats/{uid}/gender → e.g. 0 (male)
   ↓
7. Firebase writes to live_runners/{uid}:
   {
     lat, lng, startedAt,
     displayName, photoUrl,
     eventId: 'event002',
     categoryId: 'cat_0',
     gender: 0             ← read from user_stats at run start
   }
```

### Scenario: Admin Views Leaderboard

```
1. Admin opens event with 2 categories: 1km (cat_0), 7km (cat_1)
   ↓
2. Leaderboard screen loads
   - Creates TabController with 2 tabs
   - Shows TabBar with category labels
   - Gender filter defaults to "All"
   ↓
3. User 1 (male)   running 1km (categoryId: cat_0, gender: 0) in live_runners
   User 2 (female) running 1km (categoryId: cat_0, gender: 1) in live_runners
   User 3 (male)   running 7km (categoryId: cat_1, gender: 0) in live_runners
   ↓
4. Admin is on tab "1km", filter = All
   - Shows User 1 and User 2
   ↓
5. Admin taps "Male" chip
   - Filters where r.categoryId == 'cat_0' && r.gender == 0
   - Shows only User 1
   ↓
6. Admin taps "Female" chip
   - Filters where r.categoryId == 'cat_0' && r.gender == 1
   - Shows only User 2
   ↓
7. Admin switches to tab "7km" (filter stays on "Male")
   - Filters where r.categoryId == 'cat_1' && r.gender == 0
   - Shows only User 3
```

## Firebase Structure

**Live Runners:**
```json
live_runners/{uid} = {
  "lat": 37.7749,
  "lng": -122.4194,
  "startedAt": 1717858543000,
  "lastSeen": 1717858600000,
  "distanceKm": 1.23,
  "displayName": "John Runner",
  "photoUrl": "...",
  "eventId": "event002",
  "categoryId": "cat_0",
  "gender": 0              // 0 = male, 1 = female, omitted if not set
}
```

**Event Categories:**
```json
events/{eventId} = {
  "name": "Marathon 2024",
  "date": "2024-06-10",
  "categories": {
    "cat_0": {
      "label": "1km run",
      "cutoff": "00:30",
      "kmlPath": "...",
      "kmlUrl": "..."
    },
    "cat_1": {
      "label": "7km run",
      "cutoff": "02:00",
      "kmlPath": "...",
      "kmlUrl": "..."
    }
  }
}
```

## Category ID Generation

When creating an event, categories are assigned auto-generated IDs:
- Format: `cat_0`, `cat_1`, `cat_2`, etc.
- Generated at: `lib/screens/admin/event_form_screen.dart` (line 308)
- `final catId = 'cat_$i';` where `i` is the index

## Debug Logging

Added debug logs for troubleshooting:

**Map Screen (when starting run):**
```
[MAP_SCREEN] Starting run with categoryId: cat_0, category label: 1kmrun
```

**KML Controller (when route loads):**
```
[KML_CONTROLLER] prepareRoute - categoryId: "cat_0", eventId: "event002"
```

**Tracking (when run starts):**
```
[TRACKING] calling startBroadcasting with categoryId: cat_0, eventId: event002
```

**Leaderboard (when displaying):**
```
[LEADERBOARD] Event: event002, Categories count: 2
[LEADERBOARD] Category: cat_0 - 1kmrun
[LEADERBOARD] Category: cat_1 - 7kmrun
[LEADERBOARD] All runners: 2
[LEADERBOARD] Runner: User1, categoryId: "cat_0", eventId: "event002"
[LEADERBOARD] Runner: User2, categoryId: "cat_1", eventId: "event002"
[LEADERBOARD] Filtering by categoryId: "cat_0", Result: 1 runners
```

## Testing Checklist

- [ ] Create event with 2+ categories (with KML files)
- [ ] User 1 (male profile) starts run, selects Category 1
- [ ] User 2 (female profile) starts run, selects Category 1
- [ ] User 3 (male profile) starts run, selects Category 2
- [ ] Admin views live leaderboard
- [ ] Category tabs appear (one for each category)
- [ ] Gender filter chips appear inside each tab (All / Male / Female)
- [ ] Tab 1 + All shows User 1 and User 2
- [ ] Tab 1 + Male shows only User 1
- [ ] Tab 1 + Female shows only User 2
- [ ] Tab 2 shows only User 3 (gender filter still applies)
- [ ] Switching tabs preserves the selected gender filter
- [ ] Console shows categoryId values (not empty)
- [ ] Firebase `live_runners/{uid}` contains `gender` field

## Troubleshooting

**Runners not showing in leaderboard:**
1. Check console for `categoryId: ""` (empty) → categoryId not passed from app
2. Check if `Result: 0 runners` → categoryId mismatch between runner data and event
3. Verify KML files exist for all categories

**Tabs not showing:**
1. Check if event has categories loaded: `Categories count: 0` → event not fetching categories
2. Check TabController initialization: ensure `length: widget.event.categories.length`

**categoryId empty in Firebase:**
1. Check if `selectedCategoryId` is set in KML controller
2. Verify navigation arguments include `'categoryId': cat.id`
3. Check if `startBroadcasting()` is called with categoryId parameter

**gender missing from Firebase live_runners:**
1. Check if the user has set their gender in profile settings — if not set, the field is omitted (null)
2. Gender is read from `user_stats/{uid}/gender` at run start; verify the value exists there
3. Runners with no gender stored will only appear under the "All" filter, not Male/Female
