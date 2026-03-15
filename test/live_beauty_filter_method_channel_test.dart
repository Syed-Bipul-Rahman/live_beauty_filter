import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:live_beauty_filter/live_beauty_filter_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelLiveBeautyFilter platform = MethodChannelLiveBeautyFilter();
  const MethodChannel channel = MethodChannel('live_beauty_filter');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
