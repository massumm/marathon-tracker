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
  final String kmlFilePath;
  MapScreen({required this.kmlFilePath});

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
    
    _loadKmlRoute();
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
  Future<void> _loadKmlRoute() async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.ref(widget.kmlFilePath);
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
  Future<void> _loadRouteFromStorage(String fileName) async {
    try {
      final ref = firebase_storage.FirebaseStorage.instance.ref('routes/$fileName');
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));

      final List<dynamic> jsonData = jsonDecode(response.body);
      final List<LatLng> loadedPoints = jsonData
          .map((e) => LatLng(e['lat'], e['lng']))
          .toList();

      setState(() {
        _polylines = {
          Polyline(
            polylineId: PolylineId(fileName),
            points: loadedPoints,
            color: Colors.red,
            width: 4,
          )
        };
        _initialLocation = loadedPoints.first;
      });

      _controller?.animateCamera(CameraUpdate.newLatLng(_initialLocation));
    } catch (e) {
      print("Error loading saved route: $e");
    }
  }
  Future<List<String>> _fetchSavedRoutes() async {
    try {
      final listResult = await firebase_storage.FirebaseStorage.instance.ref('routes').listAll();

      // Only keep .json files
      return listResult.items
          .where((item) => item.name.endsWith(".json"))
          .map((item) => item.name)
          .toList();
    } catch (e) {
      print("Error listing routes: $e");
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
              future: _fetchSavedRoutes(), // Fetch file list from Firebase
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text("Error loading routes"));
                }

                final routes = snapshot.data ?? [];

                return ListView.builder(
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final fileName = routes[index];
                    return ListTile(
                      title: Text(fileName),
                      onTap: () => _loadRouteFromStorage(fileName),
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
