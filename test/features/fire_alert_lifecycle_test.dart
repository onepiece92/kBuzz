import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fire_alert_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// Lifecycle coverage for the fire-alert audio: what fires (and crucially what
/// does NOT) across Start / restart / pause / resume — the "weird audio on play"
/// scenarios. Detection itself is unit-tested in [fire_alert_test]; here we drive
/// the real cubits to lock down the Start/Resume **priming** + the **running
/// gate**.

/// Hand-set wall clock (epoch + foreground-sync reconciliation read from here).
class _FakeWall extends Clock {
  _FakeWall(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// Hand-driven monotonic clock so a forward run advances deterministically.
class _FakeMono extends MonotonicClock {
  Duration _e = Duration.zero;
  void advance(Duration d) => _e += d;
  @override
  Duration elapsed() => _e;
}

typedef _Harness = ({
  DemoDataCubit demo,
  ServiceClockCubit clock,
  SettingsCubit settings,
  FireAlertCubit fire,
  _FakeWall wall,
  _FakeMono mono,
});

void main() {
  final DateTime t0 = DateTime(2026, 1, 1, 18);

  /// Build the real cubit graph with a generated board. [fireImmediately] makes
  /// every cook's fireAt == 0, so "due now" vs "backlog" is unambiguous.
  _Harness build({required bool fireImmediately}) {
    final _FakeWall wall = _FakeWall(t0);
    final _FakeMono mono = _FakeMono();
    final DemoDataCubit demo = DemoDataCubit(clock: wall, random: Random(7))
      ..generate();
    final SettingsCubit settings = SettingsCubit()
      ..setFireImmediately(fireImmediately);
    final ServiceClockCubit clock = ServiceClockCubit(
      clock: wall,
      monotonic: mono,
    );
    final FireAlertCubit fire = FireAlertCubit(
      data: demo,
      clock: clock,
      settings: settings,
    );
    addTearDown(() async {
      await fire.close();
      await clock.close();
      await demo.close();
      await settings.close();
    });
    return (
      demo: demo,
      clock: clock,
      settings: settings,
      fire: fire,
      wall: wall,
      mono: mono,
    );
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('a fresh Start (elapsed 0) fires the due batch', () async {
    final _Harness h = build(fireImmediately: true);
    h.clock.setSpeed(1);
    h.clock.start(epoch: h.wall.now()); // epoch == now → elapsed 0
    await settle();
    // fireImmediately ⇒ the t=0 cooks are genuinely due now → they fire.
    expect(h.fire.state.latest, isNotEmpty);
    expect(h.fire.state.tick, greaterThan(0));
    h.clock.pause();
  });

  test('a restart with a stale epoch does NOT replay the backlog', () async {
    final _Harness h = build(fireImmediately: true);
    h.clock.setSpeed(1);
    // Simulate a cold-start auto-resume / late Start: epoch 30 min in the past →
    // elapsed seeds to 30. Every cook (fireAt 0) is already long past.
    h.clock.start(epoch: h.wall.now().subtract(const Duration(minutes: 30)));
    await settle();
    // Primed away — no chime + spoken backlog dump on play.
    expect(h.fire.state.latest, isEmpty);
    expect(h.fire.state.tick, 0);
    h.clock.pause();
  });

  test('a paused run takes no orders when it foreground-syncs', () async {
    final _Harness h = build(fireImmediately: false); // spread fireAt
    h.clock.setSpeed(1);
    h.clock.start(epoch: h.wall.now()); // elapsed 0
    await settle();
    final int afterStart = h.fire.state.tick;

    h.clock.pause();
    await settle();
    // Time passes while backgrounded, then the app foregrounds and syncs.
    h.wall.advance(const Duration(minutes: 120));
    h.clock.sync();
    await settle();

    // The run is paused → no fires, even though elapsed jumped past every cook.
    expect(h.fire.state.tick, afterStart);
    h.clock.reset();
  });

  test('resuming after a long pause does not burst the backlog', () async {
    final _Harness h = build(fireImmediately: false);
    h.clock.setSpeed(1);
    h.clock.start(epoch: h.wall.now());
    await settle();
    final int afterStart = h.fire.state.tick;

    h.clock.pause();
    await settle();
    h.wall.advance(const Duration(minutes: 120));
    h.clock.resume(); // re-anchors elapsed forward, then runs
    await settle();

    // Resume primes the backlog → only forward crossings announce, no burst.
    expect(h.fire.state.tick, afterStart);
    h.clock.reset();
  });

  test('a normal forward run still fires as the clock advances', () async {
    // Priming on Start must not suppress genuine forward fires.
    final _Harness h = build(fireImmediately: false);
    h.clock.setSpeed(1);
    h.clock.start(epoch: h.wall.now()); // elapsed 0, nothing primed
    await settle();

    h.mono.advance(
      const Duration(minutes: 120),
    ); // run forward past the horizon
    h.clock.tick();
    await settle();

    expect(h.fire.state.latest, isNotEmpty); // cooks fired going forward
    h.clock.reset();
  });
}
