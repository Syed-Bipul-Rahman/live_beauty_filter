import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_beauty_filter_platform_interface.dart';

/// An implementation of [LiveBeautyFilterPlatform] that uses method channels.
class MethodChannelLiveBeautyFilter extends LiveBeautyFilterPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('live_beauty_filter');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
