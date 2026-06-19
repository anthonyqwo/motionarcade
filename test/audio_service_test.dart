import 'package:flutter_test/flutter_test.dart';
import 'package:motionarcade/shared/feedback/audio_service.dart';

void main() {
  group('AudioService Unit Tests', () {
    test('AudioService is a singleton', () {
      final service1 = AudioService();
      final service2 = AudioService();
      expect(identical(service1, service2), isTrue);
    });

    test('AudioService default volumes and mute state', () {
      final service = AudioService();
      expect(service.isMuted, isFalse);
      expect(service.bgmVolume, closeTo(0.4, 0.001));
      expect(service.sfxVolume, closeTo(0.8, 0.001));
    });

    test('AudioService volume controls', () {
      final service = AudioService();
      
      service.bgmVolume = 0.5;
      expect(service.bgmVolume, closeTo(0.5, 0.001));
      
      service.sfxVolume = 0.9;
      expect(service.sfxVolume, closeTo(0.9, 0.001));

      // Test volume bounds
      service.bgmVolume = 1.5;
      expect(service.bgmVolume, closeTo(1.0, 0.001));

      service.sfxVolume = -0.5;
      expect(service.sfxVolume, closeTo(0.0, 0.001));
    });

    test('AudioService toggle mute', () {
      final service = AudioService();
      expect(service.isMuted, isFalse);
      
      service.toggleMute();
      expect(service.isMuted, isTrue);
      
      service.setMuted(false);
      expect(service.isMuted, isFalse);
    });

    test('AudioService methods do not throw in test environment', () async {
      final service = AudioService();
      
      // These should execute without throwing platform exceptions in tests
      await expectLater(service.playBGM('audio/bgm_lobby.wav'), completes);
      await expectLater(service.playSFX('audio/sfx_click.wav'), completes);
      await expectLater(service.stopBGM(), completes);
      await expectLater(service.stopAll(), completes);
    });
  });
}
