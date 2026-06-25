import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/ai/ticket_scanner.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/scan/scan_page.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// Scan error path: with no Claude key configured, tapping "Scan" must NOT touch
/// the network — it drops the user straight to manual entry with an explanation.
void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  testWidgets('Scan with no API key → manual entry + advisory toast, no network',
      (WidgetTester tester) async {
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now))..generate();
    final ServiceClockCubit clock = ServiceClockCubit();

    // Unconfigured scanner (blank key) whose client must never be called.
    bool networkHit = false;
    final TicketScanner scanner = TicketScanner(
      client: MockClient((http.Request _) async {
        networkHit = true;
        return http.Response('{}', 200);
      }),
      apiKey: '',
    );
    expect(scanner.isConfigured, isFalse);

    await tester.pumpWidget(
      RepositoryProvider<TicketScanner>.value(
        value: scanner,
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<DemoDataCubit>.value(value: demo),
            BlocProvider<ServiceClockCubit>.value(value: clock),
          ],
          child: const MaterialApp(home: ScanPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan KOT'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Scan'));
    await tester.pump(); // run the guard + toast insert
    await tester.pump(const Duration(milliseconds: 350)); // slide-in

    // Routed to manual review, with the no-key advisory, and the network
    // was never touched (no fabricated ticket from the demo menu).
    expect(find.text('Review KOT'), findsOneWidget);
    expect(find.textContaining('No AI key'), findsOneWidget);
    expect(networkHit, isFalse);

    // Drain the toast timer so nothing outlives the test.
    await tester.pump(const Duration(seconds: 12));
    await tester.pumpAndSettle();

    await clock.close();
    await demo.close();
  });
}
