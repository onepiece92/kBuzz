import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/queue/queue_page.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

class _Wall extends Clock {
  _Wall(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// Fire-next is the upcoming/in-progress feed: a cook that has FINISHED cooking
/// drops off even before its ticket is served (it's the expo's to serve now),
/// so the queue doesn't accumulate a backlog of done items as tickets arrive.
void main() {
  testWidgets('a finished (but not-yet-served) cook drops off Fire-next',
      (WidgetTester tester) async {
    final DateTime now = DateTime(2026, 1, 1, 18);
    final _Wall wall = _Wall(now);
    final DemoDataCubit demo = DemoDataCubit(clock: wall);
    final ServiceClockCubit clock = ServiceClockCubit(clock: wall);
    addTearDown(demo.close);
    addTearDown(clock.close);

    const Station grill =
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2);
    const Dish quick = Dish(
      id: 'quick',
      name: 'Quick Fry',
      emoji: '🍟',
      stationId: 'grill',
      cookMins: 2,
      holdable: false,
      batchable: false,
    );
    const Dish slow = Dish(
      id: 'slow',
      name: 'Slow Roast',
      emoji: '🍖',
      stationId: 'grill',
      cookMins: 60,
      holdable: true,
      batchable: false,
    );

    // Two independent tickets so the quick one isn't held to plate with the slow.
    demo.seedFromScan(
      stations: const <Station>[grill],
      menu: const <Dish>[quick, slow],
      kot: Kot(
        id: 'A',
        table: '1',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(id: 'a1', dishId: 'quick', qty: 1)],
      ),
    );
    demo.addKot(
      Kot(
        id: 'B',
        table: '2',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(id: 'b1', dishId: 'slow', qty: 1)],
      ),
    );

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        ],
        child: const MaterialApp(home: QueuePage()),
      ),
    );
    await tester.pumpAndSettle();

    // Before the run, both cooks are queued.
    expect(find.textContaining('Quick Fry'), findsWidgets);
    expect(find.textContaining('Slow Roast'), findsWidgets);

    // Run to minute 15: Quick (finishes ~14) is cooked but NOT yet served
    // (plate 14 + retain 3 = 17), while Slow (finishes 60) is still cooking.
    clock.start(epoch: demo.state.generatedAt);
    wall.advance(const Duration(minutes: 15));
    clock.sync();
    await tester.pump(const Duration(seconds: 1));

    expect(find.textContaining('Quick Fry'), findsNothing); // dropped: cooked
    expect(find.textContaining('Slow Roast'), findsWidgets); // still cooking

    clock.reset();
    await tester.pumpAndSettle();
  });
}
