# Speed-Tier Polyline Coloring — Execution Plan

## Feature Summary

Check runner speed every 10 seconds and color the tracked polyline on the map based on speed tier. Speed is also printed to the debug console on every tick.

---

## Speed Tiers

| Tier   | Speed        | Polyline Color   |
|--------|--------------|------------------|
| Normal | < 20 km/h   | `AppTheme.primary` (existing color) |
| Medium | 20 – 40 km/h | `Colors.orange`  |
| Fast   | > 40 km/h   | `Colors.red`     |

---

## How Speed Is Measured

A `Timer.periodic(10 seconds)` fires every 10 s. On each tick:

1. Read `currentPosition` (latest GPS point).
2. Compare against `_speedCheckPosition` (position saved at the previous tick).
3. Compute `distanceMetres / 10.0 * 3.6` → km/h.
4. Print to debug console: `[SPEED] X.X km/h (tier)`.
5. Determine tier; if tier changed → close the current segment and open a new one.
6. Save current position as `_speedCheckPosition` for the next tick.

---

## Polyline Representation — Colored Segments

The path is drawn as a list of `ColoredSegment` objects instead of a single polyline.
Each segment carries a color and a list of `LatLng` points.
When the speed tier changes, the last point of the old segment is copied as the first point of the new one so there is no visual gap.

```
segment 0 [primary] ──────●
                           ● segment 1 [orange] ────●
                                                     ● segment 2 [red] ──
```

---

## New Shared Data Class

**File:** `lib/models/colored_segment.dart` (new file)

```dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ColoredSegment {
  final Color color;
  final List<LatLng> points;
  const ColoredSegment({required this.color, required this.points});
}
```

---

## Files to Modify

### 1. `lib/controllers/free_run_controller.dart`

- Replace `segments: <RxList<LatLng>>` with `coloredSegments: <ColoredSegment>[].obs`
- Add fields:
  - `Timer? _speedTimer`
  - `LatLng? _speedCheckPosition`
  - `SpeedTier _currentTier = SpeedTier.normal`
- In `startRun()`: start `_speedTimer`
- In `pauseRun()`: cancel `_speedTimer`
- In `resumeRun()`: restart `_speedTimer`, reset `_speedCheckPosition`
- In `stopRun()`: cancel `_speedTimer`
- In `resetRun()`: clear `coloredSegments`, reset tier
- Add `_onSpeedTick()`: compute speed, print, split segment if tier changed
- In `_startPositionStream()`: append points to `coloredSegments.last.points`
- Save: flatten `coloredSegments` points for the JSON route (unchanged save format)

### 2. `lib/screens/free_run_screen.dart`

- In the `GoogleMap` widget's `polylines:` parameter:
  - Replace the current segment-based loop with one `Polyline` per `ColoredSegment`
  - Each polyline gets `color: segment.color`

### 3. `lib/controllers/kml_map_controller.dart`

- Add `coloredSegments: <ColoredSegment>[].obs`
- Add fields:
  - `Timer? _speedTimer`
  - `LatLng? _speedCheckPosition`
  - `SpeedTier _currentTier = SpeedTier.normal`
- In `startTracking()`: start `_speedTimer`, initialize first segment
- In `stopTracking()`: cancel `_speedTimer`
- In `onClose()`: cancel `_speedTimer`
- In the GPS stream listener: append smoothed points to `coloredSegments.last.points`
  (existing `trackingPoints` list stays for distance/finish/off-route calculations)
- Add `_onSpeedTick()`: same logic as free run version

### 4. `lib/screens/kml_map_screen.dart`

- Add colored segment polylines to the `GoogleMap` widget
  (KML route overlay polylines remain unchanged)

---

## Enum / Helper (can live in the controller file or a shared utils file)

```dart
enum SpeedTier { normal, medium, fast }

SpeedTier _tierFromKmh(double kmh) {
  if (kmh >= 40) return SpeedTier.fast;
  if (kmh >= 20) return SpeedTier.medium;
  return SpeedTier.normal;
}

Color _colorForTier(SpeedTier tier) => switch (tier) {
  SpeedTier.normal => AppTheme.primary,
  SpeedTier.medium => Colors.orange,
  SpeedTier.fast   => Colors.red,
};
```

---

## What Does NOT Change

- GPS smoothing / jump filter / distance checkpoint pipeline
- Existing vehicle detection flag in `KmlMapController` (separate anti-cheat feature)
- KML route overlay rendering
- Finish line detection, off-route warning, live broadcasting
- JSON save format (route points are still saved as a flat lat/lng list)

---

## Implementation Order

1. Create `lib/models/colored_segment.dart`
2. Update `FreeRunController` + `FreeRunScreen` (simpler, no live tracking)
3. Update `KmlMapController` + `kml_map_screen.dart`
4. Manual test: walk/run and verify color changes; check debug console output
