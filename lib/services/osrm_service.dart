import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';

// A simple class to hold our turn-by-turn data
class RouteStep {
  final LatLng location;
  final String instruction;

  RouteStep({required this.location, required this.instruction});
}

class OsrmService {
  // 🟢 YOUR API KEYS
  static const String _orsApiKey =
      'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6ImRlNTEyNmVlNDhmMTQzOTg5MTMyYTAwNDhjMDc1OTI4IiwiaCI6Im11cm11cjY0In0=';
  static const String _geoapifyKey = "fd24e74b5e854fa4981cdd39f8452044";

  // ==========================================
  // 1. ROUTING (Using high-speed ORS API)
  // ==========================================
  static Future<Map<String, dynamic>?> getRoute(
    LatLng start,
    LatLng destination,
  ) async {
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
        final segments = route['properties']['segments'] as List;

        // 1. Convert line points
        List<LatLng> points = coords.map<LatLng>((c) {
          return LatLng(c[1].toDouble(), c[0].toDouble());
        }).toList();

        // 2. Extract Turn-by-Turn Steps
        List<RouteStep> turnByTurnSteps = [];
        if (segments.isNotEmpty && segments[0]['steps'] != null) {
          final stepsList = segments[0]['steps'] as List;

          for (var step in stepsList) {
            int coordIndex = step['way_points'][0];
            String instruction = step['instruction'];

            turnByTurnSteps.add(
              RouteStep(location: points[coordIndex], instruction: instruction),
            );
          }
        }

        double distanceKm = summary['distance'] / 1000;
        int durationMin = (summary['duration'] / 60).ceil();

        return {
          'points': points,
          'distance': '${distanceKm.toStringAsFixed(1)} km',
          'time': '$durationMin min',
          'steps': turnByTurnSteps,
        };
      } else {
        debugPrint("❌ ORS API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Failed to fetch ORS route: $e");
    }
    return null;
  }

  // ==========================================
  // 2. SEARCH BAR (Using Nominatim OSM)
  // ==========================================
  static Future<LatLng?> getCoordinatesFromText(String query) async {
    final String encodedQuery = Uri.encodeComponent(query);
    final String url =
        'https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=1';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'SafeHorizonApp/1.0 (Flutter Demo)',
          'Accept-Language': 'en-US,en;q=0.9',
        },
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
      debugPrint("❌ Search Geocoding failed: $e");
    }
    return null;
  }

  // ==========================================
  // 3. AUTOCOMPLETE (Using Geoapify)
  // ==========================================
  static Future<List<Map<String, dynamic>>> getAutocompleteSuggestions(
    String query,
  ) async {
    final String encodedQuery = Uri.encodeComponent(query);
    final String url =
        'https://api.geoapify.com/v1/geocode/autocomplete?text=$encodedQuery&apiKey=$_geoapifyKey&limit=5';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features.map((f) {
          return {
            'formatted': f['properties']['formatted'],
            'lat': f['properties']['lat'],
            'lon': f['properties']['lon'],
          };
        }).toList();
      }
    } catch (e) {
      debugPrint("Autocomplete API failed: $e");
    }
    return [];
  }
}
