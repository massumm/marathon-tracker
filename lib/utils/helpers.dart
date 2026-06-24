import 'package:google_maps_flutter/google_maps_flutter.dart';

// ── Calories ──────────────────────────────────────────────────────────────────

int caloriesKcal(double distanceKm) => (distanceKm * 65).round();

String formatCalories(double distanceKm) {
  final c = caloriesKcal(distanceKm);
  return c > 0 ? '$c kcal' : '';
}

/// Parses a distance string like "5.23 km" or "523 m" and returns "X kcal".
String caloriesFromDistStr(String distanceStr) {
  final str = distanceStr.trim();
  if (str.isEmpty) return '';
  final kmMatch = RegExp(r'([\d.]+)\s*km').firstMatch(str);
  if (kmMatch != null) {
    final km = double.tryParse(kmMatch.group(1) ?? '') ?? 0;
    return formatCalories(km);
  }
  final mMatch = RegExp(r'([\d.]+)\s*m\b').firstMatch(str);
  if (mMatch != null) {
    final m = double.tryParse(mMatch.group(1) ?? '') ?? 0;
    return formatCalories(m / 1000);
  }
  return '';
}

// ── Pace ──────────────────────────────────────────────────────────────────────

/// Converts a speed in km/h to "m:ss/km". Returns "" for zero or invalid input.
String paceFromKmh(double kmh) {
  if (kmh <= 0) return '';
  final minPerKm = 60.0 / kmh;
  final mins = minPerKm.floor();
  final secs = ((minPerKm - mins) * 60).round();
  return '$mins:${secs.toString().padLeft(2, '0')}/km';
}

/// Computes a "m:ss/km" pace string from distance and elapsed seconds.
String calcPaceStr(double distanceKm, int seconds) {
  if (seconds <= 0 || distanceKm <= 0) return '';
  return paceFromKmh(distanceKm / (seconds / 3600));
}

/// Normalises stored pace strings. Converts old "X.X km/h" → "m:ss/km".
/// Validates already-formatted "m:ss/km" strings — rejects "0:00/km" etc.
String normalisePace(String pace) {
  if (pace.isEmpty || pace == '—') return '';
  if (pace.contains('/km')) {
    final clean = pace.replaceAll('/km', '').trim();
    final parts = clean.split(':');
    if (parts.length != 2) return '';
    final mins = int.tryParse(parts[0]);
    final secs = int.tryParse(parts[1]);
    if (mins == null || secs == null) return '';
    if (mins == 0 && secs == 0) return '';
    return pace;
  }
  final match = RegExp(r'([\d.]+)\s*km/h').firstMatch(pace);
  if (match == null) return '';
  final kmh = double.tryParse(match.group(1) ?? '');
  return paceFromKmh(kmh ?? 0);
}

// ── Time ──────────────────────────────────────────────────────────────────────

/// Formats a duration in seconds to "Xh Ym" or "Ym".
String formatRunTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return '${h}h ${m}m';
  return '${m}m';
}

// ── Steps ─────────────────────────────────────────────────────────────────────

int calcSteps(double distanceKm) => (distanceKm * 1000 / 0.762).round();

String formatSteps(double distanceKm) {
  final steps = calcSteps(distanceKm);
  if (steps >= 1000) return '${(steps / 1000).toStringAsFixed(1)}k';
  return '$steps';
}

// ── Map bounds ────────────────────────────────────────────────────────────────

LatLngBounds boundsOf(List<LatLng> points) {
  double minLat = points.first.latitude;
  double maxLat = points.first.latitude;
  double minLng = points.first.longitude;
  double maxLng = points.first.longitude;
  for (final p in points) {
    if (p.latitude < minLat) minLat = p.latitude;
    if (p.latitude > maxLat) maxLat = p.latitude;
    if (p.longitude < minLng) minLng = p.longitude;
    if (p.longitude > maxLng) maxLng = p.longitude;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLng),
    northeast: LatLng(maxLat, maxLng),
  );
}
