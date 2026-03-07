import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'services/marker_animation_service.dart';

import 'profile_screen.dart';
import 'report_accident_screen.dart';
import 'services/location_tracking_service.dart';

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

  final MapController mapController = MapController();
  final LocationTrackingService locationService = LocationTrackingService();

  @override
  void initState() {
    super.initState();

    locationService.startTracking((location) {
      if (!mounted) return;

      // First GPS fix
      if (currentLocation == null) {
        setState(() {
          currentLocation = location;
        });

        mapController.move(location, 16);
        return;
      }

      // Smooth animation between GPS points
      MarkerAnimationService.animate(
        start: currentLocation!,
        end: location,
        onUpdate: (pos) {
          if (!mounted) return;

          setState(() {
            currentLocation = pos;
          });

          mapController.move(pos, mapController.camera.zoom);
        },
      );
    });
  }

  @override
  void dispose() {
    locationService.stopTracking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
                ),
              ),
              child: Stack(
                children: [
                  /// MAP
                  FlutterMap(
                    mapController: mapController,
                    options: MapOptions(
                      initialCenter: currentLocation!,
                      initialZoom: 16,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: "com.example.safehorizon",
                      ),

                      /// CURRENT LOCATION MARKER
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLocation!,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.my_location,
                              size: 45,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  /// SEARCH BAR
                  Positioned(
                    top: 60,
                    left: 20,
                    right: 20,
                    child: Container(
                      height: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.search, color: Colors.grey),
                          SizedBox(width: 10),
                          Text(
                            "Search Destination...",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                  /// BOTTOM NAV
                  Positioned(
                    bottom: 25,
                    left: 25,
                    right: 25,
                    child: Container(
                      height: 65,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(35),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.home, color: Colors.blue),
                              Text("Home", style: TextStyle(fontSize: 12)),
                            ],
                          ),

                          /// REPORT
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportAccidentScreen(
                                    userEmail: widget.userEmail,
                                  ),
                                ),
                              );
                            },
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.blue,
                                ),
                                Text("Report", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),

                          /// PROFILE
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    name: widget.userName,
                                    email: widget.userEmail,
                                    phone: widget.userPhone,
                                  ),
                                ),
                              );
                            },
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person_outline, color: Colors.blue),
                                Text("Profile", style: TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
