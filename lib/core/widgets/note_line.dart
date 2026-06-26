import 'package:flutter/material.dart';
import 'package:kbuzz/app/theme.dart';

/// A single special-instruction line — a sticky-note glyph followed by the note
/// text — rendered consistently across the Tickets, Stations and Fire-next
/// boards.
///
/// The colour and size differ per surface (amber on the roomy ticket / queue
/// rows, compact white on the dense stations bar), so those are parameters; the
/// structure, icon and italic styling live here so a tweak lands once.
class NoteLine extends StatelessWidget {
  const NoteLine(
    this.text, {
    super.key,
    this.color,
    this.iconColor,
    this.fontSize = 12,
    this.iconSize = 13,
    this.fontWeight = FontWeight.w600,
    this.topPadding = 2,
    this.flexible = true,
    this.maxLines,
  });

  final String text;

  /// Text colour (and the icon colour unless [iconColor] overrides it).
  ///
  /// Defaults to the theme's held / special-note colour ([KdsColors.expoHeld])
  /// when null, resolved against the active theme in [build].
  final Color? color;
  final Color? iconColor;
  final double fontSize;
  final double iconSize;
  final FontWeight fontWeight;
  final double topPadding;

  /// Wrap the text in a [Flexible] so it ellipsizes within a bounded row
  /// (Tickets / Fire-next). Set false inside an unbounded row such as the
  /// stations bar's `OverflowBox`, where a [Flexible] has no width to claim.
  final bool flexible;

  /// When set, the text is clamped to this many lines with an ellipsis;
  /// otherwise it wraps freely.
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final Color effectiveColor = color ?? c.expoHeld;
    final Widget label = Text(
      text,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: TextStyle(
        color: effectiveColor,
        fontSize: fontSize,
        fontFamily: kJetBrainsMono,
        fontWeight: fontWeight,
      ),
    );
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Row(
        mainAxisSize: flexible ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.sticky_note_2_outlined,
              size: iconSize, color: iconColor ?? effectiveColor),
          SizedBox(width: flexible ? 4 : 2),
          if (flexible) Flexible(child: label) else label,
        ],
      ),
    );
  }
}
