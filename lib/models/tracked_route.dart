import 'package:google_maps_flutter/google_maps_flutter.dart';

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
    required this.storagePath,
  });

  factory TrackedRoute.fromJson(
      Map<String, dynamic> json, String storagePath) {
    final routeData = json['route'] as List<dynamic>;
    return TrackedRoute(
      event: json['event'] as String? ?? '',
      type: json['type'] as String? ?? '',
      runStartMs: json['run_start_ms'] as int? ?? 0,
      startDate: json['start_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      time: json['time'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      pace: _normalisePace(json['pace'] as String? ?? ''),
      storagePath: storagePath,
      route: routeData
          .map((e) => LatLng(
                (e['lat'] as num).toDouble(),
                (e['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  /// Converts old "X.X km/h" pace strings to "m:ss/km" format.
  /// Already-converted strings (contain "/km") are returned unchanged.
  static String _normalisePace(String pace) {
    if (pace.isEmpty || pace == '—') return pace;
    if (pace.contains('/km')) return pace; // already correct format
    final match = RegExp(r'([\d.]+)\s*km/h').firstMatch(pace);
    if (match == null) return pace;
    final kmh = double.tryParse(match.group(1) ?? '');
    if (kmh == null || kmh <= 0) return '—';
    final minPerKm = 60.0 / kmh;
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}/km';
  }

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
