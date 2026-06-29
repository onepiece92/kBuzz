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

/// Regression for the accumulation bug: a board whose horizon far exceeds the
/// on-screen window must NOT compress every bar into a sliver — the rail switches
/// to a fixed scale you scroll, and renders without overflow.
void main() {
  testWidgets('a long-horizon board renders the rail without overflow',
      (WidgetTester tester) async {
    final DateTime now = DateTime(2026, 1, 1, 18);
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now));
    final ServiceClockCubit clock = ServiceClockCubit();
    addTearDown(demo.close);
    addTearDown(clock.close);

    // One very long cook ⇒ horizon (120) far exceeds the 90-min window, forcing
    // the fixed-scale + scroll path rather than fit-to-width compression.
    demo.seedFromScan(
      stations: const <Station>[
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 1),
      ],
      menu: const <Dish>[
        Dish(
          id: 'brisket',
          name: 'Smoked Brisket',
          emoji: '🍖',
          stationId: 'grill',
          cookMins: 120,
          holdable: true,
          batchable: false,
        ),
      ],
      kot: Kot(
        id: 'k1',
        table: '5',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(id: 'l1', dishId: 'brisket', qty: 1)],
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        ],
        child: const MaterialApp(
          home: TickerMode(enabled: false, child: StationsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Smoked Brisket'), findsWidgets);
  });
}
