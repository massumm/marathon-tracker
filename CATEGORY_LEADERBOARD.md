# Category-Wise Leaderboard Implementation

## Overview
Implemented category-wise filtering for live leaderboards in the admin panel. Users can now view rankings filtered by marathon category (e.g., 1km, 7km, etc.).

## Changes Made

### 1. **RunnerData Model** (`lib/models/runner_data.dart`)
- Added `categoryId` field to track which category the runner is participating in
- Updated `fromMap()` and `toMap()` to serialize/deserialize categoryId

```dart
class RunnerData {
  ...
  final String categoryId;  // NEW
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
- Updated `startBroadcasting()` method signature to accept `categoryId` parameter
- Stores categoryId in Firebase `live_runners/{uid}` node

```dart
Future<void> startBroadcasting(double lat, double lng,
    {String eventId = '', String categoryId = ''}) async {
  final data = RunnerData(
    ...
    categoryId: categoryId,  // NEW
    ...
  ).toMap();
  ...
}
```

### 5. **Admin Live Leaderboard** (`lib/screens/admin/admin_live_leaderboard_screen.dart`)
- Added `TabController` to manage category tabs
- Added category tabs above the leaderboard (one tab per category)
- Created `_buildCategoryLeaderboard()` method that filters runners by categoryId
- Tabs are scrollable if more than 3 categories exist

**UI Changes:**
```
┌─────────────────────────────┐
│ [1km] [7km] [21km] ...      │  ← Category Tabs
├─────────────────────────────┤
│ #1 Runner1  2.3km  |  11m   │  ← Filtered by cat
│ #2 Runner2  1.8km  |  9m    │
└─────────────────────────────┘
```

### 6. **Organizer Live Leaderboard** (`lib/screens/admin/organizer_live_leaderboard_screen.dart`)
- Applied same category tab logic for the organizer view
- Changed to `TickerProviderStateMixin` to support TabController
- Added category tabs and filtering

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
     categoryId: 'cat_0'  ← NEW
   )
   ↓
7. Firebase writes to live_runners/{uid}:
   {
     lat, lng, startedAt,
     displayName, photoUrl,
     eventId: 'event002',
     categoryId: 'cat_0'  ← NEW
   }
```

### Scenario: Admin Views Leaderboard

```
1. Admin opens event with 2 categories: 1km (cat_0), 7km (cat_1)
   ↓
2. Leaderboard screen loads
   - Creates TabController with 2 tabs
   - Shows TabBar with category labels
   ↓
3. User 1 running 1km (categoryId: cat_0) shows in live_runners
   User 2 running 7km (categoryId: cat_1) shows in live_runners
   ↓
4. Admin clicks tab "1km"
   - _buildCategoryLeaderboard('cat_0') called
   - Filters runners where r.categoryId == 'cat_0'
   - Shows only User 1
   ↓
5. Admin clicks tab "7km"
   - _buildCategoryLeaderboard('cat_1') called
   - Filters runners where r.categoryId == 'cat_1'
   - Shows only User 2
```

## Firebase Structure

**Live Runners:**
```json
live_runners/{uid} = {
  "lat": 37.7749,
  "lng": -122.4194,
  "startedAt": 1717858543000,
  "displayName": "John Runner",
  "photoUrl": "...",
  "eventId": "event002",
  "categoryId": "cat_0"    // ← NEW
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
- [ ] User 1 starts run, selects Category 1
- [ ] User 2 starts run, selects Category 2
- [ ] Admin views live leaderboard
- [ ] Category tabs appear (one for each category)
- [ ] Tab 1 shows only User 1
- [ ] Tab 2 shows only User 2
- [ ] Switching tabs updates the filtered view
- [ ] Console shows categoryId values (not empty)

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
