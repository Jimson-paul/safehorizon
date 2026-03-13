import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapMatchingService {
  static Future<LatLng?> snapToRoad(LatLng location) async {
    final url = Uri.parse(
      "https://router.project-osrm.org/nearest/v1/driving/"
      "${location.longitude},${location.latitude}",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final snapped = data["waypoints"][0]["location"];

      return LatLng(snapped[1], snapped[0]);
    }

    return null;
  }
}
