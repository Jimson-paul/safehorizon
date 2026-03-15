import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart'; // 🟢 Swapped to OpenStreetMap coordinates

class MapMatchingService {
  static Future<LatLng?> snapToRoad(LatLng location) async {
    final url = Uri.parse(
      "https://router.project-osrm.org/nearest/v1/driving/"
      "${location.longitude},${location.latitude}",
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data["code"] == "Ok" &&
            data["waypoints"] != null &&
            data["waypoints"].isNotEmpty) {
          final snapped = data["waypoints"][0]["location"];

          // OSRM returns [lon, lat], latlong2 expects (lat, lon)
          // Adding .toDouble() for safety just in case the API returns an integer
          return LatLng(snapped[1].toDouble(), snapped[0].toDouble());
        }
      }
    } catch (e) {
      // It's good practice to catch network errors silently in background services
      // so it doesn't crash the app if the user loses connection briefly.
      print("Map matching failed: $e");
    }

    return null;
  }
}
