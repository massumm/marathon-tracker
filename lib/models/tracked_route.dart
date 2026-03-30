import 'package:google_maps_flutter/google_maps_flutter.dart';

class TrackedRoute {
  final String event;
  final String type;
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
      startDate: json['start_date'] as String? ?? '',
      startTime: json['start_time'] as String? ?? '',
      time: json['time'] as String? ?? '',
      distance: json['distance'] as String? ?? '',
      pace: json['pace'] as String? ?? '',
      storagePath: storagePath,
      route: routeData
          .map((e) => LatLng(
                (e['lat'] as num).toDouble(),
                (e['lng'] as num).toDouble(),
              ))
          .toList(),
    );
  }

  /// Parses a human-readable date from filenames like `my_route_1712345678000.json`.
  static String parseDateFromFileName(String fileName) {
    try {
      final ms = int.parse(
          fileName.replaceAll('.json', '').split('_').last);
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
