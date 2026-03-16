import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'route_preview_screen.dart';
import 'services/map_matching_service.dart';
import 'profile_screen.dart';
import 'report_accident_screen.dart';
import 'services/location_tracking_service.dart';
import 'services/marker_animation_service.dart';
import 'services/osrm_service.dart';

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String userEmail;
  final String? userPhone;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.userEmail,
    required this.userPhone,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _selectedTabIndex = 0;
  bool _isTrackingCamera = true;

  LatLng? currentLocation;
  final MapController mapController = MapController();
  final LocationTrackingService locationService = LocationTrackingService();
  DateTime? _lastApiCallTime;

  @override
  void initState() {
    super.initState();

    locationService.startTracking((location) {
      if (!mounted) return;

      final rawLocation = LatLng(location.latitude, location.longitude);
      final now = DateTime.now();

      _animateMarkerTo(rawLocation);

      if (_lastApiCallTime == null ||
          now.difference(_lastApiCallTime!).inSeconds >= 4) {
        _lastApiCallTime = now;
        _fetchSnappedLocationInBackground(rawLocation);
      }
    });
  }

  void _animateMarkerTo(LatLng targetLocation) {
    if (currentLocation == null) {
      setState(() => currentLocation = targetLocation);
      return;
    }

    if (_isTrackingCamera) {
      mapController.move(targetLocation, mapController.camera.zoom);
    }

    MarkerAnimationService.animate(
      vsync: this,
      start: currentLocation!,
      end: targetLocation,
      onUpdate: (value) {
        if (!mounted) return;
        setState(() {
          currentLocation = value;
        });
      },
    );
  }

  Future<void> _fetchSnappedLocationInBackground(LatLng rawLoc) async {
    try {
      final snapped = await MapMatchingService.snapToRoad(rawLoc);
      if (snapped != null && mounted) {
        _animateMarkerTo(snapped);
      }
    } catch (e) {
      debugPrint("Map matching failed: $e");
    }
  }

  @override
  void dispose() {
    locationService.stopTracking();
    MarkerAnimationService.stop();
    super.dispose();
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportAccidentScreen(userEmail: widget.userEmail),
        ),
      );
    } else if (index == 0) {
      setState(() => _selectedTabIndex = 0);
    } else if (index == 2) {
      setState(() => _selectedTabIndex = 1);
    }
  }

  int get _currentNavIndex {
    if (_selectedTabIndex == 0) return 0;
    return 2;
  }

  Widget _buildGlowingMarker() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.withOpacity(0.3),
      ),
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }

  Widget _buildMapTab() {
    return currentLocation == null
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: currentLocation!,
                  initialZoom: 17.5,
                  onPointerDown: (_, __) {
                    setState(() => _isTrackingCamera = false);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.safehorizon.app',
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: currentLocation!,
                        width: 60,
                        height: 60,
                        child: _buildGlowingMarker(),
                      ),
                    ],
                  ),
                ],
              ),

              // 🟢 THE NEW AUTOCOMPLETE SEARCH BAR
              Positioned(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Autocomplete<Map<String, dynamic>>(
                    // 1. Fetch data from Geoapify
                    optionsBuilder: (TextEditingValue textEditingValue) async {
                      if (textEditingValue.text.length < 3) {
                        return const Iterable<Map<String, dynamic>>.empty();
                      }
                      return await OsrmService.getAutocompleteSuggestions(
                        textEditingValue.text,
                      );
                    },

                    // 2. String to display
                    displayStringForOption: (option) =>
                        option['formatted'] as String,

                    // 3. Action when user taps a suggestion
                    onSelected: (Map<String, dynamic> selection) {
                      if (currentLocation != null) {
                        final destLatLng = LatLng(
                          selection['lat'],
                          selection['lon'],
                        );
                        final destName = selection['formatted'];

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RoutePreviewScreen(
                              startLocation: currentLocation!,
                              destination: destLatLng,
                              // Just grab the primary city/location name before the comma
                              destinationName: destName
                                  .toString()
                                  .split(',')[0]
                                  .toUpperCase(),
                            ),
                          ),
                        );
                      }
                    },

                    // 4. Customizing the Search Bar UI
                    fieldViewBuilder:
                        (context, controller, focusNode, onEditingComplete) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: "Search Destination (e.g. Kottayam)...",
                              hintStyle: TextStyle(color: Colors.grey.shade400),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: Colors.blue,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                              ),
                            ),
                          );
                        },

                    // 5. Customizing the dropdown list
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 8,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: MediaQuery.of(context).size.width - 40,
                            constraints: const BoxConstraints(maxHeight: 250),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final option = options.elementAt(index);
                                return ListTile(
                                  leading: const Icon(
                                    Icons.location_on_outlined,
                                    color: Colors.blue,
                                  ),
                                  title: Text(
                                    option['formatted'],
                                    style: const TextStyle(fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                right: 15,
                bottom: 30,
                child: Column(
                  children: [
                    FloatingActionButton(
                      heroTag: "zoomIn",
                      mini: true,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.add, color: Colors.black87),
                      onPressed: () {
                        mapController.move(
                          mapController.camera.center,
                          mapController.camera.zoom + 1,
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.remove, color: Colors.black87),
                      onPressed: () {
                        mapController.move(
                          mapController.camera.center,
                          mapController.camera.zoom - 1,
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    FloatingActionButton(
                      heroTag: "myLocation",
                      backgroundColor: _isTrackingCamera
                          ? Colors.blue
                          : Colors.white,
                      child: Icon(
                        Icons.my_location,
                        color: _isTrackingCamera ? Colors.white : Colors.blue,
                      ),
                      onPressed: () async {
                        setState(() => _isTrackingCamera = true);

                        if (currentLocation != null) {
                          mapController.move(currentLocation!, 17.5);
                        }

                        try {
                          Position pos = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high,
                          );
                          _animateMarkerTo(LatLng(pos.latitude, pos.longitude));
                        } catch (e) {
                          debugPrint("Manual GPS fetch failed: $e");
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedTabIndex,
        children: [
          _buildMapTab(),
          ProfileScreen(
            name: widget.userName,
            email: widget.userEmail,
            phone: widget.userPhone,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onBottomNavTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline, size: 28),
            label: "Report",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}
