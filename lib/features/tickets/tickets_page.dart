import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/app/theme.dart';
import 'package:kbuzz/core/format.dart';
import 'package:kbuzz/core/widgets/app_badge.dart';
import 'package:kbuzz/core/widgets/note_line.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/board/board_widgets.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fired_cooks_cubit.dart';
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

// Expo status palette now resolves through [KdsColors.of(context)] so the app
// can swap neon/pastel themes at runtime; the matching fields are:
//   expoReady (green), expoHeld (amber), expoLate (red), brand (orange/firing).

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
      body: NestedScrollView(
        floatHeaderSlivers: true,
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) =>
            <Widget>[
              SliverAppBar(
                title: const Text('Tickets'),
                floating: true,
                snap: true,
                forceElevated: innerBoxIsScrolled,
              ),
            ],
        body: BlocBuilder<DemoDataCubit, DemoDataState>(
          builder: (BuildContext context, DemoDataState state) {
            if (state.data == null || state.generatedAt == null) {
              return const BoardEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'Tickets',
              );
            }
            final BoardData board = BoardData.from(
              state.data!,
              now: state.generatedAt!,
              fireImmediately: context
                  .watch<SettingsCubit>()
                  .state
                  .fireImmediately,
              // Optional: present app-wide (DI), absent in lean widget tests →
              // empty pins (no pinning, identical schedule).
              pinnedFireMins:
                  context.watch<FiredCooksCubit?>()?.state.pinnedFireMins ??
                      const <String, int>{},
            );
            // Rebuild on each tick so cooking status / under-lamp stay live.
            return BlocBuilder<ServiceClockCubit, ServiceClockState>(
              builder: (BuildContext context, ServiceClockState clock) =>
                  _TicketList(board: board, clock: clock),
            );
          },
        ),
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
      final int byTarget = board
          .statusOf(a)
          .targetMins
          .compareTo(board.statusOf(b).targetMins);
      if (byTarget != 0) return byTarget;
      return a.id.compareTo(b.id);
    });

    return ListView(
      padding: const EdgeInsets.all(kSpaceLg),
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
  const _TicketCard({
    required this.kot,
    required this.board,
    required this.clock,
  });

  final Kot kot;
  final BoardData board;
  final ServiceClockState clock;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    final TicketStatus status = board.statusOf(kot);
    final bool done = kot.status == TicketState.done;
    final bool allReady = _allReady(status.plateMins);
    final bool late = status.lateMins > 0;
    final bool anyOpen = kot.lines.any(
      (OrderLine l) => l.state == LineState.open,
    );

    final Color border = done
        ? c.hairlineStrong
        : kot.rush
        ? c.brand
        : allReady
        ? c.expoReady
        : late
        ? c.expoLate
        : c.hairline;

    return TicketStripeCard(
      // Ticket-colour stripe matching this order's bars on the Stations rail.
      ticketColor: ticketColor(kot.id),
      margin: const EdgeInsets.only(bottom: kSpaceMd),
      padding: const EdgeInsets.all(kSpaceLg),
      border: Border.all(color: border, width: 1.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TicketHeader(
            kot: kot,
            now: board.now,
            done: done,
            allReady: allReady,
          ),
          const SizedBox(height: kSpaceSm),
          Text(
            done
                ? 'plates ${atMin(status.plateMins)} · target ${atMin(status.targetMins)}'
                : '${kot.type == KotType.delivery ? "Rider" : "Plate together"} · '
                      'plate ${atMin(status.plateMins)} · target ${atMin(status.targetMins)}',
            style: kMonoNumberStyle.copyWith(
              color: c.textMuted,
              fontSize: kFontSm,
            ),
          ),
          Divider(height: 18, color: c.hairline),
          for (final OrderLine line in kot.lines)
            _LineTile(
              kot: kot,
              line: line,
              board: board,
              clock: clock,
              plateMins: status.plateMins,
            ),
          const SizedBox(height: kSpaceSm),
          _TicketFooter(
            kot: kot,
            done: done,
            anyOpen: anyOpen,
            allResolved: _allResolved(),
          ),
        ],
      ),
    );
  }

  bool _allResolved() =>
      kot.lines.every((OrderLine l) => l.state != LineState.open);

  // Gate on the same ticket [plateMins] the line tiles use, so the header
  // "all ready" never contradicts a line still "holding for table".
  bool _allReady(int plateMins) {
    if (!clock.started) return false;
    final List<OrderLine> open = kot.lines
        .where((OrderLine l) => l.state == LineState.open)
        .toList();
    if (open.isEmpty) return false;
    return open.every((OrderLine l) {
      final ScheduledDish? d = _schedFor(board, kot.id, l.dishId);
      return d != null &&
          dishLiveStatus(
                d,
                clock.elapsedMins,
                started: true,
                plateMins: plateMins,
              ) ==
              DishLiveStatus.ready;
    });
  }
}

