import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'services/osrm_service.dart';
import 'active_navigation_screen.dart'; // 🟢 Import your new screen!

class RoutePreviewScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destination;
  final String destinationName;

  const RoutePreviewScreen({
    super.key,
    required this.startLocation,
    required this.destination,
    required this.destinationName,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final MapController _mapController = MapController();

  List<LatLng> _routePoints = [];
  List<RouteStep> _routeInstructions = [];
  String _eta = "Calculating...";
  String _distance = "...";

  final Color primaryBlue = const Color(0xFF51A8E7);
  final Color darkBlue = const Color(0xFF1B6AAB);

  @override
  void initState() {
    super.initState();
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    final routeData = await OsrmService.getRoute(
      widget.startLocation,
      widget.destination,
    );

    if (routeData != null && mounted) {
      setState(() {
        _routePoints = routeData['points'];
        _eta = routeData['time'];
        _distance = routeData['distance'];
        _routeInstructions = routeData['steps'] ?? [];
      });

      if (_routePoints.isNotEmpty) {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(_routePoints),
            padding: const EdgeInsets.all(80),
          ),
        );
      }
    } else if (mounted) {
      setState(() {
        _eta = "Error";
        _distance = "Too Far";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startLocation,
              initialZoom: 13,
            ),
            children: [
              // 🟢 THE FIX: Unique Package Name added here too!
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.safehorizon.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: darkBlue,
                      strokeWidth: 8,
                    ),
                    Polyline(
                      points: _routePoints,
                      color: primaryBlue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.startLocation,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 30,
                    ),
                  ),
                  Marker(
                    point: widget.destination,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              color: primaryBlue,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 16,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 8,
                    top: -4,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    "Route Preview",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: primaryBlue, width: 3),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoItem(
                          "Destination:",
                          widget.destinationName,
                          isBlue: true,
                        ),
                      ),
                      Expanded(child: _buildInfoItem("Estimated Time:", _eta)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildInfoItem("Distance:", _distance)),
                    ],
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _routePoints.isEmpty
                          ? null
                          : () {
                              // 🟢 THIS IS THE BRIDGE: Pushes the active navigation screen!
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ActiveNavigationScreen(
                                    initialRoutePoints: _routePoints,
                                    initialInstructions: _routeInstructions,
                                    startLocation: widget.startLocation,
                                    destination: widget.destination,
                                    destinationName: widget.destinationName,
                                  ),
                                ),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _routePoints.isEmpty
                            ? Colors.grey
                            : primaryBlue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "Start Navigation",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, {bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isBlue ? darkBlue : Colors.black87,
          ),
        ),
      ],
    );
  }
}
