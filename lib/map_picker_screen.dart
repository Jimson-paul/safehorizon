import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedLocation;
  LatLng? currentLocation;

  final MapController mapController = MapController();

  bool mapReady = false;

  // ================= GET GPS LOCATION =================
  Future<void> getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      currentLocation = LatLng(position.latitude, position.longitude);

      setState(() {});
    } catch (e) {
      debugPrint("Location error: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    getUserLocation();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select Location"),
        backgroundColor: Colors.blue,
      ),

      // ✅ WAIT UNTIL GPS LOADS
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              mapController: mapController,
              options: MapOptions(
                // ✅ START DIRECTLY AT GPS LOCATION
                initialCenter: currentLocation!,
                initialZoom: 17,

                onMapReady: () {
                  mapReady = true;
                },

                onTap: (tapPosition, point) {
                  setState(() {
                    selectedLocation = point;
                  });
                },
              ),
              children: [
                /// MAP TILES
                TileLayer(
                  urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                  userAgentPackageName: "com.example.safehorizon",
                ),

                /// CURRENT GPS MARKER
                MarkerLayer(
                  markers: [
                    Marker(
                      point: currentLocation!,
                      width: 50,
                      height: 50,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 42,
                      ),
                    ),
                  ],
                ),

                /// SELECTED LOCATION MARKER
                if (selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: selectedLocation!,
                        width: 50,
                        height: 50,
                        child: const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 45,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.check),
        onPressed: () {
          Navigator.pop(context, selectedLocation);
        },
      ),
    );
  }
}
