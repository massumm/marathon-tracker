import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/theme.dart';
import '../../models/tracked_route.dart';
import '../../services/firebase_service.dart';
import '../../services/offline_storage_service.dart';

class MyPageMapScreen extends StatefulWidget {
  const MyPageMapScreen({super.key});

  @override
  State<MyPageMapScreen> createState() => _MyPageMapScreenState();
}

class _MyPageMapScreenState extends State<MyPageMapScreen> {
  GoogleMapController? _controller;
  TrackedRoute? _route;
  bool _isLoaded = false;

  late final String _filePath;

  String get _dateTitle =>
      TrackedRoute.parseDateFromFileName(_filePath.split('/').last);

  @override
  void initState() {
    super.initState();
    _filePath = Get.arguments as String;
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final fileName = _filePath.split('/').last;
      String? body;

      if (_filePath.startsWith('local/')) {
        body = await OfflineStorageService.instance.getLocalRouteJson(uid, fileName);
      } else {
        body = await OfflineStorageService.instance.getLocalRouteJson(uid, fileName);
        body ??= await OfflineStorageService.instance.getCachedContent(_filePath);
        if (body == null) {
          final url = await FirebaseService.instance.getDownloadUrl(_filePath);
          final response = await http.get(Uri.parse(url));
          body = response.body;
          await OfflineStorageService.instance.cacheContent(_filePath, body);
        }
      }

      if (body == null) return;
      final json = jsonDecode(body) as Map<String, dynamic>;
      final route = TrackedRoute.fromJson(json, _filePath);
      setState(() {
        _route = route;
        _isLoaded = true;
      });
      if (route.route.length >= 2) {
        final bounds = _boundsOf(route.route);
        _controller?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
      } else if (route.route.isNotEmpty) {
        _controller?.animateCamera(
            CameraUpdate.newLatLngZoom(route.route.first, 16));
      }
    } catch (e) {
      debugPrint('Error loading saved route: $e');
    }
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

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _route == null) {
      return Scaffold(
        appBar: AppBar(title: Text(_dateTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final route = _route!;
    final markers = <Marker>{};
    if (route.route.isNotEmpty) {
      markers.add(Marker(
        markerId: const MarkerId('start'),
        position: route.route.first,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: 'start_marker'.tr),
      ));
    }
    if (route.route.length >= 2) {
      markers.add(Marker(
        markerId: const MarkerId('finish'),
        position: route.route.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: 'finish_marker'.tr),
      ));
    }

    return Scaffold(
      appBar: AppBar(title: Text(_dateTitle)),
      body: Stack(children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
              target: route.route.isNotEmpty
                  ? route.route.first
                  : const LatLng(35.6895, 139.6917),
              zoom: 16),
          onMapCreated: (c) {
            _controller = c;
            if (route.route.length >= 2) {
              c.animateCamera(CameraUpdate.newLatLngBounds(_boundsOf(route.route), 60));
            } else if (route.route.isNotEmpty) {
              c.animateCamera(CameraUpdate.newLatLngZoom(route.route.first, 16));
            }
          },
          polylines: route.route.length >= 2
              ? {
                  Polyline(
                    polylineId: PolylineId(_filePath),
                    points: route.route,
                    color: AppTheme.savedRouteRed,
                    width: 4,
                  ),
                }
              : {},
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
        ),
        if (route.distance.isNotEmpty)
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(Icons.straighten, route.distance, 'distance_label'.tr),
                    _divider(),
                    _stat(Icons.timer, route.time, 'time_label'.tr),
                    _divider(),
                    _stat(Icons.speed, route.pace, 'pace_label'.tr),
                  ],
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );

  Widget _divider() =>
      Container(height: 36, width: 1, color: const Color(0xFFE5E7EB));
}
