import 'package:sisyphus_core/sisyphus_core.dart';
import 'package:test/test.dart';

sealed class Ev {}

class A extends Ev {}

class B extends Ev {}

class Source with Subject<Ev> {}

class Recorder implements Observer<Ev> {
  final seen = <String>[];

  @override
  void onEvent(Ev event) => seen.add(switch (event) { A() => 'a', B() => 'b' });
}

void main() {
  test('n:m — every observer hears every subject it is attached to', () {
    final s1 = Source(), s2 = Source();
    final r1 = Recorder(), r2 = Recorder();
    s1
      ..attach(r1)
      ..attach(r2);
    s2.attach(r2);

    s1.notify(A());
    s2.notify(B());

    expect(r1.seen, ['a']);
    expect(r2.seen, ['a', 'b']);
  });

  test('attach is idempotent and detach stops delivery', () {
    final s = Source(), r = Recorder();
    s
      ..attach(r)
      ..attach(r);
    expect(s.observerCount, 1);
    s.detach(r);
    s.notify(A());
    expect(r.seen, isEmpty);
  });

  test('observers may detach while being notified', () {
    final s = Source();
    late CallbackObserver<Ev> once;
    var calls = 0;
    once = CallbackObserver((_) {
      calls++;
      s.detach(once);
    });
    s
      ..attach(once)
      ..notify(A())
      ..notify(A());
    expect(calls, 1);
  });
}
