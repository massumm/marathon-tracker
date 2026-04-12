import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/kml_map_controller.dart';
import '../core/theme.dart';
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
      final title =
          _ctrl.routeLabel.isNotEmpty ? _ctrl.routeLabel : 'map_view_title'.tr;

      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (lb.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: Icon(
                        _leaderOpen
                            ? Icons.leaderboard
                            : Icons.leaderboard_outlined,
                        color: _leaderOpen
                            ? Colors.amberAccent
                            : Colors.white,
                      ),
                      onPressed: () =>
                          setState(() => _leaderOpen = !_leaderOpen),
                    ),
                    if (myRank != null && !_leaderOpen)
                      Positioned(
                        top: 8,
                        right: 6,
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
              ),
          ],
        ),
        body: _buildBody(lb),
      );
    });
  }

  Widget _buildBody(List<LeaderboardEntry> lb) {
    if (!_ctrl.kmlLoaded.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final isTracking = _ctrl.isTracking.value;
    final isSaving = _ctrl.isSaving.value;
    final elapsedSecs = _ctrl.elapsedSeconds.value;
    final snapped = _ctrl.snappedPoints.toList();
    final raw = _ctrl.trackingPoints.toList();
    final points = snapped.isNotEmpty ? snapped : raw;
    final runnerMarkersSet = _ctrl.runnerMarkers.values.toSet();

    return Stack(children: [
      // ── Map ───────────────────────────────────────────────────────────────
      GoogleMap(
        initialCameraPosition:
            CameraPosition(target: _ctrl.initialLocation, zoom: 17),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (c) {
          _ctrl.mapController = c;
          c.animateCamera(CameraUpdate.newLatLng(_ctrl.initialLocation));
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
        },
      ),

      // ── Stats panel (tracking active) ─────────────────────────────────────
      if (isTracking)
        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child: _StatsPanel(
            time: _ctrl.formatTime(elapsedSecs),
            distance: _ctrl.currentDistanceKm,
            pace: _ctrl.currentPaceKmH,
          ),
        )
      else
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(
            child: _GlassChip(
              child: Text(
                _ctrl.formatTime(elapsedSecs),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),

      // ── Start / Stop button ───────────────────────────────────────────────
      Positioned(
        bottom: lb.isNotEmpty && _leaderOpen ? 200 : 48,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: isTracking
                ? () => _ctrl.stopTracking()
                : () => _onStartTap(),
            child: Image.asset(
              isTracking
                  ? 'assets/images/stop.png'
                  : 'assets/images/start.png',
              height: 80,
              width: 80,
            ),
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
            height: _leaderOpen
                ? (60 + lb.length * 56.0).clamp(120, 340)
                : 0,
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
                    style:
                        const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),
    ]);
  }
}

// ── Frosted glass chip ────────────────────────────────────────────────────────

class _GlassChip extends StatelessWidget {
  final Widget child;
  const _GlassChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(20),
          ),
          child: child,
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
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
                  onTap: entries[i].isSelf
                      ? null
                      : () => onTapRunner(entries[i]),
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
        color: isSelf
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.transparent,
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
                  fontWeight:
                      isSelf ? FontWeight.w700 : FontWeight.w500,
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
