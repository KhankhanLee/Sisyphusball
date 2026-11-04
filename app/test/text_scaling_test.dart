import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphusball/ui/theme.dart';

void main() {
  // Some WebViews (the Pi Browser among them) report a huge base font size,
  // which Flutter turns into a text scale large enough to push every word
  // off screen. The app keeps text scaling within a small, accessible range.
  testWidgets('a huge platform text scale is clamped', (tester) async {
    Future<double> heightAt(double scale) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      await tester.pumpWidget(MaterialApp(
        builder: clampTextScaling,
        home: const Scaffold(body: Text('Sisyphusball', style: TextStyle(fontSize: 20))),
      ));
      return tester.getSize(find.text('Sisyphusball')).height;
    }

    final normal = await heightAt(1);
    final huge = await heightAt(10);
    expect(huge / normal, lessThanOrEqualTo(maxTextScale + 0.01));
    expect(huge, greaterThan(normal), reason: 'some scaling stays for accessibility');
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}
