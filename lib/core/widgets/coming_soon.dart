import 'package:flutter/material.dart';
import 'package:kbuzz/app/theme.dart';

/// Placeholder body for screens whose feature lands in a later milestone.
///
/// Keeps the skeleton runnable and navigable without shipping dead UI code.
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final KdsColors c = KdsColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpaceXxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: kSpaceMd),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: kSpaceXs),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
