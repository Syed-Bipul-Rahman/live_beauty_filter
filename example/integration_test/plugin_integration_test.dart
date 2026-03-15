import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:live_beauty_filter/live_beauty_filter.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MilkyFilterController initializes and returns a texture id', (
    WidgetTester tester,
  ) async {
    final controller = MilkyFilterController();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: SizedBox())),
    );

    // Timeout in case camera permission is not granted
    bool initialized = false;
    try {
      await controller.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          fail('initialize() timed out — camera permission likely not granted');
        },
      );
      initialized = true;
    } catch (e) {
      fail('initialize() threw: $e');
    }

    expect(initialized, true);
    expect(controller.isInitialized, true);
    expect(controller.textureId, isNotNull);
    expect(controller.textureId, greaterThanOrEqualTo(0));

    await controller.dispose();
    expect(controller.isInitialized, false);
  });

  testWidgets('setFilterIntensity does not throw', (WidgetTester tester) async {
    final controller = MilkyFilterController();

    await controller.initialize().timeout(const Duration(seconds: 10));

    expect(() => controller.setFilterIntensity(0.0), returnsNormally);
    expect(() => controller.setFilterIntensity(0.5), returnsNormally);
    expect(() => controller.setFilterIntensity(1.0), returnsNormally);
    expect(() => controller.setFilterIntensity(-1.0), returnsNormally);
    expect(() => controller.setFilterIntensity(2.0), returnsNormally);

    await controller.dispose();
  });
}
