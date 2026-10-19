import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

abstract class ScreenService {
  Future<void> init();
  Future<double> getBrightness();
  Future<void> setBrightness(double value);
  Future<void> setMaxBrightness();
  Future<void> restoreBrightness();
  Future<void> setKeepAwake(bool enable);
  bool get isKeepAwake;
  double get currentBrightness;
  bool get isBrightnessSupported;
}

class DefaultScreenService implements ScreenService {
  final ScreenBrightness _screenBrightness;
  double _currentBrightness = 1.0;
  double? _initialBrightness;
  bool _isKeepAwake = false;
  bool _isBrightnessSupported = true;

  DefaultScreenService({ScreenBrightness? screenBrightness})
      : _screenBrightness = screenBrightness ?? ScreenBrightness();

  @override
  double get currentBrightness => _currentBrightness;

  @override
  bool get isKeepAwake => _isKeepAwake;

  @override
  bool get isBrightnessSupported => _isBrightnessSupported;

  @override
  Future<void> init() async {
    try {
      final current = await _screenBrightness.application;
      _initialBrightness = current;
      _currentBrightness = current;
    } catch (e) {
      debugPrint('ScreenBrightness initialization not supported on this platform: $e');
      _isBrightnessSupported = false;
      _currentBrightness = 1.0;
    }
  }

  @override
  Future<double> getBrightness() async {
    try {
      final val = await _screenBrightness.application;
      _currentBrightness = val;
      return val;
    } catch (e) {
      debugPrint('Error getting brightness: $e');
      return _currentBrightness;
    }
  }

  @override
  Future<void> setBrightness(double value) async {
    final clamped = value.clamp(0.05, 1.0);
    _currentBrightness = clamped;

    if (!_isBrightnessSupported) return;

    try {
      // Remember initial brightness before our first modification
      if (_initialBrightness == null) {
        try {
          _initialBrightness = await _screenBrightness.application;
        } catch (_) {}
      }
      await _screenBrightness.setApplicationScreenBrightness(clamped);
    } catch (e) {
      debugPrint('Error setting screen brightness: $e');
    }
  }

  @override
  Future<void> setMaxBrightness() async {
    await setBrightness(1.0);
  }

  @override
  Future<void> restoreBrightness() async {
    if (!_isBrightnessSupported) return;

    try {
      await _screenBrightness.resetApplicationScreenBrightness();
      if (_initialBrightness != null) {
        _currentBrightness = _initialBrightness!;
      }
    } catch (e) {
      debugPrint('Error restoring screen brightness: $e');
    }
  }

  @override
  Future<void> setKeepAwake(bool enable) async {
    _isKeepAwake = enable;
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint('Error setting wakelock: $e');
    }
  }
}
