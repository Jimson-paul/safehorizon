import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationTrackingService {
  StreamSubscription<Position>? _positionStream;

  /// Start listening to GPS updates
  Future<void> startTracking(Function(LatLng) onLocationUpdate) async {
    // Prevent multiple streams running
    if (_positionStream != null) return;

    // Check if GPS service is enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    // Check permission
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    // GPS update settings (FILTERED)
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 5, // only update every 5 meters
    );

    // Start GPS stream
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: locationSettings,
        ).listen((Position position) {
          final LatLng location = LatLng(position.latitude, position.longitude);

          onLocationUpdate(location);
        });
  }

  /// Stop GPS tracking (called when screen closes)
  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _positionStream = null;
  }
}
