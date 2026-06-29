import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// A wall clock we can move by hand. The run clock reconciles to this on
/// start/resume (and seeds elapsed from it), so jumping it simulates real time
/// passing while backgrounded, plus NTP/DST/manual clock edits.
class _FakeClock extends Clock {
  _FakeClock(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  void jumpTo(DateTime t) => _now = t;
  @override
  DateTime now() => _now;
}

/// A hand-driven monotonic clock — in-session elapsed advances off THIS, so
/// advancing it (but not the wall clock) is "real foreground time passing", and
/// advancing the wall clock (but not this) is a wall-clock jump the board must
/// ignore.
class _FakeMono extends MonotonicClock {
  Duration _e = Duration.zero;
  void advance(Duration d) => _e += d;
  @override
  Duration elapsed() => _e;
}

void main() {
  late _FakeClock clock;
  late _FakeMono mono;
  final DateTime t0 = DateTime(2026, 1, 1, 18); // 6pm

  ServiceClockCubit make() {
    final ServiceClockCubit c =
        ServiceClockCubit(clock: clock, monotonic: mono);
    addTearDown(c.close); // cancel the periodic ticker
    return c;
  }

  setUp(() {
    clock = _FakeClock(t0);
    mono = _FakeMono();
  });

  group('ServiceClockCubit — wall epoch + monotonic elapsed', () {
    test('start() anchors the epoch and zeroes elapsed', () {
      final ServiceClockCubit c = make();
      expect(c.state.started, isFalse);
      expect(c.state.epoch, isNull);

      c.start();
      expect(c.state.started, isTrue);
      expect(c.state.epoch, t0);
      expect(c.state.elapsed, Duration.zero);
    });

    test('start(epoch:) resumes the real wall gap since the board epoch', () {
      final ServiceClockCubit c = make()..setSpeed(1);
      c.start(epoch: t0.subtract(const Duration(minutes: 3)));
      // 3 real minutes already elapsed since that epoch.
      expect(c.state.elapsedMins, closeTo(3, 1e-9));
    });

    test('foreground elapsed advances off the MONOTONIC clock', () {
      final ServiceClockCubit c = make()..setSpeed(1)..start();
      mono.advance(const Duration(minutes: 10));
      c.tick();
      expect(c.state.elapsedMins, closeTo(10, 1e-9));
    });

    test('a wall-clock JUMP does not move foreground elapsed (NTP/DST immune)',
        () {
      final ServiceClockCubit c = make()..setSpeed(1)..start();
      mono.advance(const Duration(minutes: 5));
      c.tick();
      expect(c.state.elapsedMins, closeTo(5, 1e-9));

      // Device clock lurches +60m forward and then backward — no real time
      // passed (mono unchanged), so elapsed must stay put.
      clock.advance(const Duration(minutes: 60));
      c.tick();
      expect(c.state.elapsedMins, closeTo(5, 1e-9));
      clock.jumpTo(t0.subtract(const Duration(hours: 2)));
      c.tick();
      expect(c.state.elapsedMins, closeTo(5, 1e-9));
    });

    test('sync() reconciles to the wall clock — recovers a long background gap',
        () {
      final ServiceClockCubit c = make()..setSpeed(1)..start();
      // Backgrounded 47 min: no ticks, the Stopwatch may not have advanced.
      clock.advance(const Duration(minutes: 47));
      c.sync();
      expect(c.state.elapsedMins, closeTo(47, 1e-9));
    });

    test('pause does NOT stop wall time — resume reconciles to true elapsed', () {
      final ServiceClockCubit c = make()..setSpeed(1)..start();
      clock.advance(const Duration(minutes: 5));
      c.pause();
      expect(c.state.running, isFalse);
      clock.advance(const Duration(minutes: 20)); // wall flows while paused
      c.resume();
      expect(c.state.running, isTrue);
      expect(c.state.elapsedMins, closeTo(25, 1e-9)); // none lost to the pause
    });

    test('default speed is 1x (real time)', () {
      expect(make().state.speed, 1);
    });

    test('speed scales monotonic time (8x ⇒ 1 real min = 8 kitchen min)', () {
      final ServiceClockCubit c = make()..setSpeed(8);
      c.start();
      expect(c.state.speed, 8);
      mono.advance(const Duration(minutes: 1));
      c.tick();
      expect(c.state.elapsedMins, closeTo(8, 1e-9));
    });

    test('cold-start resume scales the wall gap by the restored speed', () {
      // A 5-min-old board at 8x must resume at 40 kitchen-min, not 5 — the
      // persisted speed is applied to the wall gap.
      final ServiceClockCubit c = make()..setSpeed(8);
      c.start(epoch: t0.subtract(const Duration(minutes: 5)));
      expect(c.state.elapsedMins, closeTo(40, 1e-9)); // 5 wall min × 8
    });

    test('setSpeed keeps elapsed continuous and never moves the epoch', () {
      final ServiceClockCubit c = make()..setSpeed(1)..start();
      mono.advance(const Duration(minutes: 10));
      c.tick();
      expect(c.state.elapsedMins, closeTo(10, 1e-9));

      c.setSpeed(8); // switch at the 10-min mark
      expect(c.state.elapsedMins, closeTo(10, 1e-9)); // no jump at the instant
      expect(c.state.epoch, t0); // epoch is immutable across a speed change

      mono.advance(const Duration(minutes: 1)); // 1 more real min, now at 8x
      c.tick();
      expect(c.state.elapsedMins, closeTo(18, 1e-9)); // 10 + 8
      expect(c.state.epoch, t0);
    });

    test('sync after a speed change reconciles per-segment (no forward jump)',
        () {
      // 10 real min at 1x → board +10.
      final ServiceClockCubit c = make()..setSpeed(1)..start();
      mono.advance(const Duration(minutes: 10));
      clock.advance(const Duration(minutes: 10));
      c.tick();
      expect(c.state.elapsedMins, closeTo(10, 1e-9));

      // Switch to 8x, then 1 real min → board +8 (total 18).
      c.setSpeed(8);
      mono.advance(const Duration(minutes: 1));
      clock.advance(const Duration(minutes: 1));
      c.tick();
      expect(c.state.elapsedMins, closeTo(18, 1e-9));

      // Resume / app-foreground: sync must add only the gap since the speed
      // change (×8), NOT re-scale the whole 11-min wall span (which gave 88).
      c.sync();
      expect(c.state.elapsedMins, closeTo(18, 1e-9));

      // And a further background gap accrues at the *current* speed.
      clock.advance(const Duration(minutes: 2)); // 2 wall min while away
      c.sync();
      expect(c.state.elapsedMins, closeTo(34, 1e-9)); // 18 + 2×8
    });

    test('a future epoch never yields negative elapsed', () {
      final ServiceClockCubit c = make();
      c.start(epoch: t0.add(const Duration(minutes: 5)));
      expect(c.state.elapsedMins, 0);
    });

    test('reset clears back to not-started', () {
      final ServiceClockCubit c = make()..start();
      clock.advance(const Duration(minutes: 5));
      c.sync();
      expect(c.state.started, isTrue);

      c.reset();
      expect(c.state.started, isFalse);
      expect(c.state.epoch, isNull);
      expect(c.state.elapsed, Duration.zero);
    });
  });
}
