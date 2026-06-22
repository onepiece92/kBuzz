import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/app/app.dart';
import 'package:kbuzz/app/di.dart';

void main() {
  testWidgets('app boots to the Stations board', (WidgetTester tester) async {
    await tester.pumpWidget(const AppProviders(child: KBuzzApp()));
    await tester.pumpAndSettle();

    // The shell shows all four tabs; Stations is the initial branch.
    expect(find.text('Stations'), findsWidgets);
    expect(find.text('Fire next'), findsWidgets);
    expect(find.text('Tickets'), findsWidgets);
    expect(find.text('Profile'), findsWidgets);
  });
}
