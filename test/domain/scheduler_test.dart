import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart';

void main() {
  // Fixed reference time so DateTime → relative-minute conversion is exact and
  // deterministic (matches the prototype's integer `orderMin`).
  final DateTime now = DateTime(2026, 1, 1, 12);
  final DemoData demo = buildDemoData(now: now);
  final Map<String, Dish> menuByName = <String, Dish>{
    for (final Dish d in demo.menu) d.name: d,
  };
  final Map<String, Dish> menuById = <String, Dish>{
    for (final Dish d in demo.menu) d.id: d,
  };
  final Map<String, Station> stationsById = <String, Station>{
    for (final Station s in demo.stations) s.id: s,
  };

  OrderLine ol(String name, int qty) =>
      OrderLine(dishId: menuByName[name]!.id, qty: qty);
  Kot kot(
    String id,
    String table,
    KotType type,
    int orderMin,
    List<OrderLine> lines,
  ) =>
      Kot(
        id: id,
        table: table,
        type: type,
        orderedAt: now.add(Duration(minutes: orderMin)),
        lines: lines,
      );

  // The prototype's SAMPLE() rush, with ids matching the captured golden.
  final List<Kot> sampleRush = <Kot>[
    kot('101', '5', KotType.dineIn, -2, <OrderLine>[
      ol('BBQ Ribs', 1),
      ol('Steamed Mussels', 2),
      ol('French Fries', 1),
    ]),
    kot('102', '8', KotType.dineIn, -1, <OrderLine>[
      ol('Chicken Stir-Fry', 1),
      ol('Steamed Clams', 1),
      ol('Caesar Salad', 1),
    ]),
    kot('103', '3', KotType.takeaway, 0, <OrderLine>[
      ol('Shrimp Alfredo', 1),
      ol('Steamed Mussels', 1),
      ol('Clam Chowder', 1),
    ]),
    kot('104', 'D21', KotType.delivery, 0, <OrderLine>[
      ol('Cheeseburger', 1),
      ol('French Fries', 1),
    ]),
  ];

  Schedule run(List<Kot> kots) => schedule(
        kots: kots,
        menu: menuById,
        stations: stationsById,
        now: now,
      );

  group('golden: prototype sample rush (captured from MultiKOT.jsx)', () {
    test('reproduces the prototype schedule exactly', () {
      final Schedule plan = run(sampleRush);
      final Map<String, dynamic> golden =
          jsonDecode(_goldenJson) as Map<String, dynamic>;

      expect(plan.horizonMins, golden['horizon'], reason: 'horizon');

      final List<dynamic> gd = golden['dishes'] as List<dynamic>;
      expect(plan.dishes.length, gd.length, reason: 'dish count');

      for (int i = 0; i < gd.length; i++) {
        final Map<String, dynamic> g = gd[i] as Map<String, dynamic>;
        final ScheduledDish d = plan.dishes[i];
        expect(d.uid, g['uid'], reason: 'uid @$i');
        expect(d.stationId, g['station'], reason: 'station @$i (${d.name})');
        expect(d.name, g['name'], reason: 'name @$i');
        expect(d.qty, g['qty'], reason: 'qty @$i (${d.name})');
        expect(d.cookMins, g['cook'], reason: 'cook @$i (${d.name})');
        expect(d.targetMins, g['target'], reason: 'target @$i (${d.name})');
        expect(d.fireAt, g['fire'], reason: 'fire @$i (${d.name})');
        expect(d.finishAt, g['finish'], reason: 'finish @$i (${d.name})');
        expect(d.holdMins, g['hold'], reason: 'hold @$i (${d.name})');
        expect(d.lateMins, g['late'], reason: 'late @$i (${d.name})');
        expect(d.lane, g['lane'], reason: 'lane @$i (${d.name})');

        final List<dynamic> gm = g['members'] as List<dynamic>;
        expect(d.members.length, gm.length, reason: 'member count @$i');
        for (int j = 0; j < gm.length; j++) {
          final Map<String, dynamic> m = gm[j] as Map<String, dynamic>;
          final ScheduledMember mem = d.members[j];
          expect(mem.kotId, m['kotId'].toString(), reason: 'member.kotId @$i/$j');
          expect(mem.table, m['table'], reason: 'member.table @$i/$j');
          expect(mem.qty, m['qty'], reason: 'member.qty @$i/$j');
          expect(mem.type, _typeFromKey(m['type'] as String),
              reason: 'member.type @$i/$j');
        }
      }
    });

    test('lane counts per station match the golden', () {
      final Schedule plan = run(sampleRush);
      final Map<String, dynamic> golden =
          jsonDecode(_goldenJson) as Map<String, dynamic>;
      final Map<String, dynamic> lanes =
          golden['lanesByStation'] as Map<String, dynamic>;
      lanes.forEach((String station, dynamic count) {
        expect(plan.byStation[station]?.lanes, count,
            reason: 'lanes for $station');
      });
    });

    test('steam is the bottleneck at +9 (Steamed Clams behind Steamed Mussels)', () {
      final Schedule plan = run(sampleRush);
      expect(plan.bottleneck, isNotNull);
      expect(plan.bottleneck!.stationId, 'steam');
      expect(plan.bottleneck!.lateMins, 9);
    });
  });

  group('invariants (AGENTS.md §10)', () {
    test('empty input → empty schedule, horizon 1, no bottleneck', () {
      final Schedule plan = run(<Kot>[]);
      expect(plan.dishes, isEmpty);
      expect(plan.byStation, isEmpty);
      expect(plan.horizonMins, 1);
      expect(plan.bottleneck, isNull);
    });

    test('no station ever exceeds its capacity at any minute', () {
      final Schedule plan = run(sampleRush);
      final Map<String, Map<int, int>> occ = <String, Map<int, int>>{};
      for (final ScheduledDish d in plan.dishes) {
        final Map<int, int> bucket = occ[d.stationId] ??= <int, int>{};
        for (int m = d.fireAt; m < d.finishAt; m++) {
          bucket[m] = (bucket[m] ?? 0) + 1;
        }
      }
      occ.forEach((String station, Map<int, int> bucket) {
        final int cap = stationsById[station]!.capacity;
        for (final MapEntry<int, int> e in bucket.entries) {
          expect(e.value, lessThanOrEqualTo(cap),
              reason: '$station over capacity at minute ${e.key}');
        }
      });
    });

    test('no dish fires before now (minute 0)', () {
      final Schedule plan = run(sampleRush);
      for (final ScheduledDish d in plan.dishes) {
        expect(d.fireAt, greaterThanOrEqualTo(0), reason: d.name);
      }
    });

    test('finishAt == fireAt + cookMins; hold/late are exclusive', () {
      final Schedule plan = run(sampleRush);
      for (final ScheduledDish d in plan.dishes) {
        expect(d.finishAt, d.fireAt + d.cookMins, reason: '${d.name} finish');
        expect(d.holdMins > 0 && d.lateMins > 0, isFalse,
            reason: '${d.name} cannot both hold and be late');
      }
    });

    test('deterministic: identical inputs → identical output', () {
      expect(run(sampleRush), run(sampleRush));
    });
  });

  group('batching', () {
    test('identical batchable dishes within the window collapse to one cook', () {
      // Two dine-in tickets ordering Steamed Mussels (batchable) at the same time →
      // one merged cook carrying both members.
      final List<Kot> kots = <Kot>[
        kot('a', '1', KotType.dineIn, 0, <OrderLine>[ol('Steamed Mussels', 2)]),
        kot('b', '2', KotType.dineIn, 0, <OrderLine>[ol('Steamed Mussels', 3)]),
      ];
      final Schedule plan = run(kots);
      final List<ScheduledDish> momo = plan.dishes
          .where((ScheduledDish d) => d.name == 'Steamed Mussels')
          .toList();
      expect(momo, hasLength(1), reason: 'should merge into a single cook');
      expect(momo.single.qty, 5);
      expect(momo.single.members, hasLength(2));
      expect(momo.single.isBatched, isTrue);
    });

    test('batchable dishes outside the window do NOT collapse', () {
      // French Fries from a dine-in (target 0+14=14, fires earlier) vs a
      // delivery (target 0+9=9): targets 6 apart (> 2 window) → two cooks.
      final List<Kot> kots = <Kot>[
        kot('a', '1', KotType.dineIn, 0, <OrderLine>[ol('French Fries', 1)]),
        kot('b', 'D9', KotType.delivery, 0, <OrderLine>[ol('French Fries', 1)]),
      ];
      final Schedule plan = run(kots);
      final List<ScheduledDish> fries = plan.dishes
          .where((ScheduledDish d) => d.name == 'French Fries')
          .toList();
      expect(fries, hasLength(2));
    });

    test('non-batchable dishes never merge even at the same target', () {
      final List<Kot> kots = <Kot>[
        kot('a', '1', KotType.dineIn, 0, <OrderLine>[ol('BBQ Ribs', 1)]),
        kot('b', '2', KotType.dineIn, 0, <OrderLine>[ol('BBQ Ribs', 1)]),
      ];
      final Schedule plan = run(kots);
      final List<ScheduledDish> sizzlers = plan.dishes
          .where((ScheduledDish d) => d.name == 'BBQ Ribs')
          .toList();
      expect(sizzlers, hasLength(2));
    });
  });

  group('placement edge cases', () {
    test('single on-time dish fires at max(0, target - cook)', () {
      // Shrimp Alfredo (wok, cook 9), takeaway target 0+11=11 → ideal 2.
      final List<Kot> kots = <Kot>[
        kot('a', '1', KotType.takeaway, 0, <OrderLine>[ol('Shrimp Alfredo', 1)]),
      ];
      final ScheduledDish d = run(kots).dishes.single;
      expect(d.fireAt, 2);
      expect(d.finishAt, 11);
      expect(d.lateMins, 0);
      expect(d.holdMins, 0);
    });

    test('a dish whose ideal is negative is clamped to fire at now', () {
      // Cheeseburger (grill, cook 12), delivery target 0+9=9 → ideal -3.
      final List<Kot> kots = <Kot>[
        kot('a', 'D1', KotType.delivery, 0, <OrderLine>[ol('Cheeseburger', 1)]),
      ];
      final ScheduledDish d = run(kots).dishes.single;
      expect(d.fireAt, 0);
      expect(d.lateMins, 3);
    });

    test('unknown dish ids are skipped, not crashed', () {
      final List<Kot> kots = <Kot>[
        kot('a', '1', KotType.dineIn, 0, const <OrderLine>[
          OrderLine(dishId: 'does-not-exist', qty: 1),
        ]),
      ];
      expect(run(kots).dishes, isEmpty);
    });
  });
}

