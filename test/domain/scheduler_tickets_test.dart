import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart';

/// Scheduler behaviour for the waiter ticket-state inputs (TICKETS.md scheduler
/// contract): skip served/void, `reAt` fires-now with priority, rush tightens
/// the SLA + prioritises, and priority never batches.
void main() {
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

  String idOf(String name) => menuByName[name]!.id;

  OrderLine line(
    String name, {
    int qty = 1,
    LineState state = LineState.open,
    int? reAt,
  }) =>
      OrderLine(dishId: idOf(name), qty: qty, state: state, reAt: reAt);

  Kot kot(
    String id,
    KotType type,
    int orderMin,
    List<OrderLine> lines, {
    bool rush = false,
  }) =>
      Kot(
        id: id,
        table: id,
        type: type,
        orderedAt: now.add(Duration(minutes: orderMin)),
        lines: lines,
        rush: rush,
      );

  Schedule run(List<Kot> kots, {bool jit = false}) => schedule(
        kots: kots,
        menu: menuById,
        stations: stationsById,
        now: now,
        config: SchedulerConfig(justInTime: jit),
      );

  test('served and void lines carry no kitchen work', () {
    final Schedule plan = run(<Kot>[
      kot('k', KotType.dineIn, 0, <OrderLine>[
        line('French Fries'),
        line('Cheeseburger', state: LineState.served),
        line('Steamed Mussels', state: LineState.voided),
      ]),
    ]);
    expect(plan.dishes.map((ScheduledDish d) => d.name), <String>['French Fries']);
  });

  test('a re-fired (reAt) line fires now and sorts first, even over a lower ideal', () {
    // Ribeye Steak would normally fire first (ideal −2); the re-fired Milkshake
    // (reAt 10, ideal 10) must still sort ahead of it because it's priority.
    final Schedule plan = run(<Kot>[
      kot('k', KotType.dineIn, 0, <OrderLine>[
        line('Ribeye Steak'),
        line('Milkshake', reAt: 10),
      ]),
    ]);
    expect(plan.dishes.first.name, 'Milkshake'); // priority dominates the sort
    final ScheduledDish lassi =
        plan.dishes.firstWhere((ScheduledDish d) => d.name == 'Milkshake');
    expect(lassi.fireAt, 10); // reAt 10 + cook 2 → target 12, ideal 10 → fires 10
  });

  test('rush tightens the SLA and prioritises the ticket', () {
    final Schedule plan = run(<Kot>[
      kot('a', KotType.dineIn, 0, <OrderLine>[line('Shrimp Alfredo')]),
      kot('b', KotType.dineIn, 0, <OrderLine>[line('Shrimp Alfredo')], rush: true),
    ]);
    ScheduledDish forKot(String id) => plan.dishes
        .firstWhere((ScheduledDish d) =>
            d.members.any((ScheduledMember m) => m.kotId == id));

    expect(forKot('a').targetMins, 14); // 0 + dine-in SLA 14
    expect(forKot('b').targetMins, 7); //  0 + min(14, RUSH 7) = 7
    expect(plan.dishes.first.members.first.kotId, 'b'); // rushed sorts first
  });

  test('priority lines never batch (a re-fire splits a would-be batch)', () {
    // Two Steamed Mussels (batchable) at the same target normally merge into one cook…
    expect(
      run(<Kot>[
        kot('a', KotType.dineIn, 0, <OrderLine>[line('Steamed Mussels', qty: 2)]),
        kot('b', KotType.dineIn, 0, <OrderLine>[line('Steamed Mussels', qty: 1)]),
      ]).dishes.where((ScheduledDish d) => d.name == 'Steamed Mussels'),
      hasLength(1),
    );
    // …but a re-fired one stays standalone.
    expect(
      run(<Kot>[
        kot('a', KotType.dineIn, 0, <OrderLine>[line('Steamed Mussels', qty: 2)]),
        kot('b', KotType.dineIn, 0, <OrderLine>[line('Steamed Mussels', qty: 1, reAt: 0)]),
      ]).dishes.where((ScheduledDish d) => d.name == 'Steamed Mussels'),
      hasLength(2),
    );
  });

  test('rushed + effective SLA matches SlaConfig.effective', () {
    const SlaConfig sla = SlaConfig.standard();
    expect(sla.effective(KotType.dineIn, rush: false), 14);
    expect(sla.effective(KotType.dineIn, rush: true), 7);
    expect(sla.effective(KotType.delivery, rush: true), 7); // min(9, 7)
    // A type whose SLA is already under RUSH keeps its own (min wins).
    expect(
      const SlaConfig(minsByType: <KotType, int>{KotType.takeaway: 5})
          .effective(KotType.takeaway, rush: true),
      5,
    );
  });

  test('scheduled cooks carry the priority kind + recook reason (kitchen badge)', () {
    final Schedule plan = run(<Kot>[
      kot('a', KotType.dineIn, 0, <OrderLine>[line('Ribeye Steak')]),
      kot('b', KotType.dineIn, 0, <OrderLine>[line('Milkshake', reAt: 3)]),
      kot('c', KotType.dineIn, 0, <OrderLine>[
        OrderLine(dishId: idOf('Shrimp Alfredo'), qty: 1, reAt: 2, reason: 'Cold'),
      ]),
      kot('d', KotType.dineIn, 0, <OrderLine>[line('Cheeseburger')], rush: true),
    ]);
    PriorityKind kindOf(String name) =>
        plan.dishes.firstWhere((ScheduledDish d) => d.name == name).priority;

    expect(kindOf('Ribeye Steak'), PriorityKind.none);
    expect(kindOf('Milkshake'), PriorityKind.fireNow);
    expect(kindOf('Cheeseburger'), PriorityKind.rush);
    final ScheduledDish recook =
        plan.dishes.firstWhere((ScheduledDish d) => d.name == 'Shrimp Alfredo');
    expect(recook.priority, PriorityKind.recook);
    expect(recook.recookReason, 'Cold');
  });

  group('just-in-time firing (plate-together)', () {
    OrderLine ol(String name, int cook, {int? reAt}) =>
        OrderLine(dishId: idOf(name), qty: 1, cookOverrideMins: cook, reAt: reAt);

    ScheduledDish named(Schedule s, String n) =>
        s.dishes.firstWhere((ScheduledDish d) => d.name == n);

    // Rush delivery ordered 4m ago → target +3; every cook (4/6/12, on three
    // distinct stations) exceeds it, so without JIT all fire now.
    List<Kot> d25() => <Kot>[
          kot('D25', KotType.delivery, -4, <OrderLine>[
            ol('Caesar Salad', 4),
            ol('Steamed Mussels', 12),
            ol('French Fries', 6),
          ], rush: true),
        ];

    test('without JIT every dish fires now and finishes staggered', () {
      final Schedule s = run(d25());
      expect(named(s, 'Caesar Salad').fireAt, 0);
      expect(named(s, 'French Fries').fireAt, 0);
      expect(named(s, 'Steamed Mussels').fireAt, 0);
      expect(named(s, 'Caesar Salad').finishAt, 4);
      expect(named(s, 'French Fries').finishAt, 6);
      expect(named(s, 'Steamed Mussels').finishAt, 12);
    });

    test('with JIT the fast dishes are delayed to plate together', () {
      final Schedule s = run(d25(), jit: true);
      expect(named(s, 'Steamed Mussels').fireAt, 0); // bottleneck unchanged
      expect(named(s, 'Caesar Salad').fireAt, 8); // 12 − 4
      expect(named(s, 'French Fries').fireAt, 6); // 12 − 6
      // all three now finish together at the plate (12).
      expect(s.dishes.map((ScheduledDish d) => d.finishAt).toSet(), <int>{12});
    });

    test('JIT leaves an on-time ticket unchanged (it already converges)', () {
      // Dine-in ordered now, SLA 14: a 4m and a 12m dish both finish at 14.
      List<Kot> onTime() => <Kot>[
            kot('T1', KotType.dineIn, 0, <OrderLine>[
              ol('Caesar Salad', 4),
              ol('Steamed Mussels', 12),
            ]),
          ];
      final Schedule base = run(onTime());
      final Schedule jit = run(onTime(), jit: true);
      for (final String n in <String>['Caesar Salad', 'Steamed Mussels']) {
        expect(named(jit, n).fireAt, named(base, n).fireAt, reason: n);
        expect(named(jit, n).finishAt, named(base, n).finishAt, reason: n);
      }
    });

    test('JIT exempts re-fires — a fire-now line still fires immediately', () {
      final Schedule s = run(<Kot>[
        kot('D9', KotType.delivery, -4, <OrderLine>[
          ol('Steamed Mussels', 12),
          ol('French Fries', 6, reAt: 0), // fire-now
        ], rush: true),
      ], jit: true);
      expect(named(s, 'French Fries').fireAt, 0); // not delayed
      expect(named(s, 'Steamed Mussels').fireAt, 0);
    });

    test('JIT stays within station capacity and never delays the plate', () {
      // Three non-batchable grill dishes (16/14/12) in one rushed, late ticket
      // force contention on a single station — the case a naive re-seat breaks.
      List<Kot> grillRush() => <Kot>[
            kot('T9', KotType.dineIn, -10, <OrderLine>[
              ol('Ribeye Steak', 16),
              ol('BBQ Ribs', 14),
              ol('Cheeseburger', 12),
            ], rush: true),
          ];
      int plateOf(Schedule s) => s.dishes
          .fold<int>(0, (int a, ScheduledDish d) => d.finishAt > a ? d.finishAt : a);

      final Schedule base = run(grillRush());
      final Schedule jit = run(grillRush(), jit: true);

      // (1) No station ever exceeds its capacity at any minute — under JIT too.
      for (final Schedule s in <Schedule>[base, jit]) {
        final Map<String, Map<int, int>> occ = <String, Map<int, int>>{};
        for (final ScheduledDish d in s.dishes) {
          final Map<int, int> byMin = occ[d.stationId] ??= <int, int>{};
          for (int m = d.fireAt; m < d.finishAt; m++) {
            byMin[m] = (byMin[m] ?? 0) + 1;
          }
        }
        occ.forEach((String station, Map<int, int> byMin) {
          final int cap = stationsById[station]!.capacity;
          for (final int used in byMin.values) {
            expect(used, lessThanOrEqualTo(cap), reason: '$station over capacity');
          }
        });
      }

      // (2) JIT must never push the ticket's plate later than plain placement.
      expect(plateOf(jit), lessThanOrEqualTo(plateOf(base)));
    });
  });
}
