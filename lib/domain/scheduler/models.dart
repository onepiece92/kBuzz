import 'package:equatable/equatable.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';

/// Default tightened SLA window for a rushed ticket (TICKETS.md `RUSH_SLA`).
const int kDefaultRushMins = 7;

/// SLA windows (minutes from order to plate) per ticket type. Config data, not
/// hardcoded constants — a restaurant can edit these (AGENTS.md §4).
class SlaConfig extends Equatable {
  const SlaConfig({required this.minsByType, this.rushMins = kDefaultRushMins});

  /// The prototype's defaults: dine-in 14, takeaway 11, delivery 9; rush 7.
  const SlaConfig.standard()
      : minsByType = const <KotType, int>{
          KotType.dineIn: 14,
          KotType.takeaway: 11,
          KotType.delivery: 9,
        },
        rushMins = kDefaultRushMins;

  final Map<KotType, int> minsByType;

  /// SLA applied to a rushed ticket — the order plates within this many minutes.
  final int rushMins;

  /// SLA window for [type] (0 if unconfigured).
  int forType(KotType type) => minsByType[type] ?? 0;

  /// Effective SLA for a ticket: tightened to [rushMins] when [rush] is set
  /// (TICKETS.md — rush ⇒ `min(SLA, RUSH_SLA)`).
  int effective(KotType type, {required bool rush}) {
    final int base = forType(type);
    if (!rush) return base;
    return base < rushMins ? base : rushMins;
  }

  @override
  List<Object?> get props => <Object?>[minsByType, rushMins];
}

/// Tunables for the scheduler (no magic numbers in the algorithm — AGENTS.md §12).
class SchedulerConfig extends Equatable {
  const SchedulerConfig({
    this.horizonMins = 120,
    this.batchWindowMins = 2,
    this.justInTime = false,
  });

  /// Hard scheduling horizon (`HMAX` in the prototype). Nothing fires at/after it.
  final int horizonMins;

  /// Batchable dishes whose targets fall within this window cook together
  /// (`BATCH_WIN` in the prototype).
  final int batchWindowMins;

  /// **Just-in-time firing** — a deliberate refinement over the prototype. After
  /// placement, a ticket's non-bottleneck dishes are delayed so they *finish* at
  /// the ticket's realized plate time (`max(finishAt)`) instead of cooking early
  /// and waiting under the lamp — so a table's dishes plate together. Re-fires
  /// (recook / fire-now) and batched cooks are exempt, nothing is fired before
  /// now, and no dish is pushed past its plate (so the plate never moves). Off by
  /// default to preserve the pure prototype placement (and its golden test); the
  /// app enables it via [BoardData].
  final bool justInTime;

  @override
  List<Object?> get props =>
      <Object?>[horizonMins, batchWindowMins, justInTime];
}

/// Default kitchen-minutes a fully-ready ticket is retained on a board before it
/// becomes "served" (moves to the bottom / drops off fire-next). Tunable via
/// [BoardConfig].
const int kDefaultRetainMins = 3;

/// Presentation/run-time board tunables — distinct from the pure-scheduler
/// [SchedulerConfig]. [retainMins] is **not** a scheduler input (it doesn't
/// affect fire/finish times), so it lives here rather than polluting the
/// algorithm's surface. No magic numbers in the board logic (AGENTS.md §12).
class BoardConfig extends Equatable {
  const BoardConfig({this.retainMins = kDefaultRetainMins});

  /// Kitchen-minutes a fully-ready ticket is retained before being served.
  final int retainMins;

  @override
  List<Object?> get props => <Object?>[retainMins];
}

/// A ticket's claim on a (possibly batched) scheduled dish.
class ScheduledMember extends Equatable {
  const ScheduledMember({
    required this.kotId,
    required this.table,
    required this.type,
    required this.qty,
    this.note,
  });

  final String kotId;
  final String table;
  final KotType type;
  final int qty;

  /// This ticket-line's special instruction (e.g. "less salt"), carried through
  /// from [OrderLine.note] so the Stations board and fire alert can surface it.
  /// Null/empty when there's nothing special.
  final String? note;

  @override
  List<Object?> get props => <Object?>[kotId, table, type, qty, note];
}

