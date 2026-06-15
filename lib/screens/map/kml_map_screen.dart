import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/kml_map_controller.dart';
import '../../core/image_utils.dart';
import '../../core/theme.dart';
import '../../services/firebase_service.dart';
import '../../widgets/user_avatar.dart';

const _medals = ['🥇', '🥈', '🥉'];

class KmlMapScreen extends StatefulWidget {
  const KmlMapScreen({super.key});

  @override
  State<KmlMapScreen> createState() => _KmlMapScreenState();
}

class _KmlMapScreenState extends State<KmlMapScreen>
    with WidgetsBindingObserver {
  late final KmlMapController _ctrl;
  bool _leaderOpen = false;
  bool _countdownActive = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<KmlMapController>();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ctrl.mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[LIFECYCLE] state=$state countdownActive=$_countdownActive isTracking=${_ctrl.isTracking.value}');
    if (state != AppLifecycleState.resumed) return;

    // If tracking is already running (started in background), dismiss the
    // overlay and snap the camera to the current position immediately so the
    // accumulated background route is visible right away.
    if (_ctrl.isTracking.value) {
      if (_countdownActive) setState(() => _countdownActive = false);
      final pos = _ctrl.currentPosition.value;
      if (pos != null && !_ctrl.isUserPanned.value) {
        _ctrl.mapController?.animateCamera(CameraUpdate.newLatLng(pos));
      }
      return;
    }

    if (!_countdownActive) return;
    final eventStart = _ctrl.eventStartTime;
    final now = DateTime.now();
    debugPrint('[LIFECYCLE] eventStart=$eventStart now=$now timePassed=${eventStart != null && !now.isBefore(eventStart)}');
    if (eventStart != null && !now.isBefore(eventStart)) {
      debugPrint('[LIFECYCLE] time passed — calling startTracking from resume');
      setState(() => _countdownActive = false);
      _ctrl.startTracking();
    }
  }

  Future<void> _takePhoto() async {
    if (!mounted) return;

    // Show a bottom sheet first so the user has a clear back/cancel option
    // before entering the native camera viewfinder.
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Icon(Icons.camera_alt_rounded, size: 40, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text('take_selfie'.tr,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('selfie_hint'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(sheetCtx, true),
                icon: const Icon(Icons.camera_alt),
                label: Text('open_camera'.tr),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(sheetCtx, false),
                child: Text('cancel'.tr,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final photo = await ImagePicker().pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 85,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    final compressed = await compressImageUnder1MB(bytes);
    if (compressed == null) {
      Get.snackbar('', 'image_too_large'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12));
      return;
    }
    await FirebaseService.instance.saveRunPhoto(_ctrl.runStartMs, compressed);
  }

  Future<void> _onStartTap() async {
    final eventStart = _ctrl.eventStartTime;
    if (eventStart != null && DateTime.now().isBefore(eventStart)) {
      final minsLeft = eventStart.difference(DateTime.now()).inMinutes;
      if (minsLeft > 5) {
        if (!mounted) return;
        final h = eventStart.hour.toString().padLeft(2, '0');
        final m = eventStart.minute.toString().padLeft(2, '0');
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule_rounded,
                      color: AppTheme.primary, size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Not Yet!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Event starts at $h:$m',
                  style: const TextStyle(
                      fontSize: 15, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Got it',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
      // Within 5 minutes — show countdown overlay.
      final ready = await _checkLocationReady();
      if (!ready || !mounted) return;
      setState(() => _countdownActive = true);
      await _ctrl.beginCountdown(eventStart);
      return;
    }
    // Category cutoff gate: event is over, no new starters allowed
    final cutoffDeadline = _ctrl.categoryCutoffDeadline;
    if (cutoffDeadline != null && DateTime.now().isAfter(cutoffDeadline)) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.flag_rounded,
                    color: Colors.grey, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Event Ended',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'The cut-off time for this category has passed.\nRegistration is now closed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }

    // Chip time gate: reject start if past the chip window
    final deadline = _ctrl.chipDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(28, 28, 28, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_off_rounded,
                    color: Colors.red, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                'start_window_closed_title'.tr,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'start_window_closed_body'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      );
      return;
    }
    await _doLocationChecksAndStart();
  }

  /// Returns true when GPS is on and permission is granted.
  /// Shows the appropriate dialog on failure.
  Future<bool> _checkLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) _showLocationOffDialog();
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionDeniedDialog(
            forever: permission == LocationPermission.deniedForever);
      }
      return false;
    }
    if (Platform.isIOS && permission != LocationPermission.always) {
      if (!mounted) return false;
      final proceed = await _showIosAlwaysLocationDialog();
      if (!proceed) return false;
    }
    return true;
  }

  Future<void> _doLocationChecksAndStart() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      _showLocationOffDialog();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      _showPermissionDeniedDialog(
          forever: permission == LocationPermission.deniedForever);
      return;
    }

    if (Platform.isIOS && permission != LocationPermission.always) {
      if (!mounted) return;
      final proceed = await _showIosAlwaysLocationDialog();
      if (!proceed) return;
    }

    final distKm = await _ctrl.distanceToStartKm();
    if (!mounted) return;
    if (distKm >= 0 && distKm > KmlMapController.proximityThresholdKm) {
      _showTooFarDialog(distKm);
    } else {
      _ctrl.startTracking();
    }
  }

  void _showLocationOffDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.location_disabled,
            color: Colors.redAccent, size: 40),
        title: Text('location_off_title'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('location_off_body'.tr,
            textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: Text('open_settings'.tr),
          ),
        ],
      ),
    );
  }

  void _showPermissionDeniedDialog({required bool forever}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.location_off_outlined,
            color: Colors.orange, size: 40),
        title: Text('location_permission_title'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            forever
                ? 'location_permission_forever'.tr
                : 'location_permission_denied'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr)),
          if (forever)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Geolocator.openAppSettings();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white),
              child: Text('open_settings'.tr),
            ),
        ],
      ),
    );
  }

  Future<bool> _showIosAlwaysLocationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.location_on, color: AppTheme.primary, size: 40),
        title: Text('ios_bg_title'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text('ios_bg_body'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, height: 1.5)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, false);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            child: Text('open_settings'.tr),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('continue_anyway'.tr,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showTooFarDialog(double distKm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.location_off_outlined,
            color: Colors.orange, size: 40),
        title: Text('too_far_title'.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            'too_far_body'.tr.replaceAll('@dist', distKm.toStringAsFixed(2)),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('cancel'.tr)),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _ctrl.startTracking();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: Text('start_anyway'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final lb = _ctrl.leaderboard.toList();
      final myRank = lb.where((e) => e.isSelf).firstOrNull?.rank;

      return PopScope(
        canPop: !_ctrl.isSaving.value,
        child: Scaffold(
          body: _buildBody(context, lb, myRank),
        ),
      );
    });
  }

  Widget _buildBody(
      BuildContext context, List<LeaderboardEntry> lb, int? myRank) {
    if (_ctrl.kmlLoadError.value) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'No internet connection',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'The route map could not be loaded.\nConnect to the internet and try again.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  _ctrl.kmlLoadError.value = false;
                  _ctrl.kmlLoaded.value = false;
                  _ctrl.prepareRoute(Get.arguments);
                },
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_ctrl.kmlLoaded.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final isTracking = _ctrl.isTracking.value;
    final isSaving = _ctrl.isSaving.value;
    final gpsAccuracy = _ctrl.gpsAccuracy.value;
    final elapsedSecs = _ctrl.elapsedSeconds.value;
    final snapped = _ctrl.snappedPoints.toList();
    final raw = _ctrl.trackingPoints.toList();
    // During tracking use raw GPS for live continuous feedback — snappedPoints
    // updates in batches of 10 which causes visible gaps. After the run ends
    // prefer the cleaner road-snapped version if available.
    final points = isTracking ? raw : (snapped.isNotEmpty ? snapped : raw);
    final runnerMarkersSet = _ctrl.runnerMarkers.values.toSet();
    final topPad = MediaQuery.of(context).padding.top;
    final lbShift = lb.isNotEmpty && _leaderOpen;

    return Stack(children: [
      // ── Map ───────────────────────────────────────────────────────────────
      GoogleMap(
        initialCameraPosition: _ctrl.lastCameraPosition ??
            CameraPosition(target: _ctrl.initialLocation, zoom: 17),
        myLocationEnabled: false,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        onMapCreated: (c) {
          _ctrl.mapController = c;
          final saved = _ctrl.lastCameraPosition;
          if (saved != null) {
            c.animateCamera(CameraUpdate.newCameraPosition(saved));
          } else {
            c.animateCamera(CameraUpdate.newLatLng(_ctrl.initialLocation));
          }
        },
        onCameraMove: (pos) {
          _ctrl.saveCamera(pos);
          if (isTracking) _ctrl.onUserPan();
        },
        polylines: {
          ..._ctrl.kmlPolylines,
          if (isTracking && points.length >= 2)
            Polyline(
              polylineId: const PolylineId('tracking'),
              points: points,
              color: AppTheme.trackingGreen,
              width: 5,
            ),
        },
        markers: {
          ..._ctrl.kmlMarkers,
          ...runnerMarkersSet,
          if (_ctrl.selfMarker.value != null) _ctrl.selfMarker.value!,
        },
      ),

      // ── Back button ───────────────────────────────────────────────────────
      Positioned(
        top: topPad + 8,
        left: 12,
        child: FloatingActionButton.small(
          heroTag: 'back',
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.textSecondary,
          elevation: 3,
          onPressed: () => Get.back(),
          child: const Icon(Icons.arrow_back, size: 20),
        ),
      ),

      // ── Stats panel (tracking active) ─────────────────────────────────────
      if (isTracking)
        Positioned(
          top: topPad + 8,
          left: 62,
          right: 12,
          child: _StatsPanel(
            time: _ctrl.formatTime(elapsedSecs),
            distance: _ctrl.currentDistanceKm,
            pace: _ctrl.currentPaceKmH,
          ),
        ),

      // ── GPS signal indicator (pre-run only — moves to bottom-left during tracking) ──
      if (!isTracking)
        Positioned(
          top: topPad + 8,
          right: 12,
          child: _GpsSignalBadge(accuracy: gpsAccuracy),
        ),

      // ── Camera + recenter buttons (visible during tracking) ──────────────
      if (isTracking)
        Positioned(
          bottom: lbShift ? 204 : 52,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'recenter',
                backgroundColor:
                    _ctrl.isUserPanned.value ? Colors.white : AppTheme.primary,
                foregroundColor:
                    _ctrl.isUserPanned.value ? AppTheme.primary : Colors.white,
                onPressed: _ctrl.recenterCamera,
                child: Icon(_ctrl.isUserPanned.value
                    ? Icons.my_location
                    : Icons.navigation),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'camera',
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                onPressed: () => _takePhoto(),
                child: const Icon(Icons.camera_alt),
              ),
            ],
          ),
        ),

      // ── Bottom-left: leaderboard + share FABs ─────────────────────────────
      Positioned(
        bottom: lbShift ? 208 : 40,
        left: 16,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isTracking) ...[
              SizedBox(
                width: 40,
                height: 40,
                child: Center(child: _GpsSignalBadge(accuracy: gpsAccuracy)),
              ),
              const SizedBox(height: 8),
            ],
            if (lb.isNotEmpty)
              Stack(
                clipBehavior: Clip.none,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'leaderboard',
                    backgroundColor:
                        _leaderOpen ? Colors.amberAccent : Colors.white,
                    foregroundColor:
                        _leaderOpen ? Colors.black87 : AppTheme.primary,
                    elevation: 3,
                    onPressed: () => setState(() => _leaderOpen = !_leaderOpen),
                    child: Icon(_leaderOpen
                        ? Icons.leaderboard
                        : Icons.leaderboard_outlined),
                  ),
                  if (myRank != null && !_leaderOpen)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#$myRank',
                          style: const TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.black),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),

      // ── Start / Stop button ───────────────────────────────────────────────
      Positioned(
        bottom: lbShift ? 200 : 36,
        left: 0,
        right: 0,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isTracking) _EventStartLabel(eventStart: _ctrl.eventStartTime),
              if (!isTracking) const SizedBox(height: 10),
              _TrackingButton(
                isTracking: isTracking,
                onTap:
                    isTracking ? () => _ctrl.stopTracking() : () => _onStartTap(),
              ),
            ],
          ),
        ),
      ),

      // ── Live leaderboard panel ────────────────────────────────────────────
      if (lb.isNotEmpty)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            height: _leaderOpen ? (60 + lb.length * 56.0).clamp(120, 340) : 0,
            child: ClipRect(
              child: OverflowBox(
                maxHeight: double.infinity,
                alignment: Alignment.topCenter,
                child: _LiveLeaderboard(
                entries: lb,
                onClose: () => setState(() => _leaderOpen = false),
                onTapRunner: (e) {
                  final r = _ctrl.activeRunners
                      .where((r) => r.uid == e.uid)
                      .firstOrNull;
                  if (r != null) {
                    _ctrl.flyToRunner(r);
                  }
                },
              ),
            ),
          ),
        ),
      ),

      // ── Saving overlay ────────────────────────────────────────────────────
      if (isSaving)
        Container(
          color: Colors.black45,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 14),
                Text('saving'.tr,
                    style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),

      // ── Pre-event countdown overlay ───────────────────────────────────────
      if (_countdownActive &&
          !_ctrl.isTracking.value &&
          _ctrl.eventStartTime != null)
        Positioned.fill(
          child: _CountdownOverlay(
            eventStart: _ctrl.eventStartTime!,
            routeLabel: _ctrl.routeLabel,
            onCancel: () {
              _ctrl.cancelCountdown();
              setState(() => _countdownActive = false);
            },
            onExpire: () async {
              debugPrint('[OVERLAY] onExpire fired — calling startTracking');
              setState(() => _countdownActive = false);
              await _ctrl.startTracking();
            },
          ),
        ),
    ]);
  }
}

