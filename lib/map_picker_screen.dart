import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedLocation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        backgroundColor: Colors.blue,
      ),

      body: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(12.9716, 77.5946),
          initialZoom: 13,

          // 👇 User taps map to choose location
          onTap: (tapPosition, point) {
            setState(() {
              selectedLocation = point;
            });
          },
        ),

        children: [
          /// ================= MAP TILES =================
          TileLayer(
            urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
            userAgentPackageName: "com.example.safehorizon",
          ),

          /// ================= SELECTED MARKER =================
          if (selectedLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: selectedLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ],
            ),
        ],
      ),

      /// ================= CONFIRM BUTTON =================
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),

        onPressed: () {
          // return selected coordinates to previous screen
          Navigator.pop(context, selectedLocation);
        },
      ),
    );
  }
}
