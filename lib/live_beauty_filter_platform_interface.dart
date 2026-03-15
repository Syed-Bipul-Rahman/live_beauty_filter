import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'live_beauty_filter_method_channel.dart';

abstract class LiveBeautyFilterPlatform extends PlatformInterface {
  /// Constructs a LiveBeautyFilterPlatform.
  LiveBeautyFilterPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiveBeautyFilterPlatform _instance = MethodChannelLiveBeautyFilter();

  /// The default instance of [LiveBeautyFilterPlatform] to use.
  ///
  /// Defaults to [MethodChannelLiveBeautyFilter].
  static LiveBeautyFilterPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LiveBeautyFilterPlatform] when
  /// they register themselves.
  static set instance(LiveBeautyFilterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
