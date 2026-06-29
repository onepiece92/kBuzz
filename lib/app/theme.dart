import 'package:flutter/material.dart';

/// kBuzz brand colours and the dark KDS board theme (AGENTS.md §3 / §12).
///
/// Brand colours are the app's identity. The *functional* station colours
/// ([kStationColors]) encode meaning (which station) and are intentionally kept
/// separate — never swap one for the other.
abstract final class KBuzzColors {
  /// Brand primary (orange). Drives primary actions, the scan shutter and
  /// CTA / selected accents. (theme.md "Primary Brand" neon.)
  static const Color brandPrimary = Color(0xFFFF7A1A);

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

/// Ticket-identity palette: a stable, vivid colour per ticket so all of an
/// order's cooks share one bar colour **across stations** — letting the kitchen
/// trace one ticket down the Stations rail. Deliberately avoids red / orange /
/// amber / white, which a dish bar reserves for *status* (plates-late, rush /
/// recook, holding, selected) so grouping never reads as an alert.
const List<Color> kTicketColors = <Color>[
  Color(0xFF60A5FA), // blue
  Color(0xFFA78BFA), // violet
  Color(0xFFF472B6), // pink
  Color(0xFF34D399), // emerald
  Color(0xFF22D3EE), // cyan
  Color(0xFF818CF8), // indigo
  Color(0xFF2DD4BF), // teal
  Color(0xFFC084FC), // purple
  Color(0xFF4ADE80), // green
  Color(0xFFE879F9), // fuchsia
];

/// Stable [kTicketColors] entry for a ticket id — deterministic across runs and
/// platforms (a hand-rolled hash, not `String.hashCode`), so the same ticket
/// always maps to the same colour within and between sessions.
Color ticketColor(String kotId) {
  int h = 0;
  for (final int unit in kotId.codeUnits) {
    h = (h * 31 + unit) & 0x7fffffff;
  }
  return kTicketColors[h % kTicketColors.length];
}

/// Expo / ticket status palette — the colours the **waiter** boards use to flag a
/// line's plate state. Defined once here so a rebrand is a single edit (the
/// Tickets page and the shared [NoteLine] reference these, not raw hex).
///
/// Distinct from the kitchen-side *slack* palette in `board_widgets.dart`
/// (planned hold/late/on-time), which encodes scheduler slack rather than expo
/// state — keep the two separate.
const Color kStatusReady = Color(
  0xFF39FF88,
); // neon green — all lines plated/ready
const Color kStatusHeld = Color(0xFFFBBF24); // amber — held / special note
const Color kStatusLate = Color(0xFFFF4D6D); // neon red — past target
const Color kStatusFiring = KBuzzColors.brandPrimary; // orange — rush / firing

/// Legible ink for text/icons placed on a **brand-coloured fill** (e.g. a
/// selected chip). The brand orange is too light for white text (~2.7:1) and the
/// fill is orange in both themes, so this is a near-black that clears WCAG AA
/// (~6:1) on the brand in both the neon and pastel palettes.
const Color kOnBrand = Color(0xFF1C1917);

/// Kitchen "slack / live" palette — the kitchen-side colours for a cook's timing
/// and shared accents (distinct from the waiter-side expo palette above). These
/// are the single source of truth for the boards' status colours; retheme here.
const Color kDanger = Color(0xFFFF4D6D); // neon red — late / bottleneck / error
const Color kSlackHold = Color(0xFF33A1FF); // neon blue — can hold
const Color kSuccess = Color(
  0xFF39FF88,
); // neon green — on time / ready / success
const Color kSlackCook = Color(0xFFFFD60A); // neon amber — cooking
const Color kHoldStripe = Color(0xFFFDE68A); // pale amber — holding edge marker
const Color kSwatchGrey = Color(0xFF94A3B8); // neutral legend swatch

// ── Pastel palette (light theme) ──────────────────────────────────────────
// theme.md's pastels are tuned as fills; for foreground/border/text accents on a
// light background we use the slightly stronger "standard" shades so contrast
// holds. Light-mode neutrals (below, in [KdsColors.pastel]) are dark-on-light.
const Color _pastelBrand = Color(0xFFF97316);
const Color _pastelReady = Color(0xFF22C55E);
const Color _pastelHeld = Color(0xFFD97706);
const Color _pastelLate = Color(0xFFEF4444);
const Color _pastelInfo = Color(0xFF3B82F6);
const Color _pastelCook = Color(0xFFF59E0B);
const Color _pastelSuccess = Color(0xFF16A34A);
const Color _pastelHoldStripe = Color(0xFFF59E0B);
const Color _pastelGrey = Color(0xFF94A3B8);

/// Theme-aware colour set. Every colour that differs between the neon (dark) and
/// pastel (light) themes is a field here; read it with `KdsColors.of(context)`.
/// Station fills ([kStationColors]) and the white bar-label text stay constant
/// across themes (the saturated station fills carry white text in both).
///
/// The top-level `k*` tokens above are the neon values and remain the dark
/// fallback for any call site not yet migrated to [of].
@immutable
class KdsColors extends ThemeExtension<KdsColors> {
  const KdsColors({
    required this.brand,
    required this.onBrand,
    required this.expoReady,
    required this.expoHeld,
    required this.expoLate,
    required this.danger,
    required this.slackHold,
    required this.slackCook,
    required this.success,
    required this.holdStripe,
    required this.swatchGrey,
    required this.board,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textFaint,
    required this.hairline,
    required this.hairlineStrong,
    required this.scrim,
  });

