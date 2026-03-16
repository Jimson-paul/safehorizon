import 'dart:async';
import 'dart:math' show pi;
import '../widgets/poi_action_buttons.dart';
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

  // 🟢 Turn-by-Turn State
  late List<RouteStep> _currentRouteSteps;
  int _currentStepIndex = 0;
  String _currentInstruction = "Proceed to route";
  double _distanceToNextTurn = 0.0;

  // 🟢 NEW: Point of Interest (POI) Marker State
  List<Marker> _poiMarkers = [];

  // Heading State
  double _animatedHeading = 0.0;
  double _targetHeading = 0.0;
  double _oldHeading = 0.0;

  // System Flags
  bool _isMapLocked = true;
  bool _isRerouting = false;
  bool _hasInitialGpsLock = false;
  DateTime _lastRerouteTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastGpsUpdateTime;

  // Styling
  final Color primaryBlue = const Color(0xFF51A8E7);
  final Color darkBlue = const Color(0xFF1B6AAB);

  @override
  void initState() {
    super.initState();
    _routePoints = widget.initialRoutePoints;
    _animatedLocation = widget.startLocation;
    _currentRouteSteps = widget.initialInstructions;

    // Set initial instruction if available
    if (_currentRouteSteps.isNotEmpty) {
      _currentInstruction = _currentRouteSteps.first.instruction;
    }

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

      // 🟢 SYNCS THE TURN BANNER TO THE ANIMATED MARKER
      _updateTurnGuidanceUI(_animatedLocation!);
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

  // 🟢 NEW: Math to update the banner distance and flip to the next instruction
  void _updateTurnGuidanceUI(LatLng currentMarkerPos) {
    if (_currentRouteSteps.isEmpty) return;

    if (_currentStepIndex >= _currentRouteSteps.length) {
      _currentInstruction = "You have arrived at your destination!";
      _distanceToNextTurn = 0.0;
      return;
    }

    final currentStep = _currentRouteSteps[_currentStepIndex];

    // Calculate the distance from the animated car to the intersection
    double distance = Geolocator.distanceBetween(
      currentMarkerPos.latitude,
      currentMarkerPos.longitude,
      currentStep.location.latitude,
      currentStep.location.longitude,
    );

    _distanceToNextTurn = distance;
    _currentInstruction = currentStep.instruction;

    // If the car gets within 15 meters of the turn, jump to the next instruction
    if (distance < 15.0) {
      _currentStepIndex++;
    }
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

    return minDistance > 100; // 100-meter virtual fence
  }

  Future<void> _triggerReroute(LatLng newLocation) async {
    if (_isRerouting) return;
    if (DateTime.now().difference(_lastRerouteTime).inSeconds < 10) return;

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
          _navAssistant.clearMemory();

          // 🟢 Reset turn-by-turn state for new route
          _currentRouteSteps = routeData['steps'] ?? [];
          _currentStepIndex = 0;
          if (_currentRouteSteps.isNotEmpty) {
            _currentInstruction = _currentRouteSteps[0].instruction;
          }

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

  // --- 3. GPS STREAM HANDLER & UI UPDATES ---

  Future<void> _startLocationTracking() async {
    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: settings)
        .listen((Position pos) {
          if (!mounted) return;

          LatLng rawGpsLocation = LatLng(pos.latitude, pos.longitude);

          // Apply Snap-to-Route
          LatLng snappedLocation = _snapToRoute(rawGpsLocation);

          DateTime now = DateTime.now();

          if (!_hasInitialGpsLock) {
            _hasInitialGpsLock = true;
            _animatedLocation = snappedLocation;
          } else if (_isUserOffTrack(rawGpsLocation)) {
            _triggerReroute(rawGpsLocation);
          }

          // DYNAMIC LATENCY CALCULATION
          int durationMs = 1200;
          if (_lastGpsUpdateTime != null) {
            int pingDelta = now.difference(_lastGpsUpdateTime!).inMilliseconds;
            durationMs = (pingDelta * 1.2).clamp(1000, 5000).toInt();
          }
          _lastGpsUpdateTime = now;

          LatLng animationStart = _animatedLocation ?? snappedLocation;
          _oldHeading = _animatedHeading;
          _targetLocation = snappedLocation;

          if (pos.heading > 0) {
            _targetHeading = pos.heading;
          }

          _latLngTween = LatLngTween(
            begin: animationStart,
            end: _targetLocation!,
          );
          _animationController.value = 0.0;

          _animationController.animateTo(
            1.0,
            duration: Duration(milliseconds: durationMs),
            curve: Curves.linear,
          );

          // Trigger TTS
          _navAssistant.announceInstruction(
            _currentInstruction,
            _distanceToNextTurn,
          );
        });
  }

  // --- 4. ICON HELPER ---

  IconData _getTurnIcon(String instruction) {
    final lowerInst = instruction.toLowerCase();
    if (lowerInst.contains("left")) return Icons.turn_left;
    if (lowerInst.contains("right")) return Icons.turn_right;
    if (lowerInst.contains("u-turn")) return Icons.u_turn_left;
    if (lowerInst.contains("roundabout")) return Icons.roundabout_right;
    if (lowerInst.contains("arrive") || lowerInst.contains("destination")) {
      return Icons.flag;
    }
    return Icons.straight;
  }

  // --- 4.5 SNAP TO ROUTE LOGIC ---

  LatLng _snapToRoute(LatLng rawLocation) {
    if (_routePoints.isEmpty) return rawLocation;

    double minDistance = double.infinity;
    LatLng snappedPoint = rawLocation;

    for (int i = 0; i < _routePoints.length - 1; i++) {
      LatLng start = _routePoints[i];
      LatLng end = _routePoints[i + 1];

      LatLng projected = _projectPointOnSegment(rawLocation, start, end);

      double dist = Geolocator.distanceBetween(
        rawLocation.latitude,
        rawLocation.longitude,
        projected.latitude,
        projected.longitude,
      );

      if (dist < minDistance) {
        minDistance = dist;
        snappedPoint = projected;
      }
    }

    if (minDistance <= 35) {
      return snappedPoint;
    }

    return rawLocation;
  }

  LatLng _projectPointOnSegment(LatLng p, LatLng a, LatLng b) {
    double apX = p.longitude - a.longitude;
    double apY = p.latitude - a.latitude;
    double abX = b.longitude - a.longitude;
    double abY = b.latitude - a.latitude;

    double ab2 = abX * abX + abY * abY;
    if (ab2 == 0) return a;

    double t = (apX * abX + apY * abY) / ab2;
    t = t.clamp(0.0, 1.0);

    return LatLng(a.latitude + t * abY, a.longitude + t * abX);
  }

  // --- 5. UI BUILDER ---

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
                  ..._poiMarkers, // 🟢 Render the external POI markers here!
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

          // TURN-BY-TURN BANNER
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
              ),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: darkBlue,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Direction Icon
                  Icon(
                    _getTurnIcon(_currentInstruction),
                    color: Colors.white,
                    size: 40,
                  ),
                  const SizedBox(width: 16),

                  // Instruction & Distance Text
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _distanceToNextTurn > 1000
                              ? "${(_distanceToNextTurn / 1000).toStringAsFixed(1)} km"
                              : "${_distanceToNextTurn.toStringAsFixed(0)} m",
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentInstruction,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Close Button
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),

          // 🟢 NEW: Clean, external POI Buttons Component
          Positioned(
            right: 16,
            top: 180,
            child: PoiActionButtons(
              currentLocation: _animatedLocation,
              onMarkersUpdated: (newMarkers) {
                setState(() => _poiMarkers = newMarkers);
              },
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
