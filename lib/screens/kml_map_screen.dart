import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/kml_map_controller.dart';
import '../core/theme.dart';
import '../models/runner_data.dart';

class KmlMapScreen extends GetView<KmlMapController> {
  const KmlMapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マップビュー')),
      // Single Obx — all observable reads happen here, no nested Obx
      body: Obx(() => _buildBody()),
    );
  }

  Widget _buildBody() {
    if (!controller.kmlLoaded.value) {
      return const Center(child: CircularProgressIndicator());
    }

    // Read all observables once in this scope so GetX tracks them correctly
    final isTracking = controller.isTracking.value;
    final isSaving = controller.isSaving.value;
    final elapsedSecs = controller.elapsedSeconds.value;
    final points = controller.trackingPoints.toList();
    final currentPos = controller.currentPosition.value;
    final runners = controller.activeRunners.toList();
    final runnerMarkersSet = controller.runnerMarkers.values.toSet();
    final hasRunners = runners.isNotEmpty;

    return Stack(children: [
      // ── Map ─────────────────────────────────────────────────────────────
      GoogleMap(
        initialCameraPosition:
            CameraPosition(target: controller.initialLocation, zoom: 17),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (c) {
          controller.mapController = c;
          c.animateCamera(CameraUpdate.newLatLng(controller.initialLocation));
        },
        polylines: {
          ...controller.kmlPolylines,
          if (isTracking && points.length >= 2)
            Polyline(
              polylineId: const PolylineId('tracking'),
              points: points, // already a new list from .toList()
              color: AppTheme.trackingGreen,
              width: 5,
            ),
        },
        markers: {
          ...controller.kmlMarkers,
          ...runnerMarkersSet,
        },
      ),

      // ── Live runners panel ───────────────────────────────────────────────
      if (hasRunners)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: _RunnersPanel(
            runners: runners,
            onTap: (r) {
              controller.flyToRunner(r);
              controller.showRunnerInfo(r);
            },
          ),
        ),

      // ── Stats or timer chip ──────────────────────────────────────────────
      if (isTracking)
        Positioned(
          top: hasRunners ? 110 : 12,
          left: 16,
          right: 16,
          child: _statsPanel(elapsedSecs),
        )
      else
        _timerChip(elapsedSecs),

      // ── Start / Stop button ──────────────────────────────────────────────
      Positioned(
        bottom: 48,
        left: 0,
        right: 0,
        child: Center(
          child: GestureDetector(
            onTap:
                isTracking ? controller.stopTracking : controller.startTracking,
            child: Image.asset(
              isTracking ? 'assets/images/stop.png' : 'assets/images/start.png',
              height: 80,
              width: 80,
            ),
          ),
        ),
      ),

      // ── Saving overlay ───────────────────────────────────────────────────
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

  Widget _statsPanel(int elapsedSecs) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _statCol(Icons.timer, controller.formatTime(elapsedSecs), '時間'),
            _divider(),
            _statCol(Icons.straighten,
                '${controller.currentDistanceKm.toStringAsFixed(2)} km', '距離'),
            _divider(),
            _statCol(Icons.speed,
                '${controller.currentPaceKmH.toStringAsFixed(1)} km/h', 'ペース'),
          ],
        ),
      ),
    );
  }

  Widget _timerChip(int elapsedSecs) {
    return Positioned(
      top: 12,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            controller.formatTime(elapsedSecs),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCol(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _divider() =>
      Container(height: 36, width: 1, color: const Color(0xFFE5E7EB));
}

// ── Live runners panel (pure UI, no observables inside) ───────────────────────

class _RunnersPanel extends StatelessWidget {
  final List<RunnerData> runners;
  final void Function(RunnerData) onTap;
  const _RunnersPanel({required this.runners, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.radio_button_on, size: 12, color: Colors.green),
            const SizedBox(width: 5),
            Text(
              '${runners.length} runner${runners.length > 1 ? 's' : ''} live — tap to locate',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
            ),
          ]),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  runners.map((r) => _RunnerChip(r: r, onTap: onTap)).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _RunnerChip extends StatelessWidget {
  final RunnerData r;
  final void Function(RunnerData) onTap;
  const _RunnerChip({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = r.displayName.isNotEmpty
        ? r.displayName
        : r.email.isNotEmpty
            ? r.email.split('@').first
            : 'Runner';

    return GestureDetector(
      onTap: () => onTap(r),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1976D2).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border:
              Border.all(color: const Color(0xFF1976D2).withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: const Color(0xFF1976D2),
            child: Text(label[0].toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ),
          const SizedBox(width: 6),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
            Text(r.email,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ]),
        ]),
      ),
    );
  }
}
