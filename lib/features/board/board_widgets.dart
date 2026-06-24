import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/widgets/app_badge.dart';
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'No tickets yet. Open Profile and tap “Generate demo data” to '
              'load the sample rush.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
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
    final (String label, Color color) = switch ((holdMins, lateMins)) {
      (_, final int late) when late > 0 => ('late ${late}m', const Color(0xFFEF4444)),
      (final int hold, _) when hold > 0 => ('hold ${hold}m', const Color(0xFF0EA5E9)),
      _ => ('on time', const Color(0xFF10B981)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: KBuzzColors.brandSecondary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
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
    // Slack the cook has — what the firing order costs. Colour-coded like the
    // status badges: red = will plate late, blue = can hold, green = on time.
    final (String slackText, Color slackColor) = dish.lateMins > 0
        ? ('plates +${dish.lateMins}m late', const Color(0xFFEF4444))
        : dish.holdMins > 0
            ? ('can hold ${dish.holdMins}m', const Color(0xFF0EA5E9))
            : ('on time', const Color(0xFF10B981));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Text(dish.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
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
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                  if (dish.isBatched) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(Icons.merge_type,
                        size: 14, color: Colors.white38),
                  ],
                  if (dish.priority != PriorityKind.none) ...<Widget>[
                    const SizedBox(width: 6),
                    _PriorityBadge(kind: dish.priority, reason: dish.recookReason),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: <Widget>[
                  if (stationColor != null) ...<Widget>[
                    StationDot(color: stationColor!, size: 8),
                    const SizedBox(width: 5),
                    if (stationName != null) ...<Widget>[
                      Text(
                        stationName!,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
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
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                  if (showTables) ...<Widget>[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dish.members
                            .map((ScheduledMember m) => m.table)
                            .join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
    final (String, Color) styled = switch (kind) {
      PriorityKind.recook => (
          'RECOOK${reason == null ? '' : ' · $reason'}',
          const Color(0xFFEF4444),
        ),
      PriorityKind.fireNow => ('FIRE NOW', KBuzzColors.brandPrimary),
      PriorityKind.rush => ('RUSH', KBuzzColors.brandPrimary),
      PriorityKind.none => ('', Colors.transparent),
    };
    return AppBadge(
      styled.$1,
      styled.$2,
      fontSize: 9,
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
        switch (dishLiveStatus(dish, clock.elapsedMins, started: clock.started)) {
          case DishLiveStatus.planned:
            return StatusBadge.of(dish);
          case DishLiveStatus.waiting:
            final int mins = (dish.fireAt - clock.elapsedMins).ceil();
            return _LiveChip(
              icon: Icons.schedule,
              label: mins <= 0 ? 'firing' : 'in ${mins}m',
              color: Colors.white54,
            );
          case DishLiveStatus.cooking:
            return const _LiveChip(
              icon: Icons.local_fire_department,
              label: 'cooking',
              color: Color(0xFFF59E0B),
            );
          case DishLiveStatus.held:
            return const _LiveChip(
              icon: Icons.hourglass_bottom,
              label: 'holding',
              color: Color(0xFFFBBF24),
            );
          case DishLiveStatus.ready:
            return const _LiveChip(
              icon: Icons.check_circle,
              label: 'ready',
              color: Color(0xFF10B981),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$stationName is the bottleneck (+${lateMins}m). Batch or add a '
              'second.',
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Relative-minute label: `now`, `+3m`.
String atMin(int mins) => mins <= 0 ? 'now' : '+${mins}m';
