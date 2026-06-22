import 'dart:math';

import 'package:kbuzz/domain/entities/kitchen.dart';

/// A self-contained bundle of demo stations, menu and live tickets — enough to
/// exercise the app without a backend or a real scan flow.
class DemoData {
  const DemoData({
    required this.stations,
    required this.menu,
    required this.kots,
  });

  final List<Station> stations;
  final List<Dish> menu;
  final List<Kot> kots;

  /// Total dishes across all tickets (sum of line quantities).
  int get totalDishes =>
      kots.expand((Kot k) => k.lines).fold(0, (int sum, OrderLine l) => sum + l.qty);
}

/// Build the prototype's sample dataset (`MultiKOT.jsx` STATIONS / MENU /
/// SAMPLE), with ticket order times anchored to [now].
///
/// Pure and deterministic given [now] — the same `now` always yields the same
/// data (ids are stable slugs, not random), so it's safe to call from a cubit
/// or a test. This is a temporary seed for manual testing; once Drift lands it
/// will be replaced by a real repository (AGENTS.md §15 milestone 2).
DemoData buildDemoData({required DateTime now}) {
  final List<Station> stations = _demoStations();
  final List<Dish> menu = _demoMenu();

  final Map<String, Dish> byName = <String, Dish>{
    for (final Dish d in menu) d.name: d,
  };
  OrderLine line(String name, int qty) =>
      OrderLine(dishId: byName[name]!.id, qty: qty);
  DateTime orderedAt(int min) => now.add(Duration(minutes: min));

  // orderMin is minutes relative to "now" (negative = ordered earlier).
  final List<Kot> kots = <Kot>[
    Kot(
      id: 'demo-kot-1',
      table: '5',
      type: KotType.dineIn,
      orderedAt: orderedAt(-2),
      lines: <OrderLine>[
        line('BBQ Ribs', 1),
        line('Steamed Mussels', 2),
        line('French Fries', 1),
      ],
    ),
    Kot(
      id: 'demo-kot-2',
      table: '8',
      type: KotType.dineIn,
      orderedAt: orderedAt(-1),
      lines: <OrderLine>[
        line('Chicken Stir-Fry', 1),
        line('Steamed Clams', 1),
        line('Caesar Salad', 1),
      ],
    ),
    Kot(
      id: 'demo-kot-3',
      table: '3',
      type: KotType.takeaway,
      orderedAt: orderedAt(0),
      lines: <OrderLine>[
        line('Shrimp Alfredo', 1),
        line('Steamed Mussels', 1),
        line('Clam Chowder', 1),
      ],
    ),
    Kot(
      id: 'demo-kot-4',
      table: 'D21',
      type: KotType.delivery,
      orderedAt: orderedAt(0),
      lines: <OrderLine>[
        line('Cheeseburger', 1),
        line('French Fries', 1),
      ],
    ),
  ];

  return DemoData(stations: stations, menu: menu, kots: kots);
}

/// Build a randomized, *longer* demo rush against the same fixed restaurant
/// config as [buildDemoData].
///
/// The stations and menu are the fixed prototype set (so their colours,
/// capacities and ids stay valid for the boards and scheduler); only the
/// **tickets** vary — a different rush of 6–12 tickets, each ordering 1–4 random
/// dishes, with random tables, types and order times. This is the no-AI fallback
/// for "Generate demo data": no key required, but a fresh board every tap.
///
/// Pure given (`now`, `random`): pass a seeded [Random] for a deterministic
/// result in tests; omit it for a genuinely different rush each call.
DemoData buildRandomDemoData({required DateTime now, Random? random}) {
  final Random rng = random ?? Random();
  final List<Station> stations = _demoStations();
  final List<Dish> menu = _demoMenu();

  final int ticketCount = 6 + rng.nextInt(7); // 6..12
  final List<Kot> kots = <Kot>[];
  for (int i = 0; i < ticketCount; i++) {
    final KotType type = KotType.values[rng.nextInt(KotType.values.length)];
    final int lineCount = 1 + rng.nextInt(4); // 1..4 distinct dishes
    final List<Dish> pool = List<Dish>.of(menu)..shuffle(rng);
    final List<OrderLine> lines = <OrderLine>[
      for (final Dish d in pool.take(lineCount))
        // Mostly 1, occasionally 2 — keeps the rush believable.
        OrderLine(dishId: d.id, qty: rng.nextInt(4) == 0 ? 2 : 1),
    ];
    kots.add(Kot(
      id: 'demo-kot-${i + 1}',
      table: _randomTable(type, rng),
      type: type,
      orderedAt: now.subtract(Duration(minutes: rng.nextInt(9))), // 0..8 ago
      lines: lines,
    ));
  }

  return DemoData(stations: stations, menu: menu, kots: kots);
}

