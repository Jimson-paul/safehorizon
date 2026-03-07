import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationSearchService {
  static Future<Map<String, double>?> searchPlace(String query) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search?q=$query&format=json&limit=1",
    );

    final response = await http.get(
      url,
      headers: {"User-Agent": "safehorizon-app"},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data.isNotEmpty) {
        return {
          "lat": double.parse(data[0]["lat"]),
          "lon": double.parse(data[0]["lon"]),
        };
      }
    }

    return null;
  }
}
