import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/poi_service.dart';

class PoiActionButtons extends StatefulWidget {
  final LatLng? currentLocation;
  final Function(List<Marker>)
  onMarkersUpdated; // 🟢 Passes the markers back to the main map

  const PoiActionButtons({
    Key? key,
    required this.currentLocation,
    required this.onMarkersUpdated,
  }) : super(key: key);

  @override
  State<PoiActionButtons> createState() => _PoiActionButtonsState();
}

class _PoiActionButtonsState extends State<PoiActionButtons> {
  bool _isLoading = false;
  String _activeCategory = "";

  Future<void> _handlePoiClick(
    String title,
    IconData icon,
    Color color,
    String tagKey,
    String tagValue,
  ) async {
    if (widget.currentLocation == null) return;

    // Toggle off if clicking the same button
    if (_activeCategory == tagValue) {
      setState(() {
        _activeCategory = "";
        widget.onMarkersUpdated([]); // Send empty list to clear map
      });
      return;
    }

    // Toggle on and start loading
    setState(() {
      _isLoading = true;
      _activeCategory = tagValue;
      widget.onMarkersUpdated([]); // Clear map while fetching
    });

    final markers = await PoiService.fetchNearbyPlaces(
      location: widget.currentLocation!,
      tagKey: tagKey,
      tagValue: tagValue,
      displayIcon: icon,
      pinColor: color,
    );

    // Apply markers to the map if the user hasn't clicked away
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (_activeCategory == tagValue) {
          widget.onMarkersUpdated(markers);
        }
      });
    }
  }

  Widget _buildButton(
    IconData icon,
    Color color,
    String tagKey,
    String tagValue,
  ) {
    bool isActive = _activeCategory == tagValue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: FloatingActionButton(
        heroTag: tagValue, // Prevents Flutter errors when using multiple FABs
        mini: true,
        backgroundColor: isActive ? color : Colors.white,
        onPressed: () => _handlePoiClick("POI", icon, color, tagKey, tagValue),
        child: Icon(icon, color: isActive ? Colors.white : color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildButton(Icons.restaurant, Colors.orange, "amenity", "restaurant"),
        _buildButton(Icons.local_gas_station, Colors.purple, "amenity", "fuel"),
        _buildButton(Icons.local_hospital, Colors.red, "amenity", "hospital"),
        _buildButton(Icons.hotel, Colors.teal, "tourism", "hotel"),

        // Loading Spinner
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}
