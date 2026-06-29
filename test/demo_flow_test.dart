import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/app/app.dart';
import 'package:kbuzz/app/di.dart';

void main() {
  testWidgets('generate demo data, then it shows on the boards',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AppProviders(child: KBuzzApp()));
    await tester.pumpAndSettle();

    // Boards start empty until data is generated.
    expect(find.textContaining('No tickets yet'), findsOneWidget);

    // Go to Profile and generate the demo data. Sections are collapsible now —
    // open "Demo data" first, then reach its Generate button.
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Demo data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Demo data'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Generate demo data'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // scrollUntilVisible stops as soon as the button enters the viewport, which
    // can leave it at the very bottom edge (under the FAB/nav). Align it fully
    // into view so the tap lands cleanly.
    await tester.ensureVisible(find.text('Generate demo data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Generate demo data'));
    await tester.pump(); // emit state + insert toast
    // No AI key in tests → a randomized rush. The demo summary lists each ticket
    // labelled "Table N" (dine-in) or "Order N" (takeaway/delivery); assert at
    // least one tile shows up either way (a rush may have no dine-in tickets).
    expect(find.text('Tickets'), findsWidgets);
    expect(
      find.textContaining('Table ').evaluate().isNotEmpty ||
          find.textContaining('Order ').evaluate().isNotEmpty,
      isTrue,
    );

    // Let the top toast auto-dismiss so no timer outlives the test.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // The Tickets board now renders the generated tickets — each card shows a
    // 'plate … · target …' line (tickets are labelled by code, e.g. T5/D21).
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pumpAndSettle();
    expect(find.textContaining('target '), findsWidgets);
    expect(find.textContaining('plate '), findsWidgets);

    // The Stations board left its empty state — the rush reached the boards.
    await tester.tap(find.byIcon(Icons.view_week_outlined));
    // The Stations rail's name marquee loops forever, so advance a fixed amount
    // rather than pumpAndSettle (which would never settle).
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('No tickets yet'), findsNothing);
    expect(find.widgetWithText(AppBar, 'Stations'), findsOneWidget);
  });
}
