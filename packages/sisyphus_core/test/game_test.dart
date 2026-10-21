import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:test/test.dart';

void main() {
  test('the same seed builds the same mountain', () {
    final a = Mountain(42)..ensure(300);
    final b = Mountain(42)..ensure(300);
    expect(a.rocks.length, b.rocks.length);
    for (var i = 0; i < a.rocks.length; i++) {
      expect(a.rocks[i].y, b.rocks[i].y);
      expect(a.rocks[i].xAt(3.7), b.rocks[i].xAt(3.7));
    }
  });

  test('rng stays within [0, 1)', () {
    final r = Rng(defaultSeed);
    for (var i = 0; i < 10000; i++) {
      final x = r.next();
      expect(x >= 0 && x < 1, isTrue);
    }
  });

  test('rocks stay inside the path', () {
    final m = Mountain()..ensure(500);
    for (final r in m.rocks) {
      for (var t = 0.0; t < 20; t += 0.37) {
        final x = r.xAt(t);
        expect(x - r.width / 2, greaterThanOrEqualTo(-1e-9));
        expect(x + r.width / 2, lessThanOrEqualTo(1 + 1e-9));
      }
    }
  });

  test('score rises linearly, one point per meter, and never faster than maxUp',
      () {
    final c = Climber(_EmptyMountain());
    var total = 0;
    for (var i = 0; i < 600; i++) {
      final ev = c.step(1 / 60, pushing: true);
      expect(ev.gained, inInclusiveRange(0, 1));
      total += ev.gained;
    }
    expect(total, c.score);
    expect(c.score, c.max.floor());
    expect(c.score, lessThanOrEqualTo((c.t * maxPointsPerSecond).ceil()));
  });

  test('releasing lets the stone roll back without losing points', () {
    final c = Climber(_EmptyMountain());
    for (var i = 0; i < 120; i++) {
      c.step(1 / 60, pushing: true);
    }
    final score = c.score;
    for (var i = 0; i < 600; i++) {
      c.step(1 / 60, pushing: false);
    }
    expect(c.y, 0);
    expect(c.score, greaterThanOrEqualTo(score)); // momentum may add a meter
    expect(c.score, c.max.floor());
    expect(c.state, ClimbState.climbing);
  });

  test('hitting a rock sends the stone all the way to the bottom', () {
    final c = Climber(_WallMountain(6));
    var crashed = false;
    var over = false;
    for (var i = 0; i < 2000 && !over; i++) {
      final ev = c.step(1 / 60, pushing: true);
      crashed |= ev.crashed;
      over |= ev.over;
    }
    expect(crashed, isTrue);
    expect(over, isTrue);
    expect(c.y, 0);
    expect(c.score, greaterThan(0));
    expect(c.figureY, greaterThan(0), reason: 'Sisyphus stays where it slipped');
  });

  test('tiers', () {
    expect(tierFor(0).name, 'Pebble at the Bottom');
    expect(tierFor(99).min, 50);
    expect(tierFor(100000).name, 'Happy Sisyphus');
    expect(nextTier(0)!.min, 10);
    expect(nextTier(800), isNull);
  });
}

class _EmptyMountain extends Mountain {
  @override
  void ensure(double height) {}
}

/// A rock as wide as the path at [height]: it cannot be passed.
class _WallMountain extends Mountain {
  _WallMountain(double height) {
    rocks.add(Rock(y: height, width: 1, speed: 0, phase: 0, dir: 1));
  }

  @override
  void ensure(double height) {}
}
