import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/format.dart';
import 'package:kbuzz/core/widgets/app_badge.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/board/board_widgets.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// Stations rail — each station's scheduled cooks drawn as a lane-packed
/// timeline (Gantt) under its capacity, so contention is *visible*: bars start
/// at fire time, run as wide as their cook, stack into lanes, and a live "now"
/// line sweeps across once service starts. Mirrors the `MultiKOT.jsx` `Rail`
/// (AGENTS.md §10/§15).
class StationsPage extends StatelessWidget {
  const StationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stations')),
      body: BlocBuilder<DemoDataCubit, DemoDataState>(
        builder: (BuildContext context, DemoDataState state) {
          if (state.data == null) {
            return const BoardEmptyState(
              icon: Icons.view_week_outlined,
              title: 'Stations rail',
            );
          }
          final BoardData board =
              BoardData.from(state.data!, now: state.generatedAt!);
          return _StationsRail(board: board);
        },
      ),
    );
  }
}

/// Holds the page-wide bar selection (one dish across all stations) and lays
/// out the rail: bottleneck banner, per-station timelines, axis, legend and the
/// selected dish's detail card.
class _StationsRail extends StatefulWidget {
  const _StationsRail({required this.board});

  final BoardData board;

  @override
  State<_StationsRail> createState() => _StationsRailState();
}

class _StationsRailState extends State<_StationsRail> {
  int? _selectedUid;

  @override
  Widget build(BuildContext context) {
    final BoardData board = widget.board;
    final List<({Station station, StationLane lane})> sections =
        board.stationLanes;
    final Bottleneck? bottleneck = board.schedule.bottleneck;
    final int horizon = math.max(1, board.schedule.horizonMins);

    ScheduledDish? selected;
    if (_selectedUid != null) {
      for (final ScheduledDish d in board.schedule.dishes) {
        if (d.uid == _selectedUid) {
          selected = d;
          break;
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        if (bottleneck != null)
          BottleneckBanner(
            stationName: board.stationOf(bottleneck.stationId)?.name ??
                bottleneck.stationId,
            lateMins: bottleneck.lateMins,
          ),
        for (final ({Station station, StationLane lane}) s in sections)
          _StationSection(
            station: s.station,
            lane: s.lane,
            horizonMins: horizon,
            isBottleneck: board.isBottleneck(s.station.id),
            selectedUid: _selectedUid,
            onTap: (int uid) => setState(
              () => _selectedUid = _selectedUid == uid ? null : uid,
            ),
          ),
        _TimeAxis(horizonMins: horizon),
        const SizedBox(height: 10),
        const _Legend(),
        if (selected != null) ...<Widget>[
          const SizedBox(height: 12),
          _DetailCard(dish: selected, board: board),
        ],
      ],
    );
  }
}

/// One station: header (dot, name, capacity, bottleneck flag, saturation pill)
/// over its lane-packed timeline.
class _StationSection extends StatelessWidget {
  const _StationSection({
    required this.station,
    required this.lane,
    required this.horizonMins,
    required this.isBottleneck,
    required this.selectedUid,
    required this.onTap,
  });

  final Station station;
  final StationLane lane;
  final int horizonMins;
  final bool isBottleneck;
  final int? selectedUid;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(station.color);
    final bool saturated = lane.lanes >= station.capacity;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: KBuzzColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                StationDot(color: color, size: 12),
                const SizedBox(width: 8),
                Text(
                  station.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _CapacityStepper(station: station),
                if (isBottleneck) ...<Widget>[
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFEF4444)),
                ],
                const Spacer(),
                _SaturationPill(
                  saturated: saturated,
                  lanes: lane.lanes,
                  capacity: station.capacity,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StationTimeline(
              dishes: lane.dishes,
              lanes: lane.lanes,
              color: color,
              horizonMins: horizonMins,
              selectedUid: selectedUid,
              onTap: onTap,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline `− cap N +` stepper to edit a station's concurrent capacity. Each tap
/// dispatches to [DemoDataCubit.setStationCapacity], which reschedules off the
/// new capacity — lanes, saturation and the bottleneck update live. Capacity is
/// bounded to [_min]–[_max].
class _CapacityStepper extends StatelessWidget {
  const _CapacityStepper({required this.station});

  final Station station;

  static const int _min = 1;
  static const int _max = 8;

  @override
  Widget build(BuildContext context) {
    final DemoDataCubit cubit = context.read<DemoDataCubit>();
    final int cap = station.capacity;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepButton(
          icon: Icons.remove,
          onTap: cap > _min
              ? () => cubit.setStationCapacity(station.id, cap - 1)
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'cap $cap',
            style: kMonoNumberStyle.copyWith(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: cap < _max
              ? () => cubit.setStationCapacity(station.id, cap + 1)
              : null,
        ),
      ],
    );
  }
}

/// A small round +/- button; greyed out (and inert) when [onTap] is null.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: KBuzzColors.board,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? Colors.white : Colors.white24,
        ),
      ),
    );
  }
}

