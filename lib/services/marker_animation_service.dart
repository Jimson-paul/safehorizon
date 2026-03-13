import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerAnimationService {
  static AnimationController? _controller;
  static Animation<LatLng>? _animation;

  /// Smoothly animates a marker from [start] to [end] over [duration].
  static void animate({
    required TickerProvider vsync,
    required LatLng start,
    required LatLng end,
    required Function(LatLng) onUpdate,
    Duration duration = const Duration(milliseconds: 800),
  }) {
    // 1. Stop and dispose of any existing animation
    stop();

    // 2. Create a new controller tied to the screen's refresh rate
    _controller = AnimationController(vsync: vsync, duration: duration);

    // 3. Create a Tween that interpolates between the start and end LatLng
    _animation = LatLngTween(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(parent: _controller!, curve: Curves.easeOut));

    // 4. Listen to every frame of the animation
    _controller!.addListener(() {
      if (_animation?.value != null) {
        onUpdate(_animation!.value);
      }
    });

    // 5. Start the animation
    _controller!.forward();
  }

  static void stop() {
    if (_controller != null) {
      _controller!.stop();
      _controller!.dispose();
      _controller = null;
    }
  }
}

/// A custom Tween that knows how to interpolate between two LatLng objects
class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
    : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final double lat = begin!.latitude + (end!.latitude - begin!.latitude) * t;
    final double lng =
        begin!.longitude + (end!.longitude - begin!.longitude) * t;
    return LatLng(lat, lng);
  }
}
