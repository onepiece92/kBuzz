/// Time abstraction.
///
/// Inject a [Clock] instead of calling [DateTime.now] directly, so the
/// scheduler and sync engine stay deterministic and unit-testable
/// (AGENTS.md §0.3 / §10: "no `DateTime.now()` inside the scheduler — pass
/// `now` in"). Tests provide a fixed clock; production uses [SystemClock].
abstract class Clock {
  const Clock();

  /// The current wall-clock time.
  DateTime now();
}

/// Production clock backed by the system time.
class SystemClock extends Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
