import 'dart:async';
import 'package:latlong2/latlong.dart';

class MarkerAnimationService {
  static Timer? _timer;

  static void animate({
    required LatLng start,
    required LatLng end,
    required Function(LatLng) onUpdate,

    // Smooth longer animation
    Duration duration = const Duration(milliseconds: 1500),
  }) {
    // Stop previous animation
    _timer?.cancel();

    // More steps = smoother movement
    const int steps = 40;
    int step = 0;

    final interval = duration ~/ steps;

    _timer = Timer.periodic(interval, (timer) {
      step++;

      final double progress = step / steps;

      final double lat =
          start.latitude + (end.latitude - start.latitude) * progress;

      final double lng =
          start.longitude + (end.longitude - start.longitude) * progress;

      onUpdate(LatLng(lat, lng));

      // Ensure we end exactly at destination
      if (step >= steps) {
        timer.cancel();
        onUpdate(end);
      }
    });
  }
}
