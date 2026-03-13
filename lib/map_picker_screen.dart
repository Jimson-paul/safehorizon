import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedLocation;
  LatLng? currentLocation;

  GoogleMapController? mapController;

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

      // WAIT UNTIL GPS LOADS
      body: currentLocation == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: currentLocation!,
                zoom: 17,
              ),

              onMapCreated: (controller) {
                mapController = controller;
              },

              // TAP TO SELECT LOCATION
              onTap: (LatLng point) {
                setState(() {
                  selectedLocation = point;
                });
              },

              markers: {
                // CURRENT LOCATION MARKER
                Marker(
                  markerId: const MarkerId("current_location"),
                  position: currentLocation!,
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue,
                  ),
                ),

                // SELECTED LOCATION MARKER
                if (selectedLocation != null)
                  Marker(
                    markerId: const MarkerId("selected_location"),
                    position: selectedLocation!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueRed,
                    ),
                  ),
              },
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
