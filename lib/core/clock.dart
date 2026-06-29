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

/// Monotonic elapsed-time source, independent of the wall clock.
///
/// The run clock measures in-session elapsed against this so a device wall-clock
/// change (NTP sync / DST / a manual edit) can't move the board mid-service.
/// It is **never persisted** — a monotonic source resets on process death /
/// reboot, which is why durable anchors stay absolute wall timestamps and the
/// run clock re-anchors monotonic→wall on start / cold-start / resume.
abstract class MonotonicClock {
  const MonotonicClock();

  /// Elapsed time since this clock began counting (no fixed zero point — only
  /// differences are meaningful).
  Duration elapsed();
}

/// Production [MonotonicClock] backed by a single `dart:core` [Stopwatch] (no
/// plugin). The stopwatch starts the first time [elapsed] is read.
class StopwatchMonotonicClock extends MonotonicClock {
  StopwatchMonotonicClock();

  final Stopwatch _sw = Stopwatch();

  @override
  Duration elapsed() {
    if (!_sw.isRunning) _sw.start();
    return _sw.elapsed;
  }
}
