import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/service/widgets/auto_serve_listener.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

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

  // One dineIn ticket, one 4-min cook → target 14, finishes (plates) at 14.
  Future<_Harness> pump(
    WidgetTester tester, {
    required bool enabled,
    Duration delay = const Duration(minutes: 2),
  }) async {
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now));
    demo.seedFromScan(
      stations: const <Station>[
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 1),
      ],
      menu: const <Dish>[
        Dish(
          id: 'soup',
          name: 'Soup',
          emoji: '🍲',
          stationId: 'grill',
          cookMins: 4,
          holdable: true,
          batchable: false,
        ),
      ],
      kot: Kot(
        id: 'k1',
        table: '5',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(id: 'l1', dishId: 'soup', qty: 1)],
      ),
    );
    final _FakeMono mono = _FakeMono();
    final ServiceClockCubit clock =
        ServiceClockCubit(clock: _FixedClock(now), monotonic: mono);
    final SettingsCubit settings = SettingsCubit()..setAutoServeDelay(delay);
    settings.setAutoServeEnabled(enabled); // explicit: default is now ON
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
        child: const AutoServeListener(child: SizedBox.shrink()),
      ),
    );

    clock.setSpeed(1);
    clock.start(epoch: demo.state.generatedAt);
    await tester.pump();
    return (demo: demo, clock: clock, settings: settings, mono: mono);
  }

  Future<void> advanceTo(WidgetTester tester, _Harness h, int mins) async {
    h.mono.advance(Duration(minutes: mins) - h.clock.state.elapsed);
    h.clock.tick();
    await tester.pump();
  }

  bool isDone(_Harness h) =>
      h.demo.state.data!.kots.single.status == TicketState.done;

  testWidgets('auto-serves + closes a ticket once ready past the delay',
      (WidgetTester tester) async {
    final _Harness h = await pump(tester, enabled: true); // delay 2m, plate 14m
    expect(isDone(h), isFalse);

    await advanceTo(tester, h, 15); // ready (14) but within the 2-min grace
    expect(isDone(h), isFalse);

    await advanceTo(tester, h, 17); // 14 + 2 grace crossed
    expect(isDone(h), isTrue);

    h.clock.pause();
  });

  testWidgets('does nothing while the toggle is off',
      (WidgetTester tester) async {
    final _Harness h = await pump(tester, enabled: false);
    await advanceTo(tester, h, 30);
    expect(isDone(h), isFalse);
    h.clock.pause();
  });
}
