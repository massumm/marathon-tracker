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
  static const double _minMovementM = 2.0;
  static const int _smoothingWindow = 2;
  final _smoothingBuffer = <LatLng>[];

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
    final ok = await _checkPermissions();
    if (!ok) return;

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
    _smoothingBuffer.clear(); // always fresh baseline on (re)start

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

      // GPS jump filter — against last accepted point in the current segment.
      if (current.isNotEmpty) {
        final prev = current.last;
        final moved = Geolocator.distanceBetween(
          prev.latitude, prev.longitude,
          point.latitude, point.longitude,
        );
        if (moved > _maxJumpMetres) return; // impossible jump — discard
        if (moved < _minMovementM) return;  // standing still — skip
        _cachedDistanceKm += moved / 1000.0;
        distanceKm.value = _cachedDistanceKm;
      }

      // Moving-average smoothing over last N raw points (reduces zig-zag).
      _smoothingBuffer.add(point);
      if (_smoothingBuffer.length > _smoothingWindow) _smoothingBuffer.removeAt(0);
      final smoothed = LatLng(
        _smoothingBuffer.map((p) => p.latitude).reduce((a, b) => a + b) /
            _smoothingBuffer.length,
        _smoothingBuffer.map((p) => p.longitude).reduce((a, b) => a + b) /
            _smoothingBuffer.length,
      );

      // Add directly to the RxList — triggers reactive update without copying.
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

  Future<bool> _checkPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      Get.snackbar('Location Off', 'Please enable GPS to start a free run.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever ||
        perm == LocationPermission.denied) {
      Get.snackbar('Permission Denied', 'Location permission is required.',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    return true;
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
      const eventLabel = 'Free Run';
      const slug = 'Free_Run';
      final fileName = '${slug}_${dateStr}_$timeStr.json';

      final pace = elapsedSeconds.value > 0
          ? _cachedDistanceKm / (elapsedSeconds.value / 3600)
          : 0.0;

      final data = {
        'event': eventLabel,
        'type': 'free_run',
        'run_start_ms': _runStartMs,
        'start_date':
            '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}',
        'start_time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'time': _formatTime(elapsedSeconds.value),
        'distance': '${_cachedDistanceKm.toStringAsFixed(2)} km',
        'pace': '${pace.toStringAsFixed(1)} km/h',
        'route': allPoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      };

      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final runId = _runStartMs.toString();
      final jsonBody = jsonEncode(data);

      await OfflineStorageService.instance.saveRouteLocally(uid, fileName, jsonBody);

      final isOnline = OfflineStorageService.instance.isOnline.value == true;
      if (isOnline) {
        try {
          await FirebaseService.instance.saveTrackedRoute(fileName, jsonBody);
        } catch (_) {}
        await UserStatsService.instance.addRunStats(
          _cachedDistanceKm,
          elapsedSeconds.value,
          runId: runId,
          eventId: '',
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
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String get formattedTime => _formatTime(elapsedSeconds.value);

  double get paceKmH {
    if (elapsedSeconds.value == 0 || _cachedDistanceKm == 0) return 0;
    return _cachedDistanceKm / (elapsedSeconds.value / 3600);
  }
}
