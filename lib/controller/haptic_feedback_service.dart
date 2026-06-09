import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../shared/models/motion_event.dart';

class HapticFeedbackService {
  static const MethodChannel _channel = MethodChannel('motionarcade/haptics');

  static Future<void> _fallback(double intensity) async {
    try {
      if (intensity > 0.7) {
        await HapticFeedback.heavyImpact();
      } else if (intensity > 0.4) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('Fallback haptics failed: $e');
    }
  }

  static Future<void> _fallbackPattern(List<Map<String, dynamic>> pattern) async {
    try {
      final sortedPattern = List<Map<String, dynamic>>.from(pattern)
        ..sort((a, b) {
          final double tA = (a['time'] as num?)?.toDouble() ?? 0.0;
          final double tB = (b['time'] as num?)?.toDouble() ?? 0.0;
          return tA.compareTo(tB);
        });

      double lastTime = 0.0;
      for (final event in sortedPattern) {
        final double time = (event['time'] as num?)?.toDouble() ?? 0.0;
        final double intensity = (event['intensity'] as num?)?.toDouble() ?? 0.5;
        
        final double delay = time - lastTime;
        if (delay > 0.0) {
          await Future.delayed(Duration(milliseconds: (delay * 1000).round()));
        }
        lastTime = time;
        await _fallback(intensity);
      }
    } catch (e) {
      debugPrint('Fallback pattern haptics failed: $e');
    }
  }

  static Future<void> playCustom({
    required double intensity,
    required double sharpness,
    required double duration,
  }) async {
    try {
      await _channel.invokeMethod('play', {
        'intensity': intensity,
        'sharpness': sharpness,
        'duration': duration,
      });
    } on MissingPluginException catch (_) {
      await _fallback(intensity);
    } on PlatformException catch (e) {
      debugPrint('Haptics failed, falling back: $e');
      await _fallback(intensity);
    }
  }

  static Future<void> playPattern(List<Map<String, dynamic>> pattern) async {
    try {
      await _channel.invokeMethod('playPattern', {
        'pattern': pattern,
      });
    } on MissingPluginException catch (_) {
      await _fallbackPattern(pattern);
    } on PlatformException catch (e) {
      debugPrint('Haptics failed, falling back: $e');
      await _fallbackPattern(pattern);
    }
  }

  static Future<void> trigger(HapticPattern pattern) async {
    switch (pattern) {
      case HapticPattern.light:
        await playCustom(intensity: 0.3, sharpness: 0.8, duration: 0.0);
      case HapticPattern.medium:
        await playCustom(intensity: 0.6, sharpness: 0.5, duration: 0.0);
      case HapticPattern.strong:
        await playCustom(intensity: 0.9, sharpness: 0.9, duration: 0.0);
      case HapticPattern.long:
        await playCustom(intensity: 0.7, sharpness: 0.3, duration: 0.4);
      case HapticPattern.combo:
        await playPattern([
          {
            'type': 'transient',
            'time': 0.0,
            'intensity': 0.3,
            'sharpness': 0.8,
          },
          {
            'type': 'transient',
            'time': 0.1,
            'intensity': 0.3,
            'sharpness': 0.8,
          },
          {
            'type': 'transient',
            'time': 0.2,
            'intensity': 0.7,
            'sharpness': 0.9,
          },
        ]);
      case HapticPattern.perfect:
        // A crisp, rising double tap (50ms interval) for an extremely satisfying perfect feedback
        await playPattern([
          {
            'type': 'transient',
            'time': 0.0,
            'intensity': 0.4,
            'sharpness': 0.85,
          },
          {
            'type': 'transient',
            'time': 0.05,
            'intensity': 1.0,
            'sharpness': 0.95,
          },
        ]);
      case HapticPattern.good:
        // A clean, solid single click
        await playCustom(intensity: 0.7, sharpness: 0.8, duration: 0.0);
      case HapticPattern.miss:
        // A low-frequency double thud (80ms interval) to feel heavy, soft, and negative
        await playPattern([
          {
            'type': 'transient',
            'time': 0.0,
            'intensity': 0.8,
            'sharpness': 0.1,
          },
          {
            'type': 'transient',
            'time': 0.08,
            'intensity': 0.4,
            'sharpness': 0.15,
          },
        ]);
    }
  }
}
