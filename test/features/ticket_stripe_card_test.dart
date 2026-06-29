import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/features/board/board_widgets.dart';

void main() {
  testWidgets('TicketStripeCard paints a left stripe in the ticket colour', (
    WidgetTester tester,
  ) async {
    const Color tc = Color(0xFF60A5FA);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKBuzzTheme(Brightness.dark),
        home: const Scaffold(
          body: TicketStripeCard(
            ticketColor: tc,
            child: Text('Ticket'),
          ),
        ),
      ),
    );

    expect(find.text('Ticket'), findsOneWidget);
    // The stripe is a ColoredBox painted in the ticket colour.
    final Iterable<ColoredBox> stripes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((ColoredBox b) => b.color == tc);
    expect(stripes, isNotEmpty);
  });

  testWidgets('the same ticket id maps to the same stripe colour everywhere', (
    WidgetTester tester,
  ) async {
    // Cross-board consistency: a ticket's stripe colour is ticketColor(kot.id),
    // the same value the Stations rail paints its bars — so they match.
    expect(ticketColor('kot-7'), ticketColor('kot-7'));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildKBuzzTheme(Brightness.dark),
        home: Scaffold(
          body: TicketStripeCard(
            ticketColor: ticketColor('kot-7'),
            child: const Text('Order'),
          ),
        ),
      ),
    );
    final Iterable<ColoredBox> stripes = tester
        .widgetList<ColoredBox>(find.byType(ColoredBox))
        .where((ColoredBox b) => b.color == ticketColor('kot-7'));
    expect(stripes, isNotEmpty);
  });
}
