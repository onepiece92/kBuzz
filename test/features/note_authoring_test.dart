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
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/tickets/tickets_page.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// The waiter can add a special instruction from the item sheet (regression for
/// the "TextEditingController used after being disposed" crash — the dialog's
/// controller must outlive its dismiss animation).
void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  testWidgets('tap a line → Add note → Save writes the note onto the line',
      (WidgetTester tester) async {
    final AppDatabase db = AppDatabase.memory();
    final KitchenRepository repo = KitchenRepository(db);
    await repo.seedSampleData(now: now);
    final DemoDataCubit demo =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));
    await demo.settled;
    final ServiceClockCubit clock = ServiceClockCubit();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
          BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
        ],
        child: const MaterialApp(home: TicketsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Pick the first open line on the soonest-due card (label derived from data
    // so the test survives demo-menu changes). Choose one WITHOUT a sample note
    // so the action reads "Add note" and the result is unambiguous.
    final DemoData data = demo.state.data!;
    final BoardData board = BoardData.from(data, now: now);
    final List<Kot> activeKots = data.kots
        .where((Kot k) => k.status == TicketState.active)
        .toList()
      ..sort((Kot a, Kot b) =>
          board.statusOf(a).targetMins.compareTo(board.statusOf(b).targetMins));
    final OrderLine openLine = activeKots
        .expand((Kot k) => k.lines)
        .firstWhere((OrderLine l) =>
            l.state == LineState.open && (l.note ?? '').isEmpty);
    final String lineId = openLine.id!;
    final Dish dish = data.menu.firstWhere((Dish d) => d.id == openLine.dishId);
    final String label =
        openLine.qty > 1 ? '${dish.name} ×${openLine.qty}' : dish.name;

    await tester.tap(find.text(label).first);
    await tester.pumpAndSettle();

    expect(find.text('Add note'), findsOneWidget);
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();

    // Dialog open: type a note and save.
    expect(find.text('Special instruction'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'less salt');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle(); // must not throw mid-dismiss

    // The note is on the line (state) and shown on the board.
    final OrderLine updated = demo.state.data!.kots
        .expand((Kot k) => k.lines)
        .firstWhere((OrderLine l) => l.id == lineId);
    expect(updated.note, 'less salt');
    expect(find.text('less salt'), findsWidgets);

    await clock.close();
    await demo.close();
    await db.close();
  });
}
