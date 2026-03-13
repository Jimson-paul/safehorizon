import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  GoogleMapController? mapController;

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
    if (widget.routePoints.isEmpty || mapController == null) return;

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

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.currentLocation,
              zoom: 13,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              fitRoute();
            },

            polylines: {
              Polyline(
                polylineId: const PolylineId("route"),
                points: widget.routePoints,
                color: Colors.blue,
                width: 5,
              ),
            },

            markers: {
              Marker(
                markerId: const MarkerId("current_location"),
                position: widget.currentLocation,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueBlue,
                ),
              ),
              Marker(
                markerId: const MarkerId("destination"),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
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
