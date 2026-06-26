import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/widgets/marquee_text.dart';

void main() {
  const TextStyle style = TextStyle(fontSize: 11, fontWeight: FontWeight.w700);

  Widget host(double width, String text, {bool animate = true}) {
    final Widget marquee = SizedBox(
      width: width,
      child: MarqueeText(text, style: style),
    );
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: animate ? marquee : TickerMode(enabled: false, child: marquee),
        ),
      ),
    );
  }

  testWidgets('text that fits is a plain, static Text (no looping animation)',
      (WidgetTester tester) async {
    await tester.pumpWidget(host(400, 'Fries'));
    // Fits → no animation, so pumpAndSettle returns (a looping marquee wouldn't).
    await tester.pumpAndSettle();
    expect(find.text('Fries'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('overflowing text still renders in full, with no overflow error',
      (WidgetTester tester) async {
    // Narrow box + long text → it would clip; the marquee slides it instead.
    // TickerMode off keeps it still so the test can settle.
    await tester.pumpWidget(host(
      36,
      'Raw Oysters (Half Dozen) on the Half Shell',
      animate: false,
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull); // OverflowBox/ClipRect, not a throw
    expect(
      find.text('Raw Oysters (Half Dozen) on the Half Shell'),
      findsOneWidget,
    );
  });
}
