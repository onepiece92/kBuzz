import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart';

/// LOAD / ACCUMULATION characterization — what happens to the station flow when
/// tickets keep arriving over a real dinner service?
///
/// `now` is FIXED at the board epoch, mirroring the app: BoardData anchors `now`
/// to DemoDataState.generatedAt and `addKot` never advances it, so a ticket
/// scanned at service-minute M lands at orderedAt = epoch + M. The whole
/// schedule is therefore measured against a frozen t=0 that ages as service runs.
///
/// Two of these scenarios pass as healthy invariants (A, B). Two are
/// CHARACTERIZATION tests (C, D): they assert the *current, defective* behavior
/// so the suite documents it and FLIPS (fails) the day the 120-minute horizon /
/// frozen-epoch limits are fixed — at which point update the expectations.
void main() {
  final DateTime epoch = DateTime(2026, 1, 1, 18); // 6pm — service starts

  // One representative main: cook 8, non-holdable (under capacity ⇒ serialize /
  // plate late, the honest case), non-batchable (each order is its own cook).
  const Dish main = Dish(
    id: 'steak',
    name: 'Steak',
    emoji: '🥩',
    stationId: 'grill',
    cookMins: 8,
    holdable: false,
    batchable: false,
  );
  final Map<String, Dish> menu = <String, Dish>{'steak': main};

  Map<String, Station> grill(int cap) => <String, Station>{
        'grill':
            Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: cap),
      };

  /// One dineIn ticket (one steak) per given service minute — like runtime scans.
  List<Kot> arrivals(List<int> serviceMins) => <Kot>[
        for (int i = 0; i < serviceMins.length; i++)
          Kot(
            id: 'k$i',
            table: '${i + 1}',
            type: KotType.dineIn,
            orderedAt: epoch.add(Duration(minutes: serviceMins[i])),
            lines: const <OrderLine>[OrderLine(dishId: 'steak', qty: 1)],
          ),
      ];

  Schedule run(List<int> serviceMins, int cap) => schedule(
        kots: arrivals(serviceMins),
        menu: menu,
        stations: grill(cap),
        now: epoch,
        config: const SchedulerConfig(justInTime: true), // app default
      );

  /// Peak concurrent cooks at any single minute on the grill (must be <= cap).
  int peak(Schedule s) {
    final Map<int, int> perMin = <int, int>{};
    for (final ScheduledDish d in s.dishes) {
      for (int m = d.fireAt; m < d.finishAt; m++) {
        perMin[m] = (perMin[m] ?? 0) + 1;
      }
    }
    return perMin.values.isEmpty
        ? 0
        : perMin.values.reduce((int a, int b) => a > b ? a : b);
  }

  int maxFinish(Schedule s) => s.dishes
      .fold<int>(0, (int m, ScheduledDish d) => d.finishAt > m ? d.finishAt : m);
  int pastHorizon(Schedule s) =>
      s.dishes.where((ScheduledDish d) => d.finishAt > 120).length;
  int maxLate(Schedule s) => s.dishes
      .fold<int>(0, (int m, ScheduledDish d) => d.lateMins > m ? d.lateMins : m);

  group('station flow under accumulating tickets', () {
    test('A — steady arrivals the kitchen keeps up with (1 tkt/8min, cap 2)', () {
      // Arrival (1 per 8min) <= throughput (cap 2 per 8min). ~2h of service.
      final Schedule s = run(<int>[for (int m = 0; m <= 112; m += 8) m], 2);
      expect(peak(s), lessThanOrEqualTo(2), reason: 'capacity must hold');
      expect(pastHorizon(s), 0, reason: 'everything fits in the 120m window');
      expect(maxLate(s), 0, reason: 'nothing plates late when keeping up');
      expect(s.byStation['grill']?.lanes, 2);
    });

    test('B — dinner-rush burst, saturated but coping (12 at once, cap 2)', () {
      // The "saturated" screenshot case: more tickets than lanes, all at once.
      // Honest degradation — serialize, plate late, but NEVER exceed capacity.
      final Schedule s = run(<int>[for (int i = 0; i < 12; i++) 0], 2);
      expect(peak(s), lessThanOrEqualTo(2), reason: 'capacity must hold');
      expect(pastHorizon(s), 0, reason: 'still inside the 120m window');
      expect(maxLate(s), 40, reason: 'last of 12 serialized cooks plates +40m');
      expect(s.bottleneck?.stationId, 'grill');
    });

    // ---- CHARACTERIZATION: documents current defects (update when fixed) ----

    test('C — sustained overload BREACHES capacity past the horizon '
        '(1 tkt/4min, cap 1) [KNOWN BUG]', () {
      // Arrival (1 per 4min) > throughput (1 per 8min) ⇒ backlog grows without
      // bound. Once the backlog crosses HMAX=120, feasible() rejects every slot
      // and placement falls back to `t ??= want` (scheduler.dart:195) with NO
      // capacity check, so fill() stacks cooks beyond the station's capacity.
      final Schedule s = run(<int>[for (int m = 0; m <= 156; m += 4) m], 1);
      // BUG: 3 concurrent cooks on a capacity-1 grill — physically impossible.
      expect(peak(s), greaterThan(1),
          reason: 'capacity is silently violated past the horizon');
      expect(pastHorizon(s), greaterThan(0),
          reason: 'work is pushed beyond the 120m wall');
      // When fixed, these excess cooks should instead serialize (peak == 1) and
      // the schedule should refuse/flag work it cannot place inside the horizon.
    });

    test('D — long service blows past the 120m horizon with a frozen epoch '
        '(1 tkt/10min to 200min, cap 2) [KNOWN BUG]', () {
      // Capacity is never contended here (arrival <= throughput), yet because
      // `now` stays pinned to service-start, tickets ordered late in the night
      // land far beyond HMAX=120: their fireAt/finishAt run off the end of the
      // rail's time axis and the now-line stops being meaningful.
      final Schedule s = run(<int>[for (int m = 0; m <= 200; m += 10) m], 2);
      expect(peak(s), lessThanOrEqualTo(2),
          reason: 'no contention here, so capacity still holds');
      expect(maxFinish(s), greaterThan(120),
          reason: 'late-service tickets finish past the horizon');
      expect(pastHorizon(s), greaterThan(0));
      // When fixed (advancing epoch / rolling window), the active window should
      // stay bounded and late-night tickets should schedule relative to *then*.
    });
  });
}
