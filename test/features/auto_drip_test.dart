import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/service/widgets/auto_drip_listener.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// Hand-driven monotonic clock so the test advances run time deterministically
/// (the service clock derives `elapsed` from this × speed each [tick]).
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
  _FakeMono mono,
});

void main() {
  final DateTime now = DateTime(2026, 6, 21, 18);

  /// Pumps the drip listener over a generated board + a hand-driven run clock,
  /// then starts the run at 1× (elapsed advances 1:1 with [_FakeMono]).
  Future<_Harness> pump(
    WidgetTester tester, {
    required bool enabled,
    int mins = 2,
  }) async {
    final DemoDataCubit demo =
        DemoDataCubit(clock: _FixedClock(now), random: Random(3))..generate();
    final _FakeMono mono = _FakeMono();
    final ServiceClockCubit clock =
        ServiceClockCubit(clock: _FixedClock(now), monotonic: mono);
    final SettingsCubit settings = SettingsCubit()..setAutoDripMins(mins);
    if (enabled) settings.setAutoDripEnabled(true);
    addTearDown(demo.close);
    addTearDown(clock.close);
    addTearDown(settings.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
          BlocProvider<SettingsCubit>.value(value: settings),
        ],
        child: const AutoDripListener(child: SizedBox.shrink()),
      ),
    );

    clock.setSpeed(1);
    clock.start(epoch: demo.state.generatedAt); // elapsed = 0, running
    await tester.pump();
    return (demo: demo, clock: clock, settings: settings, mono: mono);
  }

  /// Advance run time by [d] and fire one tick (the service clock re-derives
  /// elapsed), then let the listener react.
  Future<void> advance(WidgetTester tester, _Harness h, Duration d) async {
    h.mono.advance(d);
    h.clock.tick();
    await tester.pump();
  }

  testWidgets('drips one ticket each interval of run time', (
    WidgetTester tester,
  ) async {
    final _Harness h = await pump(tester, enabled: true, mins: 2);
    final int start = h.demo.state.data!.kots.length;

    // Half an interval — nothing yet.
    await advance(tester, h, const Duration(minutes: 1));
    expect(h.demo.state.data!.kots.length, start);

    // Crossing 2 run-minutes drops one ticket.
    await advance(tester, h, const Duration(minutes: 1));
    expect(h.demo.state.data!.kots.length, start + 1);

    // Another full interval → a second ticket.
    await advance(tester, h, const Duration(minutes: 2));
    expect(h.demo.state.data!.kots.length, start + 2);

    h.clock.pause(); // cancel the run ticker so no timer outlives the test
  });

  testWidgets('a paused run takes no auto orders', (WidgetTester tester) async {
    final _Harness h = await pump(tester, enabled: true, mins: 2);
    final int start = h.demo.state.data!.kots.length;

    h.clock.pause();
    // Elapsed still advances on a manual tick, but the run isn't playing.
    await advance(tester, h, const Duration(minutes: 10));
    expect(h.demo.state.data!.kots.length, start);
  });

  testWidgets('no drip while the toggle is off', (WidgetTester tester) async {
    final _Harness h = await pump(tester, enabled: false, mins: 2);
    final int start = h.demo.state.data!.kots.length;

    await advance(tester, h, const Duration(minutes: 10));
    expect(h.demo.state.data!.kots.length, start);

    h.clock.pause(); // cancel the run ticker so no timer outlives the test
  });
}
