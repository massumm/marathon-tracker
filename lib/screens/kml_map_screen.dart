import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../core/theme.dart';
import '../services/firebase_service.dart';
import '../services/kml_service.dart';
import '../services/location_service.dart';

// NOTE: HomeScreen.setTabIndex is a static callback defined in main.dart.
// This tight coupling is intentional — do not remove without replacing with
// a proper navigator callback passed down from HomeScreen.
import '../main.dart' show HomeScreen;

class KmlMapScreen extends StatefulWidget {
  final String kmlFilePath;
  const KmlMapScreen({super.key, required this.kmlFilePath});

  @override
  State<KmlMapScreen> createState() => _KmlMapScreenState();
}

class _KmlMapScreenState extends State<KmlMapScreen> {
  GoogleMapController? _controller;
  Timer? _timer;
  int _elapsedSeconds = 0;
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};
  LatLng _initialLocation = const LatLng(23.777176, 90.399452);
  final List<LatLng> _trackingPoints = [];
  bool _isTracking = false;
  StreamSubscription? _positionStream;
  bool _isSaving = false;
  bool _kmlLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadKmlRoute(widget.kmlFilePath);
  }

  Future<void> _loadKmlRoute(String path) async {
    try {
      final url = await FirebaseService.instance.getDownloadUrl(path);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final parsed = KmlService.instance.parse(response.body,
            polylineColor: AppTheme.primary);
        if (parsed.polylines.isNotEmpty) {
          setState(() {
            _polylines = parsed.polylines;
            _markers = parsed.markers;
            _initialLocation = parsed.polylines.first.points.first;
            _kmlLoaded = true;
          });
          _controller?.animateCamera(
              CameraUpdate.newLatLng(_initialLocation));
        }
      }
    } catch (e) {
      debugPrint('Error loading KML: $e');
    }
  }

  Future<void> _startTracking() async {
    _trackingPoints.clear();
    _elapsedSeconds = 0;
    _timer?.cancel();

    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null) {
      _controller?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _elapsedSeconds++);
    });

    _positionStream =
        LocationService.instance.getPositionStream().listen((position) {
      final latLng = LatLng(position.latitude, position.longitude);
      _controller?.animateCamera(CameraUpdate.newLatLng(latLng));
      setState(() => _trackingPoints.add(latLng));
    });

    setState(() => _isTracking = true);
  }

  Future<void> _stopTracking() async {
    setState(() => _isSaving = true);
    _positionStream?.cancel();
    _timer?.cancel();
    _isTracking = false;

    final now = DateTime.now();
    final fileName = 'my_route_${now.millisecondsSinceEpoch}.json';
    final elapsedTime = Duration(seconds: _elapsedSeconds);
    final startTime = now.subtract(elapsedTime);
    final totalDistance =
        LocationService.instance.totalDistanceKm(_trackingPoints);
    final pace = _elapsedSeconds > 0
        ? totalDistance / (_elapsedSeconds / 3600)
        : 0.0;

    final data = {
      'event': AppConfig.eventName,
      'type': AppConfig.eventType,
      'start_date':
          '${startTime.year}/${startTime.month.toString().padLeft(2, '0')}/${startTime.day.toString().padLeft(2, '0')}',
      'start_time':
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:${startTime.second.toString().padLeft(2, '0')}',
      'time': _formatTime(_elapsedSeconds),
      'distance': '${totalDistance.toStringAsFixed(1)} km',
      'pace': '${pace.toStringAsFixed(1)} km/h',
      'route': _trackingPoints
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    };

    await FirebaseService.instance.saveTrackedRoute(fileName, jsonEncode(data));
    setState(() => _isSaving = false);

    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      HomeScreen.setTabIndex(1);
    }
  }

  String _formatTime(int seconds) {
    final d = Duration(seconds: seconds);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  double get _currentDistanceKm =>
      LocationService.instance.totalDistanceKm(_trackingPoints);

  double get _currentPaceKmH {
    if (_elapsedSeconds == 0 || _currentDistanceKm == 0) return 0;
    return _currentDistanceKm / (_elapsedSeconds / 3600);
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マップビュー')),
      body: Stack(
        children: [
          // Map
          if (_kmlLoaded)
            GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _initialLocation, zoom: 17),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (c) => _controller = c,
              polylines: {
                ..._polylines,
                if (_isTracking)
                  Polyline(
                    polylineId: const PolylineId('tracking'),
                    points: _trackingPoints,
                    color: AppTheme.trackingGreen,
                    width: 4,
                  ),
              },
              markers: _markers,
            ),

          if (!_kmlLoaded)
            const Center(child: CircularProgressIndicator()),

          // Floating stats panel (visible during tracking)
          if (_isTracking)
            Positioned(
              top: 12,
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
                      _statColumn(
                          Icons.timer, _formatTime(_elapsedSeconds), '時間'),
                      _divider(),
                      _statColumn(Icons.straighten,
                          '${_currentDistanceKm.toStringAsFixed(2)} km',
                          '距離'),
                      _divider(),
                      _statColumn(Icons.speed,
                          '${_currentPaceKmH.toStringAsFixed(1)} km/h',
                          'ペース'),
                    ],
                  ),
                ),
              ),
            ),

          // Timer chip when not yet tracking (after KML loaded)
          if (!_isTracking && _kmlLoaded)
            Positioned(
              top: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatTime(_elapsedSeconds),
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

          // Start / Stop button
          if (_kmlLoaded)
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _isTracking ? _stopTracking : _startTracking,
                  child: Image.asset(
                    _isTracking
                        ? 'assets/images/stop.png'
                        : 'assets/images/start.png',
                    height: 80,
                    width: 80,
                  ),
                ),
              ),
            ),

          // Saving overlay
          if (_isSaving)
            Container(
              color: Colors.black45,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 14),
                    Text('保存中...',
                        style:
                            TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statColumn(IconData icon, String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.primary, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _divider() => Container(
        height: 36,
        width: 1,
        color: const Color(0xFFE5E7EB),
      );
}
