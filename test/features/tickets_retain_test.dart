import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/queue/queue_page.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/tickets/tickets_page.dart';

/// Pumps [child] with a freshly-generated demo dataset and a service clock.
/// Returns both so the test can drive kitchen time and advance past the rush's
/// (random) horizon. A seeded [Random] keeps the generated rush reproducible.
typedef _Pumped = ({ServiceClockCubit clock, DemoDataCubit demo});

Future<_Pumped> _pumpWithDemo(WidgetTester tester, Widget child) async {
  final DemoDataCubit demo = DemoDataCubit(random: Random(20260621))..generate();
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
      child: MaterialApp(home: child),
    ),
  );
  await tester.pumpAndSettle();
  return (clock: clock, demo: demo);
}

/// Run kitchen time at 30× past the rush's horizon + [retainMins] so every cook
/// finishes and every ticket clears its retain window. At 30×, one real second
/// advances ≈0.5 kitchen-minutes, so pump `2 × kitchenMinutes` real seconds.
Future<void> _runPastHorizon(
  WidgetTester tester,
  _Pumped p, {
  required int retainMins,
}) async {
  final BoardData board =
      BoardData.from(p.demo.state.data!, now: p.demo.state.generatedAt!);
  final int kitchenMins = board.schedule.horizonMins + retainMins + 2;
  p.clock.setSpeed(30);
  p.clock.start();
  await tester.pump(Duration(seconds: 2 * kitchenMins));
  await tester.pump();
}

void main() {
  testWidgets('serving all lines then Done moves a ticket to the Done section',
      (WidgetTester tester) async {
    await _pumpWithDemo(tester, const TicketsPage());

    // Nothing is done yet (a done ticket shows a "Reopen" action).
    expect(find.text('Reopen'), findsNothing);

    // Waiter serves every line on the top ticket, then closes it.
    await tester.tap(find.text('Serve all').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done').first);
    await tester.pumpAndSettle();

    // It dropped into the dimmed "Done" section at the bottom of the list
    // (off-screen in a long rush) — scroll it into view; it's now reopenable.
    await tester.scrollUntilVisible(
      find.text('Reopen'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Reopen'), findsWidgets);
  });

  testWidgets('served cooks fall off the Fire-next queue', (
    WidgetTester tester,
  ) async {
    final _Pumped p = await _pumpWithDemo(
      tester,
      const QueuePage(config: BoardConfig(retainMins: 1)),
    );

    // Before the run, the queue lists cooks (each row shows "Xm cook · …").
    expect(find.textContaining('cook'), findsWidgets);

    await _runPastHorizon(tester, p, retainMins: 1);

    expect(find.textContaining('cook'), findsNothing);

    p.clock.reset();
    await tester.pumpAndSettle();
  });
}