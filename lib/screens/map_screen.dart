import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../app/routes/app_routes.dart';
import '../controllers/map_controller.dart';
import '../core/config.dart';
import '../services/location_service.dart';
import '../widgets/route_list_card.dart';

class MapScreen extends GetView<MapController> {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MapBody();
  }
}

class _MapBody extends StatefulWidget {
  const _MapBody();

  @override
  State<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends State<_MapBody> {
  GoogleMapController? _mapController;
  static const _default = LatLng(AppConfig.defaultLat, AppConfig.defaultLng);

  @override
  void initState() {
    super.initState();
    _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    final pos = await LocationService.instance.getCurrentPosition();
    if (pos != null && mounted) {
      _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(pos.latitude, pos.longitude)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<MapController>();
    return Scaffold(
      appBar: AppBar(title: const Text('地図表示')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition:
                  const CameraPosition(target: _default, zoom: 11),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              onMapCreated: (c) {
                _mapController = c;
                _moveToCurrentLocation();
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Obx(() {
              if (ctrl.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (ctrl.errorMsg.value.isNotEmpty) {
                return Center(child: Text(ctrl.errorMsg.value));
              }
              if (ctrl.routes.isEmpty) {
                return const Center(
                    child: Text('No routes available',
                        style: TextStyle(color: Colors.grey)));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                    child: Text(
                      'コース一覧  (${ctrl.routes.length})',
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
                      itemCount: ctrl.routes.length,
                      itemBuilder: (_, i) {
                        final route = ctrl.routes[i];
                        return RouteListCard(
                          title: route.displayName,
                          subtitle: route.fileName,
                          onTap: () => Get.toNamed(
                            AppRoutes.kmlMap,
                            arguments: route.storagePath,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
