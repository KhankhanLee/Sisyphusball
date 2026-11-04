import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sisyphusball/ads/ad_breaks.dart';
import 'package:sisyphusball/events.dart';
import 'package:sisyphusball/game/scene.dart' show GameMode;

void main() {
  const delay = Duration(milliseconds: 1500);

  void solo(AdBreaks ads) => ads
    ..onEvent(const RunStarted(GameMode.solo))
    ..onEvent(const RunEnded(GameMode.solo, [5]));

  test('an ad follows every third solo climb, after a pause', () {
    fakeAsync((time) {
      var shown = 0;
      final results = <String>[];
      final ads = AdBreaks(() async {
        shown++;
        return 'AD_CLOSED';
      }, onResult: results.add);

      for (var i = 0; i < 2; i++) {
        solo(ads);
        time.elapse(delay * 2);
      }
      expect(shown, 0);

      solo(ads);
      time.elapse(delay ~/ 2);
      expect(shown, 0, reason: 'the score is seen first');
      time.elapse(delay);
      expect(shown, 1);
      expect(results, ['AD_CLOSED']);

      for (var i = 0; i < 3; i++) {
        solo(ads);
        time.elapse(delay * 2);
      }
      expect(shown, 2);
    });
  });

  test('2P games never show ads', () {
    fakeAsync((time) {
      var shown = 0;
      final ads = AdBreaks(() async => '${shown++}');
      for (var i = 0; i < 6; i++) {
        ads
          ..onEvent(const RunStarted(GameMode.versus))
          ..onEvent(const RunEnded(GameMode.versus, [1, 2]));
        time.elapse(delay * 2);
      }
      expect(shown, 0);
    });
  });

  test('starting the next climb right away skips the ad', () {
    fakeAsync((time) {
      var shown = 0;
      final ads = AdBreaks(() async => '${shown++}', every: 1);
      solo(ads);
      ads.onEvent(const RunStarted(GameMode.solo));
      time.elapse(delay * 2);
      expect(shown, 0);
    });
  });
}
