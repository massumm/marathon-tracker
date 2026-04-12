import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/kml_map_controller.dart';
import '../core/theme.dart';
import '../models/runner_data.dart';
import '../widgets/user_avatar.dart';

class KmlMapScreen extends StatefulWidget {
  const KmlMapScreen({super.key});

  @override
  State<KmlMapScreen> createState() => _KmlMapScreenState();
}

class _KmlMapScreenState extends State<KmlMapScreen> {
  late final KmlMapController _ctrl;
  bool _panelOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.find<KmlMapController>();
  }

  void _togglePanel() => setState(() => _panelOpen = !_panelOpen);
  void _closePanel() => setState(() => _panelOpen = false);

  void _handleRunnerTap(RunnerData r) {
    _closePanel();
    _ctrl.flyToRunner(r);
    _ctrl.showRunnerInfo(r);
  }

  Future<void> _onStartTap() async {
    final distKm = await _ctrl.distanceToStartKm();
    // -1 means location unavailable — allow start
    if (distKm >= 0 && distKm > KmlMapController.proximityThresholdKm) {
      if (!mounted) return;
      _showTooFarDialog(distKm);
    } else {
      _ctrl.startTracking();
    }
  }

  void _showTooFarDialog(double distKm) {
    final distStr = distKm.toStringAsFixed(2);
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
          'too_far_body'.tr.replaceAll('@dist', distStr),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _ctrl.startTracking();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: Text('start_anyway'.tr),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final runners = _ctrl.activeRunners.toList();

      // AppBar title: category label if available, else localised fallback
      final title =
          _ctrl.routeLabel.isNotEmpty ? _ctrl.routeLabel : 'map_view_title'.tr;

      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _panelOpen ? Icons.close : Icons.people_alt_outlined,
                    ),
                    color: Colors.white,
                    onPressed: _togglePanel,
                  ),
                  if (runners.isNotEmpty && !_panelOpen)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                            color: Colors.green, shape: BoxShape.circle),
                        child: Center(
                          child: Text(
                            '${runners.length}',
                            style: const TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        body: _buildBody(runners),
      );
    });
  }

  Widget _buildBody(List<RunnerData> runners) {
    if (!_ctrl.kmlLoaded.value) {
      return const Center(child: CircularProgressIndicator());
    }

    final isTracking = _ctrl.isTracking.value;
    final isSaving = _ctrl.isSaving.value;
    final elapsedSecs = _ctrl.elapsedSeconds.value;
    // Prefer road-snapped points; fall back to raw GPS while snapping is pending
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
        // ── Timer chip (before tracking starts) ───────────────────────────
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
        bottom: 48,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap: isTracking ? _ctrl.stopTracking : _onStartTap,
            child: Image.asset(
              isTracking ? 'assets/images/stop.png' : 'assets/images/start.png',
              height: 80,
              width: 80,
            ),
          ),
        ),
      ),

      // ── Transparent dismiss layer ─────────────────────────────────────────
      if (_panelOpen)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePanel,
          ),
        ),

      // ── Sliding runner panel ──────────────────────────────────────────────
      Positioned(
        top: 0,
        right: 0,
        bottom: 0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          width: _panelOpen ? 240 : 0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            boxShadow: _panelOpen
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(-4, 0),
                    ),
                  ]
                : [],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              bottomLeft: Radius.circular(16),
            ),
            child: SingleChildScrollView(
              child: _RunnerPanelContent(
                runners: runners,
                onTap: _handleRunnerTap,
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

// ── Panel content ─────────────────────────────────────────────────────────────

class _RunnerPanelContent extends StatelessWidget {
  final List<RunnerData> runners;
  final void Function(RunnerData) onTap;
  const _RunnerPanelContent({required this.runners, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 6),
          child: Text(
            runners.isEmpty
                ? 'no_runners_live'.tr
                : '${runners.length} ${'runners_live'.tr}',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const Divider(height: 1),
        if (runners.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'no_runners_running'.tr,
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          )
        else
          ...runners.map((r) => _RunnerTile(runner: r, onTap: () => onTap(r))),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RunnerTile extends StatelessWidget {
  final RunnerData runner;
  final VoidCallback onTap;
  const _RunnerTile({required this.runner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = runner.displayName.isNotEmpty
        ? runner.displayName
        : runner.email.isNotEmpty
            ? runner.email.split('@').first
            : 'runner'.tr;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            UserAvatar(
              label: label,
              photoUrl: runner.photoUrl,
              size: 34,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    runner.email,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.my_location, size: 15, color: Colors.green),
          ],
        ),
      ),
    );
  }
}

// ── Stats panel (transparent glass card) ─────────────────────────────────────

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
