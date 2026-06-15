import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../controllers/free_run_controller.dart';
import '../core/theme.dart';

class FreeRunScreen extends StatelessWidget {
  const FreeRunScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(FreeRunController());
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────
          Obx(() => GoogleMap(
                onMapCreated: ctrl.onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(23.8103, 90.4125),
                  zoom: 16,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                polylines: ctrl.trackingPoints.length > 1
                    ? {
                        Polyline(
                          polylineId: const PolylineId('free_run'),
                          points: ctrl.trackingPoints.toList(),
                          color: AppTheme.primary,
                          width: 5,
                        ),
                      }
                    : {},
              )),

          // ── GPS health badge ─────────────────────────────────────────────
          Obx(() {
            final state = ctrl.runState.value;
            if (state == FreeRunState.idle) return const SizedBox.shrink();
            return Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 12,
              child: _GpsSignalBadge(accuracy: ctrl.gpsAccuracy.value),
            );
          }),

          // ── Current location button ───────────────────────────────────────
          Obx(() {
            final state = ctrl.runState.value;
            if (state == FreeRunState.stopped || ctrl.isSaving.value) {
              return const SizedBox.shrink();
            }
            return Positioned(
              right: 12,
              bottom: 180,
              child: GestureDetector(
                onTap: () {
                  final pos = ctrl.currentPosition.value;
                  if (pos.latitude != 0 || pos.longitude != 0) {
                    ctrl.mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(pos, 17));
                  }
                },
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 1),
                  ),
                  child: const Icon(Icons.my_location,
                      color: Colors.white, size: 22),
                ),
              ),
            );
          }),

          // ── Back button ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () {
                  final state = ctrl.runState.value;
                  if (state == FreeRunState.running ||
                      state == FreeRunState.paused) {
                    _confirmExit(context, ctrl);
                  } else {
                    Get.back();
                  }
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),

          // ── Stats overlay (visible during/after run) ──────────────────────
          Obx(() {
            final state = ctrl.runState.value;
            if (state == FreeRunState.idle) return const SizedBox.shrink();
            return Positioned(
              top: MediaQuery.of(context).padding.top + 60,
              left: 16,
              right: 16,
              child: _StatsCard(ctrl: ctrl),
            );
          }),

          // ── Bottom controls ───────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomControls(ctrl: ctrl),
          ),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context, FreeRunController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Stop Free Run?'),
        content: const Text('Your run will be stopped and saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ctrl.stopRun();
              Get.back();
            },
            child: const Text('Stop & Exit',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Stats card ───────────────────────────────────────────────────────────────
class _StatsCard extends StatelessWidget {
  final FreeRunController ctrl;
  const _StatsCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Obx(() => Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(
                label: 'Distance',
                value: '${ctrl.distanceKm.value.toStringAsFixed(2)} km',
              ),
              _divider(),
              _Stat(label: 'Time', value: ctrl.formattedTime),
              _divider(),
              _Stat(
                label: 'Pace',
                value: ctrl.paceKmH > 0
                    ? '${ctrl.paceKmH.toStringAsFixed(1)} km/h'
                    : '—',
              ),
            ],
          )),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: Colors.white.withValues(alpha: 0.2),
      );
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            )),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }
}

// ── Bottom controls ───────────────────────────────────────────────────────────
class _BottomControls extends StatelessWidget {
  final FreeRunController ctrl;
  const _BottomControls({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.92),
            Colors.black.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Obx(() {
        final state = ctrl.runState.value;

        if (state == FreeRunState.idle) {
          return _RunButton(ctrl: ctrl);
        }

        if (state == FreeRunState.stopped || ctrl.isSaving.value) {
          return _SummaryCard(ctrl: ctrl);
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Pause / Resume
            _CircleBtn(
              icon: state == FreeRunState.paused
                  ? Icons.play_arrow_rounded
                  : Icons.pause_rounded,
              color: Colors.white,
              iconColor: Colors.black,
              size: 64,
              label: state == FreeRunState.paused ? 'Resume' : 'Pause',
              onTap: state == FreeRunState.paused
                  ? ctrl.resumeRun
                  : ctrl.pauseRun,
            ),
            const SizedBox(width: 32),
            // Stop
            _CircleBtn(
              icon: Icons.stop_rounded,
              color: Colors.red.shade600,
              iconColor: Colors.white,
              size: 64,
              label: 'Stop',
              onTap: () => _confirmStop(context, ctrl),
            ),
          ],
        );
      }),
    );
  }

  void _confirmStop(BuildContext context, FreeRunController ctrl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Finish Run?'),
        content: const Text('Your route and stats will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ctrl.stopRun();
            },
            child: const Text('Finish',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ── Big pulsing RUN button ────────────────────────────────────────────────────
class _RunButton extends StatefulWidget {
  final FreeRunController ctrl;
  const _RunButton({required this.ctrl});

  @override
  State<_RunButton> createState() => _RunButtonState();
}

class _RunButtonState extends State<_RunButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08)
        .animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Tap to start your free run',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        ScaleTransition(
          scale: _scale,
          child: GestureDetector(
            onTap: widget.ctrl.startRun,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.primary,
                    AppTheme.primary.withValues(alpha: 0.75),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.55),
                    blurRadius: 28,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run_rounded,
                      color: Colors.white, size: 36),
                  SizedBox(height: 2),
                  Text('RUN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      )),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Summary card shown after stopping ────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final FreeRunController ctrl;
  const _SummaryCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isSaving.value) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 12),
              Text('Saving your run…',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
        );
      }

      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flag_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text('Run Complete!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SummaryStat(
                  icon: Icons.straighten_rounded,
                  label: 'Distance',
                  value: '${ctrl.distanceKm.value.toStringAsFixed(2)} km',
                ),
                _SummaryStat(
                  icon: Icons.timer_outlined,
                  label: 'Time',
                  value: ctrl.formattedTime,
                ),
                _SummaryStat(
                  icon: Icons.speed_rounded,
                  label: 'Pace',
                  value: ctrl.paceKmH > 0
                      ? '${ctrl.paceKmH.toStringAsFixed(1)} km/h'
                      : '—',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Get.back(),
                child: const Text('Done',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
    });
  }
}

class _SummaryStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.primary, size: 22),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
      ],
    );
  }
}

// ── GPS signal badge ──────────────────────────────────────────────────────────
class _GpsSignalBadge extends StatelessWidget {
  final double accuracy; // metres; -1 = no fix

  const _GpsSignalBadge({required this.accuracy});

  int get _bars {
    if (accuracy < 0) return 0;
    if (accuracy <= 5) return 4;
    if (accuracy <= 10) return 3;
    if (accuracy <= 20) return 2;
    return 1;
  }

  Color get _color {
    if (accuracy < 0) return Colors.grey;
    if (accuracy <= 5) return Colors.green;
    if (accuracy <= 10) return Colors.lightGreen;
    if (accuracy <= 20) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gps_fixed, color: _color, size: 13),
          const SizedBox(width: 4),
          Row(
            children: List.generate(4, (i) {
              final filled = i < _bars;
              return Container(
                width: 4,
                height: 6 + i * 2.0,
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: filled ? _color : Colors.white24,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
          const SizedBox(width: 4),
          Text(
            accuracy < 0
                ? 'No fix'
                : '±${accuracy.toStringAsFixed(0)}m',
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable circle button ────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final double size;
  final String? label;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.size,
    required this.onTap,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.45),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 8),
          Text(label!,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]
      ],
    );
  }
}
