import 'package:flutter/material.dart';
import 'package:kbuzz/app/theme.dart';

/// The app's soft-tinted badge: a rounded chip with a translucent [color] fill
/// and bold [color] text, optionally led by an [icon].
///
/// Single source of truth for the pill/tag/badge shape repeated across the
/// boards (status, priority, live, table-saturation) and elsewhere. Each caller
/// keeps its own label/color/size by passing the relevant knobs; the container,
/// tint, radius and text styling live here so a visual tweak lands once.
class AppBadge extends StatelessWidget {
  const AppBadge(
    this.text,
    this.color, {
    super.key,
    this.icon,
    this.fontSize = 11,
    this.fontWeight = FontWeight.w700,
    this.horizontal = 8,
    this.vertical = 3,
    this.radius = 6,
    this.alpha = 0.16,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final double fontSize;
  final FontWeight fontWeight;
  final double horizontal;
  final double vertical;
  final double radius;

  /// Opacity of the tinted fill. Pass `0` for a transparent (text-only) chip.
  final double alpha;

  @override
  Widget build(BuildContext context) {
    final Text label = Text(
      text,
      style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight),
    );
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical),
      decoration: BoxDecoration(
        color: color.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: icon == null
          ? label
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: fontSize + 1, color: color),
                const SizedBox(width: kSpaceXs),
                label,
              ],
            ),
    );
  }
}
