import 'package:flutter/services.dart';

class MilkyFilterController {
  static const _channel = MethodChannel('live_beauty_filter');

  int? _textureId;
  bool _isInitialized = false;

  int? get textureId => _textureId;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    final id = await _channel.invokeMethod<int>('initialize');
    _textureId = id;
    _isInitialized = true;
  }

  /// intensity: 0.0 (no filter) → 1.0 (full milky)
  Future<void> setFilterIntensity(double intensity) async {
    await _channel.invokeMethod('setFilterIntensity', {
      'intensity': intensity.clamp(0.0, 1.0),
    });
  }

  Future<void> dispose() async {
    await _channel.invokeMethod('dispose');
    _isInitialized = false;
    _textureId = null;
  }
}
