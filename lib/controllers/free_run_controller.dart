import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../services/firebase_service.dart';
import '../services/location_service.dart';
import 'kml_map_controller.dart';
import 'my_page_controller.dart';
import '../services/offline_storage_service.dart';
import '../services/user_stats_service.dart';

enum FreeRunState { idle, running, paused, stopped }

class FreeRunController extends GetxController {
  // ── observable state ──────────────────────────────────────────────────────
  final runState = FreeRunState.idle.obs;
  final elapsedSeconds = 0.obs;
  final distanceKm = 0.0.obs;
  // Each RxList is one continuous segment (new segment created on resume).
  final segments = <RxList<LatLng>>[].obs;
  final currentPosition = const LatLng(0, 0).obs;
  final isSaving = false.obs;
  final mapReady = false.obs;
  final gpsAccuracy = (-1.0).obs;

  // ── internals ─────────────────────────────────────────────────────────────
  GoogleMapController? mapController;
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  double _cachedDistanceKm = 0;
  int _runStartMs = 0;

  static const double _maxJumpMetres = 50.0;
  static const double _minPolylineM = 2.0;
  static const double _minDistanceM = 8.0;
  static const int _smoothingWindow = 2;
  final _smoothingBuffer = <LatLng>[];
  LatLng? _lastDistancePoint;

  // ── lifecycle ─────────────────────────────────────────────────────────────
  @override
  void onClose() {
    _positionSub?.cancel();
    _timer?.cancel();
    mapController?.dispose();
    super.onClose();
  }

