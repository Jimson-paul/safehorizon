import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'profile_screen.dart';
import 'report_accident_screen.dart';

class DashboardScreen extends StatelessWidget {
  final String userName;
  final String userEmail;
  final String? userPhone; // ✅ NEW

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone, // ✅ NEW
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB)],
          ),
        ),
        child: Stack(
          children: [
            /// ================= MAP =================
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(12.9716, 77.5946),
                initialZoom: 13,
              ),
              children: [
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.safehorizon",
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(12.9716, 77.5946),
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.location_pin,
                        size: 50,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            /// ================= SEARCH BAR =================
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

            /// ================= BOTTOM NAV =================
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
                    /// HOME
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
                            builder: (_) =>
                                ReportAccidentScreen(userEmail: userEmail),
                          ),
                        );
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, color: Colors.blue),
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
                              name: userName,
                              email: userEmail,
                              phone: userPhone, // ✅ PASS PHONE
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