class _SaturationPill extends StatelessWidget {
  const _SaturationPill({
    required this.saturated,
    required this.lanes,
    required this.capacity,
  });

  final bool saturated;
  final int lanes;
  final int capacity;

  @override
  Widget build(BuildContext context) {
    const Color hot = Color(0xFFEF4444);
    return AppBadge(
      saturated ? 'saturated' : '$lanes/$capacity',
      saturated ? hot : Colors.white38,
      alpha: saturated ? 0.16 : 0,
    );
  }
}

/// The Gantt track for one station. Bars are positioned by fire time and sized
/// by cook time; lanes stack vertically. Rebuilds on every clock tick so the
/// now-line sweeps and bars fade / flame / check with live status.
class _StationTimeline extends StatelessWidget {
  const _StationTimeline({
    required this.dishes,
    required this.lanes,
    required this.color,
    required this.horizonMins,
    required this.selectedUid,
    required this.onTap,
  });

  static const double laneHeight = 30;
  static const double barHeight = 24;
  static const double minBarWidth = 46;

  final List<ScheduledDish> dishes;
  final int lanes;
  final Color color;
  final int horizonMins;
  final int? selectedUid;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ServiceClockCubit, ServiceClockState>(
      builder: (BuildContext context, ServiceClockState clock) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double trackW = constraints.maxWidth;
            final double height = lanes * laneHeight;
            return SizedBox(
              height: height,
              width: trackW,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  for (final ScheduledDish d in dishes)
                    _buildBar(d, trackW, clock),
                  if (clock.started)
                    _buildNowLine(trackW, clock.elapsedMins),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBar(ScheduledDish d, double trackW, ServiceClockState clock) {
    final double left = (d.fireAt / horizonMins * trackW).clamp(0.0, trackW);
    final double maxW = math.max(minBarWidth, trackW - left);
    final double width =
        (d.cookMins / horizonMins * trackW).clamp(minBarWidth, maxW);
    final DishLiveStatus status =
        dishLiveStatus(d, clock.elapsedMins, started: clock.started);
    return Positioned(
      left: left,
      top: d.lane * laneHeight,
      width: width,
      height: barHeight,
      child: _DishBar(
        dish: d,
        color: color,
        status: status,
        selected: d.uid == selectedUid,
        onTap: () => onTap(d.uid),
      ),
    );
  }

  Widget _buildNowLine(double trackW, double elapsedMins) {
    final double x = (elapsedMins / horizonMins * trackW).clamp(0.0, trackW);
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single dish bar: emoji + name (+qty) + live icon, with late (red outline),
/// selected (white outline) and holding (amber right edge) markers. Faded while
/// it's still planned or waiting to fire.
class _DishBar extends StatelessWidget {
  const _DishBar({
    required this.dish,
    required this.color,
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final ScheduledDish dish;
  final Color color;
  final DishLiveStatus status;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool faded = status == DishLiveStatus.planned ||
        status == DishLiveStatus.waiting;
    final bool late = dish.lateMins > 0;
    final bool holding = dish.holdMins > 0;
    // Re-fired / rushed cooks get an accent outline (recook red, else orange).
    final Color? priorityColor = dish.priority == PriorityKind.recook
        ? const Color(0xFFF87171)
        : dish.priority != PriorityKind.none
            ? KBuzzColors.brandPrimary
            : null;

    final BoxBorder? border = late
        ? Border.all(color: const Color(0xFFF87171), width: 2)
        : priorityColor != null
            ? Border.all(color: priorityColor, width: 2)
            : selected
                ? Border.all(color: Colors.white, width: 2)
                : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: faded ? 0.5 : 1),
          borderRadius: BorderRadius.circular(5),
          border: border,
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(dish.emoji, style: const TextStyle(fontSize: 11)),
                      const SizedBox(width: 3),
                      Text(
                        dish.qty > 1 ? '${dish.name} ×${dish.qty}' : dish.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (status == DishLiveStatus.cooking) ...<Widget>[
                        const SizedBox(width: 4),
                        const Icon(Icons.local_fire_department,
                            size: 11, color: Colors.white),
                      ] else if (status == DishLiveStatus.ready) ...<Widget>[
                        const SizedBox(width: 4),
                        const Icon(Icons.check, size: 11, color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (holding)
              Positioned(
                top: 0,
                bottom: 0,
                right: 0,
                child: Container(width: 3, color: const Color(0xFFFDE68A)),
              ),
          ],
        ),
      ),
    );
  }
}

/// `0:00 … mid … end` track ruler under the rail.
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.horizonMins});

