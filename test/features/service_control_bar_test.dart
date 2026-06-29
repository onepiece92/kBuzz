import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/features/service/widgets/service_control_bar.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

class _FakeMono extends MonotonicClock {
  Duration _e = Duration.zero;
  void advance(Duration d) => _e += d;
  @override
  Duration elapsed() => _e;
}

void main() {
  testWidgets(
      'clock readout is a live elapsed timer — 0:00 at start, ticks up, '
      '0:00 after reset', (WidgetTester tester) async {
    final DateTime now = DateTime(2026, 1, 1, 18);
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now));
    final _FakeMono mono = _FakeMono();
    final ServiceClockCubit clock =
        ServiceClockCubit(clock: _FixedClock(now), monotonic: mono)
          ..setSpeed(1);
    addTearDown(demo.close);
    addTearDown(clock.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<DemoDataCubit>.value(value: demo),
          BlocProvider<ServiceClockCubit>.value(value: clock),
        ],
        child: const MaterialApp(home: Scaffold(body: ServiceControlBar())),
      ),
    );

    // Before a run: the Start button, no timer.
    expect(find.text('Start service'), findsOneWidget);

    // Start → the readout reads 0:00 (a session timer, not the time of day).
    // Two pumps: a synchronous cubit emit settles the BlocBuilder on the second
    // frame, and pumpAndSettle would hang on the 1s ticker.
    clock.start(epoch: now);
    await tester.pump();
    await tester.pump();
    expect(find.text('0:00'), findsOneWidget);

    // It ticks up as elapsed advances.
    mono.advance(const Duration(seconds: 90));
    clock.tick();
    await tester.pump();
    await tester.pump();
    expect(find.text('1:30'), findsOneWidget);

    // Reset zeroes it back (and returns to the Start button).
    clock.reset();
    await tester.pump();
    await tester.pump();
    expect(find.text('Start service'), findsOneWidget);
    expect(find.text('1:30'), findsNothing);
  });

  test('elapsed format: m:ss under an hour, h:mm:ss past it', () {
    expect(ServiceControlBar.formatElapsed(Duration.zero), '0:00');
    expect(
        ServiceControlBar.formatElapsed(const Duration(seconds: 90)), '1:30');
    expect(
        ServiceControlBar.formatElapsed(
            const Duration(hours: 1, minutes: 2, seconds: 9)),
        '1:02:09');
    expect(ServiceControlBar.formatElapsed(const Duration(seconds: -5)), '0:00');
  });
}