/// A plausible table / order code for [type] (delivery codes carry a `D`
/// prefix, matching the prototype's stored labels).
String _randomTable(KotType type, Random rng) {
  switch (type) {
    case KotType.delivery:
      return 'D${20 + rng.nextInt(30)}'; // D20..D49
    case KotType.takeaway:
    case KotType.dineIn:
      return '${1 + rng.nextInt(20)}'; // 1..20
  }
}

/// The fixed kitchen line — American station names. The ids/colours/capacities
/// are stable (the boards, scheduler and persistence key on the id), so only the
/// display [Station.name] changes for the US menu.
List<Station> _demoStations() => <Station>[
      const Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2),
      const Station(
          id: 'steam', name: 'Steamer', color: 0xFF0EA5E9, capacity: 1),
      const Station(id: 'wok', name: 'Sauté', color: 0xFFF59E0B, capacity: 1),
      const Station(id: 'fry', name: 'Fry', color: 0xFFF97316, capacity: 2),
      const Station(id: 'curry', name: 'Pasta', color: 0xFFF43F5E, capacity: 2),
      const Station(id: 'soup', name: 'Soup', color: 0xFF8B5CF6, capacity: 1),
      const Station(id: 'cold', name: 'Salad', color: 0xFF10B981, capacity: 3),
      const Station(id: 'tandoor', name: 'Oven', color: 0xFFEAB308, capacity: 1),
      const Station(id: 'bar', name: 'Bar', color: 0xFF14B8A6, capacity: 2),
    ];

/// The fixed demo menu — American casual-dining fare for our US target market.
/// cook = predicted minutes · hold = can rest off-heat · batch = cook together.
/// Cook times / hold / batch / station mix mirror the prototype so the
/// scheduler's golden behaviour (contention, bottleneck) is preserved.
List<Dish> _demoMenu() => <Dish>[
      _dish('Ribeye Steak', '🥩', 'grill', 16, hold: true, batch: false),
      _dish('BBQ Ribs', '🍖', 'grill', 14, hold: true, batch: false),
      _dish('Cheeseburger', '🍔', 'grill', 12, hold: true, batch: false),
      _dish('Steamed Mussels', '🦪', 'steam', 12, hold: true, batch: true),
      _dish('Steamed Clams', '🦞', 'steam', 10, hold: true, batch: true),
      _dish('Shrimp Alfredo', '🍤', 'wok', 9, hold: true, batch: false),
      _dish('Chicken Stir-Fry', '🥘', 'wok', 8, hold: false, batch: false),
      _dish('Chicken Tenders', '🍗', 'fry', 7, hold: true, batch: false),
      _dish('French Fries', '🍟', 'fry', 6, hold: false, batch: true),
      _dish('Spaghetti & Meatballs', '🍝', 'curry', 11, hold: true, batch: false),
      _dish('Clam Chowder', '🥣', 'soup', 5, hold: true, batch: false),
      _dish('Caesar Salad', '🥗', 'cold', 4, hold: false, batch: false),
      _dish('Garlic Bread', '🥖', 'tandoor', 4, hold: false, batch: true),
      _dish('Milkshake', '🥤', 'bar', 2, hold: false, batch: false),
    ];

/// Stable, human-readable dish id from its name (e.g. "Buff Momo" -> "buff-momo").
Dish _dish(
  String name,
  String emoji,
  String stationId,
  int cookMins, {
  required bool hold,
  required bool batch,
}) {
  final String id = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return Dish(
    id: id,
    name: name,
    emoji: emoji,
    stationId: stationId,
    cookMins: cookMins,
    holdable: hold,
    batchable: batch,
  );
}
