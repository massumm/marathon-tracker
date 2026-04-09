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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final runners = _ctrl.activeRunners.toList();

      return Scaffold(
        appBar: AppBar(
          title: const Text('マップビュー'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _panelOpen
                          ? Icons.close
                          : Icons.people_alt_outlined,
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
    final points = _ctrl.trackingPoints.toList();
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
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
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
            onTap: isTracking ? _ctrl.stopTracking : _ctrl.startTracking,
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

      // ── Transparent dismiss layer (closes panel on outside tap) ───────────
      if (_panelOpen)
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closePanel,
          ),
        ),

      // ── Sliding runner panel (from right) — always on top ─────────────────
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
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 14),
                Text('保存中...',
                    style: TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),
    ]);
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
                ? 'No runners live'
                : '${runners.length} Runner${runners.length > 1 ? 's' : ''} Live',
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
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'No one is running yet.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
          )
        else
          ...runners
              .map((r) => _RunnerTile(runner: r, onTap: () => onTap(r))),
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
            : 'Runner';

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

// ── Stats panel ───────────────────────────────────────────────────────────────

class _StatsPanel extends StatelessWidget {
  final String time;
  final double distance;
  final double pace;
  const _StatsPanel(
      {required this.time, required this.distance, required this.pace});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _col(Icons.timer, time, '時間'),
            _divider(),
            _col(Icons.straighten, '${distance.toStringAsFixed(2)} km', '距離'),
            _divider(),
            _col(Icons.speed, '${pace.toStringAsFixed(1)} km/h', 'ペース'),
          ],
        ),
      ),
    );
  }

  Widget _col(IconData icon, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 17),
          const SizedBox(height: 3),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      );

  Widget _divider() =>
      Container(height: 32, width: 1, color: const Color(0xFFE5E7EB));
}
