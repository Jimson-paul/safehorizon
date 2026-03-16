import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // 🟢 Needed for Deduplication Math

class PoiService {
  // 🟢 1. YOUR API KEYS
  static const String _geoapifyKey = "fd24e74b5e854fa4981cdd39f8452044";
  static const String _foursquareKey =
      "HUUXFWETKEJNMIO4IVHFOCMPX3IIQKFT223UQDVPIE4OIJDC";

  // --- MAIN PUBLIC METHOD ---
  static Future<List<Marker>> fetchNearbyPlaces({
    required LatLng location,
    required String tagKey,
    required String tagValue,
    required IconData displayIcon,
    required Color pinColor,
  }) async {
    debugPrint("🔍 Multi-Source: Searching for $tagValue...");

    // 🟢 2. CONCURRENCY: Fire both APIs at the exact same time!
    final List<List<Marker>> results = await Future.wait([
      _fetchFromGeoapify(location, tagValue, displayIcon, pinColor),
      _fetchFromFoursquare(location, tagValue, displayIcon, pinColor),
    ]);

    // Flatten the two lists into one massive list
    List<Marker> combinedRawMarkers = [...results[0], ...results[1]];

    // 🟢 3. SPATIAL DEDUPLICATION (The "Anti-Clump" Filter)
    List<Marker> cleanMarkers = [];

    for (var rawMarker in combinedRawMarkers) {
      bool isDuplicate = false;

      // Check if this new marker is too close to one we already saved
      for (var cleanMarker in cleanMarkers) {
        double distance = Geolocator.distanceBetween(
          rawMarker.point.latitude,
          rawMarker.point.longitude,
          cleanMarker.point.latitude,
          cleanMarker.point.longitude,
        );

        // If it's within 40 meters of an existing pin, it's the same building!
        if (distance < 40.0) {
          isDuplicate = true;
          break;
        }
      }

      if (!isDuplicate) {
        cleanMarkers.add(rawMarker);
      }
    }

    debugPrint(
      "✅ Multi-Source Success: Combined and filtered down to ${cleanMarkers.length} unique $tagValue(s).",
    );
    return cleanMarkers;
  }

  // --- GEOAPIFY WORKER ---
  static Future<List<Marker>> _fetchFromGeoapify(
    LatLng location,
    String tagValue,
    IconData icon,
    Color color,
  ) async {
    String category = "";
    switch (tagValue) {
      case "restaurant":
        category = "catering.restaurant,catering.fast_food";
        break;
      case "fuel":
        category = "commercial.gas";
        break;
      case "hospital":
        category = "healthcare.hospital,healthcare.clinic";
        break;
      case "hotel":
        category = "accommodation";
        break;
      default:
        category = "commercial";
    }

    final url = Uri.parse(
      'https://api.geoapify.com/v2/places?categories=$category'
      '&filter=circle:${location.longitude},${location.latitude},5000'
      '&limit=50&apiKey=$_geoapifyKey',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final features = data['features'] as List;

        return features
            .map(
              (f) => _buildMarker(
                f['properties']['lat'],
                f['properties']['lon'],
                icon,
                color,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint("💥 Geoapify failed, but Foursquare will keep going!");
    }
    return [];
  }

  // --- FOURSQUARE WORKER ---
  static Future<List<Marker>> _fetchFromFoursquare(
    LatLng location,
    String tagValue,
    IconData icon,
    Color color,
  ) async {
    // Foursquare uses specific Category IDs
    String categoryId = "";
    switch (tagValue) {
      case "restaurant":
        categoryId = "13065";
        break; // Restaurants
      case "fuel":
        categoryId = "19006";
        break; // Gas Stations
      case "hospital":
        categoryId = "15014";
        break; // Hospitals
      case "hotel":
        categoryId = "19014";
        break; // Hotels
      default:
        categoryId = "";
    }

    final url = Uri.parse(
      'https://api.foursquare.com/v3/places/search?'
      'll=${location.latitude},${location.longitude}'
      '&radius=5000&categories=$categoryId&limit=50',
    );

    try {
      final response = await http
          .get(
            url,
            headers: {
              'Authorization': _foursquareKey,
              'accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;

        return results
            .map(
              (r) => _buildMarker(
                r['geocodes']['main']['latitude'],
                r['geocodes']['main']['longitude'],
                icon,
                color,
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint("💥 Foursquare failed, but Geoapify will keep going!");
    }
    return [];
  }

  // --- UI HELPER ---
  static Marker _buildMarker(
    double lat,
    double lon,
    IconData icon,
    Color color,
  ) {
    return Marker(
      point: LatLng(lat, lon),
      width: 50,
      height: 50,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