/// The ticket card's top row: code + type, a RUSH/DONE/all-ready tag, and the
/// ticket's age. Pure presentation — the derived booleans come from [_TicketCard].
class _TicketHeader extends StatelessWidget {
  const _TicketHeader({
    required this.kot,
    required this.now,
    required this.done,
    required this.allReady,
  });

  final Kot kot;
  final DateTime now;
  final bool done;
  final bool allReady;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Row(
      children: <Widget>[
        Text(
          _codeOf(kot),
          style: const TextStyle(
            fontSize: kFontLg,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: kSpaceSm),
        Text(
          kot.type.label,
          style: TextStyle(color: c.textMuted, fontSize: kFontSm),
        ),
        if (kot.rush) ...<Widget>[
          const SizedBox(width: kSpaceSm),
          _Tag('RUSH', c.brand),
        ],
        const Spacer(),
        if (done)
          _Tag('DONE', c.textFaint)
        else if (allReady)
          _Tag('all ready', c.expoReady),
        const SizedBox(width: kSpaceSm),
        Text(
          _ageLabel(kot.orderedAt, now),
          style: kMonoNumberStyle.copyWith(
            color: c.textFaint,
            fontSize: kFontXs,
          ),
        ),
      ],
    );
  }
}

/// The ticket card's action row: Rush toggle + Serve-all + Done (with an
/// unserved-items confirm), or a Reopen button once the ticket is done.
class _TicketFooter extends StatelessWidget {
  const _TicketFooter({
    required this.kot,
    required this.done,
    required this.anyOpen,
    required this.allResolved,
  });

