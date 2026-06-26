import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/widgets/app_badge.dart';
import 'package:kbuzz/core/widgets/note_line.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// Shown on every board when no demo data has been generated yet. Points the
/// user at Profile → Generate demo data.
class BoardEmptyState extends StatelessWidget {
  const BoardEmptyState({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

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
              'No tickets yet. Open Profile and tap “Generate demo data” to '
              'load the sample rush.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small filled dot in a station's functional colour.
class StationDot extends StatelessWidget {
  const StationDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Hold / late / on-time badge derived from a [ScheduledDish].
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.holdMins, required this.lateMins});

  StatusBadge.of(ScheduledDish d, {Key? key})
      : this(key: key, holdMins: d.holdMins, lateMins: d.lateMins);

  final int holdMins;
  final int lateMins;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final (String label, Color color) = switch ((holdMins, lateMins)) {
      (_, final int late) when late > 0 => ('late ${late}m', c.danger),
      (final int hold, _) when hold > 0 => ('hold ${hold}m', c.slackHold),
      _ => ('on time', c.success),
    };
    return AppBadge(label, color);
  }
}

/// A compact pill (brand navy) — used for table labels.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpaceSm, vertical: kSpaceXs),
      decoration: BoxDecoration(
        color: KBuzzColors.brandSecondary,
        borderRadius: BorderRadius.circular(kRadiusMd),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: kFontXs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// One scheduled cook: emoji, name (+qty), optional station dot, cook time +
/// slack (can-hold / plates-late / on-time), status badge, and (optionally) the
/// tables it serves.
class ScheduledDishRow extends StatelessWidget {
  const ScheduledDishRow({
    super.key,
    required this.dish,
    this.stationColor,
    this.stationName,
    this.showTables = false,
  });

  final ScheduledDish dish;

  /// When provided, a leading station dot + name is shown.
  final Color? stationColor;
  final String? stationName;

  /// Show the member tables on the right (batched cooks list several).
  final bool showTables;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    // Slack the cook has — what the firing order costs. Colour-coded like the
    // status badges: red = will plate late, blue = can hold, green = on time.
    final (String slackText, Color slackColor) = dish.lateMins > 0
        ? ('plates +${dish.lateMins}m late', c.danger)
        : dish.holdMins > 0
            ? ('can hold ${dish.holdMins}m', c.slackHold)
            : ('on time', c.success);
    // Distinct special instructions across the tickets this (possibly batched)
    // cook serves, shown as a line under the dish name.
    final List<String> notes = <String>[
      for (final ScheduledMember m in dish.members)
        if ((m.note ?? '').trim().isNotEmpty) m.note!.trim(),
    ];
    final String? noteText = notes.isEmpty ? null : notes.toSet().join('; ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(dish.emoji, style: const TextStyle(fontSize: kFontXl)),
        const SizedBox(width: kSpaceSm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      dish.qty > 1 ? '${dish.name} ×${dish.qty}' : dish.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: c.textPrimary, fontSize: kFontMd),
                    ),
                  ),
                  if (dish.isBatched) ...<Widget>[
                    const SizedBox(width: kSpaceSm),
                    Icon(Icons.merge_type, size: 14, color: c.textFaint),
                  ],
                  if (dish.priority != PriorityKind.none) ...<Widget>[
                    const SizedBox(width: kSpaceSm),
                    _PriorityBadge(kind: dish.priority, reason: dish.recookReason),
                  ],
                ],
              ),
              if (noteText != null)
                NoteLine(noteText, iconSize: 12, maxLines: 1),
              const SizedBox(height: kSpaceXs),
              Row(
                children: <Widget>[
                  if (stationColor != null) ...<Widget>[
                    StationDot(color: stationColor!, size: 8),
                    const SizedBox(width: kSpaceXs),
                    if (stationName != null) ...<Widget>[
                      Text(
                        stationName!,
                        style: TextStyle(
                            color: c.textMuted, fontSize: kFontXs),
                      ),
                      const SizedBox(width: kSpaceSm),
                    ],
                  ],
                  Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(text: '${dish.cookMins}m cook · '),
                        TextSpan(
                          text: slackText,
                          style: TextStyle(
                            color: slackColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: kMonoNumberStyle.copyWith(
                      color: c.textFaint,
                      fontSize: kFontXs,
                    ),
                  ),
                  if (showTables) ...<Widget>[
                    const SizedBox(width: kSpaceSm),
                    Flexible(
                      child: Text(
                        dish.members
                            .map((ScheduledMember m) => m.table)
                            .join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: c.textFaint, fontSize: kFontXs),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: kSpaceSm),
        _DishStatusTrailing(dish),
      ],
    );
  }
}

