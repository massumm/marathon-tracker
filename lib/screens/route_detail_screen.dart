import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../app/routes/app_routes.dart';
import '../core/theme.dart';
import '../models/tracked_route.dart';
import '../screens/run_selfie_screen.dart';
import '../services/firebase_service.dart';
import '../services/offline_storage_service.dart';

class RouteDetailScreen extends StatefulWidget {
  const RouteDetailScreen({super.key});

  @override
  State<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends State<RouteDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final String _storagePath;

  TrackedRoute? _route;
  bool _routeLoaded = false;

  List<String> _photoUrls = [];
  bool _photosLoaded = false;

  @override
  void initState() {
    super.initState();
    _storagePath = Get.arguments as String;
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_photosLoaded) _loadPhotos();
    });
    _loadRoute();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final fileName = _storagePath.split('/').last;
      String? body;

      if (_storagePath.startsWith('local/')) {
        // Locally saved run — read straight from device file
        body = await OfflineStorageService.instance
            .getLocalRouteJson(uid, fileName);
      } else {
        // Try local file first (pending upload), then content cache, then network
        body = await OfflineStorageService.instance
            .getLocalRouteJson(uid, fileName);
        body ??= await OfflineStorageService.instance
            .getCachedContent(_storagePath);
        if (body == null) {
          final url =
              await FirebaseService.instance.getDownloadUrl(_storagePath);
          final response = await http.get(Uri.parse(url));
          body = response.body;
          await OfflineStorageService.instance
              .cacheContent(_storagePath, body);
        }
      }

      if (body == null) return;
      final json = jsonDecode(body) as Map<String, dynamic>;
      setState(() {
        _route = TrackedRoute.fromJson(json, _storagePath);
        _routeLoaded = true;
      });
    } catch (e) {
      debugPrint('RouteDetailScreen: error loading route: $e');
    }
  }

  Future<void> _loadPhotos() async {
    try {
      // Use runStartMs from the loaded route JSON (reliable for new format).
      // Fall back to storage-path extraction for old-format routes.
      final runStartMs = _route?.runStartMs ?? 0;
      final refs = await FirebaseService.instance
          .fetchRunPhotoRefs(_storagePath, runStartMs: runStartMs);
      final urls = await Future.wait(
        refs.map((r) => r.getDownloadURL()),
      );
      setState(() {
        _photoUrls = urls;
        _photosLoaded = true;
      });
    } catch (e) {
      debugPrint('RouteDetailScreen: error loading photos: $e');
      setState(() => _photosLoaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = TrackedRoute.parseDateFromFileName(
        _storagePath.split('/').last);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (_route != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'share_run'.tr,
              onPressed: () => Get.to(() => RunSelfieScreen(route: _route!)),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'my_route_tab'.tr),
            Tab(text: 'photos_tab'.tr),
          ],
        ),
      ),
      body: !_routeLoaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _StatsHeader(route: _route!),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _MapTab(route: _route!, storagePath: _storagePath),
                      _PhotosTab(
                        photoUrls: _photoUrls,
                        loaded: _photosLoaded,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Stats header ──────────────────────────────────────────────────────────────

class _StatsHeader extends StatelessWidget {
  final TrackedRoute route;
  const _StatsHeader({required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            route.event.isNotEmpty ? route.event : 'event'.tr,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            [
              if (route.type.isNotEmpty) route.type,
              if (route.startDate.isNotEmpty) route.startDate,
              if (route.startTime.isNotEmpty) route.startTime,
            ].join('  ·  '),
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StatCell(
                icon: Icons.straighten,
                value: route.distance.isNotEmpty ? route.distance : '—',
                label: 'distance_label'.tr,
              ),
              _divider(),
              _StatCell(
                icon: Icons.timer,
                value: route.time.isNotEmpty ? route.time : '—',
                label: 'time_label'.tr,
              ),
              _divider(),
              _StatCell(
                icon: Icons.speed,
                value: route.pace.isNotEmpty ? route.pace : '—',
                label: 'pace_label'.tr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      height: 36, width: 1, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 8));
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCell(
      {required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(height: 3),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700)),
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

// ── My Route tab ──────────────────────────────────────────────────────────────

class _MapTab extends StatefulWidget {
  final TrackedRoute route;
  final String storagePath;
  const _MapTab({required this.route, required this.storagePath});

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final route = widget.route;
    final initial = route.route.isNotEmpty
        ? route.route.first
        : const LatLng(35.6895, 139.6917);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: initial, zoom: 15),
          onMapCreated: (c) {
            if (route.route.length >= 2) {
              final bounds = _boundsOf(route.route);
              c.animateCamera(
                  CameraUpdate.newLatLngBounds(bounds, 48));
            }
          },
          polylines: route.route.length >= 2
              ? {
                  Polyline(
                    polylineId:
                        PolylineId(widget.storagePath),
                    points: route.route,
                    color: AppTheme.savedRouteRed,
                    width: 4,
                  ),
                }
              : {},
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: true,
        ),
        Positioned(
          top: 12,
          right: 12,
          child: FloatingActionButton.small(
            heroTag: 'fullmap',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.primary,
            onPressed: () => Get.toNamed(
              AppRoutes.myPageMap,
              arguments: widget.storagePath,
            ),
            child: const Icon(Icons.fullscreen),
          ),
        ),
      ],
    );
  }

  LatLngBounds _boundsOf(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}

// ── Photos tab ────────────────────────────────────────────────────────────────

class _PhotosTab extends StatelessWidget {
  final List<String> photoUrls;
  final bool loaded;
  const _PhotosTab({required this.photoUrls, required this.loaded});

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (photoUrls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_camera_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('no_photos'.tr,
                style: const TextStyle(
                    fontSize: 15, color: AppTheme.textSecondary)),
            const SizedBox(height: 4),
            Text('no_photos_subtitle'.tr,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photoUrls.length,
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => _openPhoto(context, i),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: photoUrls[i],
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey.shade200),
            errorWidget: (_, __, ___) =>
                Container(color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image_outlined)),
          ),
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: photoUrls[index],
                fit: BoxFit.contain,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
