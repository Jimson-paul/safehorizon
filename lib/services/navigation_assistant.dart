import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'osrm_service.dart'; // To get access to the RouteStep class

class NavigationAssistant {
  final FlutterTts _flutterTts = FlutterTts();
  List<RouteStep> _steps = [];
  int _currentStepIndex = 0;

  // Flag to prevent the app from screaming the same instruction 100 times
  bool _hasAnnouncedApproaching = false;

  NavigationAssistant() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Natural speaking speed
    await _flutterTts.setPitch(1.0);
  }

  /// Load the turn-by-turn steps from your ORS routing data
  void setRouteSteps(List<RouteStep> steps) {
    _steps = steps;
    _currentStepIndex = 0;
    _hasAnnouncedApproaching = false;
  }

  /// Feed this method your live GPS location updates
  void processLocationUpdate(LatLng currentPos) {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return;

    RouteStep nextTurn = _steps[_currentStepIndex];

    // Calculate distance to the next turn in meters
    double distanceToTurn = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      nextTurn.location.latitude,
      nextTurn.location.longitude,
    );

    // TRIGGER 1: Approach Warning (50 meters away)
    if (distanceToTurn < 50 && !_hasAnnouncedApproaching) {
      _speak(nextTurn.instruction);
      _hasAnnouncedApproaching = true;
    }

    // TRIGGER 2: Turn Completed (Within 15 meters)
    if (distanceToTurn < 15) {
      _currentStepIndex++;
      _hasAnnouncedApproaching = false; // Reset flag for the next instruction
    }
  }

  Future<void> _speak(String text) async {
    debugPrint("🗣️ TTS Announcing: $text");
    await _flutterTts.speak(text);
  }

  void stop() {
    _flutterTts.stop();
  }
}
