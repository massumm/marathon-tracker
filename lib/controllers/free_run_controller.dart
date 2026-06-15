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
  final trackingPoints = <LatLng>[].obs;
  final currentPosition = const LatLng(0, 0).obs;
  final isSaving = false.obs;
  final mapReady = false.obs;
  final gpsAccuracy = (-1.0).obs;

  // ── internals ─────────────────────────────────────────────────────────────
  GoogleMapController? mapController;
  StreamSubscription<Position>? _positionSub;
  Timer? _timer;
  LatLng? _lastPoint;
  double _cachedDistanceKm = 0;
  int _runStartMs = 0;

  static const double _minMovementM = 5.0;
  static const double _jumpFilterM = 30.0;

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
      mapController?.animateCamera(CameraUpdate.newLatLngZoom(latlng, 17));
    } catch (_) {}
  }

  // ── run controls ──────────────────────────────────────────────────────────
  Future<void> startRun() async {
    final ok = await _checkPermissions();
    if (!ok) return;

    trackingPoints.clear();
    _cachedDistanceKm = 0;
    distanceKm.value = 0;
    elapsedSeconds.value = 0;
    _lastPoint = null;
    _runStartMs = DateTime.now().millisecondsSinceEpoch;

    _startTimer();
    _startPositionStream();
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
    _startPositionStream();
    runState.value = FreeRunState.running;
  }

  Future<void> stopRun() async {
    _positionSub?.cancel();
    _timer?.cancel();
    runState.value = FreeRunState.stopped;
    await FlutterForegroundTask.stopService();
    await _saveRun();
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

  void _startPositionStream() {
    _positionSub?.cancel();
    _positionSub = LocationService.instance.getPositionStream().listen((pos) {
      final point = LatLng(pos.latitude, pos.longitude);
      currentPosition.value = point;
      gpsAccuracy.value = pos.accuracy;

      if (_lastPoint != null) {
        final dist = Geolocator.distanceBetween(
          _lastPoint!.latitude, _lastPoint!.longitude,
          point.latitude, point.longitude,
        );
        if (dist < _minMovementM) return;
        if (dist > _jumpFilterM) return; // GPS jump — ignore
        _cachedDistanceKm += dist / 1000.0;
        distanceKm.value = _cachedDistanceKm;
      }

      _lastPoint = point;
      trackingPoints.add(point);
      mapController?.animateCamera(CameraUpdate.newLatLng(point));
    });
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
    if (trackingPoints.isEmpty) return;
    isSaving.value = true;
    try {
      final now = DateTime.fromMillisecondsSinceEpoch(_runStartMs);
      final dateStr =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final timeStr =
          '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'free_run_${dateStr}_$timeStr.json';

      final pace = elapsedSeconds.value > 0
          ? _cachedDistanceKm / (elapsedSeconds.value / 3600)
          : 0.0;

      final data = {
        'event': 'Free Run',
        'type': 'free_run',
        'run_start_ms': _runStartMs,
        'start_date':
            '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}',
        'start_time':
            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}',
        'time': _formatTime(elapsedSeconds.value),
        'distance': '${_cachedDistanceKm.toStringAsFixed(2)} km',
        'pace': '${pace.toStringAsFixed(1)} km/h',
        'route': trackingPoints
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
