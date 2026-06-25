import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// One "fire next" event — a cook whose `fireAt` the live clock just crossed.
class FireAlert extends Equatable {
  const FireAlert({
    required this.stationId,
    required this.stationName,
    required this.dishName,
    required this.qty,
    this.emoji,
    this.notes = const <String>[],
  });

  final String stationId;
  final String stationName;
  final String dishName;
  final int qty;
  final String? emoji;

  /// Special instructions on this cook's lines (e.g. "no salt", "extra spicy"),
  /// deduped across the tickets it serves. Read aloud after the dish.
  final List<String> notes;

  /// The dish part of the announcement, e.g. "Grill — 2 Cheeseburger, note: no
  /// salt". Used standalone ([spokenText]) and inside a batch ([batchSpokenText]).
  String get spokenDish {
    final String base = '$stationName — $qty $dishName';
    return notes.isEmpty ? base : '$base, note: ${notes.join('; ')}';
  }

  /// What the [Announcer] speaks, e.g. "Fire Grill — 2 Cheeseburger, note: no
  /// salt".
  String get spokenText => 'Fire $spokenDish';

  @override
  List<Object?> get props =>
      <Object?>[stationId, stationName, dishName, qty, emoji, notes];
}

/// One spoken line covering a whole batch of fires that crossed on the same
/// tick, so a listening chef never loses a simultaneous multi-station fire (the
/// announcer speaks once per tick and `_tts.stop()` cuts the prior utterance —
/// see [Announcer.announce]). [alerts] arrive in fire-priority order; **every**
/// item is named, joined by commas with a final "and". A single fire reads
/// exactly like its own [FireAlert.spokenText].
String batchSpokenText(List<FireAlert> alerts) {
  if (alerts.isEmpty) return '';
  if (alerts.length == 1) return alerts.single.spokenText;
  final List<String> parts =
      alerts.map((FireAlert a) => a.spokenDish).toList();
  final String last = parts.removeLast();
  return 'Fire ${parts.join(', ')}, and $last';
}

/// State carrying the alerts produced on the latest processed tick. [tick] is a
/// monotonic counter so two identical [latest] batches still emit distinct
/// states (the shell listener keys off [tick]).
class FireAlertState extends Equatable {
  const FireAlertState({this.latest = const <FireAlert>[], this.tick = 0});

  final List<FireAlert> latest;
  final int tick;

  @override
  List<Object?> get props => <Object?>[latest, tick];
}

/// Stable identity for a scheduled cook, so each fires exactly once even as the
/// schedule is recomputed. A reschedule (a served ticket, a station's capacity
/// changed) re-packs lanes and shifts every surviving cook's `fireAt`/`uid`, so
/// keying on those re-fires cooks that already fired. We key instead on station
/// + dish + the **tickets it serves** (`members`) — invariant under re-packing.
///
/// A deliberate re-fire — recook / fire-now ([PriorityKind.recook] /
/// [PriorityKind.fireNow]) — appends its `fireAt`, so each new re-fire of the
/// same line is a distinct key and re-announces.
String fireKey(ScheduledDish d) {
  final List<String> kotIds = <String>[
    for (final ScheduledMember m in d.members) m.kotId,
  ]..sort();
  final String base = '${d.stationId}|${d.dishId}|${kotIds.join(',')}';
  final bool isRefire = d.priority == PriorityKind.recook ||
      d.priority == PriorityKind.fireNow;
  return isRefire ? '$base|refire:${d.fireAt}' : base;
}

/// The cooks worth firing: a cook stays in the fire stream while at least one
/// ticket it serves is still active. A cook whose every ticket is
/// [TicketState.done] is dropped — its food is already plated and gone, so it
/// must not keep buzzing the kitchen. A batched cook can span several tickets,
/// so it survives as long as any of them remains active. (A member-less cook
/// can't happen from the scheduler, but is kept rather than silently dropped.)
List<ScheduledDish> firableDishes(
  List<ScheduledDish> dishes,
  Map<String, Kot> kotsById,
) =>
    dishes
        .where(
          (ScheduledDish d) =>
              d.members.isEmpty ||
              d.members.any(
                (ScheduledMember m) =>
                    kotsById[m.kotId]?.status != TicketState.done,
              ),
        )
        .toList(growable: false);

