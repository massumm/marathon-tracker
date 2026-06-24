# Admin Marker System — Reference Doc

Three screens are involved in the marker lifecycle:
1. **Route Editor** — where markers are created and embedded into KML
2. **Event Form** — where the route editor is launched per race category
3. **Organizer Live Map** — where KML markers + live runner markers are displayed together

---

## 1. Route Editor (`lib/screens/admin/route_editor_screen.dart`)

This is the primary marker tool. It has two modes toggled by a toolbar button:

| Mode | What map taps do |
|------|-----------------|
| **Draw Route** | Appends a `LatLng` point to `_routePoints` — builds the polyline |
| **Add Marker** | Opens `_AddMarkerDialog`, then appends a `_PlacedMarker` to `_markers` |

### Marker Types (`_MarkerType` enum)

| Type | Label | Color | Icon |
|------|-------|-------|------|
| `start` | Start | Green | `play_circle_outline` |
| `finish` | Finish | Red | `flag_outlined` |
| `water` | Water Station | Blue | `water_drop_outlined` |
| `restroom` | Restroom | Orange | `wc_outlined` |
| `snack` | Snacks | Cyan | `fastfood_outlined` |
| `medical` | Medical Aid | Pink | `local_hospital_outlined` |
| `info` | Info / Lobby | Purple | `info_outline` |

### Data Model (`_PlacedMarker`)

```dart
class _PlacedMarker {
  final String id;        // 'marker_0', 'marker_1', …
  final LatLng position;
  final String name;      // user-entered label, falls back to type.label
  final _MarkerType type;
}
```

### How Markers Are Rendered on the Map

Each `_PlacedMarker` becomes a Google Maps `Marker`:
- **Icon**: a custom 48×48 px circular bitmap (filled with `type.color`, white border, Material icon glyph centred)
- **Anchor**: `(0.5, 0.5)` — pin point is the circle centre, not the bottom tip
- **InfoWindow**: title = marker name, snippet = type label
- Built async once in `_buildIcons()` at startup and cached in `_typeIcons`

Route dots (the polyline vertex handles) are separate 18×18 px blue dot markers (`_routeDotIcon`) drawn on top of the polyline so the admin can see individual points.

### How Markers Are Saved → KML

On Save, `_generateKml()` writes a KML `<Document>` containing:

1. **Style blocks** — one `<Style id="…">` per `_MarkerType` with `kmlColor` (ABGR hex) and scale
2. **Route Placemark** — `<LineString>` with all `_routePoints` as `lng,lat,0` coordinates
3. **Marker Placemarks** — one `<Placemark>` per `_PlacedMarker`:
   ```xml
   <Placemark>
     <name>Water Station 1</name>
     <styleUrl>#water</styleUrl>
     <Point><coordinates>139.123,35.456,0</coordinates></Point>
   </Placemark>
   ```

The KML is uploaded to Firebase Storage at:
```
events/{eventId}/kml/{categoryId}.kml
```

### Loading an Existing KML Back

`_loadExistingKml()` downloads and parses the KML:
- `<LineString>` → populates `_routePoints` → re-draws the polyline
- `<Point>` Placemarks → re-creates `_PlacedMarker` objects by matching `<styleUrl>` to `_MarkerType.name`

### Other Controls

| Control | Action |
|---------|--------|
| Undo button | Removes last route point (Route mode) or last marker (Marker mode) |
| Clear button | Confirms, then clears both `_routePoints` and `_markers` |
| Search bar | Geocodes a location string via Google Maps Geocoding API and pans the camera |
| Tutorial button | Opens `AppConfig.drawOnMapTutorialUrl` in external browser |
| Distance counter | `_computeCumulativeDistances()` summed — shows total route length next to point count |
| Marker legend strip | Horizontal scrollable chips below the map; each chip shows icon + name and has an `×` to remove that marker |

---

## 2. Event Form (`lib/screens/admin/event_form_screen.dart`)

The form manages one or more **race categories**, each of which can have its own KML route.

### Per-Category Route Options

Each `_CategoryEntry` (one card in the Race Categories section) has two ways to attach a route:

| Button | What it does |
|--------|-------------|
| **Upload KML** | Picks a `.kml` file from disk via `AdminService.pickFile()` and stores raw bytes in `entry.pickedBytes` |
| **Draw on Map** | Pushes `RouteEditorScreen` and waits for a `RouteEditorResult` containing `kmlPath`, `kmlUrl`, `distanceKm` |

