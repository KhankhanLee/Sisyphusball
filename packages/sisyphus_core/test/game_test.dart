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

  test('a careful player gets through the warm-up on the real mountain', () {
    expect(cautiousBotScore(Mountain()), greaterThanOrEqualTo(warmUpHeight));
  });

  test('steering moves across the path no faster than maxSide, and not into the walls', () {
    final c = Climber(_EmptyMountain())..steerTo(-5);
    expect(c.targetX, Climber.minX);
    c.step(0.1, pushing: true);
    expect(0.5 - c.x, closeTo(Phys.maxSide / laneWidth * 0.1, 1e-9));
    for (var i = 0; i < 120; i++) {
      c.step(1 / 60, pushing: true);
    }
    expect(c.x, Climber.minX);
    c.steerTo(5);
    for (var i = 0; i < 240; i++) {
      c.step(1 / 60, pushing: true);
    }
    expect(c.x, Climber.maxX);
  });

  test('a rock in the middle of the path can be passed by steering around it', () {
    Climber climb({required bool steer}) {
      final c = Climber(_PillarMountain(6));
      if (steer) c.steerTo(0.1);
      for (var i = 0; i < 300 && c.state == ClimbState.climbing; i++) {
        c.step(1 / 60, pushing: true);
      }
      return c;
    }

    expect(climb(steer: false).state, isNot(ClimbState.climbing), reason: 'straight up hits it');
    final dodged = climb(steer: true);
    expect(dodged.state, ClimbState.climbing);
    expect(dodged.y, greaterThan(8));
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

/// A still rock, 30% of the path wide, right in the middle at [height].
class _PillarMountain extends Mountain {
  _PillarMountain(double height) {
    rocks.add(Rock(y: height, width: 0.3, speed: 0, phase: 0.5, dir: 1));
  }

  @override
  void ensure(double height) {}
}

/// A cautious player: pushes only while the rocks just above stay clear of
/// the stone for the next [look] seconds, otherwise lets it slide.
int cautiousBotScore(Mountain m, {double look = 0.5, double maxSeconds = 600}) {
  final c = Climber(m);
  var elapsed = 0.0;
  while (c.state == ClimbState.climbing && elapsed < maxSeconds) {
    var clear = true;
    for (final rock in m.inRange(c.y, c.y + 3)) {
      for (var k = 0; k <= 10 && clear; k++) {
        final dt = look * k / 10;
        final y = (c.y + c.v * dt + 0.5 * Phys.pushAcc * dt * dt).clamp(c.y, c.y + Phys.maxUp * dt);
        if (rock.hits(c.t + dt, y)) clear = false;
      }
    }
    c.step(1 / 60, pushing: clear);
    elapsed += 1 / 60;
  }
  return c.score;
}
