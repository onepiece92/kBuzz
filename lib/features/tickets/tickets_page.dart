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

/// Reasons offered when sending a line back (TICKETS.md `RECOOK_REASONS`).
const List<String> kRecookReasons = <String>[
  'Cold',
  'Undercooked',
  'Wrong dish',
  'Dropped',
  'Allergy',
];

/// Minutes a line may sit ready-but-unserved before the "under-lamp" warning.
const int kReadyLimitMins = 4;

const Color _green = Color(0xFF34D399);
const Color _amber = Color(0xFFFBBF24);
const Color _red = Color(0xFFF87171);
const Color _orange = KBuzzColors.brandPrimary;

/// Tickets — the **waiter** expo page (TICKETS.md). Each ticket is a card the
/// waiter drives: tap a line for the action sheet (serve / recook / fire-now /
/// void), or use the footer (rush / serve-all / done). Actions mutate state via
/// [DemoDataCubit]; the kitchen boards react through the scheduler. Active
/// tickets sort soonest-due first; done tickets drop to a dimmed section.
class TicketsPage extends StatelessWidget {
  const TicketsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tickets')),
      body: BlocBuilder<DemoDataCubit, DemoDataState>(
        builder: (BuildContext context, DemoDataState state) {
          if (state.data == null || state.generatedAt == null) {
            return const BoardEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Tickets',
            );
          }
          final BoardData board =
              BoardData.from(state.data!, now: state.generatedAt!);
          // Rebuild on each tick so cooking status / under-lamp stay live.
          return BlocBuilder<ServiceClockCubit, ServiceClockState>(
            builder: (BuildContext context, ServiceClockState clock) =>
                _TicketList(board: board, clock: clock),
          );
        },
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({required this.board, required this.clock});

  final BoardData board;
  final ServiceClockState clock;

