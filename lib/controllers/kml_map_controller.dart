import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../app/routes/app_routes.dart';
import '../core/config.dart';
import '../core/theme.dart';
import '../models/runner_data.dart';
import '../services/firebase_service.dart';
import '../services/kml_service.dart';
import '../services/live_tracking_service.dart';
import '../services/location_service.dart';
import '../widgets/runner_info_sheet.dart';
import 'home_controller.dart';

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

  // ── Live runners ──────────────────────────────────────────────────────────
  final isLive = false.obs;
  final activeRunners = <RunnerData>[].obs;
  final runnerMarkers = <String, Marker>{}.obs;
  StreamSubscription<List<RunnerData>>? _runnersSub;

  late final String kmlFilePath;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    kmlFilePath = Get.arguments as String;
    _loadKml();
    _subscribeToRunners();
  }

  @override
  void onClose() {
    _timer?.cancel();
    _positionSub?.cancel();
    _runnersSub?.cancel();
    if (isLive.value) LiveTrackingService.instance.stopBroadcasting();
    super.onClose();
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

  // ── My tracking ───────────────────────────────────────────────────────────

  Future<void> startTracking() async {
    trackingPoints.clear();
    elapsedSeconds.value = 0;
    _timer?.cancel();

    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      elapsedSeconds.value++;
    });

    _positionSub =
        LocationService.instance.getPositionStream().listen((position) {
      final latLng = LatLng(position.latitude, position.longitude);
      mapController?.animateCamera(CameraUpdate.newLatLng(latLng));
      currentPosition.value = latLng;
      trackingPoints.add(latLng);

      if (isLive.value) {
        LiveTrackingService.instance
            .updateLocation(position.latitude, position.longitude);
      }
    });

    // Auto-broadcast when tracking starts
    final lat = pos?.latitude ?? initialLocation.latitude;
    final lng = pos?.longitude ?? initialLocation.longitude;
    await LiveTrackingService.instance.startBroadcasting(lat, lng);
    isLive.value = true;

    isTracking.value = true;
  }

  Future<void> stopTracking() async {
    isSaving.value = true;
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;
    isTracking.value = false;

    await LiveTrackingService.instance.stopBroadcasting();
    isLive.value = false;

    final now = DateTime.now();
    final fileName = 'my_route_${now.millisecondsSinceEpoch}.json';
    final elapsed = Duration(seconds: elapsedSeconds.value);
    final startTime = now.subtract(elapsed);
    final totalDistance =
        LocationService.instance.totalDistanceKm(trackingPoints);
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
      'route': trackingPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };

    await FirebaseService.instance.saveTrackedRoute(fileName, jsonEncode(data));
    isSaving.value = false;

    Get.find<HomeController>().changeTab(1);
    Get.offAllNamed(AppRoutes.home);
  }

  // ── Live runners ──────────────────────────────────────────────────────────

  void _subscribeToRunners() {
    _runnersSub = LiveTrackingService.instance.watchRunners().listen(
      (runners) {
        final updated = <String, Marker>{};
        for (final r in runners) {
          final label = _runnerLabel(r);
          updated[r.uid] = Marker(
            markerId: MarkerId(r.uid),
            position: LatLng(r.lat, r.lng),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: label, snippet: r.email),
            onTap: () => showRunnerInfo(r),
          );
        }
        runnerMarkers.value = updated;
        activeRunners.value = List.of(runners);
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

  double get currentDistanceKm =>
      LocationService.instance.totalDistanceKm(trackingPoints);

  double get currentPaceKmH {
    if (elapsedSeconds.value == 0 || currentDistanceKm == 0) return 0;
    return currentDistanceKm / (elapsedSeconds.value / 3600);
  }
}