  final int horizonMins;

  @override
  Widget build(BuildContext context) {
    final TextStyle style = kMonoNumberStyle.copyWith(
      color: Colors.white30,
      fontSize: 10,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text('0:00', style: style),
          Text(_clock(horizonMins / 2), style: style),
          Text(_clock(horizonMins), style: style),
        ],
      ),
    );
  }
}

/// Marker key: holding (amber edge) and plates-late (red outline).
class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    const TextStyle style = TextStyle(color: Colors.white38, fontSize: 11);
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 16,
              height: 11,
              decoration: const BoxDecoration(
                color: Color(0xFF52525B),
                border: Border(
                  right: BorderSide(color: Color(0xFFFDE68A), width: 3),
                ),
              ),
            ),
            const SizedBox(width: 5),
            const Text('holding', style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 16,
              height: 11,
              decoration: BoxDecoration(
                color: const Color(0xFF52525B),
                border: Border.all(color: const Color(0xFFF87171), width: 1.5),
              ),
            ),
            const SizedBox(width: 5),
            const Text('plates late', style: style),
          ],
        ),
        const Text('tap a bar for tables', style: style),
      ],
    );
  }
}

/// Expanded card for the tapped bar: emoji + name + station chip, the tables it
/// serves, and fire / cook / outcome stats.
class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.dish, required this.board});

  final ScheduledDish dish;
  final BoardData board;

  @override
  Widget build(BuildContext context) {
    final Station? station = board.stationOf(dish.stationId);
    final Color color =
        station == null ? Colors.white : Color(station.color);
    final bool late = dish.lateMins > 0;
    final bool holding = dish.holdMins > 0;

    final String outcomeLabel =
        late ? 'late by' : holding ? 'holds' : 'plate';
    final String outcomeValue = late
        ? '+${_clock(dish.lateMins)}'
        : holding
            ? _clock(dish.holdMins)
            : 'on time';
    final Color outcomeColor = late
        ? const Color(0xFFF87171)
        : holding
            ? const Color(0xFFFBBF24)
            : const Color(0xFF34D399);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KBuzzColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(dish.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  dish.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '×${dish.qty}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const Spacer(),
              if (station != null) _StationChip(station: station, color: color),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final ScheduledMember m in dish.members)
                Pill(_tableCode(m) + (m.qty > 1 ? ' ×${m.qty}' : '')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _Stat(
                label: 'fire',
                value: dish.fireAt <= 0 ? 'now' : '+${_clock(dish.fireAt)}',
              ),
              const SizedBox(width: 8),
              _Stat(label: 'cook', value: '${dish.cookMins}m'),
              const SizedBox(width: 8),
              _Stat(
                label: outcomeLabel,
                value: outcomeValue,
                color: outcomeColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StationChip extends StatelessWidget {
  const _StationChip({required this.station, required this.color});

  final Station station;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StationDot(color: color, size: 6),
          const SizedBox(width: 5),
          Text(
            station.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.color = const Color(0xFFE4E4E7),
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: kMonoNumberStyle.copyWith(color: color, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// `M:SS` from a minute count (mirrors the prototype's `fmt`).
String _clock(num minutes) {
  final int sec = math.max(0, (minutes * 60).round());
  return '${sec ~/ 60}:${(sec % 60).toString().padLeft(2, '0')}';
}

/// Ticket code for a member: `T5` (dine-in), `TA3` (takeaway), `D21` (delivery)
/// — mirrors the prototype's `codeOf`.
String _tableCode(ScheduledMember m) => ticketCode(m.type, m.table);
