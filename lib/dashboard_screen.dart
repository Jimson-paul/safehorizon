import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'services/map_matching_service.dart';
import 'profile_screen.dart';
import 'report_accident_screen.dart';
import 'services/location_tracking_service.dart';
import 'services/marker_animation_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userPhone;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  LatLng? currentLocation;
  LatLng? previousLocation;

  GoogleMapController? mapController;

  final LocationTrackingService locationService = LocationTrackingService();

  final List<LatLng> gpsBuffer = [];

  LatLng? lastGpsLocation;
  DateTime? lastGpsTime;

  /// Smooth GPS using moving average
  LatLng smoothLocation(LatLng newPoint) {
    gpsBuffer.add(newPoint);

    if (gpsBuffer.length > 5) {
      gpsBuffer.removeAt(0);
    }

    double lat = 0;
    double lng = 0;

    for (var p in gpsBuffer) {
      lat += p.latitude;
      lng += p.longitude;
    }

    return LatLng(lat / gpsBuffer.length, lng / gpsBuffer.length);
  }

  /// Distance calculation
  double distance(LatLng a, LatLng b) {
    const double R = 6371000;

    double dLat = (b.latitude - a.latitude) * (pi / 180);
    double dLng = (b.longitude - a.longitude) * (pi / 180);

    double lat1 = a.latitude * (pi / 180);
    double lat2 = b.latitude * (pi / 180);

    double x = dLng * ((lat1 + lat2) / 2);
    double y = dLat;

    return R * sqrt(x * x + y * y);
  }

  /// Dead reckoning prediction
  LatLng predictLocation(LatLng previous, LatLng current, double seconds) {
    double latSpeed = (current.latitude - previous.latitude) / seconds;
    double lngSpeed = (current.longitude - previous.longitude) / seconds;

    double predictedLat = current.latitude + latSpeed * seconds;
    double predictedLng = current.longitude + lngSpeed * seconds;

    return LatLng(predictedLat, predictedLng);
  }

  @override
  void initState() {
    super.initState();

    locationService.startTracking((location) async {
      if (!mounted) return;

      final rawLocation = LatLng(location.latitude, location.longitude);

      /// Snap GPS to road
      final snappedLocation = await MapMatchingService.snapToRoad(rawLocation);

      final gpsPoint = snappedLocation ?? rawLocation;

      /// Smooth GPS
      final filteredLocation = smoothLocation(gpsPoint);

      final now = DateTime.now();

      /// First GPS fix
      if (currentLocation == null || previousLocation == null) {
        setState(() {
          currentLocation = filteredLocation;
        });

        previousLocation = filteredLocation;
        lastGpsLocation = filteredLocation;
        lastGpsTime = now;
        return;
      }

      /// Ignore tiny movement (<2 meters)
      double dist = distance(previousLocation!, filteredLocation);
      if (dist < 2) return;

      LatLng targetLocation = filteredLocation;

      /// Dead reckoning prediction
      if (lastGpsLocation != null && lastGpsTime != null) {
        double seconds = now.difference(lastGpsTime!).inMilliseconds / 1000.0;

        if (seconds > 0.2) {
          targetLocation = predictLocation(
            lastGpsLocation!,
            filteredLocation,
            seconds,
          );
        }
      }

      /// Smooth marker animation
      MarkerAnimationService.animate(
        start: previousLocation!,
        end: targetLocation,
        onUpdate: (value) {
          if (!mounted) return;

          setState(() {
            currentLocation = value;
          });
        },
      );

      /// STEP 4 — update previous location
      previousLocation = targetLocation;

      /// Update prediction state
      lastGpsLocation = filteredLocation;
      lastGpsTime = now;
    });
  }

  @override
  void dispose() {
    locationService.stopTracking();
    MarkerAnimationService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 16,
                  ),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    mapController = controller;
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId("current_location"),
                      position: currentLocation!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      ),
                    ),
                  },
                ),

                /// Map controls
                Positioned(
                  left: 15,
                  top: MediaQuery.of(context).size.height * 0.35,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: "zoomIn",
                        mini: true,
                        child: const Icon(Icons.add),
                        onPressed: () {
                          mapController?.animateCamera(CameraUpdate.zoomIn());
                        },
                      ),
                      const SizedBox(height: 10),
                      FloatingActionButton(
                        heroTag: "zoomOut",
                        mini: true,
                        child: const Icon(Icons.remove),
                        onPressed: () {
                          mapController?.animateCamera(CameraUpdate.zoomOut());
                        },
                      ),
                      const SizedBox(height: 15),
                      FloatingActionButton(
                        heroTag: "myLocation",
                        mini: true,
                        child: const Icon(Icons.my_location),
                        onPressed: () {
                          mapController?.animateCamera(
                            CameraUpdate.newLatLng(currentLocation!),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
