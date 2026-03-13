import 'dart:async';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerAnimationService {
  static Timer? _timer;

  static void animate({
    required LatLng start,
    required LatLng end,
    required Function(LatLng) onUpdate,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    // Stop any running animation
    _timer?.cancel();
    _timer = null;

    const int steps = 25;
    int step = 0;

    // Ensure interval is never zero
    final int interval = (duration.inMilliseconds ~/ steps).clamp(
      1,
      duration.inMilliseconds,
    );

    _timer = Timer.periodic(Duration(milliseconds: interval), (timer) {
      step++;

      double progress = step / steps;

      if (progress > 1) progress = 1;

      final double lat =
          start.latitude + (end.latitude - start.latitude) * progress;

      final double lng =
          start.longitude + (end.longitude - start.longitude) * progress;

      onUpdate(LatLng(lat, lng));

      if (step >= steps) {
        timer.cancel();
        _timer = null;
      }
    });
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
