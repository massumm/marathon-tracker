import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../utils/helpers.dart';

class TrackedRoute {
  final String event;
  final String type;
  final int runStartMs;
  final String startDate;
  final String startTime;
  final String time;
  final String distance;
  final String pace;
  final List<LatLng> route;
  final List<int> timestamps;
  final String storagePath;

  const TrackedRoute({
    required this.event,
    required this.type,
    this.runStartMs = 0,
    required this.startDate,
    required this.startTime,
    required this.time,
    required this.distance,
    required this.pace,
    required this.route,
    this.timestamps = const [],
    required this.storagePath,
  });

  bool get hasTimestamps => timestamps.length == route.length && timestamps.any((t) => t > 0);

  /// Real timestamps when available; otherwise a uniform estimate from
  /// runStartMs + total time — good enough for speed-tier coloring on old saves.
  List<int> get effectiveTimestamps {
    if (hasTimestamps) return timestamps;
    if (runStartMs <= 0 || route.length < 2) return [];
    final totalMs = _parseDurationMs(time);
    if (totalMs <= 0) return [];
    final step = totalMs / (route.length - 1);
    return List.generate(route.length, (i) => runStartMs + (i * step).round());
  }

  bool get hasEffectiveTimestamps =>
      hasTimestamps ||
      (runStartMs > 0 && route.length >= 2 && _parseDurationMs(time) > 0);

  static int _parseDurationMs(String t) {
    final parts = t.split(':');
    try {
      if (parts.length == 2) {
        return (int.parse(parts[0]) * 60 + int.parse(parts[1])) * 1000;
      } else if (parts.length == 3) {
        return (int.parse(parts[0]) * 3600 +
                int.parse(parts[1]) * 60 +
                int.parse(parts[2])) *
            1000;
      }
    } catch (_) {}
    return 0;
  }

  factory TrackedRoute.fromJson(
      Map<String, dynamic> json, String storagePath) {
    final routeData = json['route'] as List<dynamic>;
    final points = <LatLng>[];
    final timestamps = <int>[];
    for (final e in routeData) {
      points.add(LatLng(
        (e['lat'] as num).toDouble(),
        (e['lng'] as num).toDouble(),
      ));
      timestamps.add((e['t'] as int?) ?? 0);
    }
    return TrackedRoute(
      event: json['event'] as String? ?? '',
      type: json['type'] as String? ?? '',
      runStartMs: json['run_start_ms'] as int? ?? 0,
      startDate: json['start_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      time: json['time'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      pace: normalisePace(json['pace'] as String? ?? ''),
      storagePath: storagePath,
      route: points,
      timestamps: timestamps,
    );
  }

  String get caloriesStr => caloriesFromDistStr(distance);

  /// Extracts a sortable DateTime from both old and new filename formats.
  static DateTime parseDateTimeFromFileName(String fileName) {
    final base = fileName.replaceAll('.json', '');
    final parts = base.split('_');
    // New format: EventName_YYYY-MM-DD_HH-mm
    if (parts.length >= 2) {
      final timePart = parts.last;
      final datePart = parts[parts.length - 2];
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart) &&
          RegExp(r'^\d{2}-\d{2}$').hasMatch(timePart)) {
        final tp = timePart.split('-');
        final dp = datePart.split('-');
        return DateTime(int.parse(dp[0]), int.parse(dp[1]), int.parse(dp[2]),
            int.parse(tp[0]), int.parse(tp[1]));
      }
    }
    // Old format: my_route_<ms>
    try {
      return DateTime.fromMillisecondsSinceEpoch(int.parse(parts.last));
    } catch (_) {
      return DateTime(0);
    }
  }

  /// Returns event name from filename.
  /// New format: `EventName_YYYY-MM-DD_HH-mm.json`
  /// Old format: `my_route_<ms>.json` — falls back to raw name.
  static const _months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  static String parseEventFromFileName(String fileName) {
    final base = fileName.replaceAll('.json', '');
    final parts = base.split('_');
    if (parts.length >= 3) {
      final timePart = parts.last; // HH-mm
      final datePart = parts[parts.length - 2]; // YYYY-MM-DD
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart) &&
          RegExp(r'^\d{2}-\d{2}$').hasMatch(timePart)) {
        final eventName = parts.sublist(0, parts.length - 2).join(' ');
        // For Free Run, append the date so each card has a unique title.
        if (eventName == 'Free Run' || eventName == 'Daily Challenge') {
          final dp = datePart.split('-');
          final month = _months[int.parse(dp[1])];
          return 'Daily Challenge · $month ${int.parse(dp[2])}';
        }
        return eventName;
      }
    }
    return base;
  }

  /// Returns date/time string from filename.
  static String parseDateFromFileName(String fileName) {
    final base = fileName.replaceAll('.json', '');
    final parts = base.split('_');
    // New format: EventName_YYYY-MM-DD_HH-mm
    if (parts.length >= 2) {
      final timePart = parts.last;
      final datePart = parts[parts.length - 2];
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart) &&
          RegExp(r'^\d{2}-\d{2}$').hasMatch(timePart)) {
        final dp = datePart.split('-');
        final month = _months[int.parse(dp[1])];
        final day = int.parse(dp[2]);
        final year = dp[0];
        final time = timePart.replaceAll('-', ':');
        return '$month $day, $year  $time';
      }
    }
    // Old format: my_route_<ms>
    try {
      final ms = int.parse(parts.last);
      final dt = DateTime.fromMillisecondsSinceEpoch(ms);
      final d = dt.day.toString().padLeft(2, '0');
      final mo = dt.month.toString().padLeft(2, '0');
      final h = dt.hour.toString().padLeft(2, '0');
      final mi = dt.minute.toString().padLeft(2, '0');
      return '${dt.year}/$mo/$d  $h:$mi';
    } catch (_) {
      return fileName;
    }
  }
}