  @override
  Widget build(BuildContext context) {
    final List<Kot> active = <Kot>[];
    final List<Kot> done = <Kot>[];
    for (final Kot k in board.data.kots) {
      (k.status == TicketState.done ? done : active).add(k);
    }
    active.sort((Kot a, Kot b) {
      final int byTarget =
          board.statusOf(a).targetMins.compareTo(board.statusOf(b).targetMins);
      if (byTarget != 0) return byTarget;
      return a.id.compareTo(b.id);
    });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final Kot k in active)
          _TicketCard(kot: k, board: board, clock: clock),
        if (done.isNotEmpty) ...<Widget>[
          const _SectionDivider('Done'),
          for (final Kot k in done)
            Opacity(
              opacity: 0.6,
              child: _TicketCard(kot: k, board: board, clock: clock),
            ),
        ],
      ],
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.kot, required this.board, required this.clock});

  final Kot kot;
  final BoardData board;
  final ServiceClockState clock;

  @override
  Widget build(BuildContext context) {
    final TicketStatus status = board.statusOf(kot);
    final bool done = kot.status == TicketState.done;
    final bool allReady = _allReady(status.plateMins);
    final bool late = status.lateMins > 0;
    final bool anyOpen =
        kot.lines.any((OrderLine l) => l.state == LineState.open);

    final Color border = done
        ? Colors.white24
        : kot.rush
            ? _orange
            : allReady
                ? _green
                : late
                    ? _red
                    : Colors.white12;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KBuzzColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _header(done: done, allReady: allReady),
          const SizedBox(height: 6),
          Text(
            done
                ? 'plates ${atMin(status.plateMins)} · target ${atMin(status.targetMins)}'
                : '${kot.type == KotType.delivery ? "Rider" : "Plate together"} · '
                    'plate ${atMin(status.plateMins)} · target ${atMin(status.targetMins)}',
            style: kMonoNumberStyle.copyWith(color: Colors.white54, fontSize: 12),
          ),
          const Divider(height: 18, color: Colors.white12),
          for (final OrderLine line in kot.lines)
            _LineTile(
              kot: kot,
              line: line,
              board: board,
              clock: clock,
              plateMins: status.plateMins,
            ),
          const SizedBox(height: 8),
          _footer(context, done: done, anyOpen: anyOpen, allResolved: _allResolved()),
        ],
      ),
    );
  }

  Widget _header({
    required bool done,
    required bool allReady,
  }) {
    return Row(
      children: <Widget>[
        Text(
          _codeOf(kot),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Text(kot.type.label,
            style: const TextStyle(color: Colors.white54, fontSize: 12)),
        if (kot.rush) ...<Widget>[
          const SizedBox(width: 6),
          const _Tag('RUSH', _orange),
        ],
        const Spacer(),
        if (done)
          const _Tag('DONE', Colors.white38)
        else if (allReady)
          const _Tag('all ready', _green),
        const SizedBox(width: 8),
        Text(
          _ageLabel(kot.orderedAt, board.now),
          style: kMonoNumberStyle.copyWith(color: Colors.white38, fontSize: 11),
        ),
      ],
    );
  }

  Widget _footer(
    BuildContext context, {
    required bool done,
    required bool anyOpen,
    required bool allResolved,
  }) {
    final DemoDataCubit cubit = context.read<DemoDataCubit>();
    if (done) {
      return Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => cubit.reopenTicket(kot.id),
          icon: const Icon(Icons.undo, size: 16),
          label: const Text('Reopen'),
        ),
      );
    }
    return Row(
      children: <Widget>[
        OutlinedButton.icon(
          onPressed: () => cubit.setRush(kot.id, on: !kot.rush),
          icon: Icon(kot.rush ? Icons.bolt : Icons.bolt_outlined, size: 16),
          label: Text(kot.rush ? 'Rushing' : 'Rush'),
          style: OutlinedButton.styleFrom(
            foregroundColor: kot.rush ? _orange : Colors.white70,
          ),
        ),
        const Spacer(),
        if (anyOpen)
          TextButton(
            onPressed: () => cubit.serveAll(kot.id),
            child: const Text('Serve all'),
          ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: () => _onDone(context, cubit),
          style: FilledButton.styleFrom(
            backgroundColor: allResolved ? _green : Colors.white12,
            foregroundColor: allResolved ? Colors.black : Colors.white,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _onDone(BuildContext context, DemoDataCubit cubit) async {
    final int openCount =
        kot.lines.where((OrderLine l) => l.state == LineState.open).length;
    if (openCount == 0) {
      cubit.markTicketDone(kot.id);
      return;
    }
    final bool? close = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: KBuzzColors.surface,
        title: const Text('Close ticket?'),
        content: Text('$openCount item${openCount == 1 ? '' : 's'} not served '
            'yet. Close it anyway?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Close anyway'),
          ),
        ],
      ),
    );
    if (close ?? false) cubit.markTicketDone(kot.id);
  }

  bool _allResolved() =>
      kot.lines.every((OrderLine l) => l.state != LineState.open);

  // Gate on the same ticket [plateMins] the line tiles use, so the header
  // "all ready" never contradicts a line still "holding for table".
  bool _allReady(int plateMins) {
    if (!clock.started) return false;
    final List<OrderLine> open =
        kot.lines.where((OrderLine l) => l.state == LineState.open).toList();
    if (open.isEmpty) return false;
    return open.every((OrderLine l) {
      final ScheduledDish? d = _schedFor(board, kot.id, l.dishId);
      return d != null &&
          dishLiveStatus(d, clock.elapsedMins,
                  started: true, plateMins: plateMins) ==
              DishLiveStatus.ready;
    });
  }
}

/// One line row, rendered by its waiter state; tap opens the action sheet.
class _LineTile extends StatelessWidget {
  const _LineTile({
    required this.kot,
    required this.line,
    required this.board,
    required this.clock,
    required this.plateMins,
  });

  final Kot kot;
  final OrderLine line;
  final BoardData board;
  final ServiceClockState clock;

  /// The ticket's plate-together time (`max(finishAt)` over its lines), used to
  /// gate this line's ready / under-lamp signal so the table plates together.
  final int plateMins;

