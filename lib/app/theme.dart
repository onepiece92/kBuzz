import 'package:flutter/material.dart';

/// kBuzz brand colours and the dark KDS board theme (AGENTS.md §3 / §12).
///
/// Brand colours are the app's identity. The *functional* station colours
/// ([kStationColors]) encode meaning (which station) and are intentionally kept
/// separate — never swap one for the other.
abstract final class KBuzzColors {
  /// Brand primary (orange). Drives primary actions, the scan shutter and
  /// CTA / selected accents.
  static const Color brandPrimary = Color(0xFFFF6600);

  /// Brand secondary (navy). Branded chrome only (app bar, sign-in, elevated
  /// surfaces) — not text/fills on the near-black board, where contrast is too
  /// low.
  static const Color brandSecondary = Color(0xFF274074);

  /// Near-black KDS board background (matches the prototype).
  static const Color board = Color(0xFF0A0E14);

  /// Slightly raised surface sitting on the board.
  static const Color surface = Color(0xFF12161D);
}

/// Functional station colours, ported 1:1 from `MultiKOT.jsx` `STATIONS`.
///
/// These encode *station*, not brand — do not replace them with brand colours.
const Map<String, Color> kStationColors = <String, Color>{
  'grill': Color(0xFFEF4444),
  'steam': Color(0xFF0EA5E9),
  'wok': Color(0xFFF59E0B),
  'fry': Color(0xFFF97316),
  'curry': Color(0xFFF43F5E),
  'soup': Color(0xFF8B5CF6),
  'cold': Color(0xFF10B981),
  'tandoor': Color(0xFFEAB308),
  'bar': Color(0xFF14B8A6),
};

/// Monospace style for all clocks, timers and quantities (AGENTS.md §12).
const TextStyle kMonoNumberStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  fontWeight: FontWeight.w600,
);

/// Builds the single dark KDS theme.
ThemeData buildKBuzzTheme() {
  final ColorScheme scheme = const ColorScheme.dark().copyWith(
    primary: KBuzzColors.brandPrimary,
    onPrimary: Colors.white,
    secondary: KBuzzColors.brandSecondary,
    surface: KBuzzColors.surface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: KBuzzColors.board,
    appBarTheme: const AppBarTheme(
      backgroundColor: KBuzzColors.board,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: KBuzzColors.surface,
      indicatorColor: KBuzzColors.brandPrimary.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
