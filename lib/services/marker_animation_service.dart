import 'dart:async';
import 'package:latlong2/latlong.dart';

class MarkerAnimationService {
  static Timer? _timer;

  static void animate({
    required LatLng start,
    required LatLng end,
    required Function(LatLng) onUpdate,
    Duration duration = const Duration(milliseconds: 300),
  }) {
    // stop previous animation
    _timer?.cancel();

    const int steps = 15;
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

      if (step >= steps) {
        timer.cancel();
      }
    });
  }
}
