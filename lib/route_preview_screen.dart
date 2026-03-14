import 'dart:math';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'services/location_tracking_service.dart';
import 'services/marker_animation_service.dart';
import 'services/osrm_service.dart'; // 🟢 Fixed import to OSRM

class RoutePreviewScreen extends StatefulWidget {
  final LatLng startLocation;
  final LatLng destination;
  final String destinationName;

  const RoutePreviewScreen({
    super.key,
    required this.startLocation,
    required this.destination,
    required this.destinationName,
  });

  @override
  State<RoutePreviewScreen> createState() => _RoutePreviewScreenState();
}

class _RoutePreviewScreenState extends State<RoutePreviewScreen>
    with TickerProviderStateMixin {
  GoogleMapController? mapController;
  final LocationTrackingService locationService = LocationTrackingService();

  // State variables
  bool _isNavigating = false;
  LatLng? _currentLocation;
  BitmapDescriptor? _roundedMarker;
  Set<Polyline> _polylines = {};

  // Dynamic state variables for OSRM data
  String _eta = "Calculating...";
  String _distance = "...";

  // Theme Colors matching your mockup
  final Color primaryBlue = const Color(0xFF51A8E7);
  final Color darkBlue = const Color(0xFF1B6AAB);

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.startLocation;
    _createRoundedMarker();
    _fetchRealRoute(); // 🟢 Calls the real API instead of the mock route
  }

  // ==========================================
  // CUSTOM MARKER
  // ==========================================
  Future<void> _createRoundedMarker() async {
    const int size = 100;
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    final Paint glowPaint = Paint()..color = primaryBlue.withOpacity(0.3);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2.0, glowPaint);

    final Paint whiteBorder = Paint()..color = Colors.white;
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 3.0,
      whiteBorder,
    );

    final Paint innerCore = Paint()..color = primaryBlue;
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

  // ==========================================
  // ROUTING LOGIC
  // ==========================================
  Future<void> _fetchRealRoute() async {
    final routeData = await OsrmService.getRoute(
      widget.startLocation,
      widget.destination,
    );

    if (routeData != null && mounted) {
      final List<LatLng> points = routeData['points'];

      setState(() {
        _eta = routeData['time'];
        _distance = routeData['distance'];

        // 🟢 NEW: Double polyline trick for the "Casing" effect
        _polylines = {
          // 1. The Background Border (Thicker, Darker)
          Polyline(
            polylineId: const PolylineId("route_outline"),
            points: points,
            color: darkBlue, // Your dark blue theme color
            width: 8, // Thicker width
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            zIndex: 0, // Renders underneath
          ),
          // 2. The Foreground Fill (Thinner, Lighter)
          Polyline(
            polylineId: const PolylineId("route_fill"),
            points: points,
            color: primaryBlue, // Your bright blue theme color
            width: 4, // Thinner width
            jointType: JointType.round,
            startCap: Cap.roundCap,
            endCap: Cap.roundCap,
            zIndex: 1, // Renders on top
          ),
        };
      });

      // 🟢 Automatically bounds the camera to the high-precision route
      _animateCameraToBounds(points);
    } else if (mounted) {
      // In case of error (e.g. no internet or invalid coordinates)
      setState(() {
        _eta = "Error";
        _distance = "Error";
      });
    }
  }

  // 🟢 NEW: Calculates the bounding box of the entire route and zooms the map
  void _animateCameraToBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // Add 80 pixels of padding so the route isn't hidden under your custom headers/bottom sheets
    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _startNavigation() {
    setState(() {
      _isNavigating = true;
    });

    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 19.5, tilt: 45.0),
      ),
    );

    locationService.startTracking((location) {
      if (!mounted) return;
      final newLoc = LatLng(location.latitude, location.longitude);

      MarkerAnimationService.animate(
        vsync: this,
        start: _currentLocation!,
        end: newLoc,
        onUpdate: (value) {
          if (!mounted) return;
          setState(() => _currentLocation = value);
        },
      );

      mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: newLoc, zoom: 19.5, tilt: 45.0, bearing: 0.0),
        ),
      );
    });
  }

  @override
  void dispose() {
    locationService.stopTracking();
    MarkerAnimationService.stop();
    super.dispose();
  }

  // ==========================================
  // UI WIDGETS
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. THE MAP
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: widget.startLocation,
              zoom: 14,
            ),
            padding: EdgeInsets.only(
              top: _isNavigating ? 0 : 100,
              bottom: _isNavigating ? 100 : 250,
            ),
            polylines: _polylines,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              mapController = controller;
              // 🟢 Removed old Future.delayed bounds check - _animateCameraToBounds handles it when the route loads!
            },
            markers: {
              if (_roundedMarker != null)
                Marker(
                  markerId: const MarkerId("user_nav_marker"),
                  position: _currentLocation!,
                  icon: _roundedMarker!,
                  anchor: const Offset(0.5, 0.5),
                ),
              Marker(
                markerId: const MarkerId("destination_marker"),
                position: widget.destination,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueRed,
                ),
              ),
            },
          ),

          // 2. TOP HEADER (Hidden during active navigation)
          if (!_isNavigating)
            Align(alignment: Alignment.topCenter, child: _buildTopHeader()),

          // 3. BOTTOM SHEET
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: EdgeInsets.only(
                bottom: 24,
                left: _isNavigating ? 20 : 16,
                right: _isNavigating ? 20 : 16,
              ),
              child: _isNavigating
                  ? _buildActiveNavInfo()
                  : _buildPreviewInfo(),
            ),
          ),
        ],
      ),
    );
  }

  // --- HEADER WIDGET ---
  Widget _buildTopHeader() {
    return Container(
      width: double.infinity,
      color: primaryBlue,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        bottom: 16,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 8,
            top: -4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Text(
            "Route Preview",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // --- PREVIEW BOTTOM SHEET WIDGET ---
  Widget _buildPreviewInfo() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryBlue, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // GRID DATA
          Row(
            children: [
              Expanded(
                child: _buildInfoItem(
                  "Destination:",
                  widget.destinationName,
                  isBlue: true,
                ),
              ),
              Expanded(child: _buildInfoItem("Estimated Travel Time:", _eta)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _buildInfoItem("Distance:", _distance)),
              Expanded(
                child: _buildRiskItem("Overall Route Risk:", "Medium Risk"),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // START BUTTON
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _startNavigation,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                "Start Navigation",
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER FOR GRID TEXT ---
  Widget _buildInfoItem(String label, String value, {bool isBlue = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isBlue ? darkBlue : Colors.black87,
          ),
        ),
      ],
    );
  }

  // --- HELPER FOR RISK ICON ---
  Widget _buildRiskItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text("⚠️", style: TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- ACTIVE NAVIGATION BOTTOM SHEET ---
  Widget _buildActiveNavInfo() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _eta,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text(
                "$_distance • 2:35 PM",
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
            ],
          ),
          CircleAvatar(
            radius: 25,
            backgroundColor: Colors.red.shade50,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => Navigator.pop(context), // Exit navigation
            ),
          ),
        ],
      ),
    );
  }
}