// ── Event start time label ────────────────────────────────────────────────────

class _EventStartLabel extends StatelessWidget {
  final DateTime? eventStart;
  const _EventStartLabel({this.eventStart});

  @override
  Widget build(BuildContext context) {
    final dt = eventStart;
    if (dt == null || dt.year == 0) return const SizedBox.shrink();

    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final isFuture = dt.isAfter(now);
    if (!isFuture) return const SizedBox.shrink();

    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final timeStr = '$hh:$mm';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateStr = '${dt.day} ${months[dt.month - 1]}';

    final label = isToday
        ? 'starts_today_at'.tr.replaceAll('@time', timeStr)
        : 'starts_on'.tr.replaceAll('@date', dateStr).replaceAll('@time', timeStr);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.schedule_rounded, size: 14, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Start / Stop tracking button ─────────────────────────────────────────────

class _TrackingButton extends StatefulWidget {
  final bool isTracking;
  final VoidCallback onTap;
  const _TrackingButton({required this.isTracking, required this.onTap});

  @override
  State<_TrackingButton> createState() => _TrackingButtonState();
}

class _TrackingButtonState extends State<_TrackingButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isStart = !widget.isTracking;
    final gradientA =
        isStart ? const Color(0xFF48BB78) : const Color(0xFFE53E3E);
    final gradientB =
        isStart ? const Color(0xFF276749) : const Color(0xFF9B1C1C);
    final icon = isStart ? Icons.play_arrow_rounded : Icons.stop_rounded;
    final label = isStart ? 'start_run'.tr : 'stop_run'.tr;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [gradientA, gradientB],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: Colors.white, width: 3.5),
                boxShadow: [
                  BoxShadow(
                    color: gradientA.withValues(alpha: 0.55),
                    blurRadius: 28,
                    spreadRadius: 3,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final String time;
  final double distance;
  final double pace;

  const _StatsPanel(
      {required this.time, required this.distance, required this.pace});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _col(Icons.timer, time, 'time_label'.tr),
              _divider(),
              _col(Icons.straighten, '${distance.toStringAsFixed(2)} km',
                  'distance_label'.tr),
              _divider(),
              _col(Icons.speed, '${pace.toStringAsFixed(1)} km/h',
                  'pace_label'.tr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _col(IconData icon, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 17),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white60)),
        ],
      );

  Widget _divider() => Container(
      height: 32, width: 1, color: Colors.white.withValues(alpha: 0.25));
}

