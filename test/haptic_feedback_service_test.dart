import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/controller/haptic_feedback_service.dart';
import 'package:motionarcade/shared/models/motion_event.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final List<String> hapticCalls = [];

  setUp(() {
    hapticCalls.clear();
    // Intercept standard Flutter HapticFeedback calls on SystemChannels.platform
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      if (methodCall.method == 'HapticFeedback.vibrate') {
        hapticCalls.add(methodCall.arguments as String);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('playCustom falls back to lightImpact when intensity <= 0.4', () async {
    await HapticFeedbackService.playCustom(intensity: 0.3, sharpness: 0.5, duration: 0.1);
    expect(hapticCalls, contains('HapticFeedbackType.lightImpact'));
  });

  test('playCustom falls back to mediumImpact when intensity > 0.4 and <= 0.7', () async {
    await HapticFeedbackService.playCustom(intensity: 0.6, sharpness: 0.5, duration: 0.1);
    expect(hapticCalls, contains('HapticFeedbackType.mediumImpact'));
  });

  test('playCustom falls back to heavyImpact when intensity > 0.7', () async {
    await HapticFeedbackService.playCustom(intensity: 0.8, sharpness: 0.5, duration: 0.1);
    expect(hapticCalls, contains('HapticFeedbackType.heavyImpact'));
  });

  test('playPattern executes sequential fallbacks with delays', () async {
    final pattern = [
      {'time': 0.0, 'intensity': 0.3},
      {'time': 0.05, 'intensity': 0.8},
    ];
    await HapticFeedbackService.playPattern(pattern);
    expect(hapticCalls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  test('trigger routes standard HapticPattern to correct fallback haptics', () async {
    await HapticFeedbackService.trigger(HapticPattern.light);
    expect(hapticCalls.last, 'HapticFeedbackType.lightImpact');

    await HapticFeedbackService.trigger(HapticPattern.medium);
    expect(hapticCalls.last, 'HapticFeedbackType.mediumImpact');

    await HapticFeedbackService.trigger(HapticPattern.strong);
    expect(hapticCalls.last, 'HapticFeedbackType.heavyImpact');

    await HapticFeedbackService.trigger(HapticPattern.long);
    expect(hapticCalls.last, 'HapticFeedbackType.mediumImpact');

    hapticCalls.clear();
    await HapticFeedbackService.trigger(HapticPattern.perfect);
    expect(hapticCalls, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.heavyImpact',
    ]);

    hapticCalls.clear();
    await HapticFeedbackService.trigger(HapticPattern.good);
    expect(hapticCalls, [
      'HapticFeedbackType.mediumImpact',
    ]);

    hapticCalls.clear();
    await HapticFeedbackService.trigger(HapticPattern.miss);
    expect(hapticCalls, [
      'HapticFeedbackType.heavyImpact',
      'HapticFeedbackType.lightImpact',
    ]);
  });
}