When the event is saved, `_save()` resolves which path to use:
- If `pickedBytes != null` → upload bytes to `events/{tmpEventId}/kml/cat_{i}.kml`
- Else if `existingKmlPath` is set → use it unchanged (loaded from an edit)
- The resulting `kmlPath` + `kmlUrl` + optional `distanceKm` are written into the `categories` map in Firebase

Each category also stores:
- `label` — display name (e.g. "21.1 km Half Marathon")
- `cutoff` — time-picker value in `HH:mm` format (e.g. "03:45")
- `endTime` — auto-computed from start time + cutoff minutes

---

## 3. Organizer Live Map (`lib/screens/admin/organizer_live_map_screen.dart`)

### KML Markers

KML is loaded per tab (one tab per race category) via `_loadKmlForTab()`:
- Downloads via `AdminService.downloadKml()` (Firebase Storage SDK) or falls back to direct HTTP URL
- Parsed by `KmlService.instance.parse()` — returns `parsed.polylines` (route overlay) and `parsed.markers` (the POI markers from the KML)
- Both are cached in `_kmlPolylineCache` / `_kmlMarkerCache` by category key so switching tabs is instant

KML markers from the file (Start, Finish, Water stations, etc.) are passed directly to the `GoogleMap` widget:
```dart
markers: {
  ..._kmlMarkers,       // Start, Finish, Water, etc. — from KML
  ..._runnerMarkers(filtered),  // Live runner avatars
}
```

### Live Runner Markers

Built by `_runnerMarkers()` from real-time `RunnerData` streamed via `AdminService.watchLiveRunnersForEvent()`:

| Property | Value |
|----------|-------|
| `markerId` | `'runner_{uid}'` |
| `position` | `LatLng(r.lat, r.lng)` |
| `icon` | Custom circular avatar (photo or initial), cached in `_iconCache` keyed by `'{uid}_{photoUrl}'`. Falls back to `hueAzure` (online) or `hueRed` (offline) default pin if icon not yet loaded. |
| `zIndexInt` | 10 = selected, 5 = online, 1 = offline |
| `infoWindow` | `'#{rank} {name}'` + `'{distanceKm} km · online/offline'` |

A runner is considered **online** if `lastSeen` is within the last 120 seconds.

#### Runner Icon Format
Same 44×44 px circular bitmap used by the runner app:
- White border ring (3 px)
- Clipped inner circle: profile photo from URL, or primary-colour circle with name initial as fallback
- Built in `_buildRunnerIcon()`, cached so network hits happen once per runner

### Camera & Fit Logic

- On KML load: `_fitCameraToRoute()` computes a `LatLngBounds` from all polyline points and calls `animateCamera(newLatLngBounds(…, padding: 60))`
- If the map controller isn't ready yet, the bounds are stored in `_pendingFitPolylines` and applied in `onMapCreated`
- If no KML exists and runners appear: `_autoCenterOnRunners()` averages all runner positions and zooms to 14

### Filtering

| Filter | Where |
|--------|-------|
| Category tab | Runners shown on map/panel are filtered to the selected category key. Runners with `categoryId == ''` fall into the first tab. |
| Gender filter | `_GenderFilterRow` chips (All / Male / Female); filters both the floating runner panel and the Final Standings list |
| Pagination | Runner panel shows 20 per page (`_pageSize`) with prev/next buttons |

### State Phases

| Phase | Condition | What's shown |
|-------|-----------|-------------|
| Live | category not finished AND event not ended | Google Map + floating dark runner panel |
| Finished | `isCategoryFinished(cat)` returns true OR cutoff passed | Final Standings list replaces the map entirely |

`_computeFinishedCats()` marks a category done using `EventModel.isCategoryFinished()`. A 1-second `Timer.periodic` re-evaluates this and the overall cutoff countdown.

---

## Data Flow Summary

```
Admin draws route + places markers in RouteEditorScreen
         ↓
_generateKml() serialises route + markers to KML XML
         ↓
KML uploaded to Firebase Storage: events/{id}/kml/{catId}.kml
         ↓  stored in EventModel.categories[catId].kmlPath
         ↓
OrganizerLiveMapScreen downloads KML → KmlService.parse()
         → parsed.polylines → route overlay on map
         → parsed.markers   → POI markers (Start, Finish, Water…)
         ↓
Alongside KML markers: live runner avatar markers from RTDB
```
