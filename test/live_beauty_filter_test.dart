import 'package:flutter_test/flutter_test.dart';
import 'package:live_beauty_filter/live_beauty_filter.dart';
import 'package:live_beauty_filter/live_beauty_filter_platform_interface.dart';
import 'package:live_beauty_filter/live_beauty_filter_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockLiveBeautyFilterPlatform
    with MockPlatformInterfaceMixin
    implements LiveBeautyFilterPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final LiveBeautyFilterPlatform initialPlatform =
      LiveBeautyFilterPlatform.instance;

  test('$MethodChannelLiveBeautyFilter is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelLiveBeautyFilter>());
  });

  test('getPlatformVersion', () async {
    LiveBeautyFilter liveBeautyFilterPlugin = LiveBeautyFilter();
    MockLiveBeautyFilterPlatform fakePlatform = MockLiveBeautyFilterPlatform();
    LiveBeautyFilterPlatform.instance = fakePlatform;

    expect(await liveBeautyFilterPlugin.getPlatformVersion(), '42');
  });
}