/// Why a cook jumped the queue (TICKETS.md), surfaced to the kitchen views as a
/// badge: a recook (sent back, carries a reason), an expedite/fire-missing, or a
/// rushed ticket. [none] is an ordinary cook.
enum PriorityKind { none, rush, fireNow, recook }

/// The scheduler's output for one cook: when to fire it, when it finishes, and
/// how it relates to its target (held early vs plated late). Immutable.
class ScheduledDish extends Equatable {
  const ScheduledDish({
    required this.uid,
    required this.stationId,
    required this.dishId,
    required this.name,
    required this.emoji,
    required this.cookMins,
    required this.holdable,
    required this.batchable,
    required this.members,
    required this.qty,
    required this.targetMins,
    required this.fireAt,
    required this.finishAt,
    required this.holdMins,
    required this.lateMins,
    required this.lane,
    this.priority = PriorityKind.none,
    this.recookReason,
  });

  /// Stable index within the schedule's `dishes` list (used for UI selection).
  final int uid;
  final String stationId;
  final String dishId;
  final String name;
  final String emoji;
  final int cookMins;
  final bool holdable;
  final bool batchable;

  /// The tickets this cook serves (more than one ⇒ batched).
  final List<ScheduledMember> members;

  /// Total quantity across [members].
  final int qty;

  /// Target plate time (minutes from now): tightest member's `orderedAt + sla`.
  final int targetMins;

  /// Minute (from now) to fire; never before 0.
  final int fireAt;

  /// `fireAt + cookMins`.
  final int finishAt;

  /// Minutes the food waits off-heat after finishing early (`> 0` ⇒ held).
  final int holdMins;

  /// Minutes past target (`> 0` ⇒ plates late).
  final int lateMins;

  /// Lane index within its station's rail (0-based; `< station.capacity`).
  final int lane;

  /// Why this cook jumped the queue (re-fire / rush) — drives the kitchen badge.
  final PriorityKind priority;

  /// The recook reason when [priority] is [PriorityKind.recook].
  final String? recookReason;

  /// Whether this cook serves more than one ticket.
  bool get isBatched => members.length > 1;

  @override
  List<Object?> get props => <Object?>[
        uid,
        stationId,
        dishId,
        name,
        emoji,
        cookMins,
        holdable,
        batchable,
        members,
        qty,
        targetMins,
        fireAt,
        finishAt,
        holdMins,
        lateMins,
        lane,
        priority,
        recookReason,
      ];
}

/// One station's dishes plus how many concurrent lanes they pack into (for the
/// rail view). `lanes <= station.capacity`.
class StationLane extends Equatable {
  const StationLane({required this.dishes, required this.lanes});

  final List<ScheduledDish> dishes;
  final int lanes;

  @override
  List<Object?> get props => <Object?>[dishes, lanes];
}

/// The station whose contention induces the most lateness — the feature's
/// punchline ("steamer can't keep up → add a second").
class Bottleneck extends Equatable {
  const Bottleneck({required this.stationId, required this.lateMins});

  final String stationId;
  final int lateMins;

  @override
  List<Object?> get props => <Object?>[stationId, lateMins];
}

/// The complete schedule for a set of tickets.
class Schedule extends Equatable {
  const Schedule({
    required this.dishes,
    required this.byStation,
    required this.horizonMins,
    this.bottleneck,
  });

  /// All cooks, in fire-priority order (sorted by ideal, then target, then cook).
  final List<ScheduledDish> dishes;

  /// Per-station lane-packed view, keyed by station id.
  final Map<String, StationLane> byStation;

  /// `max(finishAt)` across all dishes (at least 1).
  final int horizonMins;

  /// The worst station, if any dish runs late.
  final Bottleneck? bottleneck;

  @override
  List<Object?> get props =>
      <Object?>[dishes, byStation, horizonMins, bottleneck];
}

/// Per-ticket roll-up: which dishes belong to a ticket and when it plates.
class TicketStatus extends Equatable {
  const TicketStatus({
    required this.dishes,
    required this.targetMins,
    required this.plateMins,
    required this.lateMins,
  });

  final List<ScheduledDish> dishes;
  final int targetMins;

  /// When the whole ticket can plate: `max(finishAt)` of its dishes.
  final int plateMins;
  final int lateMins;

  @override
  List<Object?> get props =>
      <Object?>[dishes, targetMins, plateMins, lateMins];
}
