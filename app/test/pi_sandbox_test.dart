import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphusball/pi/pi_sandbox.dart';

void main() {
  test('only the Pi Developer Portal sandbox counts as the sandbox', () {
    expect(isPiSandboxReferrer('https://sandbox.minepi.com/app/sisyphusball'), isTrue);
    expect(isPiSandboxReferrer('https://sandbox.minepi.com/'), isTrue);
    expect(isPiSandboxReferrer(''), isFalse);
    expect(isPiSandboxReferrer('https://sisyphusball.app/'), isFalse);
    expect(isPiSandboxReferrer('https://sandbox.minepi.com.evil.example/'), isFalse);
    expect(isPiSandboxReferrer('http://sandbox.minepi.com/'), isFalse);
  });
}
