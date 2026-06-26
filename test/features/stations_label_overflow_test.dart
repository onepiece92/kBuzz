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

/// Regression for the Stations rail bar (true-Gantt, sliding labels): a long
/// dish name and its note both render on the bar — name on the first line, note
/// on a second line beneath it — with no overflow / bleed even on a thin
/// short-cook bar.
void main() {
  testWidgets('name and note both render on the bar (sliding), no overflow',
      (WidgetTester tester) async {
    final DateTime now = DateTime(2026, 1, 1, 12);
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now));
    final ServiceClockCubit clock = ServiceClockCubit();
    addTearDown(demo.close);
    addTearDown(clock.close);

    demo.seedFromScan(
      stations: const <Station>[
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 1),
      ],
      menu: const <Dish>[
        Dish(
          id: 'oy',
          name: 'Raw Oysters (Half Dozen) on the Half Shell with Mignonette',
          emoji: '🦪',
          stationId: 'grill',
          cookMins: 3,
          holdable: false,
          batchable: false,
        ),
      ],
      kot: Kot(
        id: 'k1',
        table: '5',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[
          OrderLine(
            id: 'l1',
            dishId: 'oy',
            qty: 1,
            note: 'allergy: shellfish at table, separate plate, '
                'no cross-contamination',
          ),
        ],
      ),
    );

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

    // No overflow; the name is on the first line and the note on a second line
    // beneath it (both present as Text, even with the marquee held still).
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Raw Oysters'), findsWidgets);
    expect(find.byIcon(Icons.sticky_note_2_outlined), findsWidgets);
    expect(find.textContaining('allergy:'), findsWidgets);
  });
}