  final Color brand; // CTA / firing / rush accent
  final Color onBrand; // legible ink for text/icons on a brand fill
  final Color expoReady; // waiter: all lines plated
  final Color expoHeld; // waiter: held / special note
  final Color expoLate; // waiter: past target
  final Color danger; // kitchen: late / bottleneck / error
  final Color slackHold; // kitchen: can hold
  final Color slackCook; // kitchen: cooking
  final Color success; // kitchen: on time / ready
  final Color holdStripe; // holding edge marker
  final Color swatchGrey; // neutral legend swatch
  final Color board; // scaffold background
  final Color surface; // raised surface / cards
  final Color textPrimary; // primary text
  final Color textSecondary; // secondary text
  final Color textMuted; // muted / caption text
  final Color textFaint; // faint / disabled text
  final Color hairline; // thin divider / border
  final Color hairlineStrong; // stronger divider / border
  final Color scrim; // shadow / overlay

  /// Neon palette — the dark KDS board.
  static const KdsColors neon = KdsColors(
    brand: kStatusFiring,
    onBrand: kOnBrand,
    expoReady: kStatusReady,
    expoHeld: kStatusHeld,
    expoLate: kStatusLate,
    danger: kDanger,
    slackHold: kSlackHold,
    slackCook: kSlackCook,
    success: kSuccess,
    holdStripe: kHoldStripe,
    swatchGrey: kSwatchGrey,
    board: KBuzzColors.board,
    surface: KBuzzColors.surface,
    textPrimary: Colors.white,
    textSecondary: Colors.white70,
    textMuted: Colors.white54,
    textFaint: Colors.white38,
    hairline: Colors.white12,
    hairlineStrong: Colors.white24,
    scrim: Color(0x66000000),
  );

  /// Pastel palette — the light theme.
  static const KdsColors pastel = KdsColors(
    brand: _pastelBrand,
    onBrand: kOnBrand,
    expoReady: _pastelReady,
    expoHeld: _pastelHeld,
    expoLate: _pastelLate,
    danger: _pastelLate,
    slackHold: _pastelInfo,
    slackCook: _pastelCook,
    success: _pastelSuccess,
    holdStripe: _pastelHoldStripe,
    swatchGrey: _pastelGrey,
    board: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textMuted: Color(0xFF64748B),
    textFaint: Color(0xFF94A3B8),
    hairline: Color(0xFFE2E8F0),
    hairlineStrong: Color(0xFFCBD5E1),
    scrim: Color(0x14000000),
  );

  /// The active set for [context]; falls back to [neon] if unset.
  static KdsColors of(BuildContext context) =>
      Theme.of(context).extension<KdsColors>() ?? neon;

