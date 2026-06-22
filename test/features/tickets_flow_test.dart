import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/tickets/tickets_page.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  group('DemoDataCubit waiter actions (optimistic)', () {
    late DemoDataCubit cubit;

    setUp(() {
      // No repo → pure in-memory; fixed Random → deterministic rush with line ids.
      cubit = DemoDataCubit(clock: _FixedClock(now), random: Random(1))..generate();
    });
    tearDown(() => cubit.close());

    String firstLineId() => cubit.state.data!.kots.first.lines.first.id!;
    String firstKotId() => cubit.state.data!.kots.first.id;
    OrderLine lineById(String id) => cubit.state.data!.kots
        .expand((Kot k) => k.lines)
        .firstWhere((OrderLine l) => l.id == id);
    Kot kotById(String id) =>
        cubit.state.data!.kots.firstWhere((Kot k) => k.id == id);

    test('generated lines have ids and default open state', () {
      expect(cubit.state.data!.kots, isNotEmpty);
      expect(firstLineId(), isNotEmpty);
      expect(lineById(firstLineId()).state, LineState.open);
    });

    test('serve / void / restore move a line', () {
      final String id = firstLineId();
      cubit.serveLine(id);
      expect(lineById(id).state, LineState.served);
      cubit.unserveLine(id);
      expect(lineById(id).state, LineState.open);
      cubit.voidLine(id);
      expect(lineById(id).state, LineState.voided);
      cubit.restoreLine(id);
      expect(lineById(id).state, LineState.open);
    });

    test('recook bumps count, sets reAt+reason, reopens the ticket', () {
      final String kotId = firstKotId();
      final String id = firstLineId();
      cubit.markTicketDone(kotId);
      expect(kotById(kotId).status, TicketState.done);

      cubit.recookLine(id, reason: 'Cold', reAtMins: 5);
      final OrderLine l = lineById(id);
      expect(l.recook, 1);
      expect(l.reAt, 5);
      expect(l.reason, 'Cold');
      expect(l.state, LineState.open);
      expect(kotById(kotId).status, TicketState.active); // auto-reopened
    });

    test('fireNow sets reAt with no reason; rush + done/reopen flip the ticket', () {
      final String kotId = firstKotId();
      final String id = firstLineId();
      cubit.fireNowLine(id, reAtMins: 2);
      expect(lineById(id).reAt, 2);
      expect(lineById(id).reason, isNull);

      cubit.setRush(kotId, on: true);
      expect(kotById(kotId).rush, isTrue);
      cubit.markTicketDone(kotId);
      expect(kotById(kotId).status, TicketState.done);
      cubit.reopenTicket(kotId);
      expect(kotById(kotId).status, TicketState.active);
    });
  });

  testWidgets('tap a line → action sheet → Mark served updates the row',
      (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    final KitchenRepository repo = KitchenRepository(db);
    await repo.seedSampleData(now: now); // deterministic sample (Table 5 etc.)
    final DemoDataCubit demo =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));
    await demo.settled; // hydrate → lines carry ids
    final ServiceClockCubit clock = ServiceClockCubit();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
        ],
        child: const MaterialApp(home: TicketsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the first open line on the top (soonest-due) card. Derive its label
    // from the data so the test survives demo-menu changes.
    final DemoData data = demo.state.data!;
    final BoardData board = BoardData.from(data, now: now);
    final List<Kot> activeKots = data.kots
        .where((Kot k) => k.status == TicketState.active)
        .toList()
      ..sort((Kot a, Kot b) =>
          board.statusOf(a).targetMins.compareTo(board.statusOf(b).targetMins));
    final OrderLine openLine = activeKots.first.lines
        .firstWhere((OrderLine l) => l.state == LineState.open);
    final Dish dish =
        data.menu.firstWhere((Dish d) => d.id == openLine.dishId);
    final String label =
        openLine.qty > 1 ? '${dish.name} ×${openLine.qty}' : dish.name;

    expect(find.text(label), findsWidgets);
    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();

    // Contextual sheet for an open line.
    expect(find.text('Mark served'), findsOneWidget);
    expect(find.text('Fire now — missing / expedite'), findsOneWidget);
    await tester.tap(find.text('Mark served'));
    await tester.pumpAndSettle();

    // The row now reads as served.
    expect(find.textContaining('served'), findsWidgets);

    await clock.close();
    await demo.close();
    await db.close();
  });
}
