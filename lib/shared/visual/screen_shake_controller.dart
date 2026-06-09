import 'dart:math' as math;

import 'package:flutter/material.dart';

class ScreenShakeController extends ChangeNotifier {
  ScreenShakeController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  DateTime? _startedAt;
  Duration _duration = Duration.zero;
  double _intensity = 0;

  bool get isActive {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return false;
    }
    return _now().difference(startedAt) < _duration;
  }

  void trigger({
    double intensity = 10,
    Duration duration = const Duration(milliseconds: 220),
  }) {
    _startedAt = _now();
    _duration = duration;
    _intensity = intensity;
    notifyListeners();
  }

  Offset offsetAt(DateTime time) {
    final startedAt = _startedAt;
    if (startedAt == null) {
      return Offset.zero;
    }

    final elapsed = time.difference(startedAt);
    if (elapsed >= _duration || elapsed.isNegative) {
      return Offset.zero;
    }

    final progress = elapsed.inMilliseconds / _duration.inMilliseconds;
    final falloff = 1 - progress;
    final wave = math.sin(progress * math.pi * 10);
    final wobble = math.cos(progress * math.pi * 7);
    return Offset(wave * _intensity * falloff, wobble * _intensity * 0.5 * falloff);
  }
}
