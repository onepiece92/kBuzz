import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/scan/scan_page.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  group('DemoDataCubit.addKot', () {
    test('appends a ticket and keeps the board epoch', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now))
        ..generate();
      final int before = cubit.state.data!.kots.length;
      final DateTime epoch = cubit.state.generatedAt!;

      cubit.addKot(
        Kot(
          id: 'new-1',
          table: '7',
          type: KotType.takeaway,
          orderedAt: now,
          lines: const <OrderLine>[OrderLine(dishId: 'french-fries', qty: 1)],
        ),
      );

      expect(cubit.state.data!.kots.length, before + 1);
      expect(cubit.state.generatedAt, epoch); // epoch unchanged
      cubit.close();
    });

    test('is a no-op when no data has been generated', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
      cubit.addKot(
        Kot(
          id: 'x',
          table: '1',
          type: KotType.dineIn,
          orderedAt: now,
          lines: const <OrderLine>[OrderLine(dishId: 'french-fries', qty: 1)],
        ),
      );
      expect(cubit.state.data, isNull);
      cubit.close();
    });
  });

  testWidgets('manual scan flow: build a ticket through review', (
    WidgetTester tester,
  ) async {
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now))..generate();
    final ServiceClockCubit clock = ServiceClockCubit();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
        ],
        child: const MaterialApp(home: ScanPage()),
      ),
    );

    // Capture step → manual entry.
    expect(find.text('Scan KOT'), findsOneWidget);
    await tester.tap(find.text('Enter manually'));
    await tester.pumpAndSettle();
    expect(find.text('Review KOT'), findsOneWidget);

    // Empty draft → submit disabled.
    final Finder submit = find.widgetWithText(FilledButton, 'Add a dish to continue');
    expect(submit, findsOneWidget);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    // Add a dish via the picker sheet. Pick whatever the current demo menu lists
    // first, so the test survives menu changes.
    final String pick = demo.state.data!.menu.first.name;
    await tester.tap(find.text('Add dish'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(pick).last);
    await tester.pumpAndSettle();

    // The line appears and the submit button is now enabled.
    expect(find.text(pick), findsWidgets);
    final Finder ready = find.widgetWithText(FilledButton, 'Add to board');
    expect(ready, findsOneWidget);
    expect(tester.widget<FilledButton>(ready).onPressed, isNotNull);

    await clock.close();
    await demo.close();
  });
}
