import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Safe Horizon Map"), centerTitle: true),
      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(12.9716, 77.5946), // Bangalore (example)
          initialZoom: 13,
        ),

        children: [
          /// ✅ THIS LOADS THE REAL MAP
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: "com.example.safehorizon",
          ),

          /// ✅ Marker
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
    );
  }
}
