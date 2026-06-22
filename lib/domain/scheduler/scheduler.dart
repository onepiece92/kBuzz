import 'dart:math';

import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';

/// The kBuzz scheduler — a **pure, deterministic** port of `MultiKOT.jsx`'s
/// `schedule()` (AGENTS.md §10).
///
/// No Flutter/Firebase/Drift imports, no `DateTime.now()` inside — the caller
/// passes [now]. Given the same inputs it always returns the identical
/// [Schedule] (ties are broken by stable order), so it can be exhaustively
/// unit-tested. It is the product's IP; protect its test coverage.
///
/// Algorithm:
/// 1. target  = orderedAt(rel) + sla[type]   (per ticket)
/// 2. ideal   = target − cook                (back-schedule each dish)
/// 3. batch   identical batchable dishes whose targets fall within the window
/// 4. sort    by ideal, then target, then longer cook first
/// 5. place   each on its station respecting capacity (minute buckets):
///      fits at ideal              → on time
///      busy + holdable            → fire earlier, HOLD the food
///      busy + not holdable        → fire later, plate LATE
/// 6. lane-pack each station for the rail; surface the bottleneck.
Schedule schedule({
  required List<Kot> kots,
  required Map<String, Dish> menu,
  required Map<String, Station> stations,
  required DateTime now,
  SlaConfig sla = const SlaConfig.standard(),
  SchedulerConfig config = const SchedulerConfig(),
}) {
  final int hmax = config.horizonMins;
  final int batchWin = config.batchWindowMins;
  const int floor = 0; // "now" in the relative-minute frame; never fire before it.

  // 1. expand each ticket line into a raw cook, single-member. Served/void lines
  //    carry no kitchen work (skipped); a re-fired (`reAt`) line or a rushed
  //    ticket becomes a priority cook that fires now and never batches
  //    (TICKETS.md scheduler contract).
  final List<_Raw> raw = <_Raw>[];
  for (final Kot k in kots) {
    final int orderedAtMins = _relMins(k.orderedAt, now);
    final int baseTarget = orderedAtMins + sla.effective(k.type, rush: k.rush);
    for (final OrderLine line in k.lines) {
      if (line.state != LineState.open) continue; // served / void → no work
      final Dish? dish = menu[line.dishId];
      if (dish == null) continue; // unknown dish → skip, don't crash
      final int cook = line.cookOverrideMins ?? dish.cookMins;
      // Recook (reAt + reason) > fire-now (reAt) > rush; surfaced to the kitchen.
      final PriorityKind kind = (line.reAt != null && line.reason != null)
          ? PriorityKind.recook
          : line.reAt != null
              ? PriorityKind.fireNow
              : k.rush
                  ? PriorityKind.rush
                  : PriorityKind.none;
      final bool priority = kind != PriorityKind.none;
      // A re-fired line fires now: target = reAt + cook (so ideal == reAt).
      final int target = line.reAt != null ? line.reAt! + cook : baseTarget;
      raw.add(
        _Raw(
          key: '${dish.stationId}|${dish.id}',
          dish: dish,
          cook: cook,
          target: target,
          priority: priority,
          priorityKind: kind,
          recookReason: kind == PriorityKind.recook ? line.reason : null,
          member: ScheduledMember(
            kotId: k.id,
            table: k.table,
            type: k.type,
            qty: line.qty,
          ),
        ),
      );
    }
  }

  // 2. batch: merge same (station, dish) cooks whose targets fall within the
  //    window, but only when the dish is batchable.
  final Map<String, List<_Working>> open = <String, List<_Working>>{};
  final List<_Working> dishes = <_Working>[];
  int seq = 0;
  for (final _Raw r in raw) {
    final bool batchable = r.dish.batchable && !r.priority; // priority never batches
    if (batchable) {
      _Working? group;
      final List<_Working>? bucket = open[r.key];
      if (bucket != null) {
        for (final _Working b in bucket) {
          if ((b.target - r.target).abs() <= batchWin) {
            group = b;
            break;
          }
        }
      }
      if (group != null) {
        group.members.add(r.member);
        group.qty += r.member.qty;
        group.target = min(group.target, r.target);
        continue;
      }
    }
    final _Working d = _Working(
      seq: seq++,
      dish: r.dish,
      cook: r.cook,
      target: r.target,
      priority: r.priority,
      priorityKind: r.priorityKind,
      recookReason: r.recookReason,
      members: <ScheduledMember>[r.member],
      qty: r.member.qty,
    );
    dishes.add(d);
    if (batchable) {
      (open[r.key] ??= <_Working>[]).add(d);
    }
  }

  // 3. ideal fire per dish.
  for (final _Working d in dishes) {
    d.ideal = d.target - d.cook;
  }

  // 4. sort by ideal, then target, then longer cook first; stable by seq so the
  //    output is fully deterministic (Dart's List.sort is not stable).
  dishes.sort((_Working a, _Working b) {
    if (a.priority != b.priority) return a.priority ? -1 : 1; // priority first
    final int byIdeal = a.ideal.compareTo(b.ideal);
    if (byIdeal != 0) return byIdeal;
    final int byTarget = a.target.compareTo(b.target);
    if (byTarget != 0) return byTarget;
    final int byCook = b.cook.compareTo(a.cook); // longer cook first
    if (byCook != 0) return byCook;
    return a.seq.compareTo(b.seq);
  });

  // 5. place under capacity using per-station minute buckets.
  final Map<String, List<int>> occ = <String, List<int>>{};

  bool feasible(String station, int t, int cook) {
    if (t < floor) return false;
    final int cap = stations[station]?.capacity ?? 1;
    final List<int>? bucket = occ[station];
    for (int i = 0; i < cook; i++) {
      final int b = t + i;
      if (b >= hmax) return false;
      final int used = (bucket != null && b < bucket.length) ? bucket[b] : 0;
      if (used >= cap) return false;
    }
    return true;
  }

  void fill(String station, int t, int cook) {
    final List<int> bucket = occ[station] ??= <int>[];
    for (int i = 0; i < cook; i++) {
      final int b = t + i;
      while (bucket.length <= b) {
        bucket.add(0);
      }
      bucket[b] += 1;
    }
  }

  void unfill(String station, int t, int cook) {
    final List<int>? bucket = occ[station];
    if (bucket == null) return;
    for (int i = 0; i < cook; i++) {
      final int b = t + i;
      if (b >= 0 && b < bucket.length && bucket[b] > 0) bucket[b] -= 1;
    }
  }

  for (final _Working d in dishes) {
    final int want = max(floor, d.ideal);
    int? t = feasible(d.stationId, want, d.cook) ? want : null;
    for (int delta = 1; delta < hmax && t == null; delta++) {
      final int earlier = d.ideal - delta;
      final int later = want + delta;
      if (d.holdable && earlier >= floor && feasible(d.stationId, earlier, d.cook)) {
        t = earlier; // hold: fire early into a free slot
      } else if (feasible(d.stationId, later, d.cook)) {
        t = later; // can't hold (or no early slot): fire late
      } else if (!d.holdable &&
          earlier >= floor &&
          feasible(d.stationId, earlier, d.cook)) {
        t = earlier; // last resort for non-holdable
      }
    }
    t ??= want;
    fill(d.stationId, t, d.cook);
    d.fireAt = t;
    d.finishAt = t + d.cook;
    d.holdMins = max(0, d.target - d.finishAt);
    d.lateMins = max(0, d.finishAt - d.target);
  }

  // Capture per-station lateness BEFORE any JIT delay, so the bottleneck reflects
  // the genuine constraint (JIT would otherwise mark a ticket's fast dishes
  // "late" too, once they're delayed to plate with the slow one).
  final Map<String, int> lateByStation = <String, int>{};
  for (final _Working d in dishes) {
    if (d.lateMins > 0) {
      lateByStation[d.stationId] =
          max(lateByStation[d.stationId] ?? 0, d.lateMins);
    }
  }

  // 5b. Just-in-time firing (plate-together). Delay each ticket's non-bottleneck
  //     dishes so they FINISH at the ticket's realized plate time (= max finish
  //     over its cooks) instead of cooking early and waiting under the lamp.
  //     Re-fires (recook / fire-now) and batched cooks are exempt; nothing is
  //     fired before now, and no dish is pushed past its plate, so the plate
  //     itself never moves and the bottleneck dish stays put.
  if (config.justInTime) {
    final Map<String, int> plateByKot = <String, int>{};
    for (final _Working d in dishes) {
      for (final ScheduledMember m in d.members) {
        plateByKot[m.kotId] = max(plateByKot[m.kotId] ?? 0, d.finishAt);
      }
    }
    bool eligible(_Working d) =>
        d.members.length == 1 && // batched cooks serve several tickets
        d.priorityKind != PriorityKind.recook &&
        d.priorityKind != PriorityKind.fireNow && // re-fires stay ASAP
        d.finishAt < plateByKot[d.members.first.kotId]!; // not the bottleneck
    final List<_Working> movable = dishes.where(eligible).toList()
      ..sort((_Working a, _Working b) {
        final int dueA = plateByKot[a.members.first.kotId]!;
        final int dueB = plateByKot[b.members.first.kotId]!;
        if (dueA != dueB) return dueB.compareTo(dueA); // latest plate first
        return a.seq.compareTo(b.seq);
      });
    // Conservatively delay each movable dish to the latest feasible slot that
    // still finishes by its plate. Candidates are checked against the live
    // occupancy *with the dish still in place* (so an accepted slot never needs
    // the dish's own room), then it's moved. If no later slot fits, it stays
    // exactly where placement put it — JIT never fires before now, never pushes a
    // dish past its plate, and never exceeds capacity.
    for (final _Working d in movable) {
      final int latestFire = plateByKot[d.members.first.kotId]! - d.cook;
      int t = -1;
      for (int cand = latestFire; cand > d.fireAt; cand--) {
        if (feasible(d.stationId, cand, d.cook)) {
          t = cand;
          break;
        }
      }
      if (t < 0) continue; // no better slot — leave it at its placement fire
      unfill(d.stationId, d.fireAt, d.cook);
      fill(d.stationId, t, d.cook);
      d.fireAt = t;
      d.finishAt = t + d.cook;
      d.holdMins = max(0, d.target - d.finishAt);
      d.lateMins = max(0, d.finishAt - d.target);
    }
  }

  // 6. assign uid by final (sorted) order.
  for (int i = 0; i < dishes.length; i++) {
    dishes[i].uid = i;
  }

  // 7. lane-pack per station (first lane whose last finish ≤ this fire; else a
  //    new lane). Stable by uid for equal fire times.
  final Map<String, List<_Working>> stationDishes = <String, List<_Working>>{};
  for (final _Working d in dishes) {
    (stationDishes[d.stationId] ??= <_Working>[]).add(d);
  }
  final Map<String, int> lanesByStation = <String, int>{};
  for (final MapEntry<String, List<_Working>> e in stationDishes.entries) {
    final List<_Working> arr = e.value
      ..sort((_Working a, _Working b) {
        final int byFire = a.fireAt.compareTo(b.fireAt);
        if (byFire != 0) return byFire;
        return a.uid.compareTo(b.uid);
      });
    final List<int> ends = <int>[];
    for (final _Working d in arr) {
      int lane = ends.indexWhere((int end) => end <= d.fireAt);
      if (lane == -1) {
        lane = ends.length;
        ends.add(d.finishAt);
      } else {
        ends[lane] = d.finishAt;
      }
      d.lane = lane;
    }
    lanesByStation[e.key] = max(1, ends.length);
  }

  // 8. freeze to immutable outputs.
  final List<ScheduledDish> out =
      dishes.map(_freeze).toList(growable: false);
  final Map<int, ScheduledDish> byUid = <int, ScheduledDish>{
    for (final ScheduledDish d in out) d.uid: d,
  };
  final Map<String, StationLane> byStation = <String, StationLane>{};
  for (final MapEntry<String, List<_Working>> e in stationDishes.entries) {
    byStation[e.key] = StationLane(
      dishes: e.value
          .map((_Working w) => byUid[w.uid]!)
          .toList(growable: false),
      lanes: lanesByStation[e.key]!,
    );
  }

  final int horizon = out.isEmpty
      ? 1
      : max(1, out.map((ScheduledDish d) => d.finishAt).reduce(max));

  // bottleneck = station with the largest induced lateMins (captured pre-JIT
  // above, so JIT-delayed fast dishes don't masquerade as the constraint).
  Bottleneck? bottleneck;
  if (lateByStation.isNotEmpty) {
    final MapEntry<String, int> worst = lateByStation.entries.reduce(
      (MapEntry<String, int> a, MapEntry<String, int> b) =>
          b.value > a.value ? b : a,
    );
    bottleneck = Bottleneck(stationId: worst.key, lateMins: worst.value);
  }

  return Schedule(
    dishes: out,
    byStation: byStation,
    horizonMins: horizon,
    bottleneck: bottleneck,
  );
}

