import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../controllers/kml_map_controller.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../widgets/user_avatar.dart';

const _medals = ['🥇', '🥈', '🥉'];

class KmlMapScreen extends StatefulWidget {
  const KmlMapScreen({super.key});

  @override
  State<KmlMapScreen> createState() => _KmlMapScreenState();
}

class _KmlMapScreenState extends State<KmlMapScreen> {
  late final KmlMapController _ctrl;
  bool _leaderOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<KmlMapController>();
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (bytes.length > 3 * 1024 * 1024) {
      Get.snackbar('', 'image_too_large'.tr,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red.shade600,
          colorText: Colors.white,
          margin: const EdgeInsets.all(12));
      return;
    }
    await FirebaseService.instance.saveRunPhoto(_ctrl.runStartMs, bytes);
  }

  Future<void> _onStartTap() async {
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

    // On iOS, warn if permission is only "While Using" — background tracking won't work.
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
    if (!_ctrl.kmlLoaded.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final isTracking = _ctrl.isTracking.value;
    final isSharing = _ctrl.isSharing.value;
    final isSaving = _ctrl.isSaving.value;
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
              FloatingActionButton.small(
                heroTag: 'share',
                backgroundColor: isSharing ? AppTheme.primary : Colors.white,
                foregroundColor: isSharing ? Colors.white : AppTheme.primary,
                elevation: 3,
                tooltip: isSharing ? 'unshare'.tr : 'share'.tr,
                onPressed: () => _ctrl.toggleSharing(),
                child: Icon(isSharing
                    ? Icons.wifi_tethering
                    : Icons.wifi_tethering_off),
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
          child: _TrackingButton(
            isTracking: isTracking,
            onTap:
                isTracking ? () => _ctrl.stopTracking() : () => _onStartTap(),
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
            child: ClipRRect(
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
    ]);
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
