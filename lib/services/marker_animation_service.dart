import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class MarkerAnimationService {
  static AnimationController? _controller;

  static void animate({
    required TickerProvider vsync,
    required LatLng start,
    required LatLng end,
    required Function(LatLng) onUpdate,
  }) {
    // Stop any existing animation before starting a new one
    _controller?.stop();
    _controller?.dispose();

    _controller = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 1000),
    );

    final Animation<double> curve = CurvedAnimation(
      parent: _controller!,
      curve: Curves.linear,
    );

    curve.addListener(() {
      final double t = curve.value;
      // Interpolate the coordinates manually
      final double lat = start.latitude + (end.latitude - start.latitude) * t;
      final double lng =
          start.longitude + (end.longitude - start.longitude) * t;

      onUpdate(LatLng(lat, lng));
    });

    _controller!.forward();
  }

  static void stop() {
    _controller?.stop();
    _controller?.dispose();
    _controller = null;
  }
}