/// Per-ticket roll-up: the dishes belonging to [k] and when it plates
/// (AGENTS.md §10 — `ticketStatus`).
TicketStatus ticketStatusFor(
  Kot k,
  List<ScheduledDish> dishes, {
  required DateTime now,
  SlaConfig sla = const SlaConfig.standard(),
}) {
  final List<ScheduledDish> mine = dishes
      .where((ScheduledDish d) =>
          d.members.any((ScheduledMember m) => m.kotId == k.id))
      .toList(growable: false);
  final int target =
      _relMins(k.orderedAt, now) + sla.effective(k.type, rush: k.rush);
  final int plate = mine.isEmpty
      ? target
      : mine.map((ScheduledDish d) => d.finishAt).reduce(max);
  return TicketStatus(
    dishes: mine,
    targetMins: target,
    plateMins: plate,
    lateMins: max(0, plate - target),
  );
}

/// Minutes of [t] relative to [now], rounded to the nearest whole minute
/// (negative = earlier). Mirrors the prototype's integer `orderMin`.
int _relMins(DateTime t, DateTime now) =>
    (t.difference(now).inSeconds / Duration.secondsPerMinute).round();

ScheduledDish _freeze(_Working d) => ScheduledDish(
      uid: d.uid,
      stationId: d.stationId,
      dishId: d.dish.id,
      name: d.dish.name,
      emoji: d.dish.emoji,
      cookMins: d.cook,
      holdable: d.holdable,
      batchable: d.dish.batchable,
      members: List<ScheduledMember>.unmodifiable(d.members),
      qty: d.qty,
      targetMins: d.target,
      fireAt: d.fireAt,
      finishAt: d.finishAt,
      holdMins: d.holdMins,
      lateMins: d.lateMins,
      lane: d.lane,
      priority: d.priorityKind,
      recookReason: d.recookReason,
    );

/// A single expanded ticket line before batching.
class _Raw {
  _Raw({
    required this.key,
    required this.dish,
    required this.cook,
    required this.target,
    required this.priority,
    required this.priorityKind,
    required this.recookReason,
    required this.member,
  });

  final String key;
  final Dish dish;
  final int cook;
  final int target;
  final bool priority;
  final PriorityKind priorityKind;
  final String? recookReason;
  final ScheduledMember member;
}

/// Mutable working dish used during scheduling, frozen to [ScheduledDish] at the
/// end.
class _Working {
  _Working({
    required this.seq,
    required this.dish,
    required this.cook,
    required this.target,
    required this.priority,
    required this.priorityKind,
    required this.recookReason,
    required this.members,
    required this.qty,
  });

  final int seq;
  final Dish dish;
  final int cook;
  final bool priority;
  final PriorityKind priorityKind;
  final String? recookReason;
  final List<ScheduledMember> members;

  int qty;
  int target;
  int ideal = 0;
  int fireAt = 0;
  int finishAt = 0;
  int holdMins = 0;
  int lateMins = 0;
  int lane = 0;
  int uid = 0;

  String get stationId => dish.stationId;
  bool get holdable => dish.holdable;
}