  @override
  KdsColors copyWith({
    Color? brand,
    Color? onBrand,
    Color? expoReady,
    Color? expoHeld,
    Color? expoLate,
    Color? danger,
    Color? slackHold,
    Color? slackCook,
    Color? success,
    Color? holdStripe,
    Color? swatchGrey,
    Color? board,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? textFaint,
    Color? hairline,
    Color? hairlineStrong,
    Color? scrim,
  }) => KdsColors(
    brand: brand ?? this.brand,
    onBrand: onBrand ?? this.onBrand,
    expoReady: expoReady ?? this.expoReady,
    expoHeld: expoHeld ?? this.expoHeld,
    expoLate: expoLate ?? this.expoLate,
    danger: danger ?? this.danger,
    slackHold: slackHold ?? this.slackHold,
    slackCook: slackCook ?? this.slackCook,
    success: success ?? this.success,
    holdStripe: holdStripe ?? this.holdStripe,
    swatchGrey: swatchGrey ?? this.swatchGrey,
    board: board ?? this.board,
    surface: surface ?? this.surface,
    textPrimary: textPrimary ?? this.textPrimary,
    textSecondary: textSecondary ?? this.textSecondary,
    textMuted: textMuted ?? this.textMuted,
    textFaint: textFaint ?? this.textFaint,
    hairline: hairline ?? this.hairline,
    hairlineStrong: hairlineStrong ?? this.hairlineStrong,
    scrim: scrim ?? this.scrim,
  );

  @override
  KdsColors lerp(ThemeExtension<KdsColors>? other, double t) {
    if (other is! KdsColors) return this;
    return KdsColors(
      brand: Color.lerp(brand, other.brand, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      expoReady: Color.lerp(expoReady, other.expoReady, t)!,
      expoHeld: Color.lerp(expoHeld, other.expoHeld, t)!,
      expoLate: Color.lerp(expoLate, other.expoLate, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      slackHold: Color.lerp(slackHold, other.slackHold, t)!,
      slackCook: Color.lerp(slackCook, other.slackCook, t)!,
      success: Color.lerp(success, other.success, t)!,
      holdStripe: Color.lerp(holdStripe, other.holdStripe, t)!,
      swatchGrey: Color.lerp(swatchGrey, other.swatchGrey, t)!,
      board: Color.lerp(board, other.board, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      hairlineStrong: Color.lerp(hairlineStrong, other.hairlineStrong, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// Spacing scale (4-pt grid). Use these for gaps and padding so the whole app's
/// rhythm is tunable from one place. Snap any new gap to the nearest step.
const double kSpaceXs = 4;
const double kSpaceSm = 8;
const double kSpaceMd = 12;
const double kSpaceLg = 16;
const double kSpaceXl = 24;
const double kSpaceXxl = 32;

/// Corner-radius scale. `kRadiusPill` is for chip/pill shapes.
const double kRadiusSm = 4;
const double kRadiusMd = 8;
const double kRadiusLg = 12;
const double kRadiusXl = 16;
const double kRadiusPill = 20;

/// Type-size scale. Snap any text size to a step so the whole type ramp is
/// tunable from one place. (`kFontMicro`/`kFontXs` are the dense-board sizes.)
const double kFontMicro = 9;
const double kFontXs = 11;
const double kFontSm = 12;
const double kFontMd = 14;
const double kFontLg = 16;
const double kFontXl = 20;
const double kFontXxl = 28;

/// Bundled JetBrains Mono — used for special-instruction notes. Its monospace
/// shapes make short notes ("no nuts", "extra spicy") easier to read at a glance
/// than the sans-serif name above them. Declared in `pubspec.yaml` (`fonts:`),
/// files in `assets/fonts/` (OFL-1.1).
const String kJetBrainsMono = 'JetBrainsMono';

/// Monospace style for all clocks, timers and quantities (AGENTS.md §12).
const TextStyle kMonoNumberStyle = TextStyle(
  fontFamily: 'monospace',
  fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  fontWeight: FontWeight.w600,
);

/// Builds a KDS theme for [brightness] — neon on the dark board, pastel on the
/// light surface. The matching [KdsColors] set is attached as a theme extension
/// so widgets resolve their colours with `KdsColors.of(context)`.
ThemeData buildKBuzzTheme(Brightness brightness) {
  final bool dark = brightness == Brightness.dark;
  final KdsColors kc = dark ? KdsColors.neon : KdsColors.pastel;
  final ColorScheme scheme =
      (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: kc.brand,
        onPrimary: Colors.white,
        secondary: KBuzzColors.brandSecondary,
        surface: kc.surface,
        onSurface: kc.textPrimary,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: kc.board,
    extensions: <ThemeExtension<dynamic>>[kc],
    appBarTheme: AppBarTheme(
      backgroundColor: kc.board,
      foregroundColor: kc.textPrimary,
      elevation: 0,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kc.surface,
      indicatorColor: kc.brand.withValues(alpha: 0.18),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          fontSize: kFontSm,
          fontWeight: FontWeight.w600,
          color: kc.textSecondary,
        ),
      ),
    ),
  );
}
