import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePreviewScreen extends StatefulWidget {
  final LatLng currentLocation;
  final LatLng destination;
  final List<LatLng> routePoints;
  final double duration;

  const RoutePreviewScreen({
    super.key,
    required this.currentLocation,
    required this.destination,
    required this.routePoints,
    required this.duration,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen> {
  final MapController mapController = MapController();

  String formatDuration(double seconds) {
    final hours = (seconds ~/ 3600);
    final minutes = ((seconds % 3600) ~/ 60);

    return hours > 0 ? "$hours hr $minutes min" : "$minutes min";
  }

  @override
  void initState() {
    super.initState();

    /// Wait until map is built, then fit route
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fitRoute();
    });
  }

  void fitRoute() {
    if (widget.routePoints.isEmpty) return;

    double minLat = widget.routePoints.first.latitude;
    double maxLat = widget.routePoints.first.latitude;
    double minLng = widget.routePoints.first.longitude;
    double maxLng = widget.routePoints.first.longitude;

    for (var p in widget.routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));

    mapController.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: widget.currentLocation,
              initialZoom: 13,
            ),
            children: [
              /// MAP TILE LAYER
              TileLayer(
                urlTemplate:
                    "https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.safehorizon",
                minZoom: 2,
                maxZoom: 19,
              ),

              /// ROUTE LINE
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints,
                    strokeWidth: 5,
                    color: Colors.blue,
                  ),
                ],
              ),

              /// LOCATION MARKERS
              MarkerLayer(
                markers: [
                  Marker(
                    point: widget.currentLocation,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.blue,
                      size: 45,
                    ),
                  ),
                  Marker(
                    point: widget.destination,
                    width: 50,
                    height: 50,
                    child: const Icon(
                      Icons.location_pin,
                      color: Colors.red,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ],
          ),

          /// Bottom route panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 15,
                    color: Colors.black12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formatDuration(widget.duration),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text("Start"),
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
}
