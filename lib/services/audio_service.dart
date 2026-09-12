import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider for global application audio service.
final audioServiceProvider = Provider<AudioService>((ref) {
  final service = AudioService();
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Manages sound effects for moves, captures, checks, and game over states.
class AudioService {
  AudioPlayer? _player;
  bool _isMuted = false;
  static const String _mutedPrefKey = 'chess_audio_muted';

  bool get isMuted => _isMuted;

  bool get _isTest {
    if (kIsWeb) return false;
    try {
      return Platform.environment.containsKey('FLUTTER_TEST');
    } catch (_) {
      return false;
    }
  }

  AudioPlayer? _getOrCreatePlayer() {
    if (_isTest) return null;
    if (_player != null) return _player;
    try {
      final p = AudioPlayer();
      p.setReleaseMode(ReleaseMode.stop);
      p.setVolume(1.0);
      _player = p;
      return p;
    } catch (_) {
      return null;
    }
  }

  /// Initializes audio settings from local preferences.
  Future<void> init() async {
    if (_isTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _isMuted = prefs.getBool(_mutedPrefKey) ?? false;
    } catch (_) {}
  }

  /// Toggles mute state and persists preference.
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isTest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedPrefKey, _isMuted);
    } catch (_) {}
  }

  /// Plays standard piece move sound effect.
  Future<void> playMove() async {
    await _playSound('sounds/move.mp3', haptic: HapticFeedback.selectionClick);
  }

  /// Plays piece capture sound effect.
  Future<void> playCapture() async {
    await _playSound('sounds/capture.mp3', haptic: HapticFeedback.mediumImpact);
  }

  /// Plays check alert chime.
  Future<void> playCheck() async {
    await _playSound('sounds/check.mp3', haptic: HapticFeedback.heavyImpact);
  }

  /// Plays game conclusion sound effect.
  Future<void> playGameOver() async {
    await _playSound('sounds/game_over.mp3', haptic: HapticFeedback.vibrate);
  }

  /// Plays low clock warning sound effect.
  Future<void> playLowTime() async {
    await _playSound('sounds/low_time.mp3', haptic: HapticFeedback.lightImpact);
  }

  Future<void> _playSound(String assetPath, {Future<void> Function()? haptic}) async {
    if (_isTest) return;

    try {
      if (haptic != null) {
        await haptic();
      }
    } catch (_) {}

    if (_isMuted) return;

    try {
      final player = _getOrCreatePlayer();
      if (player != null) {
        await player.stop();
        await player.play(AssetSource(assetPath));
      }
    } catch (_) {}
  }

  /// Disposes underlying audio player instance.
  void dispose() {
    try {
      _player?.dispose();
    } catch (_) {}
  }
}
