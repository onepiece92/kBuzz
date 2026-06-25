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

/// Regression for the Stations rail label (option D — wrap to two lines): a long
/// dish name *and* a long special-instruction note on a tight bar must wrap and
/// stay within the lane height, not throw a RenderFlex overflow (which is what
/// happened when the lane wasn't tall enough for two wrapped lines).
void main() {
  testWidgets('a long name + long note wrap on the rail without overflowing',
      (WidgetTester tester) async {
    // Default 800×600 surface. A short cook with a late fire time lands far
    // right, so its label is narrow → the long name + note wrap to two lines.
    // A *vertical* overflow then records an exception and fails the test —
    // exactly the regression (lane too short for two wrapped lines) we guard.
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
        child: const MaterialApp(home: StationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // No overflow exception was recorded, and both the (ellipsised-but-whole)
    // name and the note string are present on the rail.
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Raw Oysters'), findsWidgets);
    expect(find.textContaining('allergy:'), findsWidgets);
  });
}
