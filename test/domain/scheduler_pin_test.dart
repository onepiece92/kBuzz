import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart';

/// Pinning already-fired cooks (scheduler input `pinnedFireMins`): a cook whose
/// key is pinned keeps its fire minute across a reschedule, so adding a ticket
/// can't re-time a dish already on the pass. Empty pins ⇒ identical output.
void main() {
  final DateTime now = DateTime(2026, 1, 1, 18);
  const Station grill =
      Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 1);
  const Dish steak = Dish(
    id: 'steak',
    name: 'Steak',
    emoji: '🥩',
    stationId: 'grill',
    cookMins: 10,
    holdable: false,
    batchable: false,
  );
  final Map<String, Dish> menu = <String, Dish>{'steak': steak};
  final Map<String, Station> stations = <String, Station>{'grill': grill};

  Kot steakKot(String id, {bool rush = false}) => Kot(
        id: id,
        table: id,
        type: KotType.dineIn,
        orderedAt: now,
        rush: rush,
        lines: <OrderLine>[OrderLine(id: 'l-$id', dishId: 'steak', qty: 1)],
      );

  int fireOf(Schedule s, String kotId) => s.dishes
      .firstWhere((ScheduledDish d) =>
          d.members.any((ScheduledMember m) => m.kotId == kotId))
      .fireAt;

  test('without a pin, adding a rush ticket re-times the existing cook', () {
    // A alone: dineIn steak, target 14, ideal 4 → fires at 4.
    final Schedule solo = schedule(
      kots: <Kot>[steakKot('A')],
      menu: menu,
      stations: stations,
      now: now,
    );
    expect(fireOf(solo, 'A'), 4);

    // Add a RUSH ticket B (sorts first, grabs the grill): A is shoved later.
    final Schedule withB = schedule(
      kots: <Kot>[steakKot('A'), steakKot('B', rush: true)],
      menu: menu,
      stations: stations,
      now: now,
    );
    expect(fireOf(withB, 'B'), 0); // rush fires now
    expect(fireOf(withB, 'A'), 10); // A pushed off its 4 → 10 (the symptom)
  });

  test('pinned, A keeps its fire minute and the rush routes around it', () {
    final String keyA = cookKey(
      stationId: 'grill',
      dishId: 'steak',
      kotIds: <String>['A'],
    );
    // A already fired at minute 4; now B (rush) arrives.
    final Schedule pinned = schedule(
      kots: <Kot>[steakKot('A'), steakKot('B', rush: true)],
      menu: menu,
      stations: stations,
      now: now,
      pinnedFireMins: <String, int>{keyA: 4},
    );
    expect(fireOf(pinned, 'A'), 4); // locked in place despite the rush
    expect(fireOf(pinned, 'B'), 14); // rush routed around A's reserved 4..13

    // Capacity still respected for the unpinned dish (no overlap with A).
    expect(fireOf(pinned, 'B'), greaterThanOrEqualTo(fireOf(pinned, 'A') + 10));
  });

  test('an empty pin map yields the identical schedule (determinism kept)', () {
    final List<Kot> kots = <Kot>[steakKot('A'), steakKot('B', rush: true)];
    final Schedule noArg =
        schedule(kots: kots, menu: menu, stations: stations, now: now);
    final Schedule emptyPin = schedule(
      kots: kots,
      menu: menu,
      stations: stations,
      now: now,
      pinnedFireMins: const <String, int>{},
    );
    expect(emptyPin, noArg); // byte-identical → golden/invariants unaffected
  });
}
