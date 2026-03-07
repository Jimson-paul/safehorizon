import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RoutingService {
  static Future<Map<String, dynamic>?> getRoute(
    LatLng start,
    LatLng end,
  ) async {
    final url =
        "http://router.project-osrm.org/route/v1/driving/"
        "${start.longitude},${start.latitude};"
        "${end.longitude},${end.latitude}"
        "?overview=full&geometries=geojson";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      final route = data["routes"][0];

      final coords = route["geometry"]["coordinates"];

      List<LatLng> points = coords.map<LatLng>((c) {
        return LatLng(c[1], c[0]); // lat, lon order
      }).toList();

      return {
        "points": points,
        "distance": route["distance"],
        "duration": route["duration"],
      };
    }

    return null;
  }
}
