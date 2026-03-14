import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/material.dart';

class OsrmService {
  static const String _routingUrl =
      'http://router.project-osrm.org/route/v1/driving';
  static const String _geocodeUrl =
      'https://nominatim.openstreetmap.org/search';

  /// Fetches a route between two LatLng points
  static Future<Map<String, dynamic>?> getRoute(
    LatLng start,
    LatLng destination,
  ) async {
    // 🟢 CHANGED: Requested polyline6 for maximum road-snapping accuracy
    final String url =
        '$_routingUrl/${start.longitude},${start.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline6&steps=true';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['code'] == 'Ok' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          double distanceKm = route['distance'] / 1000;
          int timeMinutes = (route['duration'] / 60).ceil();

          String encodedPolyline = route['geometry'];
          List<LatLng> routePoints = _decodePolyline6(encodedPolyline);

          return {
            'points': routePoints,
            'distance': '${distanceKm.toStringAsFixed(1)} km',
            'time': '$timeMinutes min',
          };
        }
      } else {
        debugPrint("OSRM Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Failed to fetch OSRM route: $e");
    }
    return null;
  }

  /// Converts a text address into LatLng coordinates using Nominatim
  static Future<LatLng?> getCoordinatesFromText(String query) async {
    final String url = '$_geocodeUrl?q=$query&format=json&limit=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'SafeHorizonApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.isNotEmpty) {
          double lat = double.parse(data[0]['lat']);
          double lon = double.parse(data[0]['lon']);
          return LatLng(lat, lon);
        }
      } else {
        debugPrint("Nominatim Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Failed to fetch coordinates: $e");
    }
    return null;
  }

  /// 🟢 CHANGED: Helper function updated for Polyline6 precision math (1E6)
  static List<LatLng> _decodePolyline6(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      // Polyline6 uses a precision factor of 10^6
      points.add(LatLng(lat / 1000000.0, lng / 1000000.0));
    }
    return points;
  }
}