/// Pure detector (AGENTS.md §10.5): the cooks whose `fireAt` the clock has
/// reached and that haven't been announced yet. **Edge-triggered, once-only** —
/// mutates [alerted] (adds fired keys); clears it when the run isn't started so
/// a reset re-arms every alert.
///
/// Newly-due cooks are summed per (station, dish): several cooks of the same
/// dish firing together read as one line — e.g. three Ribeye cooks (2 + 1 + 1)
/// become "4× Ribeye Steak" rather than three separate alerts.
List<FireAlert> detectFires({
  required List<ScheduledDish> dishes,
  required Map<String, Station> stationsById,
  required double elapsedMins,
  required bool started,
  required Set<String> alerted,
}) {
  if (!started) {
    alerted.clear();
    return const <FireAlert>[];
  }
  // Insertion-ordered so the merged alerts keep fire-priority order (dishes are
  // already in that order).
  final Map<String, FireAlert> byDish = <String, FireAlert>{};
  for (final ScheduledDish d in dishes) {
    if (elapsedMins >= d.fireAt && alerted.add(fireKey(d))) {
      final String key = '${d.stationId}|${d.dishId}';
      final FireAlert? prev = byDish[key];
      // Union this cook's line notes into the alert (deduped, order-preserving).
      final List<String> notes = <String>[...?prev?.notes];
      for (final ScheduledMember m in d.members) {
        final String n = (m.note ?? '').trim();
        if (n.isNotEmpty && !notes.contains(n)) notes.add(n);
      }
      byDish[key] = FireAlert(
        stationId: d.stationId,
        stationName: stationsById[d.stationId]?.name ?? d.stationId,
        dishName: d.name,
        qty: (prev?.qty ?? 0) + d.qty,
        emoji: prev?.emoji ?? d.emoji,
        notes: notes,
      );
    }
  }
  return byDish.values.toList(growable: false);
}

/// Watches the live clock + current schedule and emits [FireAlert]s as cooks
/// cross their `fireAt`. The detection is derived here (the service layer), not
/// in the pure scheduler (§0.3/§10). The app shell listens and presents.
class FireAlertCubit extends Cubit<FireAlertState> {
  FireAlertCubit({
    required DemoDataCubit data,
    required ServiceClockCubit clock,
  }) : super(const FireAlertState()) {
    _applyData(data.state);
    _dataSub = data.stream.listen(_applyData);
    _clockSub = clock.stream.listen(_onClock);
  }

  List<ScheduledDish> _dishes = const <ScheduledDish>[];
  Map<String, Station> _stationsById = const <String, Station>{};
  final Set<String> _alerted = <String>{};

  StreamSubscription<DemoDataState>? _dataSub;
  StreamSubscription<ServiceClockState>? _clockSub;

  void _applyData(DemoDataState state) {
    if (isClosed) return;
    final DemoData? data = state.data;
    final DateTime? now = state.generatedAt;
    if (data == null || now == null) {
      _dishes = const <ScheduledDish>[];
      _stationsById = const <String, Station>{};
      return;
    }
    final BoardData board = BoardData.from(data, now: now);
    // Don't buzz the kitchen for a closed ticket (see [firableDishes]).
    _dishes = firableDishes(board.schedule.dishes, board.kotsById);
    _stationsById = board.stationsById;
  }

  void _onClock(ServiceClockState clock) {
    if (isClosed) return;
    final List<FireAlert> fired = detectFires(
      dishes: _dishes,
      stationsById: _stationsById,
      elapsedMins: clock.elapsedMins,
      started: clock.started,
      alerted: _alerted,
    );
    if (fired.isNotEmpty) {
      emit(FireAlertState(latest: fired, tick: state.tick + 1));
    }
  }

  @override
  Future<void> close() {
    _dataSub?.cancel();
    _clockSub?.cancel();
    return super.close();
  }
}
