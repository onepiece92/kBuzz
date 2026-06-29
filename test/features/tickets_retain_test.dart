import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/queue/queue_page.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/tickets/tickets_page.dart';

/// A hand-driven wall clock. The service clock now reads real time, which
/// `tester.pump(Duration)` can't fast-forward — so the demo epoch and the run
/// clock share this fake, and the test advances it directly.
class _TestClock extends Clock {
  _TestClock(this._now);
  DateTime _now;
  void advance(Duration d) => _now = _now.add(d);
  @override
  DateTime now() => _now;
}

/// Pumps [child] with a freshly-generated demo dataset and a service clock.
/// Returns them plus the shared [wall] clock so the test can drive kitchen time
/// past the rush's (random) horizon. A seeded [Random] keeps it reproducible.
typedef _Pumped = ({ServiceClockCubit clock, DemoDataCubit demo, _TestClock wall});

Future<_Pumped> _pumpWithDemo(WidgetTester tester, Widget child) async {
  final _TestClock wall = _TestClock(DateTime(2026, 1, 1, 18));
  final DemoDataCubit demo =
      DemoDataCubit(random: Random(20260621), clock: wall)..generate();
  final ServiceClockCubit clock = ServiceClockCubit(clock: wall);
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
  return (clock: clock, demo: demo, wall: wall);
}

/// Advance kitchen time past the rush's horizon + [retainMins] so every cook
/// finishes and every ticket clears its retain window. The clock derives elapsed
/// from the wall clock, so we move the shared fake clock directly (at 1×) and
/// resync — no real-second pumping. One `pump()` rebuilds the board; we avoid
/// `pumpAndSettle` while the periodic ticker is live (it would never settle).
Future<void> _runPastHorizon(
  WidgetTester tester,
  _Pumped p, {
  required int retainMins,
}) async {
  final BoardData board =
      BoardData.from(p.demo.state.data!, now: p.demo.state.generatedAt!);
  final int kitchenMins = board.schedule.horizonMins + retainMins + 2;
  p.clock.setSpeed(1);
  p.clock.start(epoch: p.demo.state.generatedAt); // anchor at the board epoch
  p.wall.advance(Duration(minutes: kitchenMins));
  // In-session elapsed runs off a monotonic clock now; advancing the wall fake
  // alone needs an explicit resync (as on app resume) to reconcile elapsed,
  // then a tick to rebuild the board.
  p.clock.sync();
  await tester.pump(const Duration(seconds: 1));
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