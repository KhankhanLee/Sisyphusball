// Pure game logic. World units are meters; height grows upward and every
// meter climbed is exactly one point.

/// Physics of the stone.
abstract final class Phys {
  /// Upward acceleration while the player pushes (m/s²).
  static const double pushAcc = 13;

  /// The slope pulls the stone back down once released (m/s²).
  static const double gravity = 9;

  /// Fastest possible climb (m/s).
  static const double maxUp = 4.5;

  /// Fastest roll back while still in control (m/s).
  static const double maxDown = 7;

  /// Acceleration of the final tumble to the bottom (m/s²).
  static const double fallAcc = 28;
}

/// The server rejects any score that would need a faster climb than this.
const double maxPointsPerSecond = Phys.maxUp;

const double laneWidth = 9; // width of the mountain path (m)
const double ballRadius = 0.45; // stone radius (m)
const double rockThickness = 0.7; // vertical size of a sweeping rock (m)
const double safeBase = 4; // the first meters never have rocks

const int defaultSeed = 0x51515;

/// xorshift32. Only shifts, xors and masks on values below 2^32, so it yields
/// the same sequence on the Dart VM (server, tests) and on the web.
class Rng {
  Rng(int seed) : _s = (seed & 0xffffffff) == 0 ? 0x9e3779b9 : seed & 0xffffffff;

  int _s;

  double next() {
    var x = _s;
    x ^= (x << 13) & 0xffffffff;
    x ^= x >> 17;
    x ^= (x << 5) & 0xffffffff;
    _s = x & 0xffffffff;
    return _s / 4294967296;
  }
}

/// A rock that sweeps across the path at a fixed height.
class Rock {
  const Rock({
    required this.y,
    required this.width,
    required this.speed,
    required this.phase,
    required this.dir,
  });

  final double y; // height (m)
  final double width; // fraction of the path width
  final double speed; // path widths per second
  final double phase; // 0..2 starting point of the bounce
  final int dir; // 1 or -1

  /// Horizontal center (0..1) at time [t]; it bounces wall to wall.
  double xAt(double t) {
    final travel = (1 - width).clamp(0.01, 1.0);
    var u = (phase + dir * speed * t / travel) % 2;
    if (u < 0) u += 2;
    final tri = u < 1 ? u : 2 - u;
    return width / 2 + tri * travel;
  }

  /// The stone always sits in the middle of the path; only its height moves.
  bool hits(double t, double ballY) {
    if ((ballY - y).abs() >= ballRadius + rockThickness / 2) return false;
    final halfW = width / 2 + (ballRadius / laneWidth) * 0.85;
    return (xAt(t) - 0.5).abs() < halfW;
  }
}

/// The same seed yields the same mountain for every player, so the ranking
/// compares the same climb. Rocks are generated lazily as the stone rises.
class Mountain {
  Mountain([int seed = defaultSeed]) : _rng = Rng(seed);

  final Rng _rng;
  final List<Rock> rocks = [];
  double _top = safeBase;

  void ensure(double height) {
    while (_top < height) {
      _generate();
    }
  }

  void _generate() {
    final y = _top;
    final difficulty = (y / 120).clamp(0.0, 1.8);
    rocks.add(Rock(
      y: y,
      width: 0.22 + _rng.next() * 0.18,
      speed: (0.22 + _rng.next() * 0.2) * (1 + difficulty),
      phase: _rng.next() * 2,
      dir: _rng.next() < 0.5 ? 1 : -1,
    ));
    _top += (5.5 - y / 80).clamp(2.2, 5.5) + _rng.next() * 2.5;
  }

  /// Rocks whose height lies in [lo, hi].
  Iterable<Rock> inRange(double lo, double hi) sync* {
    ensure(hi + 1);
    var a = 0, b = rocks.length;
    while (a < b) {
      final mid = (a + b) >> 1;
      if (rocks[mid].y < lo) {
        a = mid + 1;
      } else {
        b = mid;
      }
    }
    for (var i = a; i < rocks.length && rocks[i].y <= hi; i++) {
      yield rocks[i];
    }
  }
}

enum ClimbState { climbing, falling, over }

/// What happened during one [Climber.step].
class StepEvents {
  int gained = 0;
  bool crashed = false;
  bool over = false;
}

/// One stone and the person pushing it. Moves strictly vertically.
class Climber {
  Climber(this.mountain);

  final Mountain mountain;

  double y = 0; // height of the stone (m)
  double v = 0; // vertical velocity (m/s)
  double max = 0; // highest point of this climb
  int score = 0; // floor(max): +1 per meter, never anything else
  double t = 0; // time since the climb started (s)
  double rotation = 0; // for drawing the rolling stone
  double figureY = 0; // where Sisyphus stands; stays put when the stone slips
  ClimbState state = ClimbState.climbing;

  void reset() {
    y = v = max = t = rotation = figureY = 0;
    score = 0;
    state = ClimbState.climbing;
  }

  StepEvents step(double dt, {required bool pushing}) {
    final ev = StepEvents();
    if (state == ClimbState.over) return ev;
    t += dt;
    final prevY = y;

    if (state == ClimbState.falling) {
      v -= Phys.fallAcc * dt;
      y += v * dt;
      if (y <= 0) {
        y = v = 0;
        state = ClimbState.over;
        ev.over = true;
      }
    } else {
      v += (pushing ? Phys.pushAcc : -Phys.gravity) * dt;
      v = v.clamp(-Phys.maxDown, Phys.maxUp);
      y += v * dt;
      if (y < 0) y = v = 0;
      if (y > max) {
        max = y;
        final next = max.floor();
        ev.gained = next - score;
        score = next;
      }
      figureY = y;
      if (mountain.inRange(y - 1.5, y + 1.5).any((r) => r.hits(t, y))) {
        state = ClimbState.falling;
        if (v > 0) v = 0;
        ev.crashed = true;
      }
    }

    rotation += (y - prevY) / ballRadius;
    return ev;
  }
}