  @override
  Widget build(BuildContext context) {
    final Dish? dish = _dishOf(board, line.dishId);
    final String name = dish?.name ?? line.dishId;
    final String emoji = dish?.emoji ?? '🍽️';

    return InkWell(
      onTap: () => _showLineSheet(context, kot, line),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: switch (line.state) {
          LineState.served => _served(name, emoji),
          LineState.voided => _voided(name, emoji),
          LineState.open => _open(context, name, emoji, dish),
        },
      ),
    );
  }

  Widget _served(String name, String emoji) {
    final String recook = line.recook > 0 ? ' · recooked ${line.recook}×' : '';
    return Opacity(
      opacity: 0.55,
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text('$name${line.qty > 1 ? ' ×${line.qty}' : ''} — served$recook',
                style: const TextStyle(color: Colors.white)),
          ),
          const _Tag('served', _green),
        ],
      ),
    );
  }

  Widget _voided(String name, String emoji) {
    return Opacity(
      opacity: 0.45,
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$name — void / 86’d',
              style: const TextStyle(
                color: Colors.white,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          const _Tag('void', Colors.white38),
        ],
      ),
    );
  }

  Widget _open(BuildContext context, String name, String emoji, Dish? dish) {
    final ScheduledDish? d = _schedFor(board, kot.id, line.dishId);
    // Strict coursing: gate "ready" on the whole ticket's plate time, not this
    // line's own cook-finish — a line that finishes early is "held" under the
    // lamp until the table can plate together.
    final DishLiveStatus status = d == null
        ? DishLiveStatus.planned
        : dishLiveStatus(d, clock.elapsedMins,
            started: clock.started, plateMins: plateMins);
    final int cook = line.cookOverrideMins ?? dish?.cookMins ?? 0;
    final int lateMins = d?.lateMins ?? 0;
    final bool underLamp = _underLamp(d);

    final List<Widget> badges = <Widget>[
      if (line.reAt != null)
        line.reason != null
            ? _Tag('RECOOK · ${line.reason}', _red)
            : const _Tag('FIRE NOW', _orange),
      if (status == DishLiveStatus.held) const _Tag('holding for table', _amber),
      if (lateMins > 0) _Tag('+${lateMins}m late', _red),
      if (underLamp) const _Tag('● under lamp', _amber),
    ];

    return Row(
      children: <Widget>[
        Text(emoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      line.qty > 1 ? '$name ×${line.qty}' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (status == DishLiveStatus.cooking) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(Icons.local_fire_department,
                        size: 14, color: _orange),
                  ] else if (status == DishLiveStatus.held) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(Icons.hourglass_bottom, size: 14, color: _amber),
                  ] else if (status == DishLiveStatus.ready) ...<Widget>[
                    const SizedBox(width: 6),
                    const Icon(Icons.check_circle, size: 14, color: _green),
                  ],
                ],
              ),
              if (d != null)
                Text(
                  _timingLabel(d, status),
                  style: TextStyle(
                    color: _timingColor(status),
                    fontSize: 11,
                    fontWeight: status == DishLiveStatus.ready
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              if (badges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Wrap(spacing: 6, runSpacing: 4, children: badges),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text('${cook}m',
            style: kMonoNumberStyle.copyWith(
                color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  bool _underLamp(ScheduledDish? d) {
    if (d == null || !clock.started) return false;
    // Strict coursing: the lamp clock starts only once the whole ticket can
    // plate (elapsed >= plateMins), so lines warn together — not piecemeal.
    final bool ticketReady = clock.elapsedMins >= plateMins;
    return ticketReady && (clock.elapsedMins - plateMins) > kReadyLimitMins;
  }

  /// Live, waiter-facing timing line: a status word plus a countdown
  /// (e.g. "Cooking · 4m left", "Up next · starts 2m", "Ready to serve").
  /// Before the run it shows the planned readiness.
  String _timingLabel(ScheduledDish d, DishLiveStatus status) {
    final double elapsed = clock.elapsedMins;
    int until(num target) {
      final num m = target - elapsed;
      return m <= 0 ? 0 : m.ceil();
    }

    switch (status) {
      case DishLiveStatus.planned:
        return d.finishAt <= 0 ? 'Ready now' : 'Ready in ${d.finishAt}m';
      case DishLiveStatus.waiting:
        final int startsIn = until(d.fireAt);
        return startsIn <= 0 ? 'Starting now' : 'Up next · starts ${startsIn}m';
      case DishLiveStatus.cooking:
        final int left = until(d.finishAt);
        return left <= 0 ? 'Cooking · almost ready' : 'Cooking · ${left}m left';
      case DishLiveStatus.held:
        final int plateIn = until(plateMins);
        return plateIn <= 0 ? 'Held for table' : 'Held · plate in ${plateIn}m';
      case DishLiveStatus.ready:
        return 'Ready to serve';
    }
  }

  /// Status colour for the timing line, so waiters can scan state at a glance.
  Color _timingColor(DishLiveStatus status) => switch (status) {
        DishLiveStatus.ready => _green,
        DishLiveStatus.cooking => _orange,
        DishLiveStatus.held => _amber,
        DishLiveStatus.waiting || DishLiveStatus.planned => Colors.white38,
      };
}

/// The contextual action sheet for a tapped line.
Future<void> _showLineSheet(BuildContext context, Kot kot, OrderLine line) async {
  final String? lineId = line.id;
  if (lineId == null) return; // not yet persisted — no stable target
  final DemoDataCubit cubit = context.read<DemoDataCubit>();
  final int reAt = context.read<ServiceClockCubit>().state.elapsedMins.round();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: KBuzzColors.surface,
    builder: (BuildContext sheet) {
      Widget tile(IconData icon, String label, VoidCallback onTap,
              {Color color = Colors.white}) =>
          ListTile(
            leading: Icon(icon, color: color),
            title: Text(label, style: TextStyle(color: color)),
            onTap: () {
              Navigator.of(sheet).pop();
              onTap();
            },
          );

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            switch (line.state) {
              LineState.voided => tile(
                  Icons.restore, 'Restore', () => cubit.restoreLine(lineId)),
              LineState.served => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    tile(Icons.undo, 'Mark unserved',
                        () => cubit.unserveLine(lineId)),
                    tile(Icons.replay, 'Recook (send back)…',
                        () => _showReasonSheet(context, cubit, lineId, reAt),
                        color: _red),
                  ],
                ),
              LineState.open => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    tile(Icons.check_circle, 'Mark served',
                        () => cubit.serveLine(lineId), color: _green),
                    tile(Icons.replay, 'Recook (send back)…',
                        () => _showReasonSheet(context, cubit, lineId, reAt),
                        color: _red),
                    tile(Icons.local_fire_department,
                        'Fire now — missing / expedite',
                        () => cubit.fireNowLine(lineId, reAtMins: reAt),
                        color: _orange),
                    tile(Icons.block, 'Void / 86',
                        () => cubit.voidLine(lineId), color: Colors.white54),
                  ],
                ),
            },
          ],
        ),
      );
    },
  );
}

