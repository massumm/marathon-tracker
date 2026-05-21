import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../app/routes/app_routes.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/runner_data.dart';
import 'package:geolocator/geolocator.dart';

import '../services/event_notification_service.dart';
import '../services/firebase_service.dart';
import '../services/offline_storage_service.dart';
import '../services/friends_service.dart';
import '../services/group_service.dart';
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
  final kmlLoadError = false.obs;
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

  // ── Self marker ───────────────────────────────────────────────────────────
  BitmapDescriptor? _selfIcon;
  final selfMarker = Rxn<Marker>();

  // ── Live runners ──────────────────────────────────────────────────────────
  final isLive = false.obs;
  final isSharing = true.obs;
  final activeRunners = <RunnerData>[].obs; // friends/group — map markers
  final allEventRunners = <RunnerData>[].obs; // same eventId — leaderboard

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
  final isUserPanned = false.obs;
  bool _programmaticCamera = false;
  double _lastHeading = 0.0;
  String currentEventId = '';
  DateTime? eventStartTime;
  DateTime? cutoffDateTime;
  DateTime? chipDeadline;
  DateTime? categoryCutoffDeadline;
  CameraPosition? lastCameraPosition;
  Timer? _countdownTimer;
  Timer? _cutoffTimer;
  Timer? _graceTimer;
  Timer? _categoryCutoffTimer;
  bool _countdownCancelled = false;
  int _graceTimeMinutes = 10;
  int? _categoryCutoffMinutes;
  LatLng? finishPosition;
  bool _finishAlertShown = false;
  bool _hasLeftFinishZone = false;
  static const double _finishRadiusM = 50.0;
  static const double _finishArmRadiusM = 150.0;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  /// Called by KmlMapBinding each time the route is opened.
  /// Skips KML reload when a run is already in progress.
  void prepareRoute(dynamic args) {
    if (isTracking.value) return; // run continues — don't reload KML
    kmlLoaded.value = false;
    kmlPolylines = {};
    kmlMarkers = {};
    _loadFriendsAndSubscribe(); // safe here — user is authenticated
    _initSelfIcon();
    if (args is Map) {
      kmlDirectUrl = args['kmlUrl'] as String? ?? '';
      kmlFilePath = args['storagePath'] as String? ?? '';
      routeLabel = args['label'] as String? ?? '';
      currentEventId = args['eventId'] as String? ?? '';
      final evMs = args['eventDateTime'] as int? ?? 0;
      final hasTime = args['hasStartTime'] as bool? ?? false;
      eventStartTime = (hasTime && evMs > 0)
          ? DateTime.fromMillisecondsSinceEpoch(evMs)
          : null;
      final cutMins = args['cutoffMinutes'] as int? ?? 0;
      cutoffDateTime = (eventStartTime != null && cutMins > 0)
          ? eventStartTime!.add(Duration(minutes: cutMins))
          : null;
      final chipMins = args['chipTimeMinutes'] as int? ?? 10;
      chipDeadline = eventStartTime?.add(Duration(minutes: chipMins));
      _graceTimeMinutes = args['graceTimeMinutes'] as int? ?? 10;
      _categoryCutoffMinutes =
          _parseCutoffMinutes(args['categoryCutoff'] as String? ?? '');
      categoryCutoffDeadline = eventStartTime != null && _categoryCutoffMinutes != null
          ? eventStartTime!.add(Duration(minutes: _categoryCutoffMinutes!))
          : null;
    } else if (args is String) {
      kmlFilePath = args;
      kmlDirectUrl = null;
      routeLabel = '';
      currentEventId = '';
      eventStartTime = null;
      cutoffDateTime = null;
      chipDeadline = null;
      categoryCutoffDeadline = null;
      _graceTimeMinutes = 10;
      _categoryCutoffMinutes = null;
    }
    _loadKml();
  }

  /// Parses "HH:MM" or "HH:MM suffix" cutoff strings into total minutes.
  /// Returns null when the string can't be parsed or totals zero.
  int? _parseCutoffMinutes(String s) {
    final parts = s.trim().split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim());
    final m = int.tryParse(parts[1].trim().split(' ').first);
    if (h == null || m == null) return null;
    final total = h * 60 + m;
    return total > 0 ? total : null;
  }

  Future<void> _loadFriendsAndSubscribe() async {
    final results = await Future.wait([
      FriendsService.instance.getFriendUids(),
      GroupService.instance.getMyGroupMemberUids(),
    ]);
    final allUids = <String>{...results[0], ...results[1]}.toList();
    _subscribeToRunners(allUids);
  }

  @override
  void onClose() {
    _timer?.cancel();
    _countdownTimer?.cancel();
    _cutoffTimer?.cancel();
    _graceTimer?.cancel();
    _categoryCutoffTimer?.cancel();
    _positionSub?.cancel();
    _runnersSub?.cancel();
    _iconCache.clear();
    if (isLive.value) LiveTrackingService.instance.stopBroadcasting();
    if (isTracking.value) FlutterForegroundTask.stopService();
    super.onClose();
  }

  /// Starts the foreground service (keeps Dart isolate alive in background)
  /// and schedules a one-shot timer that calls [startTracking] at [eventStart].
  Future<void> beginCountdown(DateTime eventStart) async {
    _countdownCancelled = false;
    _countdownTimer?.cancel();
    debugPrint('[COUNTDOWN] beginCountdown called. eventStart=$eventStart now=${DateTime.now()}');

    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      debugPrint('[COUNTDOWN] requesting battery optimisation exemption');
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    if (_countdownCancelled) {
      debugPrint('[COUNTDOWN] cancelled during setup — aborting');
      return;
    }

    await EventNotificationService.instance
        .scheduleCountdownAutoStart(eventStart.millisecondsSinceEpoch);
    debugPrint('[COUNTDOWN] AlarmManager alarm scheduled at $eventStart');

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'RunMate – Starting Soon',
      notificationText: 'Auto-starts when event begins. Keep notification visible.',
    );
    debugPrint('[COUNTDOWN] foreground service started');

    if (_countdownCancelled) {
      debugPrint('[COUNTDOWN] cancelled during FGT startup — aborting');
      EventNotificationService.instance.cancelCountdownAutoStart();
      FlutterForegroundTask.stopService();
      return;
    }

    final delay = eventStart.difference(DateTime.now());
    debugPrint('[COUNTDOWN] Dart timer delay = ${delay.inSeconds}s');
    if (delay.inSeconds <= 0) {
      debugPrint('[COUNTDOWN] already past start time — calling startTracking immediately');
      await startTracking();
      return;
    }
    _countdownTimer = Timer(delay, () async {
      debugPrint('[COUNTDOWN] Dart timer fired — calling startTracking');
      await startTracking();
    });
  }

  void cancelCountdown() {
    _countdownCancelled = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    EventNotificationService.instance.cancelCountdownAutoStart();
    FlutterForegroundTask.stopService();
  }

  // ── Runner profile icon ───────────────────────────────────────────────────

  Future<BitmapDescriptor> _getRunnerIcon(RunnerData runner) async {
    final key = '${runner.uid}_${runner.photoUrl}';
    if (_iconCache.containsKey(key)) return _iconCache[key]!;
    try {
      final icon = await _buildRunnerIcon(runner);
      _iconCache[key] = icon;
      return icon;
    } catch (_) {
      // Build initial-letter fallback so one failure doesn't kill all markers
      final noPhoto = RunnerData(
        uid: runner.uid,
        email: runner.email,
        displayName: runner.displayName,
        photoUrl: '',
        lat: runner.lat,
        lng: runner.lng,
        startedAt: runner.startedAt,
        distanceKm: runner.distanceKm,
        eventId: runner.eventId,
      );
      final fallback = await _buildRunnerIcon(noPhoto);
      _iconCache[key] = fallback;
      return fallback;
    }
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

  // ── Self icon (photo/initial + heading arrow) ─────────────────────────────

  Future<void> _initSelfIcon() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    String photoUrl = user.photoURL ?? '';
    String displayName = user.displayName ?? '';
    try {
      final snap =
          await FirebaseDatabase.instance.ref('user_stats/${user.uid}').get();
      if (snap.exists) {
        final data = snap.value as Map<dynamic, dynamic>;
        final p = data['photoUrl'] as String? ?? '';
        final n = data['displayName'] as String? ?? '';
        if (p.isNotEmpty) photoUrl = p;
        if (n.isNotEmpty) displayName = n;
      }
    } catch (_) {}
    _selfIcon = await _buildSelfIcon(photoUrl, displayName);
    // If a position already arrived before the icon was ready, paint it now.
    final pos = currentPosition.value;
    if (pos != null) _updateSelfMarker(pos);
  }

  Future<BitmapDescriptor> _buildSelfIcon(
      String photoUrl, String displayName) async {
    const double w = 56;
    const double h = 72;
    const double cx = w / 2;
    const double circleRadius = 22.0;
    // Circle sits near the bottom; arrow tip starts at top.
    const double circleCy = h - circleRadius - 2;
    const double border = 3.0;
    const double innerRadius = circleRadius - border;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Directional arrow triangle pointing up (North when rotation = 0).
    final arrowPaint = Paint()..color = AppTheme.primary;
    final arrowPath = Path()
      ..moveTo(cx, 0)
      ..lineTo(cx - 11, 22)
      ..lineTo(cx + 11, 22)
      ..close();
    canvas.drawPath(arrowPath, arrowPaint);

    // White border ring.
    canvas.drawCircle(
        Offset(cx, circleCy), circleRadius, Paint()..color = Colors.white);

    // Clip to avatar area.
    canvas.save();
    canvas.clipPath(Path()
      ..addOval(
          Rect.fromCircle(center: Offset(cx, circleCy), radius: innerRadius)));

    bool drewPhoto = false;
    if (photoUrl.isNotEmpty) {
      try {
        final resp = await http.get(Uri.parse(photoUrl));
        if (resp.statusCode == 200) {
          final completer = Completer<ui.Image>();
          ui.decodeImageFromList(resp.bodyBytes, completer.complete);
          final img = await completer.future;
          final minSide = img.width < img.height
              ? img.width.toDouble()
              : img.height.toDouble();
          final src = Rect.fromLTWH((img.width - minSide) / 2,
              (img.height - minSide) / 2, minSide, minSide);
          final dst = Rect.fromLTWH(cx - innerRadius, circleCy - innerRadius,
              innerRadius * 2, innerRadius * 2);
          canvas.drawImageRect(img, src, dst, Paint());
          drewPhoto = true;
        }
      } catch (_) {}
    }

    if (!drewPhoto) {
      canvas.drawCircle(
          Offset(cx, circleCy), innerRadius, Paint()..color = AppTheme.primary);
      final initial =
          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M';
      final tp = TextPainter(textDirection: TextDirection.ltr)
        ..text = TextSpan(
            text: initial,
            style: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white))
        ..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, circleCy - tp.height / 2));
    }

    canvas.restore();

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _updateSelfMarker(LatLng pos) {
    final icon = _selfIcon;
    if (icon == null) return;
    selfMarker.value = Marker(
      markerId: const MarkerId('_self'),
      position: pos,
      icon: icon,
      rotation: _lastHeading,
      // Pin point = center of the avatar circle (circle center at y=48/72).
      anchor: const Offset(0.5, 48 / 72),
      flat: true,
      zIndexInt: 10,
      consumeTapEvents: false,
    );
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

    // All runners in this event — use the distanceKm they broadcast
    for (final r in allEventRunners) {
      entries.add(LeaderboardEntry(
        uid: r.uid,
        name:
            r.displayName.isNotEmpty ? r.displayName : r.email.split('@').first,
        photoUrl: r.photoUrl,
        distanceKm: r.distanceKm,
        isSelf: false,
        rank: 0,
      ));
    }

    // Sort descending with hysteresis: runners within _kHysteresisKm of each
    // other keep their previous relative order instead of swapping on GPS noise.
    final prevRank = {for (final e in leaderboard) e.uid: e.rank};
    entries.sort((a, b) {
      final diff = b.distanceKm - a.distanceKm;
      if (diff.abs() < _kHysteresisKm) {
        final ra = prevRank[a.uid] ?? 999;
        final rb = prevRank[b.uid] ?? 999;
        return ra.compareTo(rb);
      }
      return diff > 0 ? 1 : -1;
    });
    final capped = entries.length > 10 ? entries.sublist(0, 10) : entries;
    leaderboard.value = [
      for (var i = 0; i < capped.length; i++) capped[i].withRank(i + 1)
    ];
  }

  // ── KML loading ───────────────────────────────────────────────────────────

  Future<void> _loadKml() async {
    kmlLoadError.value = false;

    // 1. Serve from local cache immediately so the map works offline.
    final cached = await OfflineStorageService.instance
        .getCachedContent(kmlFilePath);
    if (cached != null) {
      _applyKmlContent(cached);
      // Refresh cache in background — don't block startup.
      _fetchAndCacheKml(forceApply: false);
      return;
    }

    // 2. No cache — must fetch from network.
    final ok = await _fetchAndCacheKml(forceApply: true);
    if (!ok && !kmlLoaded.value) {
      kmlLoadError.value = true;
    }
  }

  /// Fetches the KML from the network (10 s timeout), caches it locally.
  /// [forceApply] updates the map polylines on success.
  /// Returns true when the download succeeded.
  Future<bool> _fetchAndCacheKml({required bool forceApply}) async {
    try {
      final String rawUrl;
      if (kmlDirectUrl != null && kmlDirectUrl!.isNotEmpty) {
        rawUrl = kmlDirectUrl!;
      } else {
        rawUrl = await FirebaseService.instance
            .getDownloadUrl(kmlFilePath)
            .timeout(const Duration(seconds: 10));
      }
      final response = await http
          .get(Uri.parse(rawUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return false;
      await OfflineStorageService.instance
          .cacheContent(kmlFilePath, response.body);
      if (forceApply) _applyKmlContent(response.body);
      return true;
    } catch (e) {
      debugPrint('KML fetch error: $e');
      return false;
    }
  }

  void _applyKmlContent(String kmlBody) {
    final parsed =
        KmlService.instance.parse(kmlBody, polylineColor: AppTheme.primary);
    if (parsed.polylines.isNotEmpty) {
      kmlPolylines = parsed.polylines;
      kmlMarkers = parsed.markers;
      finishPosition = parsed.finishPosition;
      initialLocation = parsed.polylines.first.points.first;
      kmlLoaded.value = true;
      kmlLoadError.value = false;
      mapController?.animateCamera(CameraUpdate.newLatLng(initialLocation));
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

  // Route-projection lookup tables built after KML loads.
  // _routePath flattens all KML polyline points; _routeCumDist[i] is the
  // cumulative metres from the route start to _routePath[i].
  final _routePath = <LatLng>[];
  final _routeCumDist = <double>[];

  // Leaderboard rank stability: runners within this gap keep their previous
  // relative order instead of swapping on GPS noise.
  static const double _kHysteresisKm = 0.05;

  // Called from onCameraMove — only register as a user pan when WE are
  // not the ones moving the camera programmatically.
  void onUserPan() {
    if (!_programmaticCamera) isUserPanned.value = true;
  }

  void recenterCamera() {
    isUserPanned.value = false;
    final pos = currentPosition.value;
    if (pos != null) {
      _animateNavCamera(pos, _lastHeading);
    }
  }

  void _animateNavCamera(LatLng target, double bearing) {
    final cam = CameraPosition(
      target: target,
      bearing: bearing,
      tilt: 0.0,
      zoom: 18.5,
    );
    lastCameraPosition = cam;
    _programmaticCamera = true;
    try {
      mapController
          ?.animateCamera(CameraUpdate.newCameraPosition(cam))
          .then((_) => _programmaticCamera = false)
          .catchError((_) => _programmaticCamera = false);
    } catch (_) {
      _programmaticCamera = false;
    }
  }

  void saveCamera(CameraPosition pos) {
    lastCameraPosition = pos;
  }

  void _onFinishLineReached() {
    _graceTimer?.cancel();
    final grace = _graceTimeMinutes;
    if (grace <= 0) {
      stopTracking();
      return;
    }
    Get.snackbar(
      'finish_line_title'.tr,
      'finish_grace_body'.tr.replaceAll('@min', '$grace'),
      duration: const Duration(seconds: 5),
      backgroundColor: AppTheme.trackingGreen.withValues(alpha: 0.95),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(12),
      borderRadius: 14,
      icon: const Icon(Icons.flag_rounded, color: Colors.white),
    );
    _graceTimer = Timer(Duration(minutes: grace), () => stopTracking());
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
      await LiveTrackingService.instance
          .startBroadcasting(lat, lng, eventId: currentEventId);
      isLive.value = true;
    }
  }

  Future<void> startTracking() async {
    debugPrint('[TRACKING] startTracking called. isTracking=${isTracking.value}');
    if (isTracking.value) {
      debugPrint('[TRACKING] already tracking — skipped');
      return;
    }
    _countdownTimer?.cancel();
    _countdownTimer = null;
    EventNotificationService.instance.cancelCountdownAutoStart();
    trackingPoints.clear();
    snappedPoints.clear();
    _rawBuffer.clear();
    _cachedDistanceKm = 0.0;
    isUserPanned.value = false;
    _finishAlertShown = false;
    _hasLeftFinishZone = false;
    elapsedSeconds.value = 0;
    isSharing.value = true;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;
    _timer?.cancel();

    // Use a short timeout so a slow GPS fix (common when screen is off) does
    // not block the stream subscription from starting.
    debugPrint('[TRACKING] awaiting getCurrentPosition (5 s timeout)');
    final pos = await LocationService.instance.getCurrentPosition()
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    debugPrint('[TRACKING] getCurrentPosition returned: ${pos?.latitude}, ${pos?.longitude}');
    if (pos != null) {
      _animateNavCamera(LatLng(pos.latitude, pos.longitude), _lastHeading);
    }

    debugPrint('[TRACKING] starting elapsed timer + position stream');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
    });

    _positionSub =
        LocationService.instance.getPositionStream().listen((position) async {
      final latLng = LatLng(position.latitude, position.longitude);

      // Always update the map marker and camera — the user must always see
      // their own position regardless of whether we record the point.
      _lastHeading = position.heading;
      if (!isUserPanned.value) {
        _animateNavCamera(latLng, position.heading);
      }
      currentPosition.value = latLng;
      _updateSelfMarker(latLng);
      _lbTickCount++;

      // Only record the point if the runner moved at least 5 m from the last
      // recorded point. Android's distanceFilter is advisory and GPS drift can
      // still fire sub-5 m updates when the device is stationary.
      const minRecordMetres = 5.0;
      if (trackingPoints.isNotEmpty) {
        final prev = trackingPoints.last;
        final moved = Geolocator.distanceBetween(
          prev.latitude, prev.longitude,
          latLng.latitude, latLng.longitude,
        );
        if (moved < minRecordMetres) return;
        _cachedDistanceKm += moved / 1000;
      }
      trackingPoints.add(latLng);
      _rawBuffer.add(latLng);

      // Finish line detection — arm only after runner leaves the finish zone
      // (handles loop courses where start == finish)
      if (!_finishAlertShown && finishPosition != null) {
        final dist = Geolocator.distanceBetween(
          latLng.latitude,
          latLng.longitude,
          finishPosition!.latitude,
          finishPosition!.longitude,
        );
        if (!_hasLeftFinishZone) {
          if (dist > _finishArmRadiusM) _hasLeftFinishZone = true;
        } else if (dist <= _finishRadiusM) {
          _finishAlertShown = true;
          _onFinishLineReached();
        }
      }
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
    debugPrint('[TRACKING] calling startBroadcasting');
    await LiveTrackingService.instance
        .startBroadcasting(lat, lng, eventId: currentEventId)
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    debugPrint('[TRACKING] startBroadcasting done');
    isLive.value = true;

    isTracking.value = true;
    debugPrint('[TRACKING] isTracking set to true — run started');

    // Arm the cutoff timer — auto-stop tracking when the event closes.
    _cutoffTimer?.cancel();
    final cutoff = cutoffDateTime;
    if (cutoff != null) {
      final delay = cutoff.difference(DateTime.now());
      if (delay.inSeconds <= 0) {
        stopTracking();
      } else {
        _cutoffTimer = Timer(delay, () => stopTracking());
      }
    }

    // Arm category cutoff timer — auto-stop when per-category time limit expires.
    _categoryCutoffTimer?.cancel();
    final catMins = _categoryCutoffMinutes;
    if (catMins != null) {
      _categoryCutoffTimer = Timer(
        Duration(minutes: catMins),
        () => stopTracking(),
      );
    }

    // Ask the user to exempt the app from battery optimisation.
    // This is critical on Samsung/Xiaomi/OnePlus — without it the OS can
    // suspend our network connection and throttle the Dart event loop even
    // while a foreground service is running.
    if (!(await FlutterForegroundTask.isIgnoringBatteryOptimizations)) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'RunMate – Run in progress',
      notificationText: 'Your run is being tracked in the background.',
      // no callback — we only need the service to exist so Android keeps the
      // process alive; a background Dart isolate would conflict on relaunch
    );
  }

  /// Calls the Google Roads Snap-to-Roads API.
  /// Returns snapped points, or empty list on failure.
  Future<List<LatLng>> _snapToRoads(List<LatLng> points) async {
    if (points.isEmpty) return [];
    try {
      final path = points.map((p) => '${p.latitude},${p.longitude}').join('|');
      final uri = Uri.parse('https://roads.googleapis.com/v1/snapToRoads'
          '?path=$path&interpolate=true&key=${AppConfig.googleMapsApiKey}');
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
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
    _graceTimer?.cancel();
    _graceTimer = null;
    _categoryCutoffTimer?.cancel();
    _categoryCutoffTimer = null;
    isSaving.value = true;
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;
    isTracking.value = false;
    _rebuildLeaderboard();

    await LiveTrackingService.instance.stopBroadcasting()
        .timeout(const Duration(seconds: 5), onTimeout: () {});
    isLive.value = false;

    // Flush remaining raw buffer — fall back to raw points if snap fails offline
    if (_rawBuffer.isNotEmpty) {
      try {
        final snapped = await _snapToRoads(List.from(_rawBuffer));
        snappedPoints.addAll(snapped.isNotEmpty ? snapped : _rawBuffer);
      } catch (_) {
        snappedPoints.addAll(_rawBuffer);
      }
      _rawBuffer.clear();
    }

    // Use snapped points for saved route; fall back to raw if snapping produced nothing
    final routePoints = snappedPoints.isNotEmpty
        ? snappedPoints.toList()
        : trackingPoints.toList();

    final now = DateTime.now();
    final elapsed = Duration(seconds: elapsedSeconds.value);
    final startTime = now.subtract(elapsed);
    final eventLabel = routeLabel.isNotEmpty ? routeLabel : AppConfig.eventName;
    final slug = eventLabel
        .replaceAll(RegExp(r'[^\w]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final dateStr =
        '${startTime.year}-${startTime.month.toString().padLeft(2, '0')}-${startTime.day.toString().padLeft(2, '0')}';
    final timeStr2 =
        '${startTime.hour.toString().padLeft(2, '0')}-${startTime.minute.toString().padLeft(2, '0')}';
    final fileName = '${slug}_${dateStr}_$timeStr2.json';
    final totalDistance = LocationService.instance.totalDistanceKm(routePoints);
    final pace = elapsedSeconds.value > 0
        ? totalDistance / (elapsedSeconds.value / 3600)
        : 0.0;

    final data = {
      'event': eventLabel,
      'type': AppConfig.eventType,
      'run_start_ms': _runStartMs,
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

    final jsonBody = jsonEncode(data);
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Runner';
    final photoUrl = user?.photoURL ?? '';
    final runId = startTime.millisecondsSinceEpoch.toString();

    // 1. Always save locally first — data is never lost
    await OfflineStorageService.instance
        .saveRouteLocally(uid, fileName, jsonBody);

    final isOnline = OfflineStorageService.instance.isOnline.value == true;

    if (!isOnline) {
      // 2a. Offline — enqueue everything; sync triggers automatically when online
      await OfflineStorageService.instance.enqueuePendingRun(
        runId: runId,
        uid: uid,
        fileName: fileName,
        distanceKm: totalDistance,
        seconds: elapsedSeconds.value,
        eventId: currentEventId,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      Get.snackbar(
        'run_saved'.tr,
        'run_saved_offline'.tr,
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 4),
        backgroundColor: const Color(0xFF333333),
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
      );
    } else {
      // 2b. Online — upload Storage, fall back to queue on failure
      try {
        await FirebaseService.instance.saveTrackedRoute(fileName, jsonBody);
      } catch (_) {
        await OfflineStorageService.instance.enqueuePendingRun(
          runId: runId,
          uid: uid,
          fileName: fileName,
          distanceKm: totalDistance,
          seconds: elapsedSeconds.value,
          eventId: currentEventId,
          displayName: displayName,
          photoUrl: photoUrl,
        );
      }
      // 3. Stats via RTDB (Firebase persistence queues if briefly offline)
      await UserStatsService.instance.addRunStats(
        totalDistance,
        elapsedSeconds.value,
        runId: runId,
        eventId: currentEventId,
      );
    }
    isSaving.value = false;
    await FlutterForegroundTask.stopService();

    Get.find<HomeController>()
        .changeTab(2); // MyPage is index 2 (0=Events,1=Friends,2=MyPage)
    Get.offAllNamed(AppRoutes.home);
  }

  // ── Live runners ──────────────────────────────────────────────────────────

  void _subscribeToRunners(List<String> friendUids) {
    final friendSet = friendUids.toSet();
    _runnersSub?.cancel();
    _runnersSub = LiveTrackingService.instance.watchRunners().listen(
      (runners) async {
        // Only friends/group members running the same event.
        // Strangers in the same event are not shown on the map or leaderboard.
        final filtered = friendSet.isEmpty
            ? <RunnerData>[]
            : runners.where((r) {
                if (!friendSet.contains(r.uid)) return false;
                if (currentEventId.isNotEmpty && r.eventId != currentEventId) {
                  return false;
                }
                return true;
              }).toList();

        allEventRunners.value = filtered;
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
