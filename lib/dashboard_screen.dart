import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'route_preview_screen.dart';
import 'services/map_matching_service.dart';
import 'profile_screen.dart';
import 'report_accident_screen.dart';
import 'services/location_tracking_service.dart';
import 'services/marker_animation_service.dart';
import 'services/osrm_service.dart'; // 🟢 Added import for OSRM Service

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
  // ==========================================
  // UI & NAVIGATION STATE
  // ==========================================
  int _selectedTabIndex = 0;
  bool _isTrackingCamera = true;

  // ==========================================
  // MAP & TRACKING STATE
  // ==========================================
  LatLng? currentLocation;
  GoogleMapController? mapController;
  final LocationTrackingService locationService = LocationTrackingService();

  DateTime? _lastApiCallTime;
  BitmapDescriptor? _roundedMarker;

  @override
  void initState() {
    super.initState();

    _createRoundedMarker();

    locationService.startTracking((location) {
      if (!mounted) return;

      final rawLocation = LatLng(location.latitude, location.longitude);
      final now = DateTime.now();

      // 1. Instantly move the marker visually
      _animateMarkerTo(rawLocation);

      // 2. Fetch road-snap data in the background (throttled 4s)
      if (_lastApiCallTime == null ||
          now.difference(_lastApiCallTime!).inSeconds >= 4) {
        _lastApiCallTime = now;
        _fetchSnappedLocationInBackground(rawLocation);
      }
    });
  }

  // ==========================================
  // HELPER: ANIMATE MARKER & CAMERA
  // ==========================================
  void _animateMarkerTo(LatLng targetLocation) {
    if (currentLocation == null) {
      setState(() => currentLocation = targetLocation);
      // Snap camera on the very first load
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(targetLocation, 17.5),
      );
      return;
    }

    // Auto-move the camera ONLY if the user hasn't dragged the map
    if (_isTrackingCamera) {
      mapController?.animateCamera(CameraUpdate.newLatLng(targetLocation));
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

  // ==========================================
  // CUSTOM MARKER GENERATOR
  // ==========================================
  Future<void> _createRoundedMarker() async {
    const int size = 100;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint glowPaint = Paint()..color = Colors.blue.withOpacity(0.3);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.0, glowPaint);

    final Paint whiteBorder = Paint()..color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 3.0,
      whiteBorder,
    );

    final Paint innerCore = Paint()..color = Colors.blue;
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 4.0, innerCore);

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      size,
      size,
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (mounted) {
      setState(() {
        _roundedMarker = BitmapDescriptor.fromBytes(
          byteData!.buffer.asUint8List(),
        );
      });
    }
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

  // ==========================================
  // WIDGET: MAP VIEW
  // ==========================================
  Widget _buildMapTab() {
    return currentLocation == null || _roundedMarker == null
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              Listener(
                onPointerDown: (_) {
                  setState(() => _isTrackingCamera = false);
                },
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: currentLocation!,
                    zoom: 17.5,
                  ),
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  onMapCreated: (controller) {
                    mapController = controller;
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId("current_location"),
                      position: currentLocation!,
                      icon: _roundedMarker!,
                      anchor: const Offset(0.5, 0.5),
                    ),
                  },
                ),
              ),

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
                  child: TextField(
                    // 🟢 CHANGED: Now uses async OSRM Geocoding
                    onSubmitted: (value) async {
                      if (currentLocation != null && value.isNotEmpty) {
                        // 1. Show a quick loading message
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Searching for '$value'...")),
                        );

                        // 2. Fetch the REAL coordinates from Nominatim (OSRM)
                        LatLng? realDestination =
                            await OsrmService.getCoordinatesFromText(value);

                        if (!mounted) return;

                        // 3. If found, go to the Preview Screen
                        if (realDestination != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RoutePreviewScreen(
                                startLocation: currentLocation!,
                                destination: realDestination,
                                destinationName: value.toUpperCase(),
                              ),
                            ),
                          );
                        } else {
                          // 4. If not found, tell the user
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Could not find that location. Try again! ❌",
                              ),
                            ),
                          );
                        }
                      }
                    },
                    decoration: InputDecoration(
                      hintText: "Search Destination...",
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
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
                        mapController?.animateCamera(CameraUpdate.zoomIn());
                      },
                    ),
                    const SizedBox(height: 10),
                    FloatingActionButton(
                      heroTag: "zoomOut",
                      mini: true,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.remove, color: Colors.black87),
                      onPressed: () {
                        mapController?.animateCamera(CameraUpdate.zoomOut());
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
                          mapController?.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: currentLocation!,
                                zoom: 19.5,
                                tilt: 45.0,
                              ),
                            ),
                          );
                        }

                        try {
                          Position pos = await Geolocator.getCurrentPosition(
                            desiredAccuracy: LocationAccuracy.high,
                          );
                          LatLng freshLoc = LatLng(pos.latitude, pos.longitude);

                          _animateMarkerTo(freshLoc);
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
