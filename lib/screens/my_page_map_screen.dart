import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../core/theme.dart';
import '../models/tracked_route.dart';
import '../services/firebase_service.dart';

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
      final url = await FirebaseService.instance.getDownloadUrl(_filePath);
      final response = await http.get(Uri.parse(url));
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final route = TrackedRoute.fromJson(json, _filePath);
      setState(() {
        _route = route;
        _isLoaded = true;
      });
      if (route.route.isNotEmpty) {
        _controller?.animateCamera(
            CameraUpdate.newLatLngZoom(route.route.first, 16));
      }
    } catch (e) {
      debugPrint('Error loading saved route: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_dateTitle)),
      body: _isLoaded && _route != null
          ? Stack(children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                    target: _route!.route.isNotEmpty
                        ? _route!.route.first
                        : const LatLng(35.6895, 139.6917),
                    zoom: 16),
                onMapCreated: (c) {
                  _controller = c;
                  if (_route!.route.isNotEmpty) {
                    c.animateCamera(CameraUpdate.newLatLngZoom(
                        _route!.route.first, 16));
                  }
                },
                polylines: {
                  Polyline(
                    polylineId: PolylineId(_filePath),
                    points: _route!.route,
                    color: AppTheme.savedRouteRed,
                    width: 4,
                  ),
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
              ),
              if (_route!.distance.isNotEmpty)
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Material(
                    elevation: 6,
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _stat(Icons.straighten, _route!.distance, '距離'),
                          _divider(),
                          _stat(Icons.timer, _route!.time, '時間'),
                          _divider(),
                          _stat(Icons.speed, _route!.pace, 'ペース'),
                        ],
                      ),
                    ),
                  ),
                ),
            ])
          : const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _stat(IconData icon, String value, String label) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.primary, size: 18),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14)),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.textSecondary)),
        ],
      );

  Widget _divider() =>
      Container(height: 36, width: 1, color: const Color(0xFFE5E7EB));
}
