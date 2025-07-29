import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class MyPageMapScreen extends StatefulWidget {
  final String filePath;

  const MyPageMapScreen({Key? key, required this.filePath}) : super(key: key);

  @override
  _MyPageMapScreenState createState() => _MyPageMapScreenState();
}

class _MyPageMapScreenState extends State<MyPageMapScreen> {
  GoogleMapController? _controller;
  Set<Polyline> _polylines = {};
  bool _isloading=false;
  LatLng _initialLocation = const LatLng(23.8103, 90.4125); // Default to Dhaka

  @override
  void initState() {
    super.initState();
    _loadRouteFromStorage(widget.filePath);
  }

  Future<void> _loadRouteFromStorage(String filePath) async {
    try {

      final ref = firebase_storage.FirebaseStorage.instance.ref(filePath);
      final url = await ref.getDownloadURL();
      final response = await http.get(Uri.parse(url));

      final Map<String,dynamic> jsonData = jsonDecode(response.body);

      final List<dynamic> routeData = jsonData['route'];
      final List<LatLng> loadedPoints = routeData
          .map((e) => LatLng(e['lat'], e['lng']))
          .toList();

      setState(() {
        _isloading = true;
        _initialLocation = loadedPoints.first;
        _polylines = {
          Polyline(
            polylineId: PolylineId(filePath),
            points: loadedPoints,
            color: Colors.red,
            width: 4,
          )
        };
      });

      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(_initialLocation, 16),
      );
    } catch (e) {
      print("Error loading saved route: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Route Viewer")),
      body: _isloading
          ? GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialLocation,
                zoom: 14,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller = controller;
              },
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }
}
