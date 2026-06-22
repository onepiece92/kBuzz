import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/stations/stations_page.dart';

void main() {
  testWidgets('capacity stepper bumps a station and the rail reflects it', (
    WidgetTester tester,
  ) async {
    final DemoDataCubit demo = DemoDataCubit()..generate();
    final ServiceClockCubit clock = ServiceClockCubit();
    addTearDown(demo.close);
    addTearDown(clock.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
        ],
        child: const MaterialApp(home: StationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    // Grill is the first station (capacity 2). No demo station starts at cap 4.
    expect(find.text('cap 4'), findsNothing);

    // Tap Grill's "+" twice → capacity 4, a value unique to Grill, so the
    // assertion is robust even if other sections are off-screen (lazy list).
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pump();

    expect(find.text('cap 4'), findsOneWidget);
  });
}
