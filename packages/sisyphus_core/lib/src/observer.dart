/// A minimal, typed Observer pattern.
///
/// Relationships are n:m: a [Subject] notifies any number of observers, and
/// one [Observer] can be attached to any number of subjects. To make that
/// work with Dart's generics, all subjects and observers of one application
/// share a single sealed event family `E` — each subject emits only its own
/// subtypes, and each observer pattern-matches on the ones it cares about.
library;

abstract interface class Observer<E> {
  void onEvent(E event);
}

/// Wraps a closure as an [Observer]; handy for tests and one-off listeners.
final class CallbackObserver<E> implements Observer<E> {
  CallbackObserver(this._callback);

  final void Function(E event) _callback;

  @override
  void onEvent(E event) => _callback(event);
}

mixin Subject<E> {
  final List<Observer<E>> _observers = [];

  int get observerCount => _observers.length;

  void attach(Observer<E> observer) {
    if (!_observers.contains(observer)) _observers.add(observer);
  }

  void detach(Observer<E> observer) => _observers.remove(observer);

  void detachAll() => _observers.clear();

  /// Delivers [event] to every observer attached right now. Observers may
  /// attach or detach while being notified; that takes effect next time.
  void notify(E event) {
    for (final observer in List.of(_observers)) {
      observer.onEvent(event);
    }
  }
}
