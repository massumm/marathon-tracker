// main.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart' as xml;
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:geolocator/geolocator.dart';


class MapScreen extends StatefulWidget {
  // final String kmlFilePath;
  // MapScreen({ this.kmlFilePath});

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  LatLng _initialLocation = LatLng(23.777176, 90.399452); // default Dhaka
  Set<Polyline> _polylines = {};
  Position? _currentPosition;

  //initial setup for tracking user
  List<LatLng> _trackingPoints = [];
  StreamSubscription<Position>? _positionStream;
  bool _isTracking = false;
  List<String> _savedRoutes = [];

  @override
  void initState() {
    super.initState();
    _determinePosition();
  }

  void _startTracking() {
    _trackingPoints.clear();
    _isTracking = true;
    setState(() {}); // Refresh UI

    _positionStream = Geolocator.getPositionStream().listen((position) {
      final latLng = LatLng(position.latitude, position.longitude);
      _trackingPoints.add(latLng);
      setState(() {}); // Redraw polyline as it updates
    });
  }
  Future<void> _stopTracking() async {
    _positionStream?.cancel();
    _isTracking = false;
    setState(() {});

    // Save the trackingPoints as a KML or JSON
    final fileName = 'route_${DateTime.now().millisecondsSinceEpoch}.json';
    final json = _trackingPoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList();

    final ref = firebase_storage.FirebaseStorage.instance.ref('routes/$fileName');
    await ref.putString(jsonEncode(json));
    _savedRoutes.add(fileName);
  }
  Future<void> _loadKmlRoute(kmlFilePath) async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.ref(kmlFilePath);
      final url = await ref.getDownloadURL();

      final response = await http.get(Uri.parse(url));
      int polylineIdCounter = 0;
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(response.body);
        final coordinatesElements = document.findAllElements('coordinates');
        final placholders= document.findAllElements('placeholders');
        int polylineIdCounter = 0;
        print(placholders);
        Set<Polyline> loadedPolylines = {};
        final List<LatLng> routePoints = [];

        for (var element in coordinatesElements) {
          final coordsText = element.text.trim();
          final coords = coordsText.split(RegExp(r'\s+'));
          final List<LatLng> segmentPoints = [];

          for (var coord in coords) {
            final parts = coord.split(',');
            if (parts.length >= 2) {
              final lon = double.tryParse(parts[0]);
              final lat = double.tryParse(parts[1]);
              if (lat != null && lon != null) {
                segmentPoints.add(LatLng(lat, lon));
              }
            }
          }
          if (segmentPoints.length >= 2) {
            loadedPolylines.add(
              Polyline(
                polylineId: PolylineId("route_$polylineIdCounter"),
                points: segmentPoints,
                color: Colors.blue,
                width: 4,
              ),
            );
            polylineIdCounter++;
          }
        }


        if (loadedPolylines.isNotEmpty) {
          setState(() {
            _polylines = loadedPolylines;
            _initialLocation = loadedPolylines.first.points.first;
          });
        }


      }
    } catch (e) {
      print("Error loading KML: $e");
    }
  }

  Future<List<String>> _fetchKmlFiles() async {
    try {
      final result = await firebase_storage.FirebaseStorage.instance
          .ref('kpl')
          .listAll();

      return result.items.map((item) => item.fullPath).toList(); // only paths
    } catch (e) {
      print("Failed to list files: $e");
      return [];
    }
  }


  Future<void> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
      _initialLocation = LatLng(position.latitude, position.longitude);

      // Move camera to current position if map is already created
      _controller?.animateCamera(CameraUpdate.newLatLng(_initialLocation));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Map Route")),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(target: _initialLocation, zoom: 15),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  onMapCreated: (controller) => _controller = controller,
                  polylines: _isTracking
                      ? {
                    Polyline(
                      polylineId: PolylineId("tracking"),
                      points: _trackingPoints,
                      color: Colors.green,
                      width: 4,
                    )
                  }
                      : _polylines,
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: _isTracking ? _stopTracking : _startTracking,
                      child: Text(_isTracking ? "Stop" : "Start"),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route list below map
          Expanded(
            flex: 2,
            child: FutureBuilder<List<String>>(
              future: _fetchKmlFiles(), // Fetch file list from Firebase
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error loading routes"));
                }

                final filePaths = snapshot.data ?? [];

                return ListView.builder(
                  itemCount: filePaths.length,
                  itemBuilder: (context, index) {
                    final path = filePaths[index];
                    final name = path.split('/').last; // Extract file name
                    return ListTile(
                      title: Text(name),
                      onTap: () => _loadKmlRoute(path),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

    );
  }
}