// ── Live leaderboard panel ────────────────────────────────────────────────────

class _LiveLeaderboard extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final VoidCallback onClose;
  final void Function(LeaderboardEntry) onTapRunner;

  const _LiveLeaderboard({
    required this.entries,
    required this.onClose,
    required this.onTapRunner,
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.78),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Row(
                children: [
                  const Text('🏆', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    'live_leaderboard'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.white70),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    iconSize: 22,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.white12),
            Flexible(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 4),
                shrinkWrap: true,
                itemCount: entries.length,
                itemBuilder: (_, i) => _LeaderRow(
                  entry: entries[i],
                  onTap:
                      entries[i].isSelf ? null : () => onTapRunner(entries[i]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pre-event countdown overlay ───────────────────────────────────────────────

class _CountdownOverlay extends StatefulWidget {
  final DateTime eventStart;
  final String routeLabel;
  final VoidCallback onCancel;
  final Future<void> Function() onExpire;

  const _CountdownOverlay({
    required this.eventStart,
    required this.routeLabel,
    required this.onCancel,
    required this.onExpire,
  });

  @override
  State<_CountdownOverlay> createState() => _CountdownOverlayState();
}

class _CountdownOverlayState extends State<_CountdownOverlay>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;
  late Duration _remaining;
  bool _expired = false;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.10)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    final rem = widget.eventStart.difference(DateTime.now());
    debugPrint('[OVERLAY] initState: remaining=${rem.inSeconds}s eventStart=${widget.eventStart}');
    if (rem.inSeconds <= 0) {
      debugPrint('[OVERLAY] already expired on init — firing onExpire via postFrameCallback');
      _remaining = Duration.zero;
      _expired = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onExpire();
      });
      return;
    }

    _remaining = rem;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = widget.eventStart.difference(DateTime.now());
      if (!mounted) {
        debugPrint('[OVERLAY] ticker fired but widget unmounted');
        return;
      }
      if (r.inSeconds <= 0) {
        debugPrint('[OVERLAY] ticker reached zero — firing onExpire');
        _ticker?.cancel();
        setState(() {
          _remaining = Duration.zero;
          _expired = true;
        });
        widget.onExpire();
      } else {
        setState(() => _remaining = r);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final h = _remaining.inHours;
    final m = _remaining.inMinutes.remainder(60);
    final s = _remaining.inSeconds.remainder(60);
    final showHours = _remaining.inHours > 0;
    final timeStr = showHours
        ? '${_pad(h)}:${_pad(m)}:${_pad(s)}'
        : '${_pad(m)}:${_pad(s)}';

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.80),
              Colors.black.withValues(alpha: 0.92),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              Text(
                'event_starts_in'.tr,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.routeLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 52),
              ScaleTransition(
                scale: _pulseAnim,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring
                    Container(
                      width: 230,
                      height: 230,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primary.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.55),
                          width: 2.5,
                        ),
                      ),
                    ),
                    // Inner ring
                    Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Countdown digits
                    if (_expired)
                      Text(
                        'auto_starting'.tr,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      )
                    else
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: showHours ? 48 : 62,
                          fontWeight: FontWeight.w800,
                          letterSpacing: showHours ? 3 : 5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.18),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.6),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'keep_app_alive'.tr,
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              TextButton(
                onPressed: widget.onCancel,
                child: Text(
                  'cancel'.tr,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LeaderRow extends StatelessWidget {
  final LeaderboardEntry entry;
  final VoidCallback? onTap;
  const _LeaderRow({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelf = entry.isSelf;
    final medal = entry.rank <= 3 ? _medals[entry.rank - 1] : null;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color:
            isSelf ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
        child: Row(
          children: [
            SizedBox(
              width: 32,
              child: medal != null
                  ? Text(medal,
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center)
                  : Text(
                      '${entry.rank}',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white60),
                      textAlign: TextAlign.center,
                    ),
            ),
            const SizedBox(width: 8),
            UserAvatar(
              label: entry.name,
              photoUrl: entry.photoUrl,
              size: 32,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSelf ? '${'you_label'.tr} (${entry.name})' : entry.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelf ? FontWeight.w700 : FontWeight.w500,
                  color: isSelf ? Colors.amberAccent : Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${entry.distanceKm.toStringAsFixed(2)} km',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelf ? Colors.amberAccent : Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── GPS Signal Badge ──────────────────────────────────────────────────────────

class _GpsSignalBadge extends StatelessWidget {
  final double accuracy; // metres; -1 = no fix

  const _GpsSignalBadge({required this.accuracy});

  int get _bars {
    if (accuracy < 0) return 0;
    if (accuracy <= 5) return 4;
    if (accuracy <= 8) return 3;
    if (accuracy <= 12) return 2;
    return 1;
  }

  Color get _color {
    if (accuracy < 0) return Colors.grey;
    if (accuracy <= 5) return const Color(0xFF22C55E);
    if (accuracy <= 8) return const Color(0xFF84CC16);
    if (accuracy <= 12) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final bars = _bars;
    final color = _color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final height = 6.0 + i * 3.0;
              return Container(
                width: 4,
                height: height,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: i < bars ? color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