  final Kot kot;
  final bool done;
  final bool anyOpen;
  final bool allResolved;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
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
            foregroundColor: kot.rush ? c.brand : c.textSecondary,
          ),
        ),
        const Spacer(),
        if (anyOpen)
          TextButton(
            onPressed: () => cubit.serveAll(kot.id),
            child: const Text('Serve all'),
          ),
        const SizedBox(width: kSpaceXs),
        FilledButton(
          onPressed: () => _onDone(context, cubit),
          style: FilledButton.styleFrom(
            backgroundColor: allResolved ? c.expoReady : c.hairline,
            // Foregrounds sit on the filled button; keep white/black so the
            // label stays legible on the bright/grey fill in both themes.
            foregroundColor: allResolved ? Colors.black : Colors.white,
          ),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Future<void> _onDone(BuildContext context, DemoDataCubit cubit) async {
    final int openCount = kot.lines
        .where((OrderLine l) => l.state == LineState.open)
        .length;
    if (openCount == 0) {
      cubit.markTicketDone(kot.id);
      return;
    }
    final KdsColors c = KdsColors.of(context);
    final bool? close = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: c.surface,
        title: const Text('Close ticket?'),
        content: Text(
          '$openCount item${openCount == 1 ? '' : 's'} not served '
          'yet. Close it anyway?',
        ),
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
    if (!context.mounted) return;
    if (close ?? false) cubit.markTicketDone(kot.id);
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
    final KdsColors c = KdsColors.of(context);
    final Dish? dish = _dishOf(board, line.dishId);
    final String name = dish?.name ?? line.dishId;
    final String emoji = dish?.emoji ?? '🍽️';

    return InkWell(
      onTap: () => _showLineSheet(context, kot, line),
      borderRadius: BorderRadius.circular(kRadiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
        child: switch (line.state) {
          LineState.served => _served(c, name, emoji),
          LineState.voided => _voided(c, name, emoji),
          LineState.open => _open(context, name, emoji, dish),
        },
      ),
    );
  }

  Widget _served(KdsColors c, String name, String emoji) {
    final String recook = line.recook > 0 ? ' · recooked ${line.recook}×' : '';
    return Opacity(
      opacity: 0.55,
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: kFontLg)),
          const SizedBox(width: kSpaceSm),
          Expanded(
            child: Text(
              '$name${line.qty > 1 ? ' ×${line.qty}' : ''} — served$recook',
              style: TextStyle(color: c.textPrimary),
            ),
          ),
          _Tag('served', c.expoReady),
        ],
      ),
    );
  }

  Widget _voided(KdsColors c, String name, String emoji) {
    return Opacity(
      opacity: 0.45,
      child: Row(
        children: <Widget>[
          Text(emoji, style: const TextStyle(fontSize: kFontLg)),
          const SizedBox(width: kSpaceSm),
          Expanded(
            child: Text(
              '$name — void / 86’d',
              style: TextStyle(
                color: c.textPrimary,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          ),
          _Tag('void', c.textFaint),
        ],
      ),
    );
  }

  Widget _open(BuildContext context, String name, String emoji, Dish? dish) {
    final KdsColors c = KdsColors.of(context);
    final ScheduledDish? d = _schedFor(board, kot.id, line.dishId);
    // Strict coursing: gate "ready" on the whole ticket's plate time, not this
    // line's own cook-finish — a line that finishes early is "held" under the
    // lamp until the table can plate together.
    final DishLiveStatus status = d == null
        ? DishLiveStatus.planned
        : dishLiveStatus(
            d,
            clock.elapsedMins,
            started: clock.started,
            plateMins: plateMins,
          );
    final int cook = line.cookOverrideMins ?? dish?.cookMins ?? 0;
    final int lateMins = d?.lateMins ?? 0;
    final bool underLamp = _underLamp(d);

    final List<Widget> badges = <Widget>[
      if (line.reAt != null)
        line.reason != null
            ? _Tag('RECOOK · ${line.reason}', c.expoLate)
            : _Tag('FIRE NOW', c.brand),
      if (status == DishLiveStatus.held) _Tag('holding for table', c.expoHeld),
      if (lateMins > 0) _Tag('+${lateMins}m late', c.expoLate),
      if (underLamp) _Tag('● under lamp', c.expoHeld),
    ];

    return Row(
      children: <Widget>[
        Text(emoji, style: const TextStyle(fontSize: kFontLg)),
        const SizedBox(width: kSpaceSm),
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
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (status == DishLiveStatus.cooking) ...<Widget>[
                    const SizedBox(width: kSpaceSm),
                    Icon(Icons.local_fire_department, size: 14, color: c.brand),
                  ] else if (status == DishLiveStatus.held) ...<Widget>[
                    const SizedBox(width: kSpaceSm),
                    Icon(Icons.hourglass_bottom, size: 14, color: c.expoHeld),
                  ] else if (status == DishLiveStatus.ready) ...<Widget>[
                    const SizedBox(width: kSpaceSm),
                    Icon(Icons.check_circle, size: 14, color: c.expoReady),
                  ],
                ],
              ),
              if ((line.note ?? '').trim().isNotEmpty)
                NoteLine(line.note!.trim()),
              if (d != null)
                Text(
                  _timingLabel(d, status),
                  style: TextStyle(
                    color: _timingColor(c, status),
                    fontSize: kFontXs,
                    fontWeight: status == DishLiveStatus.ready
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              if (badges.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: kSpaceXs),
                  child: Wrap(spacing: 6, runSpacing: 4, children: badges),
                ),
            ],
          ),
        ),
        const SizedBox(width: kSpaceSm),
        Text(
          '${cook}m',
          style: kMonoNumberStyle.copyWith(
            color: c.textMuted,
            fontSize: kFontSm,
          ),
        ),
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
  Color _timingColor(KdsColors c, DishLiveStatus status) => switch (status) {
    DishLiveStatus.ready => c.expoReady,
    DishLiveStatus.cooking => c.brand,
    DishLiveStatus.held => c.expoHeld,
    DishLiveStatus.waiting || DishLiveStatus.planned => c.textFaint,
  };
}

