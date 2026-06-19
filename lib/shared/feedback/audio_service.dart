import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  // Singleton pattern
  factory AudioService() => _instance;
  AudioService._internal() {
    if (!_isTesting) {
      _bgmPlayer = AudioPlayer();
      _bgmPlayer?.setReleaseMode(ReleaseMode.loop);
    }
  }
  static final AudioService _instance = AudioService._internal();

  AudioPlayer? _bgmPlayer;
  final List<AudioPlayer> _sfxPlayers = [];

  bool _isMuted = false;
  double _bgmVolume = 0.4;
  double _sfxVolume = 0.8;

  bool get isMuted => _isMuted;
  double get bgmVolume => _bgmVolume;
  double get sfxVolume => _sfxVolume;

  bool get _isTesting {
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false; // Fallback for platforms where Platform.environment is not available (e.g. web)
    }
  }

  set bgmVolume(double val) {
    _bgmVolume = val.clamp(0.0, 1.0);
    if (!_isMuted) {
      _bgmPlayer?.setVolume(_bgmVolume);
    }
  }

  set sfxVolume(double val) {
    _sfxVolume = val.clamp(0.0, 1.0);
    if (!_isMuted) {
      for (final p in _sfxPlayers) {
        p.setVolume(_sfxVolume);
      }
    }
  }

  Future<void> playBGM(String relativePath) async {
    if (_isMuted || _isTesting) return;
    try {
      await _bgmPlayer?.stop();
      await _bgmPlayer?.setVolume(_bgmVolume);
      await _bgmPlayer?.play(AssetSource(relativePath));
    } catch (e) {
      // Avoid throwing unhandled exceptions if asset doesn't load or play fails
      print('AudioService error playing BGM: $e');
    }
  }

  Future<void> stopBGM() async {
    if (_isTesting) return;
    try {
      await _bgmPlayer?.stop();
    } catch (e) {
      print('AudioService error stopping BGM: $e');
    }
  }

  Future<void> playSFX(String relativePath, {double? pitch}) async {
    if (_isMuted || _isTesting) return;

    try {
      // Find an idle player to avoid interrupting active SFX
      AudioPlayer? idlePlayer;
      for (final player in _sfxPlayers) {
        if (player.state != PlayerState.playing) {
          idlePlayer = player;
          break;
        }
      }

      if (idlePlayer == null) {
        idlePlayer = AudioPlayer();
        _sfxPlayers.add(idlePlayer);
      }

      // Add dynamic volume randomization (+/- 5%) to create organic variation
      final randomVolume = _sfxVolume * (0.95 + math.Random().nextDouble() * 0.05);
      await idlePlayer.setVolume(randomVolume);

      // Play the source first, then set the playback rate.
      // In audioplayers, setting properties before play is often ignored or reset on some platforms.
      await idlePlayer.play(AssetSource(relativePath));
      
      if (pitch != null) {
        try {
          await idlePlayer.setPlaybackRate(pitch);
        } catch (_) {}
      } else {
        try {
          await idlePlayer.setPlaybackRate(1.0);
        } catch (_) {}
      }
    } catch (e) {
      print('AudioService error playing SFX: $e');
    }
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    if (_isMuted) {
      _bgmPlayer?.setVolume(0);
      for (final p in _sfxPlayers) {
        p.setVolume(0);
      }
    } else {
      _bgmPlayer?.setVolume(_bgmVolume);
      for (final p in _sfxPlayers) {
        p.setVolume(_sfxVolume);
      }
    }
  }

  void setMuted(bool mute) {
    if (_isMuted == mute) return;
    toggleMute();
  }

  Future<void> stopAll() async {
    await stopBGM();
    for (final p in _sfxPlayers) {
      try {
        await p.stop();
      } catch (e) {
        print('AudioService error stopping SFX player: $e');
      }
    }
  }
}