KotType _typeFromKey(String key) => switch (key) {
      'dinein' => KotType.dineIn,
      'takeaway' => KotType.takeaway,
      'delivery' => KotType.delivery,
      _ => throw ArgumentError('unknown type $key'),
    };

/// Golden output captured by running `MultiKOT.jsx`'s `schedule(SAMPLE())`
/// verbatim under Node. Regenerate with `/tmp/kbuzz_golden/gen.js` if the
/// prototype's CONFIG or algorithm changes.
const String _goldenJson = r'''
{
  "horizon": 22,
  "dishes": [
    {"uid":0,"station":"grill","name":"Cheeseburger","qty":1,"cook":12,"ideal":-3,"target":9,"fire":0,"finish":12,"hold":0,"late":3,"lane":0,"members":[{"kotId":104,"table":"D21","type":"delivery","qty":1}]},
    {"uid":1,"station":"grill","name":"BBQ Ribs","qty":1,"cook":14,"ideal":-2,"target":12,"fire":0,"finish":14,"hold":0,"late":2,"lane":1,"members":[{"kotId":101,"table":"5","type":"dinein","qty":1}]},
    {"uid":2,"station":"steam","name":"Steamed Mussels","qty":3,"cook":12,"ideal":-1,"target":11,"fire":0,"finish":12,"hold":0,"late":1,"lane":0,"members":[{"kotId":101,"table":"5","type":"dinein","qty":2},{"kotId":103,"table":"3","type":"takeaway","qty":1}]},
    {"uid":3,"station":"wok","name":"Shrimp Alfredo","qty":1,"cook":9,"ideal":2,"target":11,"fire":2,"finish":11,"hold":0,"late":0,"lane":0,"members":[{"kotId":103,"table":"3","type":"takeaway","qty":1}]},
    {"uid":4,"station":"fry","name":"French Fries","qty":1,"cook":6,"ideal":3,"target":9,"fire":3,"finish":9,"hold":0,"late":0,"lane":0,"members":[{"kotId":104,"table":"D21","type":"delivery","qty":1}]},
    {"uid":5,"station":"steam","name":"Steamed Clams","qty":1,"cook":10,"ideal":3,"target":13,"fire":12,"finish":22,"hold":0,"late":9,"lane":0,"members":[{"kotId":102,"table":"8","type":"dinein","qty":1}]},
    {"uid":6,"station":"wok","name":"Chicken Stir-Fry","qty":1,"cook":8,"ideal":5,"target":13,"fire":11,"finish":19,"hold":0,"late":6,"lane":0,"members":[{"kotId":102,"table":"8","type":"dinein","qty":1}]},
    {"uid":7,"station":"soup","name":"Clam Chowder","qty":1,"cook":5,"ideal":6,"target":11,"fire":6,"finish":11,"hold":0,"late":0,"lane":0,"members":[{"kotId":103,"table":"3","type":"takeaway","qty":1}]},
    {"uid":8,"station":"fry","name":"French Fries","qty":1,"cook":6,"ideal":6,"target":12,"fire":6,"finish":12,"hold":0,"late":0,"lane":1,"members":[{"kotId":101,"table":"5","type":"dinein","qty":1}]},
    {"uid":9,"station":"cold","name":"Caesar Salad","qty":1,"cook":4,"ideal":9,"target":13,"fire":9,"finish":13,"hold":0,"late":0,"lane":0,"members":[{"kotId":102,"table":"8","type":"dinein","qty":1}]}
  ],
  "lanesByStation": {"grill":2,"steam":1,"wok":1,"fry":2,"soup":1,"cold":1}
}
''';
