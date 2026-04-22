import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../app/routes/app_routes.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/runner_data.dart';
import 'package:geolocator/geolocator.dart';

import '../services/firebase_service.dart';
import '../services/friends_service.dart';
import '../services/kml_service.dart';
import '../services/user_stats_service.dart';
import '../services/live_tracking_service.dart';
import '../services/location_service.dart';
import '../widgets/runner_info_sheet.dart';
import 'home_controller.dart';

// ── Leaderboard entry ─────────────────────────────────────────────────────────

class LeaderboardEntry {
  final String uid;
  final String name;
  final String photoUrl;
  final double distanceKm;
  final bool isSelf;
  final int rank;

  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.distanceKm,
    required this.isSelf,
    required this.rank,
  });

  LeaderboardEntry withRank(int r) => LeaderboardEntry(
        uid: uid,
        name: name,
        photoUrl: photoUrl,
        distanceKm: distanceKm,
        isSelf: isSelf,
        rank: r,
      );
}

// ── Controller ────────────────────────────────────────────────────────────────

class KmlMapController extends GetxController {
  // ── Map ───────────────────────────────────────────────────────────────────
  GoogleMapController? mapController;

  // ── KML ───────────────────────────────────────────────────────────────────
  final kmlLoaded = false.obs;
  Set<Polyline> kmlPolylines = {};
  Set<Marker> kmlMarkers = {};
  LatLng initialLocation =
      const LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

  // ── My tracking ───────────────────────────────────────────────────────────
  final isTracking = false.obs;
  final isSaving = false.obs;
  final elapsedSeconds = 0.obs;
  final trackingPoints = <LatLng>[].obs;
  final currentPosition = Rxn<LatLng>();

  Timer? _timer;
  StreamSubscription? _positionSub;
  int _runStartMs = 0;

  int get runStartMs => _runStartMs;

  // ── Live runners ──────────────────────────────────────────────────────────
  final isLive = false.obs;
  final isSharing = true.obs;
  final activeRunners = <RunnerData>[].obs;

  // ── Leaderboard ───────────────────────────────────────────────────────────
  final leaderboard = <LeaderboardEntry>[].obs;
  int _lbTickCount = 0;
  final runnerMarkers = <String, Marker>{}.obs;
  StreamSubscription<List<RunnerData>>? _runnersSub;
  // icon cache keyed by '{uid}_{photoUrl}'
  final _iconCache = <String, BitmapDescriptor>{};

  String kmlFilePath = '';
  String? kmlDirectUrl;
  String routeLabel = '';
  bool _userPanned = false;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called by KmlMapBinding each time the route is opened.
  /// Skips KML reload when a run is already in progress.
  void prepareRoute(dynamic args) {
    if (isTracking.value) return; // run continues — don't reload KML
    kmlLoaded.value = false;
    kmlPolylines = {};
    kmlMarkers = {};
    _loadFriendsAndSubscribe(); // safe here — user is authenticated
    if (args is Map) {
      kmlDirectUrl = args['kmlUrl'] as String? ?? '';
      kmlFilePath = args['storagePath'] as String? ?? '';
      routeLabel = args['label'] as String? ?? '';
    } else if (args is String) {
      kmlFilePath = args;
      kmlDirectUrl = null;
      routeLabel = '';
    }
    _loadKml();
  }

  Future<void> _loadFriendsAndSubscribe() async {
    final friendUids = await FriendsService.instance.getFriendUids();
    _subscribeToRunners(friendUids);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _runnersSub?.cancel();
    _iconCache.clear();
    if (isLive.value) LiveTrackingService.instance.stopBroadcasting();
    super.onClose();
  }

  // ── Runner profile icon ───────────────────────────────────────────────────

  Future<BitmapDescriptor> _getRunnerIcon(RunnerData runner) async {
    final key = '${runner.uid}_${runner.photoUrl}';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;
    final icon = await _buildRunnerIcon(runner);
    _iconCache[key] = icon;
    return icon;
  }

  Future<BitmapDescriptor> _buildRunnerIcon(RunnerData runner) async {
    const double size = 44;
    const double border = 3;
    const double inner = size / 2 - border;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White border ring
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2,
        Paint()..color = Colors.white);

