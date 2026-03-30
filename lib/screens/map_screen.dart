import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/config.dart';
import '../models/kml_route.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';
import '../widgets/route_list_card.dart';
import 'kml_map_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  static const LatLng _defaultLocation =
      LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      _controller?.animateCamera(
        CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('地図表示')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: _defaultLocation, zoom: 11),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (c) => _controller = c,
            ),
          ),
          Expanded(
            flex: 2,
            child: FutureBuilder<List<KmlRoute>>(
              future: FirebaseService.instance.fetchKmlRoutes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading routes'));
                }
                final routes = snapshot.data ?? [];
                if (routes.isEmpty) {
                  return const Center(
                    child: Text(
                      'No routes available',
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                      child: Text(
                        'コース一覧  (${routes.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: routes.length,
                        itemBuilder: (context, index) {
                          final route = routes[index];
                          return RouteListCard(
                            title: route.displayName,
                            subtitle: route.fileName,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => KmlMapScreen(
                                    kmlFilePath: route.storagePath),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
