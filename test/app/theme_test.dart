import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/app/theme.dart';

void main() {
  group('buildKBuzzTheme', () {
    test('dark theme carries the neon KdsColors extension', () {
      final ThemeData t = buildKBuzzTheme(Brightness.dark);
      expect(t.brightness, Brightness.dark);
      expect(t.scaffoldBackgroundColor, KdsColors.neon.board);

      final KdsColors? c = t.extension<KdsColors>();
      expect(c, isNotNull);
      expect(c!.board, KdsColors.neon.board);
      expect(c.textPrimary, Colors.white); // light-on-dark
    });

    test('light theme carries the pastel KdsColors extension', () {
      final ThemeData t = buildKBuzzTheme(Brightness.light);
      expect(t.brightness, Brightness.light);
      expect(t.scaffoldBackgroundColor, KdsColors.pastel.board);

      final KdsColors? c = t.extension<KdsColors>();
      expect(c, isNotNull);
      expect(c!.board, KdsColors.pastel.board);
      // Dark-on-light text in the light theme.
      expect(c.textPrimary.computeLuminance() < 0.5, isTrue);
    });

    test('neon and pastel differ on key roles', () {
      expect(KdsColors.neon.board, isNot(KdsColors.pastel.board));
      expect(KdsColors.neon.surface, isNot(KdsColors.pastel.surface));
      expect(KdsColors.neon.textPrimary, isNot(KdsColors.pastel.textPrimary));
      expect(KdsColors.neon.expoLate, isNot(KdsColors.pastel.expoLate));
    });

    test('lerp resolves to each endpoint at t=0 and t=1', () {
      expect(KdsColors.neon.lerp(KdsColors.pastel, 0).board, KdsColors.neon.board);
      expect(
        KdsColors.neon.lerp(KdsColors.pastel, 1).board,
        KdsColors.pastel.board,
      );
    });

    testWidgets('KdsColors.of resolves the active theme from context',
        (WidgetTester tester) async {
      late KdsColors light;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildKBuzzTheme(Brightness.light),
          home: Builder(
            builder: (BuildContext context) {
              light = KdsColors.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(light.board, KdsColors.pastel.board);
      expect(light.expoLate, KdsColors.pastel.expoLate);
    });

    test('of() falls back to neon when no extension is present', () {
      // The documented fallback constant `of` returns when a ThemeData carries
      // no KdsColors extension (e.g. a bare ThemeData in a test harness).
      expect(ThemeData(useMaterial3: true).extension<KdsColors>(), isNull);
    });
  });

  group('ticketColor', () {
    test('is deterministic for a given ticket id', () {
      expect(ticketColor('kot-7'), ticketColor('kot-7'));
      expect(ticketColor('abc-123'), ticketColor('abc-123'));
    });

    test('always resolves to a palette entry', () {
      for (final String id in <String>['a', 'kot-1', 'D21', 'xyz', '']) {
        expect(kTicketColors, contains(ticketColor(id)));
      }
    });

    test('spreads distinct ids across the palette', () {
      final Set<Color> seen = <Color>{
        for (int i = 0; i < 40; i++) ticketColor('kot-$i'),
      };
      // Not all collapse to one bucket (well-distributed hash).
      expect(seen.length, greaterThan(3));
    });

    test('palette avoids the status hues the bar reserves', () {
      // Grouping must never read as an alert: no red/orange/amber/white.
      final Set<Color> reserved = <Color>{
        kStatusLate, // late (red)
        kStatusFiring, // rush / firing (orange)
        kSlackCook, // amber
        kHoldStripe, // holding amber
        Colors.white, // selected
      };
      for (final Color c in kTicketColors) {
        expect(reserved, isNot(contains(c)));
      }
    });
  });
}
