import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme.dart';
import '../../models/tracked_route.dart';

class RunSelfieScreen extends StatefulWidget {
  final TrackedRoute route;
  const RunSelfieScreen({super.key, required this.route});

  @override
  State<RunSelfieScreen> createState() => _RunSelfieScreenState();
}

class _RunSelfieScreenState extends State<RunSelfieScreen> {
  CameraController? _controller;
  bool _cameraReady = false;
  File? _capturedFile;
  bool _sharing = false;
  final _previewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      final front = cameras.firstWhereOrNull(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
      final selected = front ?? cameras.first;
      _controller = CameraController(
        selected,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() => _cameraReady = true);
    } on CameraException catch (e) {
      debugPrint('Camera init error: ${e.code} ${e.description}');
      if (mounted) {
        Get.dialog(
          AlertDialog(
            title: Text('camera_permission_denied'.tr),
            content: Text('camera_permission_settings_msg'.tr),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: Text('cancel'.tr),
              ),
              TextButton(
                onPressed: () async {
                  Get.back();
                  await openAppSettings();
                },
                child: Text('open_settings'.tr),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      final file = await _controller!.takePicture();
      setState(() => _capturedFile = File(file.path));
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary =
          _previewKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final tmp = await getTemporaryDirectory();
      final path =
          '${tmp.path}/runmate_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes);

      final previewBox = _previewKey.currentContext?.findRenderObject() as RenderBox?;
      final shareRect = previewBox != null
          ? previewBox.localToGlobal(Offset.zero) & previewBox.size
          : const Rect.fromLTWH(0, 0, 100, 100);
      await Share.shareXFiles(
        [XFile(path)],
        text:
            '🏃 Just finished a run on RunMate!\n${widget.route.distance}  ·  ${widget.route.time}  ·  ${widget.route.pace}\n\n#RunMate #Running #Marathon #Run\nhttps://runmate.app',
        sharePositionOrigin: shareRect,
      );
    } catch (e) {
      debugPrint('Share error: $e');
      Get.snackbar('Error', 'Could not share image',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('share_run'.tr),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _capturedFile == null
                  ? _buildCameraPreview()
                  : _buildReview(),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_cameraReady || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRect(child: CameraPreview(_controller!)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _StatsOverlay(route: widget.route),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return RepaintBoundary(
      key: _previewKey,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.file(_capturedFile!, fit: BoxFit.cover),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _StatsOverlay(route: widget.route),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    if (_capturedFile == null) {
      return Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(
          child: GestureDetector(
            onTap: _capture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: const Icon(Icons.camera_alt,
                  color: Colors.white, size: 34),
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _capturedFile = null),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: Text('retake'.tr,
                  style: const TextStyle(color: Colors.white)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _sharing ? null : _share,
              icon: _sharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.share),
              label: Text('share_action'.tr),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats watermark overlay ───────────────────────────────────────────────────

class _StatsOverlay extends StatelessWidget {
  final TrackedRoute route;
  const _StatsOverlay({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.88),
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_run,
                  color: AppTheme.primary, size: 16),
              SizedBox(width: 6),
              Text(
                'RunMate',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          if (route.event.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              route.event,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _Stat(label: 'Distance', value: route.distance),
              _Stat(label: 'Time', value: route.time),
              _Stat(label: 'Pace', value: route.pace),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value.isNotEmpty ? value : '—',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 11),
        ),
      ],
    );
  }
}