/// The contextual action sheet for a tapped line.
Future<void> _showLineSheet(
  BuildContext context,
  Kot kot,
  OrderLine line,
) async {
  final String? lineId = line.id;
  if (lineId == null) return; // not yet persisted — no stable target
  final KdsColors c = KdsColors.of(context);
  final DemoDataCubit cubit = context.read<DemoDataCubit>();

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    builder: (BuildContext sheet) {
      Widget tile(
        IconData icon,
        String label,
        VoidCallback onTap, {
        Color? color,
      }) {
        final Color fg = color ?? c.textPrimary;
        return ListTile(
          leading: Icon(icon, color: fg),
          title: Text(label, style: TextStyle(color: fg)),
          onTap: () {
            Navigator.of(sheet).pop();
            onTap();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            switch (line.state) {
              LineState.voided => tile(
                Icons.restore,
                'Restore',
                () => cubit.restoreLine(lineId),
              ),
              LineState.served => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  tile(
                    Icons.undo,
                    'Mark unserved',
                    () => cubit.unserveLine(lineId),
                  ),
                  tile(
                    Icons.replay,
                    'Recook (send back)…',
                    () => _showReasonSheet(context, cubit, lineId),
                    color: c.expoLate,
                  ),
                ],
              ),
              LineState.open => Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  tile(
                    Icons.check_circle,
                    'Mark served',
                    () => cubit.serveLine(lineId),
                    color: c.expoReady,
                  ),
                  tile(
                    Icons.replay,
                    'Recook (send back)…',
                    () => _showReasonSheet(context, cubit, lineId),
                    color: c.expoLate,
                  ),
                  tile(
                    Icons.local_fire_department,
                    'Fire now — missing / expedite',
                    () =>
                        cubit.fireNowLine(lineId, reAtMins: _reAtNow(context)),
                    color: c.brand,
                  ),
                  tile(
                    (line.note ?? '').trim().isEmpty
                        ? Icons.sticky_note_2_outlined
                        : Icons.edit_note,
                    (line.note ?? '').trim().isEmpty ? 'Add note' : 'Edit note',
                    () => _showNoteDialog(context, cubit, line),
                    color: c.expoHeld,
                  ),
                  tile(
                    Icons.block,
                    'Void / 86',
                    () => cubit.voidLine(lineId),
                    color: c.textMuted,
                  ),
                ],
              ),
            },
          ],
        ),
      );
    },
  );
}

/// The board-relative minute a re-fire (fire-now / recook) should land on:
/// **floor** of the live elapsed so the cook's `fireAt` is never placed past the
/// current minute (which would defer the fire by up to a minute). Read at the
/// moment the action is invoked — not when the sheet opens — so it stays accurate
/// even under fast-forward and after navigating a reason sub-sheet.
int _reAtNow(BuildContext context) =>
    context.read<ServiceClockCubit>().state.elapsedMins.floor();

/// Recook reason sub-step.
Future<void> _showReasonSheet(
  BuildContext context,
  DemoDataCubit cubit,
  String lineId,
) async {
  final KdsColors c = KdsColors.of(context);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.surface,
    builder: (BuildContext sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              kSpaceLg,
              kSpaceLg,
              kSpaceLg,
              kSpaceSm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Send back — reason',
                style: TextStyle(color: c.textMuted),
              ),
            ),
          ),
          for (final String reason in kRecookReasons)
            ListTile(
              title: Text(reason),
              onTap: () {
                Navigator.of(sheet).pop();
                cubit.recookLine(
                  lineId,
                  reason: reason,
                  reAtMins: _reAtNow(context),
                );
              },
            ),
        ],
      ),
    ),
  );
}

/// Add / edit / clear a line's special instruction (e.g. "no salt"). Returns
/// after writing through [DemoDataCubit.setLineNote] (or no-op on cancel).
Future<void> _showNoteDialog(
  BuildContext context,
  DemoDataCubit cubit,
  OrderLine line,
) async {
  final String? lineId = line.id;
  if (lineId == null) return; // not yet persisted — no stable target
  // The dialog returns null on cancel; '' to clear; or the new text. The
  // controller lives inside [_NoteDialog] so it's disposed with the dialog's
  // own lifecycle (disposing it here would crash mid-dismiss-animation).
  final String? result = await showDialog<String>(
    context: context,
    builder: (BuildContext _) => _NoteDialog(initial: line.note ?? ''),
  );
  if (result == null) return; // cancelled — leave the note unchanged
  cubit.setLineNote(lineId, result); // empty string clears it
}

/// Text-entry dialog for a line's special instruction. Owns its
/// [TextEditingController] so it's disposed when the dialog route is removed.
class _NoteDialog extends StatefulWidget {
  const _NoteDialog({required this.initial});

  final String initial;

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return AlertDialog(
      backgroundColor: c.surface,
      title: const Text('Special instruction'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 80,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'e.g. no salt, extra spicy, allergy: nuts',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (String v) => Navigator.of(context).pop(v),
      ),
      actions: <Widget>[
        if (widget.initial.trim().isNotEmpty)
          TextButton(
            onPressed: () => Navigator.of(context).pop(''), // clear
            child: Text('Clear', style: TextStyle(color: c.expoLate)),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // cancel
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final KdsColors c = KdsColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: kSpaceSm),
      child: Row(
        children: <Widget>[
          Expanded(child: Divider(color: c.hairline)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpaceMd),
            child: Text(
              label,
              style: TextStyle(
                color: c.textFaint,
                fontSize: kFontSm,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Divider(color: c.hairline)),
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
      AppBadge(text, color, fontSize: kFontXs, horizontal: 7, vertical: 2);
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
