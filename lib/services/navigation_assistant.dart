import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class NavigationAssistant {
  final FlutterTts _flutterTts = FlutterTts();

  // Tracks the last spoken string so it doesn't repeat infinitely
  String _lastAnnouncedInstruction = "";

  NavigationAssistant() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // Natural speaking speed
    await _flutterTts.setPitch(1.0);
  }

  /// Feed this method from your active navigation UI's state
  void announceInstruction(String instruction, double distanceToTurn) {
    if (instruction.isEmpty) return;

    // TRIGGER: Approach Warning (50 meters away)
    // Only speak if we haven't already announced THIS specific instruction
    if (distanceToTurn < 50 && _lastAnnouncedInstruction != instruction) {
      _speak(instruction);
      _lastAnnouncedInstruction = instruction;
    }
  }

  /// Clears the memory of the last instruction (useful during rerouting)
  void clearMemory() {
    _lastAnnouncedInstruction = "";
  }

  Future<void> _speak(String text) async {
    debugPrint("🗣️ TTS Announcing: $text");
    await _flutterTts.speak(text);
  }

  void stop() {
    _flutterTts.stop();
  }
}
