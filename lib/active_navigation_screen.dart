import 'dart:async';
import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'services/osrm_service.dart';
import 'services/navigation_assistant.dart';

// --- CUSTOM TWEEN FOR SMOOTH MOVEMENT ---
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
    : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

class ActiveNavigationScreen extends StatefulWidget {
  final List<LatLng> initialRoutePoints;
  final List<RouteStep> initialInstructions;
  final LatLng startLocation;
  final LatLng destination;
  final String destinationName;

  const ActiveNavigationScreen({
    super.key,
    required this.initialRoutePoints,
    required this.initialInstructions,
    required this.startLocation,
    required this.destination,
    required this.destinationName,
  });

  @override
  State<ActiveNavigationScreen> createState() => _ActiveNavigationScreenState();
}

class _ActiveNavigationScreenState extends State<ActiveNavigationScreen>
    with TickerProviderStateMixin {
  // Controllers
  final MapController _mapController = MapController();
  final NavigationAssistant _navAssistant = NavigationAssistant();
  late AnimationController _animationController;
  StreamSubscription<Position>? _positionStream;

  // Route & Location State
  late List<LatLng> _routePoints;
  LatLngTween? _latLngTween;
  LatLng? _animatedLocation;
  LatLng? _targetLocation;

  // Heading State
  double _animatedHeading = 0.0;
  double _targetHeading = 0.0;
  double _oldHeading = 0.0;

  // System Flags
  bool _isMapLocked = true;
  bool _isRerouting = false;
  bool _hasInitialGpsLock = false;
  DateTime _lastRerouteTime = DateTime.fromMillisecondsSinceEpoch(0);

  // 🟢 NEW: Tracks the exact time of the last GPS ping
  DateTime? _lastGpsUpdateTime;

  // Styling
  final Color primaryBlue = const Color(0xFF51A8E7);
  final Color darkBlue = const Color(0xFF1B6AAB);

  @override
  void initState() {
    super.initState();
    _routePoints = widget.initialRoutePoints;
    _animatedLocation = widget.startLocation;

    _navAssistant.setRouteSteps(widget.initialInstructions);

    // Initial default is 1000ms, but this will be overridden dynamically
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _animationController.addListener(_onAnimationUpdate);

    _startLocationTracking();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _navAssistant.stop();
    _mapController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // --- 1. CORE ANIMATION ENGINE ---

  void _onAnimationUpdate() {
    if (_latLngTween == null) return;

    setState(() {
      _animatedLocation = _latLngTween!.evaluate(_animationController);
      _animatedHeading = _lerpAngle(
        _oldHeading,
        _targetHeading,
        _animationController.value,
      );
    });

    if (_isMapLocked && _animatedLocation != null) {
      _mapController.moveAndRotate(
        _animatedLocation!,
        18.0,
        360 - _animatedHeading,
      );
    }
  }

  double _lerpAngle(double a, double b, double t) {
    double delta = ((b - a + 180) % 360) - 180;
    return (a + delta * t) % 360;
  }

  // --- 2. REROUTING LOGIC ---

  bool _isUserOffTrack(LatLng currentPos) {
    if (_routePoints.isEmpty || !_hasInitialGpsLock) return false;

    double minDistance = double.infinity;
    for (var point in _routePoints) {
      double distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) minDistance = distance;
    }

    if (minDistance > 50) {
      debugPrint(
        "📏 GPS is ${minDistance.toStringAsFixed(0)}m away from route.",
      );
    }

    return minDistance > 100; // 100-meter virtual fence
  }

  Future<void> _triggerReroute(LatLng newLocation) async {
    if (_isRerouting) return;
    if (DateTime.now().difference(_lastRerouteTime).inSeconds < 10)
      return; // 10s Cooldown

    setState(() => _isRerouting = true);
    _navAssistant.stop();
    debugPrint("🔄 Rerouting...");

    final routeData = await OsrmService.getRoute(
      newLocation,
      widget.destination,
    );

    if (mounted) {
      if (routeData != null) {
        setState(() {
          _routePoints = routeData['points'];
          _navAssistant.setRouteSteps(routeData['steps'] ?? []);
          _isRerouting = false;
          _lastRerouteTime = DateTime.now();
        });
      } else {
        setState(() => _isRerouting = false);
        _lastRerouteTime = DateTime.now();
        debugPrint("❌ Reroute failed. No road found nearby.");
      }
    }
  }

  // --- 3. GPS STREAM HANDLER ---

  Future<void> _startLocationTracking() async {
    // 🟢 THE FIX: Removed distanceFilter completely.
    // We want raw, purely time-based updates as fast as the device can send them.
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings).listen((
      Position pos,
    ) {
      if (!mounted) return;

      LatLng rawGpsLocation = LatLng(pos.latitude, pos.longitude);
      DateTime now = DateTime.now();

      if (!_hasInitialGpsLock) {
        _hasInitialGpsLock = true;
        _animatedLocation = rawGpsLocation;
      } else if (_isUserOffTrack(rawGpsLocation)) {
        _triggerReroute(rawGpsLocation);
      }

      // 🟢 DYNAMIC LATENCY CALCULATION
      // Measure exactly how many milliseconds it has been since the last update
      int durationMs = 1200; // Safe default
      if (_lastGpsUpdateTime != null) {
        int pingDelta = now.difference(_lastGpsUpdateTime!).inMilliseconds;
        // Add a 20% "buffer" so the marker stays slightly behind and never stops
        durationMs = (pingDelta * 1.2).clamp(1000, 5000).toInt();
      }
      _lastGpsUpdateTime = now;

      // Prepare animation states
      LatLng animationStart = _animatedLocation ?? rawGpsLocation;
      _oldHeading = _animatedHeading;
      _targetLocation = rawGpsLocation;

      if (pos.heading > 0) {
        _targetHeading = pos.heading;
      }

      _latLngTween = LatLngTween(begin: animationStart, end: _targetLocation!);
      _animationController.value = 0.0;

      // Pass the dynamically calculated duration!
      _animationController.animateTo(
        1.0,
        duration: Duration(milliseconds: durationMs),
        curve: Curves.linear,
      );

      // Feed Voice Assistant
      _navAssistant.processLocationUpdate(rawGpsLocation);
    });
  }

  // --- 4. UI BUILDER ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // THE MAP
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.startLocation,
              initialZoom: 18,
              onPositionChanged: (pos, hasGesture) {
                if (hasGesture) setState(() => _isMapLocked = false);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.safehorizon.app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: darkBlue,
                      strokeWidth: 8,
                    ),
                    Polyline(
                      points: _routePoints,
                      color: primaryBlue,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _animatedLocation ?? widget.startLocation,
                    width: 60,
                    height: 60,
                    child: Transform.rotate(
                      angle: _animatedHeading * (pi / 180),
                      child: const Icon(
                        Icons.navigation,
                        color: Colors.blue,
                        size: 45,
                      ),
                    ),
                  ),
                  Marker(
                    point: widget.destination,
                    width: 40,
                    height: 40,
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // TOP HEADER
          Align(
            alignment: Alignment.topCenter,
            child: Container(
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
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text(
                    "Navigating",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // RECENTER BUTTON
          if (!_isMapLocked)
            Positioned(
              bottom: 40,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () => setState(() => _isMapLocked = true),
                backgroundColor: darkBlue,
                icon: const Icon(
                  Icons.center_focus_strong,
                  color: Colors.white,
                ),
                label: const Text(
                  "Recenter",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

          // REROUTING OVERLAY
          if (_isRerouting)
            Center(
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: primaryBlue,
                          strokeWidth: 3,
                        ),
                      ),
                      const SizedBox(width: 20),
                      const Text(
                        "Recalculating...",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
