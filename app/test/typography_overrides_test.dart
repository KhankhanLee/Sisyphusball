import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphusball/ui/theme.dart';

void main() {
  // Flutter on the web reads text-spacing overrides (an accessibility
  // feature) from a hidden probe element's CSS. Inside the Pi Browser that
  // probe reports a line height 625× the font size, so every line of text
  // was ~600 times too tall and pushed off screen.
  Future<double> lineHeight(WidgetTester tester, double? override) async {
    // Setting the test value to null would pin it to null for the rest of
    // the test; clearing restores the real (absent) platform value.
    if (override == null) {
      tester.platformDispatcher.clearLineHeightScaleFactorOverrideTestValue();
    } else {
      tester.platformDispatcher.lineHeightScaleFactorOverrideTestValue = override;
    }
    addTearDown(tester.platformDispatcher.clearLineHeightScaleFactorOverrideTestValue);
    await tester.pumpWidget(MaterialApp(
      builder: safeTypography,
      home: const Scaffold(body: Text('Sisyphusball', style: TextStyle(fontSize: 20))),
    ));
    return tester.getSize(find.text('Sisyphusball')).height;
  }

  testWidgets('an absurd line-height override from the browser is ignored', (tester) async {
    final normal = await lineHeight(tester, null);
    final broken = await lineHeight(tester, 625);
    expect(broken, normal);
  });

  testWidgets('a reasonable accessibility line height is still honoured', (tester) async {
    final normal = await lineHeight(tester, null);
    final roomy = await lineHeight(tester, 2.0);
    expect(roomy, greaterThan(normal));
    expect(roomy, closeTo(40, 1)); // 2 × 20 px
  });
}
