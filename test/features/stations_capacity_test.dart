import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/stations/stations_page.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  testWidgets('capacity stepper bumps a station and the rail reflects it', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime(2026, 1, 1, 12);
    // Deterministic single-station board (cap 2) so the only "+" is Grill's and
    // the result is exact — generate() uses an unseeded random rush, which made
    // "first station" / its capacity vary between runs.
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now));
    demo.seedFromScan(
      stations: const <Station>[
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2),
      ],
      menu: const <Dish>[
        Dish(
          id: 'steak',
          name: 'Steak',
          emoji: '🥩',
          stationId: 'grill',
          cookMins: 8,
          holdable: false,
          batchable: false,
        ),
      ],
      kot: Kot(
        id: 'k1',
        table: '5',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(id: 'l1', dishId: 'steak', qty: 1)],
      ),
    );
    final ServiceClockCubit clock = ServiceClockCubit();
    addTearDown(demo.close);
    addTearDown(clock.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        ],
        // TickerMode off so the bar-name marquee sits still (pumpAndSettle
        // would never settle against a forever-looping animation).
        child: const MaterialApp(
          home: TickerMode(enabled: false, child: StationsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Grill starts at cap 2.
    expect(find.text('cap 2'), findsOneWidget);
    expect(find.text('cap 4'), findsNothing);

    // Tap Grill's "+" twice → capacity 4.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(find.text('cap 4'), findsOneWidget);
  });
}
