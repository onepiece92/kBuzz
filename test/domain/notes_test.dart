import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart';

/// Special-instruction ("note") behaviour that isn't provider- or UI-specific:
/// the note flows from an [OrderLine] through the scheduler onto the
/// [ScheduledMember] (so the Stations board + fire audio can read it), and the
/// demo generators actually produce notes.
void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  group('scheduler carries the line note onto the member', () {
    final Map<String, Station> stations = <String, Station>{
      'grill': const Station(
          id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2),
    };
    final Map<String, Dish> menu = <String, Dish>{
      'burger': const Dish(
        id: 'burger',
        name: 'Burger',
        emoji: '🍔',
        stationId: 'grill',
        cookMins: 5,
        holdable: false,
        batchable: false,
      ),
    };

    test('a noted line → ScheduledMember.note', () {
      final Schedule s = schedule(
        kots: <Kot>[
          Kot(
            id: 'k1',
            table: '5',
            type: KotType.dineIn,
            orderedAt: now,
            lines: const <OrderLine>[
              OrderLine(dishId: 'burger', qty: 1, note: 'no pickles'),
            ],
          ),
        ],
        menu: menu,
        stations: stations,
        now: now,
      );
      expect(s.dishes.single.members.single.note, 'no pickles');
    });

    test('a plain line carries no note', () {
      final Schedule s = schedule(
        kots: <Kot>[
          Kot(
            id: 'k1',
            table: '5',
            type: KotType.dineIn,
            orderedAt: now,
            lines: const <OrderLine>[OrderLine(dishId: 'burger', qty: 1)],
          ),
        ],
        menu: menu,
        stations: stations,
        now: now,
      );
      expect(s.dishes.single.members.single.note, isNull);
    });
  });

  group('demo generators produce notes', () {
    test('the fixed sample has at least one noted line', () {
      final DemoData data = buildDemoData(now: now);
      final Iterable<OrderLine> lines = data.kots.expand((Kot k) => k.lines);
      expect(
        lines.any((OrderLine l) => (l.note ?? '').isNotEmpty),
        isTrue,
      );
    });

    test('the random rush sprinkles notes (seeded → deterministic)', () {
      final DemoData data = buildRandomDemoData(now: now, random: Random(7));
      final Iterable<OrderLine> lines = data.kots.expand((Kot k) => k.lines);
      expect(
        lines.any((OrderLine l) => (l.note ?? '').isNotEmpty),
        isTrue,
      );
    });
  });
}
