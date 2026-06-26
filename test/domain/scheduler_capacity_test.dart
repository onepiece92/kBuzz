import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart';

/// Golden + invariant tests for **changing a station's capacity** (the only
/// station knob the user can adjust — `setStationCapacity`, the +/- stepper).
///
/// Three identical, non-holdable, non-batchable cooks contend ONE station, so
/// capacity directly controls how many run at once. The scheduler is a pure,
/// stateless function, so "reduce 3→1" gives exactly the same result as
/// scheduling fresh at 1 — these goldens pin that behaviour both ways.
void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  // cook 8, NOT holdable (so under-capacity ⇒ fire late / serialize, the clear
  // case) and NOT batchable (so the three orders stay three separate cooks).
  const Dish steak = Dish(
    id: 'steak',
    name: 'Steak',
    emoji: '🥩',
    stationId: 'grill',
    cookMins: 8,
    holdable: false,
    batchable: false,
  );
  final Map<String, Dish> menu = <String, Dish>{'steak': steak};

  Map<String, Station> stationsAt(int cap) => <String, Station>{
        'grill':
            Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: cap),
      };

  // Three dineIn tickets, each one steak, all ordered at the same instant.
  final List<Kot> kots = <Kot>[
    for (int i = 1; i <= 3; i++)
      Kot(
        id: 'k$i',
        table: '$i',
        type: KotType.dineIn,
        orderedAt: now,
        lines: <OrderLine>[const OrderLine(dishId: 'steak', qty: 1)],
      ),
  ];

  Schedule runAt(int cap) =>
      schedule(kots: kots, menu: menu, stations: stationsAt(cap), now: now);

  /// Dishes sorted by fire time (ties by finish) for stable golden comparison.
  List<ScheduledDish> sorted(Schedule s) => s.dishes.toList()
    ..sort((ScheduledDish a, ScheduledDish b) {
      final int byFire = a.fireAt.compareTo(b.fireAt);
      return byFire != 0 ? byFire : a.finishAt.compareTo(b.finishAt);
    });

  /// Peak concurrent cooks at any single minute on [stationId].
  int peakConcurrency(Schedule s, String stationId) {
    final Map<int, int> perMinute = <int, int>{};
    for (final ScheduledDish d in s.dishes) {
      if (d.stationId != stationId) continue;
      for (int m = d.fireAt; m < d.finishAt; m++) {
        perMinute[m] = (perMinute[m] ?? 0) + 1;
      }
    }
    return perMinute.values.isEmpty
        ? 0
        : perMinute.values.reduce((int a, int b) => a > b ? a : b);
  }

  group('capacity change: golden schedules (dineIn target = 14)', () {
    test('capacity 1 → fully serialized (each cook waits for the last)', () {
      final List<ScheduledDish> d = sorted(runAt(1));
      expect(d.map((ScheduledDish x) => x.fireAt), <int>[6, 14, 22]);
      expect(d.map((ScheduledDish x) => x.finishAt), <int>[14, 22, 30]);
      expect(d.map((ScheduledDish x) => x.lateMins), <int>[0, 8, 16]);
      expect(runAt(1).byStation['grill']?.lanes, 1);
      expect(runAt(1).bottleneck?.lateMins, 16);
    });

    test('capacity 2 → two parallel, third waits', () {
      final List<ScheduledDish> d = sorted(runAt(2));
      expect(d.map((ScheduledDish x) => x.fireAt), <int>[6, 6, 14]);
      expect(d.map((ScheduledDish x) => x.finishAt), <int>[14, 14, 22]);
      expect(d.map((ScheduledDish x) => x.lateMins), <int>[0, 0, 8]);
      expect(runAt(2).byStation['grill']?.lanes, 2);
      expect(runAt(2).bottleneck?.lateMins, 8);
    });

    test('capacity 3 → all parallel, all on time, no bottleneck', () {
      final List<ScheduledDish> d = sorted(runAt(3));
      expect(d.map((ScheduledDish x) => x.fireAt), <int>[6, 6, 6]);
      expect(d.map((ScheduledDish x) => x.finishAt), <int>[14, 14, 14]);
      expect(d.map((ScheduledDish x) => x.lateMins), <int>[0, 0, 0]);
      expect(runAt(3).byStation['grill']?.lanes, 3);
      expect(runAt(3).bottleneck, isNull);
    });

    test('capacity 4 (> dishes) → same as 3; lanes capped by dish count, not cap',
        () {
      final Schedule s = runAt(4);
      expect(sorted(s).map((ScheduledDish x) => x.finishAt), <int>[14, 14, 14]);
      expect(s.byStation['grill']?.lanes, 3); // 3 dishes ⇒ 3 lanes, not 4
      expect(s.bottleneck, isNull);
    });
  });

  group('capacity change: invariants hold at every capacity', () {
    test('peak concurrency never exceeds the station capacity', () {
      for (int cap = 1; cap <= 5; cap++) {
        expect(peakConcurrency(runAt(cap), 'grill'), lessThanOrEqualTo(cap),
            reason: 'capacity $cap exceeded');
      }
    });

    test('lanes == min(capacity, dish count)', () {
      for (int cap = 1; cap <= 5; cap++) {
        expect(runAt(cap).byStation['grill']?.lanes, cap < 3 ? cap : 3,
            reason: 'lanes at capacity $cap');
      }
    });

    test('adding capacity never makes a ticket later (monotonic improvement)',
        () {
      int totalLate(int cap) => runAt(cap)
          .dishes
          .fold<int>(0, (int sum, ScheduledDish d) => sum + d.lateMins);
      // 1 → 2 → 3 strictly improves, then flattens.
      expect(totalLate(1), 24); // 0 + 8 + 16
      expect(totalLate(2), 8);
      expect(totalLate(3), 0);
      expect(totalLate(4), 0);
      for (int cap = 1; cap < 5; cap++) {
        expect(totalLate(cap + 1), lessThanOrEqualTo(totalLate(cap)),
            reason: 'raising capacity $cap→${cap + 1} increased lateness');
      }
    });

    test('pure/stateless: re-running at the same capacity is identical', () {
      for (int cap = 1; cap <= 4; cap++) {
        final List<ScheduledDish> a = sorted(runAt(cap));
        final List<ScheduledDish> b = sorted(runAt(cap));
        expect(a, b, reason: 'non-deterministic at capacity $cap');
      }
    });

    test('reducing then reading back matches a fresh schedule at that capacity',
        () {
      // The cubit recomputes from scratch on setStationCapacity, so 3→1 must
      // equal a first-time schedule at 1 (no path dependence).
      runAt(3); // pretend the user was at capacity 3
      expect(sorted(runAt(1)), sorted(runAt(1)));
      expect(sorted(runAt(1)).map((ScheduledDish d) => d.finishAt),
          <int>[14, 22, 30]);
    });
  });
}