/// Recook reason sub-step.
Future<void> _showReasonSheet(
  BuildContext context,
  DemoDataCubit cubit,
  String lineId,
  int reAt,
) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: KBuzzColors.surface,
    builder: (BuildContext sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Send back — reason',
                  style: TextStyle(color: Colors.white54)),
            ),
          ),
          for (final String reason in kRecookReasons)
            ListTile(
              title: Text(reason),
              onTap: () {
                Navigator.of(sheet).pop();
                cubit.recookLine(lineId, reason: reason, reAtMins: reAt);
              },
            ),
        ],
      ),
    ),
  );
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          const Expanded(child: Divider(color: Colors.white12)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(label,
                style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          const Expanded(child: Divider(color: Colors.white12)),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, this.color);

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      AppBadge(text, color, fontSize: 10, horizontal: 7, vertical: 2);
}

Dish? _dishOf(BoardData board, String dishId) {
  for (final Dish d in board.data.menu) {
    if (d.id == dishId) return d;
  }
  return null;
}

/// The scheduled cook for a ticket's open line (matched by ticket + dish).
ScheduledDish? _schedFor(BoardData board, String kotId, String dishId) {
  for (final ScheduledDish d in board.schedule.dishes) {
    if (d.dishId == dishId &&
        d.members.any((ScheduledMember m) => m.kotId == kotId)) {
      return d;
    }
  }
  return null;
}

/// Ticket code: `T5` (dine-in), `TA3` (takeaway), `D21` (delivery).
String _codeOf(Kot k) => ticketCode(k.type, k.table);

String _ageLabel(DateTime orderedAt, DateTime epoch) {
  final int mins = epoch.difference(orderedAt).inMinutes;
  if (mins > 0) return '${mins}m ago';
  if (mins < 0) return '+${-mins}m';
  return 'now';
}