/// Kitchen badge for a prioritised cook — `RECOOK · reason` (red), `FIRE NOW`
/// (orange), or `RUSH` (orange). Mirrors the Tickets-page badges so the waiter
/// → kitchen loop is visible on both sides (TICKETS.md two-way loop).
class _PriorityBadge extends StatelessWidget {
  const _PriorityBadge({required this.kind, this.reason});

  final PriorityKind kind;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    if (kind == PriorityKind.none) return const SizedBox.shrink();
    final KdsColors c = KdsColors.of(context);
    final (String, Color) styled = switch (kind) {
      PriorityKind.recook => (
          'RECOOK${reason == null ? '' : ' · $reason'}',
          c.danger,
        ),
      PriorityKind.fireNow => ('FIRE NOW', c.brand),
      PriorityKind.rush => ('RUSH', c.brand),
      PriorityKind.none => ('', Colors.transparent),
    };
    return AppBadge(
      styled.$1,
      styled.$2,
      fontSize: kFontMicro,
      fontWeight: FontWeight.w800,
      horizontal: 6,
      vertical: 2,
      radius: 5,
      alpha: 0.18,
    );
  }
}

/// Trailing status for a dish row: the planned hold/late/on-time badge before a
/// run, then live waiting/cooking/ready once the service clock is running.
/// Rebuilds on each clock tick via the app-wide [ServiceClockCubit].
class _DishStatusTrailing extends StatelessWidget {
  const _DishStatusTrailing(this.dish);

  final ScheduledDish dish;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServiceClockCubit, ServiceClockState>(
      builder: (BuildContext context, ServiceClockState clock) {
        final KdsColors c = KdsColors.of(context);
        switch (dishLiveStatus(dish, clock.elapsedMins, started: clock.started)) {
          case DishLiveStatus.planned:
            return StatusBadge.of(dish);
          case DishLiveStatus.waiting:
            final int mins = (dish.fireAt - clock.elapsedMins).ceil();
            return _LiveChip(
              icon: Icons.schedule,
              label: mins <= 0 ? 'firing' : 'in ${mins}m',
              color: c.textMuted,
            );
          case DishLiveStatus.cooking:
            return _LiveChip(
              icon: Icons.local_fire_department,
              label: 'cooking',
              color: c.slackCook,
            );
          case DishLiveStatus.held:
            return _LiveChip(
              icon: Icons.hourglass_bottom,
              label: 'holding',
              color: c.expoHeld,
            );
          case DishLiveStatus.ready:
            return _LiveChip(
              icon: Icons.check_circle,
              label: 'ready',
              color: c.success,
            );
        }
      },
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppBadge(label, color, icon: icon);
  }
}

/// Bottleneck call-out banner — the feature's punchline.
class BottleneckBanner extends StatelessWidget {
  const BottleneckBanner({
    super.key,
    required this.stationName,
    required this.lateMins,
  });

  final String stationName;
  final int lateMins;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: kSpaceMd),
      padding: const EdgeInsets.symmetric(horizontal: kSpaceMd, vertical: kSpaceMd),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: c.danger.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 18, color: c.danger),
          const SizedBox(width: kSpaceSm),
          Expanded(
            child: Text(
              '$stationName is the bottleneck (+${lateMins}m). Batch or add a '
              'second.',
              style: TextStyle(color: c.textPrimary, fontSize: kFontMd),
            ),
          ),
        ],
      ),
    );
  }
}

/// Relative-minute label: `now`, `+3m`.
String atMin(int mins) => mins <= 0 ? 'now' : '+${mins}m';