    // Clip to inner circle for photo / initial
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(Rect.fromCircle(
          center: const Offset(size / 2, size / 2), radius: inner)));

    bool drewPhoto = false;
    if (runner.photoUrl.isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(runner.photoUrl));
        if (resp.statusCode == 200) {
          final completer = Completer<ui.Image>();
          ui.decodeImageFromList(resp.bodyBytes, completer.complete);
          final img = await completer.future;
          final minSide = img.width < img.height
              ? img.width.toDouble()
              : img.height.toDouble();
          final src = Rect.fromLTWH((img.width - minSide) / 2,
              (img.height - minSide) / 2, minSide, minSide);
          const dst = Rect.fromLTWH(
              border, border, size - 2 * border, size - 2 * border);
          canvas.drawImageRect(img, src, dst, Paint());
          drewPhoto = true;
        }
      } catch (_) {}
    }

    if (!drewPhoto) {
      canvas.drawCircle(const Offset(size / 2, size / 2), inner,
          Paint()..color = AppTheme.primary);
      final initial = runner.displayName.isNotEmpty
          ? runner.displayName[0].toUpperCase()
          : runner.email.isNotEmpty
              ? runner.email[0].toUpperCase()
              : 'R';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
            text: initial,
            style: const TextStyle(
                fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white))
        ..layout();
      tp.paint(canvas, Offset((size - tp.width) / 2, (size - tp.height) / 2));
    }

    canvas.restore();

    final img =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  // ── Leaderboard helpers ───────────────────────────────────────────────────

  void _rebuildLeaderboard() {
    final entries = <LeaderboardEntry>[];

    // Add self when actively tracking — use live GPS-tracked distance
    final user = FirebaseAuth.instance.currentUser;
    if (isTracking.value && user != null) {
      entries.add(LeaderboardEntry(
        uid: user.uid,
        name: user.displayName?.isNotEmpty == true
            ? user.displayName!
            : user.email?.split('@').first ?? 'You',
        photoUrl: user.photoURL ?? '',
        distanceKm: currentDistanceKm,
        isSelf: true,
        rank: 0,
      ));
    }

    // Add friend runners — use the distanceKm they broadcast
    for (final r in activeRunners) {
      entries.add(LeaderboardEntry(
        uid: r.uid,
        name: r.displayName.isNotEmpty
            ? r.displayName
            : r.email.split('@').first,
        photoUrl: r.photoUrl,
        distanceKm: r.distanceKm,
        isSelf: false,
        rank: 0,
      ));
    }

    // Sort descending — most distance = 1st
    entries.sort((a, b) => b.distanceKm.compareTo(a.distanceKm));
    leaderboard.value = [
      for (var i = 0; i < entries.length; i++) entries[i].withRank(i + 1)
    ];
  }

  // ── KML loading ───────────────────────────────────────────────────────────

  Future<void> _loadKml() async {
    try {
      final url = await FirebaseService.instance.getDownloadUrl(kmlFilePath);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final parsed = KmlService.instance
            .parse(response.body, polylineColor: AppTheme.primary);
        if (parsed.polylines.isNotEmpty) {
          kmlPolylines = parsed.polylines;
          kmlMarkers = parsed.markers;
          initialLocation = parsed.polylines.first.points.first;
          kmlLoaded.value = true;
          mapController?.animateCamera(CameraUpdate.newLatLng(initialLocation));
        }
      }
    } catch (e) {
      debugPrint('KML load error: $e');
    }
  }

  // ── Proximity check ───────────────────────────────────────────────────────

  static const double proximityThresholdKm = 0.5; // 500 m

  /// Returns distance in km from current position to the route start.
  /// Returns -1 if location is unavailable (allow start in that case).
  Future<double> distanceToStartKm() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos == null) return -1;
    final metres = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      initialLocation.latitude,
      initialLocation.longitude,
    );
    return metres / 1000;
  }

  // ── My tracking ───────────────────────────────────────────────────────────

  // Accumulates raw GPS points; snapped to road every 10 points
  final _rawBuffer = <LatLng>[];
  final snappedPoints = <LatLng>[].obs;
  double _cachedDistanceKm = 0.0;

  void onUserPan() => _userPanned = true;

  void recenterCamera() {
    _userPanned = false;
    final pos = currentPosition.value;
    if (pos != null) {
      mapController?.animateCamera(CameraUpdate.newLatLng(pos));
    }
  }

  Future<void> toggleSharing() async {
    if (isSharing.value) {
      isSharing.value = false;
      isLive.value = false;
      await LiveTrackingService.instance.stopBroadcasting();
    } else {
      isSharing.value = true;
      final pos = currentPosition.value;
      final lat = pos?.latitude ?? initialLocation.latitude;
      final lng = pos?.longitude ?? initialLocation.longitude;
      await LiveTrackingService.instance.startBroadcasting(lat, lng);
      isLive.value = true;
    }
  }

  Future<void> startTracking() async {
    trackingPoints.clear();
    snappedPoints.clear();
    _rawBuffer.clear();
    _cachedDistanceKm = 0.0;
    _userPanned = false;
    elapsedSeconds.value = 0;
    isSharing.value = true;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;
    _timer?.cancel();

    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 17));
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
    });

    _positionSub =
        LocationService.instance.getPositionStream().listen((position) async {
      final latLng = LatLng(position.latitude, position.longitude);
      // Update incremental distance before adding point
      if (trackingPoints.isNotEmpty) {
        final prev = trackingPoints.last;
        _cachedDistanceKm += Geolocator.distanceBetween(
              prev.latitude, prev.longitude,
              latLng.latitude, latLng.longitude,
            ) / 1000;
      }
      if (!_userPanned) {
        mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      }
      currentPosition.value = latLng;
      trackingPoints.add(latLng);
      _rawBuffer.add(latLng);
      _lbTickCount++;
      if (_lbTickCount % 4 == 0) _rebuildLeaderboard();

      if (isLive.value) {
        LiveTrackingService.instance.updateLocation(
          position.latitude,
          position.longitude,
          currentDistanceKm,
        );
      }

      // Snap buffer to roads every 10 points (Roads API limit: 100/call)
      if (_rawBuffer.length >= 10) {
        final snapped = await _snapToRoads(List.from(_rawBuffer));
        if (snapped.isNotEmpty) {
          snappedPoints.addAll(snapped);
        } else {
          // API unavailable — fall back to raw
          snappedPoints.addAll(_rawBuffer);
        }
        _rawBuffer.clear();
      }
    });

    // Auto-broadcast when tracking starts
    final lat = pos?.latitude ?? initialLocation.latitude;
    final lng = pos?.longitude ?? initialLocation.longitude;
    await LiveTrackingService.instance.startBroadcasting(lat, lng);
    isLive.value = true;

    isTracking.value = true;
  }

  /// Calls the Google Roads Snap-to-Roads API.
  /// Returns snapped points, or empty list on failure.
  Future<List<LatLng>> _snapToRoads(List<LatLng> points) async {
    if (points.isEmpty) return [];
    try {
      final path =
          points.map((p) => '${p.latitude},${p.longitude}').join('|');
      final uri = Uri.parse(
          'https://roads.googleapis.com/v1/snapToRoads'
          '?path=$path&interpolate=true&key=${AppConfig.googleMapsApiKey}');
      final resp = await http.get(uri);
      if (resp.statusCode != 200) return [];
      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final snappedList = json['snappedPoints'] as List<dynamic>?;
      if (snappedList == null) return [];
      return snappedList.map((sp) {
        final loc = sp['location'] as Map<String, dynamic>;
        return LatLng(
          (loc['latitude'] as num).toDouble(),
          (loc['longitude'] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> stopTracking() async {
    isSaving.value = true;
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;
    isTracking.value = false;
    _rebuildLeaderboard();

    await LiveTrackingService.instance.stopBroadcasting();
    isLive.value = false;

    // Flush remaining raw buffer
    if (_rawBuffer.isNotEmpty) {
      final snapped = await _snapToRoads(List.from(_rawBuffer));
      snappedPoints.addAll(snapped.isNotEmpty ? snapped : _rawBuffer);
      _rawBuffer.clear();
    }

    // Use snapped points for saved route; fall back to raw if snapping produced nothing
    final routePoints =
        snappedPoints.isNotEmpty ? snappedPoints.toList() : trackingPoints.toList();

    final now = DateTime.now();
    final elapsed = Duration(seconds: elapsedSeconds.value);
    final startTime = now.subtract(elapsed);
    final slug = AppConfig.eventName.replaceAll(' ', '_');
    final dateStr =
        '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
    final timeStr2 =
        '${startTime.hour.toString().padLeft(2, '0')}-${startTime.minute.toString().padLeft(2, '0')}';
    final fileName = '${slug}_${dateStr}_$timeStr2.json';
    final totalDistance =
        LocationService.instance.totalDistanceKm(routePoints);
    final pace = elapsedSeconds.value > 0
        ? totalDistance / (elapsedSeconds.value / 3600)
        : 0.0;

    final data = {
      'event': AppConfig.eventName,
      'type': AppConfig.eventType,
      'start_date':
          '${startTime.year}/${startTime.month.toString().padLeft(2, '0')}/${startTime.day.toString().padLeft(2, '0')}',
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}',
      'time': formatTime(elapsedSeconds.value),
      'distance': '${totalDistance.toStringAsFixed(1)} km',
      'pace': '${pace.toStringAsFixed(1)} km/h',
      'route': routePoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };

    await FirebaseService.instance.saveTrackedRoute(fileName, jsonEncode(data));
    await UserStatsService.instance
        .addRunStats(totalDistance, elapsedSeconds.value);
    isSaving.value = false;

    Get.find<HomeController>()
        .changeTab(2); // MyPage is index 2 (0=Events,1=Friends,2=MyPage)
    Get.offAllNamed(AppRoutes.home);
  }

  // ── Live runners ──────────────────────────────────────────────────────────

  void _subscribeToRunners(List<String> friendUids) {
    final friendSet = friendUids.toSet();
    _runnersSub = LiveTrackingService.instance.watchRunners().listen(
      (runners) async {
        final filtered = friendSet.isEmpty
            ? <RunnerData>[]
            : runners.where((r) => friendSet.contains(r.uid)).toList();
        final updated = <String, Marker>{};
        // Fetch all icons in parallel instead of sequentially
        final icons = await Future.wait(filtered.map(_getRunnerIcon));
        for (var i = 0; i < filtered.length; i++) {
          final r = filtered[i];
          final label = _runnerLabel(r);
          updated[r.uid] = Marker(
            markerId: MarkerId(r.uid),
            position: LatLng(r.lat, r.lng),
            icon: icons[i],
            infoWindow: InfoWindow(title: label, snippet: r.email),
            onTap: () => showRunnerInfo(r),
          );
        }
        runnerMarkers.value = updated;
        activeRunners.value = filtered;
        _rebuildLeaderboard();
      },
      onError: (e) {
        final msg = '$e'.contains('Permission denied')
            ? 'Live tracking: permission denied. Check Firebase RTDB rules.'
            : 'Live tracking error: $e';
        Get.snackbar('Error', msg,
            snackPosition: SnackPosition.BOTTOM,
            duration: const Duration(seconds: 4));
      },
    );
  }

  void flyToRunner(RunnerData runner) {
    mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(runner.lat, runner.lng), 16));
  }

  void showRunnerInfo(RunnerData runner) {
    final elapsed = DateTime.now().millisecondsSinceEpoch - runner.startedAt;
    final totalMins = (elapsed / 60000).floor();
    final hours = totalMins ~/ 60;
    final mins = totalMins % 60;
    final durationLabel = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    Get.bottomSheet(
      RunnerInfoSheet(
        label: _runnerLabel(runner),
        email: runner.email,
        photoUrl: runner.photoUrl,
        durationLabel: durationLabel,
      ),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      backgroundColor: Get.theme.scaffoldBackgroundColor,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _runnerLabel(RunnerData r) {
    if (r.displayName.isNotEmpty) return r.displayName;
    if (r.email.isNotEmpty) return r.email.split('@').first;
    return 'Runner';
  }

  String formatTime(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double get currentDistanceKm => _cachedDistanceKm;

  double get currentPaceKmH {
    if (elapsedSeconds.value == 0 || currentDistanceKm == 0) return 0;
    return currentDistanceKm / (elapsedSeconds.value / 3600);
  }
}
