import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/format.dart';
import 'package:kbuzz/core/widgets/app_badge.dart';
import 'package:kbuzz/core/widgets/marquee_text.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/board/board_widgets.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
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
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            <Widget>[
              SliverAppBar(
                title: const Text('Stations'),
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
              ),
            ],
        body: BlocBuilder<DemoDataCubit, DemoDataState>(
          builder: (BuildContext context, DemoDataState state) {
            if (state.data == null) {
              return const BoardEmptyState(
                icon: Icons.view_week_outlined,
                title: 'Stations rail',
              );
            }
            final BoardData board = BoardData.from(
              state.data!,
              now: state.generatedAt!,
              fireImmediately: context
                  .watch<SettingsCubit>()
                  .state
                  .fireImmediately,
            );
            return _StationsRail(board: board);
          },
        ),
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
      padding: const EdgeInsets.all(kSpaceLg),
      children: <Widget>[
        if (bottleneck != null)
          BottleneckBanner(
            stationName:
                board.stationOf(bottleneck.stationId)?.name ??
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
            onTap: (int uid) =>
                setState(() => _selectedUid = _selectedUid == uid ? null : uid),
          ),
        _TimeAxis(horizonMins: horizon),
        const SizedBox(height: kSpaceMd),
        const _Legend(),
        if (selected != null) ...<Widget>[
          const SizedBox(height: kSpaceMd),
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
    final KdsColors c = KdsColors.of(context);
    final Color color = Color(station.color);
    final bool saturated = lane.lanes >= station.capacity;
    return Container(
      margin: const EdgeInsets.only(bottom: kSpaceMd),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                StationDot(color: color, size: 12),
                const SizedBox(width: kSpaceSm),
                Text(
                  station.name,
                  style: const TextStyle(
                    fontSize: kFontLg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: kSpaceSm),
                _CapacityStepper(station: station),
                if (isBottleneck) ...<Widget>[
                  const SizedBox(width: kSpaceSm),
                  Icon(Icons.warning_amber_rounded, size: 16, color: c.danger),
                ],
                const Spacer(),
                _SaturationPill(
                  saturated: saturated,
                  lanes: lane.lanes,
                  capacity: station.capacity,
                ),
              ],
            ),
            const SizedBox(height: kSpaceMd),
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
    final KdsColors c = KdsColors.of(context);
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
          padding: const EdgeInsets.symmetric(horizontal: kSpaceXs),
          child: Text(
            'cap $cap',
            style: kMonoNumberStyle.copyWith(
              color: c.textSecondary,
              fontSize: kFontSm,
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
    final KdsColors c = KdsColors.of(context);
    final bool enabled = onTap != null;
    return InkResponse(
      onTap: onTap,
      radius: 16,
      child: Container(
        padding: const EdgeInsets.all(kSpaceXs),
        decoration: BoxDecoration(color: c.board, shape: BoxShape.circle),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? c.textPrimary : c.hairlineStrong,
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
    final KdsColors c = KdsColors.of(context);
    final Color hot = c.danger;
    return AppBadge(
      saturated ? 'saturated' : '$lanes/$capacity',
      saturated ? hot : c.textFaint,
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

  // Time-scaled Gantt: bar width = cook duration. A bar is one line tall (name)
  // or two lines when it carries a note (name + a sliding note underneath). A
  // station's lanes all use the taller row height when *any* cook there has a
  // note, so lanes never overlap; note-less bars then sit short in their row.
  // Names/notes longer than the bar slide (MarqueeText) instead of widening it.
  // Heights leave room for the 2px outline a late/priority/selected bar draws
  // (which eats 4px vertically) plus the 6px label padding.
  static const double barPlainHeight = 30;
  static const double barNotedHeight = 50;
  static const double rowGap = 6;
  static const double minBarWidth = 30;

  final List<ScheduledDish> dishes;
  final int lanes;
  final Color color;
  final int horizonMins;
  final int? selectedUid;
  final ValueChanged<int> onTap;

  static bool _hasNote(ScheduledDish d) =>
      d.members.any((ScheduledMember m) => (m.note ?? '').trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
    // Per-lane row heights: a lane is tall (fits a note line) only when some cook
    // in *that* lane carries a note; otherwise it's a single-line lane. Lanes are
    // stacked cumulatively so the gap between every row is exactly [rowGap] — a
    // note-less lane no longer leaves a tall empty slot under its short bar (which
    // made the row spacing look uneven once any cook on the station had a note).
    final List<bool> laneNoted = List<bool>.filled(lanes, false);
    for (final ScheduledDish d in dishes) {
      if (d.lane >= 0 && d.lane < lanes && _hasNote(d)) laneNoted[d.lane] = true;
    }
    final List<double> laneTop = List<double>.filled(lanes, 0);
    double laneY = 0;
    for (int i = 0; i < lanes; i++) {
      laneTop[i] = laneY;
      laneY += (laneNoted[i] ? barNotedHeight : barPlainHeight) + rowGap;
    }
    final double trackHeight = laneY;
    return BlocBuilder<ServiceClockCubit, ServiceClockState>(
      builder: (BuildContext context, ServiceClockState clock) {
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final KdsColors c = KdsColors.of(context);
            final double trackW = constraints.maxWidth;
            return SizedBox(
              height: trackHeight,
              width: trackW,
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: <Widget>[
                  // Time-scaled colour bars: positioned by fire time, width = cook
                  // duration ("matches the cook clock"). Name (and note, if any)
                  // slide inside the bar; full detail is on the card on tap.
                  for (final ScheduledDish d in dishes)
                    _buildBar(d, trackW, laneTop, clock),
                  if (clock.started)
                    _buildNowLine(trackW, clock.elapsedMins, c.textPrimary),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBar(
    ScheduledDish d,
    double trackW,
    List<double> laneTop,
    ServiceClockState clock,
  ) {
    final double left = (d.fireAt / horizonMins * trackW).clamp(0.0, trackW);
    final double maxW = math.max(minBarWidth, trackW - left);
    // Width = the time-scaled cook duration ("matches the cook clock").
    final double width = (d.cookMins / horizonMins * trackW).clamp(
      minBarWidth,
      maxW,
    );
    final DishLiveStatus status = dishLiveStatus(
      d,
      clock.elapsedMins,
      started: clock.started,
    );
    return Positioned(
      left: left,
      top: laneTop[d.lane],
      width: width,
      height: _hasNote(d) ? barNotedHeight : barPlainHeight,
      child: _DishBar(
        key: ValueKey<int>(d.uid),
        dish: d,
        color: color,
        status: status,
        selected: d.uid == selectedUid,
        onTap: () => onTap(d.uid),
      ),
    );
  }

  Widget _buildNowLine(double trackW, double elapsedMins, Color color) {
    final double x = (elapsedMins / horizonMins * trackW).clamp(0.0, trackW);
    return Positioned(
      left: x,
      top: 0,
      bottom: 0,
      child: Container(
        width: 2,
        decoration: BoxDecoration(
          color: color,
          boxShadow: <BoxShadow>[
            BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// A single dish bar: emoji + name on the first line, with the cook's note (if
/// any) sliding on a second line beneath it. Late (red outline), selected (white
/// outline) and holding (amber right edge) markers; faded while planned/waiting.
/// Live status is read from the bar colour + the sweeping now-line, so no inline
/// status glyph is shown. A name or note longer than the (time-scaled) bar
/// slides instead of widening it.
class _DishBar extends StatelessWidget {
  const _DishBar({
    super.key,
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
    final KdsColors c = KdsColors.of(context);
    final bool faded =
        status == DishLiveStatus.planned || status == DishLiveStatus.waiting;
    final bool late = dish.lateMins > 0;
    final bool holding = dish.holdMins > 0;
    final bool cooking = status == DishLiveStatus.cooking;
    final List<String> notes = <String>[
      for (final ScheduledMember m in dish.members)
        if ((m.note ?? '').trim().isNotEmpty) m.note!.trim(),
    ];
    final String? noteText = notes.isEmpty ? null : notes.toSet().join('; ');
    // Outlined bars: the station colour lives in the border stroke (below) plus
    // a faint tint of itself over the surface — not a saturated fill — so the
    // label sits on a near-neutral background and reads cleanly in both themes.
    // Planned/waiting cooks dim the tint, stroke and text.
    final Color fill = Color.alphaBlend(
      color.withValues(alpha: faded ? 0.05 : 0.12),
      c.surface,
    );
    final Color textColor = faded ? c.textMuted : c.textPrimary;
    // Re-fired / rushed cooks get an accent stroke (recook red, else orange).
    final Color? priorityColor = dish.priority == PriorityKind.recook
        ? c.expoLate
        : dish.priority != PriorityKind.none
        ? c.brand
        : null;
    // Stroke precedence: plates-late, re-fire/rush, selected, then the station
    // colour itself (the bar's default identity). Accented states draw heavier.
    final bool accented = late || priorityColor != null || selected;
    final Color borderColor = late
        ? c.expoLate
        : priorityColor ??
              (selected
                  ? c.textPrimary
                  : color.withValues(alpha: faded ? 0.5 : 1));

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Container(
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(kRadiusSm),
              border: Border.all(color: borderColor, width: accented ? 2 : 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: kSpaceSm,
                    vertical: kSpaceXs,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Text(
                            dish.emoji,
                            style: const TextStyle(fontSize: kFontSm),
                          ),
                          const SizedBox(width: kSpaceXs),
                          Expanded(
                            child: MarqueeText(
                              dish.qty > 1
                                  ? '${dish.name} ×${dish.qty}'
                                  : dish.name,
                              style: TextStyle(
                                color: textColor,
                                fontSize: kFontXs,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (noteText != null)
                        Padding(
                          padding: const EdgeInsets.only(top: kSpaceXs),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.sticky_note_2_outlined,
                                size: 12,
                                color: faded ? c.textFaint : c.holdStripe,
                              ),
                              const SizedBox(width: kSpaceXs),
                              Expanded(
                                child: MarqueeText(
                                  noteText,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: kFontSm,
                                    fontFamily: kJetBrainsMono,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (holding)
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    child: Container(width: 3, color: c.holdStripe),
                  ),
              ],
            ),
          ),
          if (cooking)
            Positioned.fill(
              child: _TronTrace(color: color, radius: kRadiusSm),
            ),
        ],
      ),
    );
  }
}

/// A "light-cycle" trace: a glowing comet of light orbits the dish bar's rounded
/// border while the dish is cooking, leaving a fading trail — so an actively
/// cooking dish reads at a glance. Owns a repeating controller that respects
/// [TickerMode] (idles offscreen and in tests). Drawn as a non-interactive
/// overlay on top of the static station-colour border.
class _TronTrace extends StatefulWidget {
  const _TronTrace({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  State<_TronTrace> createState() => _TronTraceState();
}

class _TronTraceState extends State<_TronTrace>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? _) => CustomPaint(
            painter: _TronTracePainter(
              t: _controller.value,
              color: widget.color,
              radius: widget.radius,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the comet along the bar's rounded-rect perimeter at progress [t]
/// (0..1): a bright glowing head, with a trail fading from the station [color]
/// to transparent behind it.
class _TronTracePainter extends CustomPainter {
  _TronTracePainter({
    required this.t,
    required this.color,
    required this.radius,
  });

  final double t;
  final Color color;
  final double radius;

  static const double _inset = 0.9; // sit on the ~1.5px border line
  static const double _trailFraction = 0.45; // comet length, share of perimeter
  static const int _segments = 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final RRect rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(_inset),
      Radius.circular(math.max(0, radius - _inset)),
    );
    final ui.PathMetric metric = (Path()..addRRect(rrect))
        .computeMetrics()
        .first;
    final double len = metric.length;
    if (len <= 0) return;

    final double head = (t % 1.0) * len;
    final double trail = len * _trailFraction;
    final Color bright = Color.lerp(color, Colors.white, 0.9)!;

    // Soft coloured halo under the trail.
    canvas.drawPath(
      _arc(metric, head - trail, head, len),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 3.5
        ..color = color.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Bright core, fading tail -> head.
    for (int i = 0; i < _segments; i++) {
      final double a = (i + 1) / _segments; // brightness toward the head
      canvas.drawPath(
        _arc(
          metric,
          head - trail * (1 - i / _segments),
          head - trail * (1 - (i + 1) / _segments),
          len,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = ui.lerpDouble(0.6, 2.2, a)!
          ..color = Color.lerp(color, bright, a)!.withValues(alpha: a),
      );
    }

    // Glowing head.
    final ui.Tangent? tan = metric.getTangentForOffset(head);
    if (tan != null) {
      canvas
        ..drawCircle(
          tan.position,
          3.2,
          Paint()
            ..color = bright.withValues(alpha: 0.85)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
        )
        ..drawCircle(tan.position, 1.5, Paint()..color = Colors.white);
    }
  }

  /// The sub-path from [from]..[to] arc-length, wrapping past the path's end.
  Path _arc(ui.PathMetric m, double from, double to, double len) {
    double a = from % len, b = to % len;
    if (a < 0) a += len;
    if (b < 0) b += len;
    final Path out = Path();
    if (a <= b) {
      out.addPath(m.extractPath(a, b), Offset.zero);
    } else {
      out
        ..addPath(m.extractPath(a, len), Offset.zero)
        ..addPath(m.extractPath(0, b), Offset.zero);
    }
    return out;
  }

  @override
  bool shouldRepaint(_TronTracePainter old) =>
      old.t != t || old.color != color || old.radius != radius;
}

/// `0:00 … mid … end` track ruler under the rail.
class _TimeAxis extends StatelessWidget {
  const _TimeAxis({required this.horizonMins});

  final int horizonMins;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final TextStyle style = kMonoNumberStyle.copyWith(
      color: c.textFaint,
      fontSize: kFontXs,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpaceXs),
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
    final KdsColors c = KdsColors.of(context);
    final TextStyle style = TextStyle(color: c.textFaint, fontSize: kFontXs);
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
              decoration: BoxDecoration(
                color: c.swatchGrey,
                border: Border(
                  right: BorderSide(color: c.holdStripe, width: 3),
                ),
              ),
            ),
            const SizedBox(width: kSpaceXs),
            Text('holding', style: style),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 16,
              height: 11,
              decoration: BoxDecoration(
                color: c.swatchGrey,
                border: Border.all(color: c.expoLate, width: 1.5),
              ),
            ),
            const SizedBox(width: kSpaceXs),
            Text('plates late', style: style),
          ],
        ),
        Text('tap a bar for tables', style: style),
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
    final KdsColors c = KdsColors.of(context);
    final Station? station = board.stationOf(dish.stationId);
    final Color color = station == null ? c.textPrimary : Color(station.color);
    final bool late = dish.lateMins > 0;
    final bool holding = dish.holdMins > 0;

    final String outcomeLabel = late
        ? 'late by'
        : holding
        ? 'holds'
        : 'plate';
    final String outcomeValue = late
        ? '+${_clock(dish.lateMins)}'
        : holding
        ? _clock(dish.holdMins)
        : 'on time';
    final Color outcomeColor = late
        ? c.expoLate
        : holding
        ? c.expoHeld
        : c.expoReady;

    return Container(
      padding: const EdgeInsets.all(kSpaceLg),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(kRadiusLg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(dish.emoji, style: const TextStyle(fontSize: kFontXl)),
              const SizedBox(width: kSpaceSm),
              Flexible(
                child: Text(
                  dish.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: c.textPrimary,
                    fontSize: kFontMd,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: kSpaceSm),
              Text(
                '×${dish.qty}',
                style: TextStyle(color: c.textMuted, fontSize: kFontMd),
              ),
              const Spacer(),
              if (station != null) _StationChip(station: station, color: color),
            ],
          ),
          const SizedBox(height: kSpaceMd),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final ScheduledMember m in dish.members)
                Pill(_tableCode(m) + (m.qty > 1 ? ' ×${m.qty}' : '')),
            ],
          ),
          _MemberNotes(members: dish.members),
          const SizedBox(height: kSpaceMd),
          Row(
            children: <Widget>[
              _Stat(
                label: 'fire',
                value: dish.fireAt <= 0 ? 'now' : '+${_clock(dish.fireAt)}',
              ),
              const SizedBox(width: kSpaceSm),
              _Stat(label: 'cook', value: '${dish.cookMins}m'),
              const SizedBox(width: kSpaceSm),
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

/// Per-table special instructions for a (possibly batched) cook — one
/// "{table} {note}" row per member that carries a note. Renders nothing when no
/// member has one.
class _MemberNotes extends StatelessWidget {
  const _MemberNotes({required this.members});

  final List<ScheduledMember> members;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final List<ScheduledMember> noted = <ScheduledMember>[
      for (final ScheduledMember m in members)
        if ((m.note ?? '').trim().isNotEmpty) m,
    ];
    if (noted.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: kSpaceMd),
        for (final ScheduledMember m in noted)
          Padding(
            padding: const EdgeInsets.only(bottom: kSpaceXs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.sticky_note_2_outlined, size: 14, color: c.expoHeld),
                const SizedBox(width: kSpaceSm),
                Text(
                  '${_tableCode(m)} ',
                  style: TextStyle(
                    color: c.textMuted,
                    fontSize: kFontSm,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Expanded(
                  child: Text(
                    m.note!.trim(),
                    style: TextStyle(
                      color: c.expoHeld,
                      fontSize: kFontSm,
                      fontFamily: kJetBrainsMono,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: kSpaceSm,
        vertical: kSpaceXs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(kRadiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          StationDot(color: color, size: 6),
          const SizedBox(width: kSpaceXs),
          Text(
            station.name.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: kFontMicro,
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
    this.color,
  });

  final String label;
  final String value;

  /// Value colour. Null ⇒ [KdsColors.textPrimary], resolved in [build] so it
  /// follows the theme (the outcome stat passes a status colour instead).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final Color valueColor = color ?? c.textPrimary;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
        decoration: BoxDecoration(
          color: c.textPrimary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(kRadiusMd),
        ),
        child: Column(
          children: <Widget>[
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: c.textFaint,
                fontSize: kFontMicro,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: kSpaceXs),
            Text(
              value,
              style: kMonoNumberStyle.copyWith(
                color: valueColor,
                fontSize: kFontMd,
              ),
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