  void onMapCreated(GoogleMapController ctrl) {
    mapController = ctrl;
    mapReady.value = true;
    _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 8));
      final latlng = LatLng(pos.latitude, pos.longitude);
      currentPosition.value = latlng;
      _animateCamera(CameraUpdate.newLatLngZoom(latlng, 17));
    } catch (_) {}
  }

  // ── run controls ──────────────────────────────────────────────────────────
  Future<void> startRun() async {
    // Block if an event run is already in progress.
    final kml = Get.find<KmlMapController>();
    if (kml.isTracking.value) {
      Get.snackbar(
        'Event Run Active',
        'Stop your event run before starting a Daily Challenge.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.orange.shade700,
        colorText: Colors.white,
        margin: const EdgeInsets.all(12),
        borderRadius: 14,
        duration: const Duration(seconds: 3),
      );
      return;
    }
    segments.clear();
    _smoothingBuffer.clear();
    _cachedDistanceKm = 0;
    distanceKm.value = 0;
    elapsedSeconds.value = 0;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;

    _startTimer();
    _startPositionStream(newSegment: true);
    runState.value = FreeRunState.running;
    await FlutterForegroundTask.startService(
      serviceId: 257,
      notificationTitle: 'RunMate – Free Run in progress',
      notificationText: 'Your free run is being tracked in the background.',
    );
  }

  void pauseRun() {
    _positionSub?.cancel();
    _timer?.cancel();
    runState.value = FreeRunState.paused;
  }

  void resumeRun() {
    _startTimer();
    // New segment on resume so the polyline doesn't connect across the pause gap.
    _startPositionStream(newSegment: true);
    runState.value = FreeRunState.running;
  }

  Future<void> stopRun() async {
    _positionSub?.cancel();
    _timer?.cancel();
    runState.value = FreeRunState.stopped;
    await FlutterForegroundTask.stopService();
    await _saveRun();
    // Refresh the completed-runs list so this run appears on My Page
    // immediately (the screen returns via Get.back(), not a tab switch).
    if (Get.isRegistered<MyPageController>()) {
      Get.find<MyPageController>().fetchRoutes();
    }
  }

  void resetRun() {
    segments.clear();
    _smoothingBuffer.clear();
    _cachedDistanceKm = 0;
    distanceKm.value = 0;
    elapsedSeconds.value = 0;
    gpsAccuracy.value = -1;
    _runStartMs = 0;
    runState.value = FreeRunState.idle;
  }

  // ── internals ─────────────────────────────────────────────────────────────
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (runState.value == FreeRunState.running) {
        elapsedSeconds.value++;
      }
    });
  }

  void _startPositionStream({required bool newSegment}) {
    _positionSub?.cancel();
    _smoothingBuffer.clear();
    _lastDistancePoint = null; // reset so first point doesn't count phantom distance

    if (newSegment) {
      segments.add(<LatLng>[].obs); // new segment; jump filter uses this list's .last
    }

    _positionSub = LocationService.instance.getPositionStream().listen((pos) {
      final point = LatLng(pos.latitude, pos.longitude);

      // Always update map marker + GPS badge regardless of recording filters.
      currentPosition.value = point;
      gpsAccuracy.value = pos.accuracy;
      if (!isUserPanned) {
        _animateCamera(CameraUpdate.newLatLngZoom(point, 17));
      }

      final current = segments.last;

      // Smooth first, then filter — so distance is always smoothed-to-smoothed.
      _smoothingBuffer.add(point);
      if (_smoothingBuffer.length > _smoothingWindow) _smoothingBuffer.removeAt(0);
      final smoothed = LatLng(
        _smoothingBuffer.map((p) => p.latitude).reduce((a, b) => a + b) /
            _smoothingBuffer.length,
        _smoothingBuffer.map((p) => p.longitude).reduce((a, b) => a + b) /
            _smoothingBuffer.length,
      );

      // Jump + polyline density filter on smoothed point.
      if (current.isNotEmpty) {
        final prev = current.last;
        final moved = Geolocator.distanceBetween(
          prev.latitude, prev.longitude,
          smoothed.latitude, smoothed.longitude,
        );
        if (moved > _maxJumpMetres) return;
        if (moved < _minPolylineM) return;
      }

      // Distance checkpoint — only accumulate after 8 m+ of genuine movement.
      if (_lastDistancePoint == null) {
        _lastDistancePoint = smoothed;
      } else {
        final distMoved = Geolocator.distanceBetween(
          _lastDistancePoint!.latitude, _lastDistancePoint!.longitude,
          smoothed.latitude, smoothed.longitude,
        );
        if (distMoved >= _minDistanceM) {
          _cachedDistanceKm += distMoved / 1000.0;
          distanceKm.value = _cachedDistanceKm;
          _lastDistancePoint = smoothed;
        }
      }

      current.add(smoothed);
    });
  }

  bool isUserPanned = false;
  bool _programmaticCamera = false;

  void onUserPan() {
    if (!_programmaticCamera) isUserPanned = true;
  }

  void recenterCamera() {
    isUserPanned = false;
    final pos = currentPosition.value;
    if (pos.latitude != 0 || pos.longitude != 0) {
      _animateCamera(CameraUpdate.newLatLngZoom(pos, 17));
    }
  }

  void _animateCamera(CameraUpdate update) {
    _programmaticCamera = true;
    try {
      mapController
          ?.animateCamera(update)
          .then((_) => _programmaticCamera = false)
          .catchError((_) => _programmaticCamera = false);
    } catch (_) {
      _programmaticCamera = false;
    }
  }


  Future<void> _saveRun() async {
    final allPoints = segments.expand((s) => s).toList();
    if (allPoints.isEmpty) return;
    isSaving.value = true;
    try {
      final now = DateTime.fromMillisecondsSinceEpoch(_runStartMs);
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      const eventLabel = 'Daily Challenge';
      const slug = 'Free_Run';
      final fileName = '${slug}_${dateStr}_$timeStr.json';

      final paceKmh = elapsedSeconds.value > 0
          ? _cachedDistanceKm / (elapsedSeconds.value / 3600)
          : 0.0;
      final paceMinKm = paceKmh > 0 ? 60.0 / paceKmh : 0.0;
      final paceMins = paceMinKm.floor();
      final paceSecs = ((paceMinKm - paceMins) * 60).round();
      final paceStr = paceKmh > 0
          ? '$paceMins:${paceSecs.toString().padLeft(2, '0')}/km'
          : '—';

      final data = {
        'event': eventLabel,
        'type': 'daily challange',
        'run_start_ms': _runStartMs,
        'start_date':
            '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}',
        'start_time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'time': _formatTime(elapsedSeconds.value),
        'distance': '${_cachedDistanceKm.toStringAsFixed(2)} km',
        'pace': paceStr,
        'route': allPoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      };

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final runId = _runStartMs.toString();
      final jsonBody = jsonEncode(data);

      await OfflineStorageService.instance.saveRouteLocally(uid, fileName, jsonBody);

      final user = FirebaseAuth.instance.currentUser;
      final displayName =
          user?.displayName ?? user?.email?.split('@').first ?? 'Runner';
      final photoUrl = user?.photoURL ?? '';

      final isOnline = OfflineStorageService.instance.isOnline.value == true;
      if (!isOnline) {
        // Enqueue so the sync job uploads to Firebase when connectivity returns.
        await OfflineStorageService.instance.enqueuePendingRun(
          runId: runId,
          uid: uid,
          fileName: fileName,
          distanceKm: _cachedDistanceKm,
          seconds: elapsedSeconds.value,
          eventId: '',
          displayName: displayName,
          photoUrl: photoUrl,
          categoryId: '',
        );
      } else {
        try {
          await FirebaseService.instance.saveTrackedRoute(fileName, jsonBody);
          if (Get.isRegistered<MyPageController>()) {
            Get.find<MyPageController>().addRouteOptimistically(fileName, uid);
          }
        } catch (_) {
          // Upload failed — enqueue so it retries when online again.
          await OfflineStorageService.instance.enqueuePendingRun(
            runId: runId,
            uid: uid,
            fileName: fileName,
            distanceKm: _cachedDistanceKm,
            seconds: elapsedSeconds.value,
            eventId: '',
            displayName: displayName,
            photoUrl: photoUrl,
            categoryId: '',
          );
        }
        await UserStatsService.instance.addRunStats(
          _cachedDistanceKm,
          elapsedSeconds.value,
          runId: runId,
          eventId: '',
        );
        final dayKey =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
        await UserStatsService.instance.addDailyChallengeStats(
          _cachedDistanceKm,
          elapsedSeconds.value,
          dayKey: dayKey,
        );
      }
    } catch (e) {
      debugPrint('[FREE_RUN] save error: $e');
    } finally {
      isSaving.value = false;
    }
  }

  String _formatTime(int seconds) {
    final d = Duration(seconds: seconds);
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      final h = d.inHours.toString().padLeft(2, '0');
      return '$h:$m:$s';
    }
    return '$m:$s';
  }

  String get formattedTime => _formatTime(elapsedSeconds.value);

  double get paceKmH {
    if (elapsedSeconds.value == 0 || _cachedDistanceKm == 0) return 0;
    return _cachedDistanceKm / (elapsedSeconds.value / 3600);
  }

  // Returns pace as "m:ss/km" — the standard running format.
  String get formattedPace {
    final kmh = paceKmH;
    if (kmh <= 0) return '—';
    final minPerKm = 60.0 / kmh;
    final mins = minPerKm.floor();
    final secs = ((minPerKm - mins) * 60).round();
    return '$mins:${secs.toString().padLeft(2, '0')}/km';
  }
}
