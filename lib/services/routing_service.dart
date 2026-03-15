import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

class OsrmService {
  // 🟢 1. PASTE YOUR COPIED ORS API KEY INSIDE THESE QUOTES
  static const String _orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRlNTEyNmVlNDhmMTQzOTg5MTMyYTAwNDhjMDc1OTI4IiwiaCI6Im11cm11cjY0In0=';

  // ==========================================
  // 1. ROUTING (Using your new high-speed ORS API)
  // ==========================================
  static Future<Map<String, dynamic>?> getRoute(
    LatLng start,
    LatLng destination,
  ) async {
    // ORS requires [Longitude, Latitude] format
    final String url =
        'https://api.openrouteservice.org/v2/directions/driving-car'
        '?api_key=$_orsApiKey'
        '&start=${start.longitude},${start.latitude}'
        '&end=${destination.longitude},${destination.latitude}';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final route = data['features'][0];
        final coords = route['geometry']['coordinates'] as List;
        final summary = route['properties']['summary'];

        // Convert GeoJSON [lon, lat] to FlutterMap LatLng(lat, lon)
        List<LatLng> points = coords.map<LatLng>((c) {
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();

        // Format for your UI
        double distanceKm = summary['distance'] / 1000;
        int durationMin = (summary['duration'] / 60).ceil();

        return {
          'points': points,
          'distance': '${distanceKm.toStringAsFixed(1)} km',
          'time': '$durationMin min',
        };
      } else {
        debugPrint("ORS API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Failed to fetch ORS route: $e");
    }
    return null;
  }

  // ==========================================
  // 2. SEARCH BAR (Using Nominatim OSM - completely free)
  // ==========================================
  static Future<LatLng?> getCoordinatesFromText(String query) async {
    final String url =
        'https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'SafeHorizonApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.isNotEmpty) {
          return LatLng(
            double.parse(data[0]['lat']),
            double.parse(data[0]['lon']),
          );
        }
      }
    } catch (e) {
      debugPrint("Search Geocoding failed: $e");
    }
    return null;
  }
}
