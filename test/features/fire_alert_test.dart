import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/service/cubit/fire_alert_cubit.dart';

ScheduledDish _dish({
  required String dishId,
  required String stationId,
  required int fireAt,
  String name = 'Dish',
  int qty = 1,
  PriorityKind priority = PriorityKind.none,
  int reFireSeq = 0,
  List<String> kotIds = const <String>[],
  Map<String, String> notes = const <String, String>{},
}) =>
    ScheduledDish(
      uid: fireAt, // arbitrary
      stationId: stationId,
      dishId: dishId,
      name: name,
      emoji: '🍢',
      cookMins: 5,
      holdable: true,
      batchable: false,
      members: <ScheduledMember>[
        for (final String id in kotIds)
          ScheduledMember(
              kotId: id,
              table: id,
              type: KotType.dineIn,
              qty: qty,
              note: notes[id]),
      ],
      qty: qty,
      targetMins: fireAt + 5,
      fireAt: fireAt,
      finishAt: fireAt + 5,
      holdMins: 0,
      lateMins: 0,
      lane: 0,
      priority: priority,
      reFireSeq: reFireSeq,
    );

void main() {
  final Map<String, Station> stations = <String, Station>{
    'grill': const Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2),
    'steam': const Station(id: 'steam', name: 'Steam', color: 0xFF0EA5E9, capacity: 1),
  };
  final List<ScheduledDish> dishes = <ScheduledDish>[
    _dish(dishId: 'burger', stationId: 'grill', fireAt: 0, name: 'Burger', qty: 2),
    _dish(dishId: 'momo', stationId: 'steam', fireAt: 5, name: 'Momo'),
  ];

  group('detectFires', () {
    test('returns nothing and clears the set before the run starts', () {
      final Set<String> alerted = <String>{'stale'};
      final List<FireAlert> fired = detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 99,
        started: false,
        alerted: alerted,
      );
      expect(fired, isEmpty);
      expect(alerted, isEmpty); // reset re-arms everything
    });

    test('fires a dish exactly once as the clock crosses its fireAt', () {
      final Set<String> alerted = <String>{};

      // At minute 0: only the grill burger (fireAt 0) crosses.
      final List<FireAlert> t0 = detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 0,
        started: true,
        alerted: alerted,
      );
      expect(t0, hasLength(1));
      expect(t0.single.dishName, 'Burger');
      expect(t0.single.stationName, 'Grill');
      expect(t0.single.qty, 2);
      expect(t0.single.spokenText, 'Grill — 2 Burger');

      // Still minute 0 a tick later → nothing new (edge-triggered, once-only).
      expect(
        detectFires(
          dishes: dishes,
          stationsById: stations,
          elapsedMins: 0.5,
          started: true,
          alerted: alerted,
        ),
        isEmpty,
      );

      // Minute 5 → the steam momo crosses.
      final List<FireAlert> t5 = detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 5,
        started: true,
        alerted: alerted,
      );
      expect(t5, hasLength(1));
      expect(t5.single.dishName, 'Momo');
    });

    test('a jump past several fireAts fires all of them at once', () {
      final Set<String> alerted = <String>{};
      final List<FireAlert> fired = detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 99,
        started: true,
        alerted: alerted,
      );
      expect(fired, hasLength(2));
    });

    test('reset (started=false) re-arms, so a restart fires again', () {
      final Set<String> alerted = <String>{};
      detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 99,
        started: true,
        alerted: alerted,
      );
      expect(alerted, isNotEmpty);
      // Stop the run.
      detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 0,
        started: false,
        alerted: alerted,
      );
      expect(alerted, isEmpty);
      // Restart → fires again.
      final List<FireAlert> again = detectFires(
        dishes: dishes,
        stationsById: stations,
        elapsedMins: 99,
        started: true,
        alerted: alerted,
      );
      expect(again, hasLength(2));
    });

    test('fireKey ignores fireAt — a re-packed cook keeps its identity', () {
      // A reschedule shifts fireAt, but the cook still serves the same ticket,
      // so its key is unchanged → it stays fired-once (no re-announce).
      final ScheduledDish before = _dish(
          dishId: 'steak', stationId: 'grill', fireAt: 9, kotIds: <String>['t1']);
      final ScheduledDish after = _dish(
          dishId: 'steak', stationId: 'grill', fireAt: 2, kotIds: <String>['t1']);
      expect(fireKey(after), fireKey(before));

      // Different tickets ⇒ different cooks ⇒ different keys (both fire).
      final ScheduledDish other = _dish(
          dishId: 'steak', stationId: 'grill', fireAt: 2, kotIds: <String>['t2']);
      expect(fireKey(other), isNot(fireKey(after)));
    });

    test('a recook gets a distinct key so it re-fires', () {
      final ScheduledDish normal = _dish(
          dishId: 'steak', stationId: 'grill', fireAt: 2, kotIds: <String>['t1']);
      final ScheduledDish recook = _dish(
        dishId: 'steak',
        stationId: 'grill',
        fireAt: 2,
        kotIds: <String>['t1'],
        priority: PriorityKind.recook,
      );
      expect(fireKey(recook), isNot(fireKey(normal)));
    });

    test('two re-fires in the SAME minute key distinctly (reFireSeq, not fireAt)',
        () {
      // Double-tap fire-now / a second send-back within one board minute: same
      // fireAt, but the bumped reFireSeq makes each a distinct cook.
      final ScheduledDish first = _dish(
        dishId: 'steak',
        stationId: 'grill',
        fireAt: 5,
        kotIds: <String>['t1'],
        priority: PriorityKind.fireNow,
        reFireSeq: 1,
      );
      final ScheduledDish second = _dish(
        dishId: 'steak',
        stationId: 'grill',
        fireAt: 5, // identical minute
        kotIds: <String>['t1'],
        priority: PriorityKind.fireNow,
        reFireSeq: 2, // bumped
      );
      expect(fireKey(second), isNot(fireKey(first)));
    });

    test('a second re-fire at the same minute re-announces (not swallowed)', () {
      final Set<String> alerted = <String>{};
      List<FireAlert> fire(int seq) => detectFires(
            dishes: <ScheduledDish>[
              _dish(
                dishId: 'steak',
                stationId: 'grill',
                fireAt: 5,
                name: 'Steak',
                kotIds: <String>['t1'],
                priority: PriorityKind.fireNow,
                reFireSeq: seq,
              ),
            ],
            stationsById: stations,
            elapsedMins: 5,
            started: true,
            alerted: alerted,
          );
      expect(fire(1), hasLength(1)); // first re-fire announces
      expect(fire(1), isEmpty); // same seq → once-only, no duplicate
      expect(fire(2), hasLength(1)); // bumped seq, same minute → re-announces
    });
  });

  group('detectFires reschedule + aggregation', () {
    test('a re-packed cook (shifted fireAt) is not re-fired', () {
      final Set<String> alerted = <String>{};
      // Fires once at minute 2.
      expect(
        detectFires(
          dishes: <ScheduledDish>[
            _dish(dishId: 'steak', stationId: 'grill', fireAt: 2, kotIds: <String>['t1']),
          ],
          stationsById: stations,
          elapsedMins: 3,
          started: true,
          alerted: alerted,
        ),
        hasLength(1),
      );
      // A reschedule shifts the same cook to minute 1 → same key → no re-fire.
      expect(
        detectFires(
          dishes: <ScheduledDish>[
            _dish(dishId: 'steak', stationId: 'grill', fireAt: 1, kotIds: <String>['t1']),
          ],
          stationsById: stations,
          elapsedMins: 3.1,
          started: true,
          alerted: alerted,
        ),
        isEmpty,
      );
    });

    test('a cook pulled forward by a reschedule still fires once', () {
      // The reported case: raising grill capacity re-packs a waiting cook so it
      // becomes due now. It never fired, so it must fire — not be skipped.
      final Set<String> alerted = <String>{};
      // Scheduled for minute 16, not due at minute 5 → no fire yet.
      expect(
        detectFires(
          dishes: <ScheduledDish>[
            _dish(dishId: 'steak', stationId: 'grill', fireAt: 16, kotIds: <String>['t2']),
          ],
          stationsById: stations,
          elapsedMins: 5,
          started: true,
          alerted: alerted,
        ),
        isEmpty,
      );
      // Capacity raised → re-packs to fire now. Same cook, never fired → fires.
      expect(
        detectFires(
          dishes: <ScheduledDish>[
            _dish(dishId: 'steak', stationId: 'grill', fireAt: 0, kotIds: <String>['t2']),
          ],
          stationsById: stations,
          elapsedMins: 5,
          started: true,
          alerted: alerted,
        ),
        hasLength(1),
      );
    });

    test('several cooks of one dish firing together sum into a single line', () {
      // Three Ribeye cooks (2 + 1 + 1) crossing together → "4× Ribeye Steak".
      final Set<String> alerted = <String>{};
      final List<FireAlert> fired = detectFires(
        dishes: <ScheduledDish>[
          _dish(dishId: 'steak', stationId: 'grill', fireAt: 0, name: 'Ribeye Steak', qty: 2, kotIds: <String>['t1']),
          _dish(dishId: 'steak', stationId: 'grill', fireAt: 0, name: 'Ribeye Steak', qty: 1, kotIds: <String>['t2']),
          _dish(dishId: 'steak', stationId: 'grill', fireAt: 0, name: 'Ribeye Steak', qty: 1, kotIds: <String>['t3']),
          _dish(dishId: 'momo', stationId: 'steam', fireAt: 0, name: 'Momo', qty: 1, kotIds: <String>['t4']),
        ],
        stationsById: stations,
        elapsedMins: 0,
        started: true,
        alerted: alerted,
      );
      // One combined steak line (qty 4) + the momo — not three steak lines.
      expect(fired, hasLength(2));
      final FireAlert steak =
          fired.firstWhere((FireAlert a) => a.dishName == 'Ribeye Steak');
      expect(steak.qty, 4);
      expect(steak.stationName, 'Grill');
      expect(steak.spokenText, 'Grill — 4 Ribeye Steak');
    });

    test('same-dish cooks firing on different ticks are not merged', () {
      // Aggregation is per batch: a cook crossing on a later tick is its own
      // alert (it genuinely fires later).
      final Set<String> alerted = <String>{};
      final List<ScheduledDish> twoCooks = <ScheduledDish>[
        _dish(dishId: 'steak', stationId: 'grill', fireAt: 0, name: 'Ribeye Steak', qty: 2, kotIds: <String>['t1']),
        _dish(dishId: 'steak', stationId: 'grill', fireAt: 5, name: 'Ribeye Steak', qty: 1, kotIds: <String>['t2']),
      ];
      expect(
        detectFires(
          dishes: twoCooks,
          stationsById: stations,
          elapsedMins: 0,
          started: true,
          alerted: alerted,
        ).single.qty,
        2,
      );
      expect(
        detectFires(
          dishes: twoCooks,
          stationsById: stations,
          elapsedMins: 5,
          started: true,
          alerted: alerted,
        ).single.qty,
        1,
      );
    });
  });

  group('firableDishes (done tickets do not fire)', () {
    Kot kot(String id, {TicketState status = TicketState.active}) => Kot(
          id: id,
          table: id,
          type: KotType.dineIn,
          orderedAt: DateTime(2026),
          lines: const <OrderLine>[],
          status: status,
        );

    test('drops a cook whose only ticket is done', () {
      final List<ScheduledDish> kept = firableDishes(
        <ScheduledDish>[
          _dish(dishId: 'burger', stationId: 'grill', fireAt: 0, kotIds: <String>['t1']),
        ],
        <String, Kot>{'t1': kot('t1', status: TicketState.done)},
      );
      expect(kept, isEmpty);
    });

    test('keeps a cook whose ticket is still active', () {
      final List<ScheduledDish> kept = firableDishes(
        <ScheduledDish>[
          _dish(dishId: 'burger', stationId: 'grill', fireAt: 0, kotIds: <String>['t1']),
        ],
        <String, Kot>{'t1': kot('t1')},
      );
      expect(kept, hasLength(1));
    });

    test('keeps a batched cook while any of its tickets is active', () {
      // One cook serves a done t1 and an active t2 → still fires for t2.
      final List<ScheduledDish> kept = firableDishes(
        <ScheduledDish>[
          _dish(dishId: 'steak', stationId: 'grill', fireAt: 0, kotIds: <String>['t1', 't2']),
        ],
        <String, Kot>{
          't1': kot('t1', status: TicketState.done),
          't2': kot('t2'),
        },
      );
      expect(kept, hasLength(1));
    });

    test('then detectFires never buzzes for a done ticket', () {
      final Set<String> alerted = <String>{};
      final List<ScheduledDish> dueButDone = firableDishes(
        <ScheduledDish>[
          _dish(dishId: 'momo', stationId: 'steam', fireAt: 0, kotIds: <String>['t1']),
        ],
        <String, Kot>{'t1': kot('t1', status: TicketState.done)},
      );
      expect(
        detectFires(
          dishes: dueButDone,
          stationsById: stations,
          elapsedMins: 99,
          started: true,
          alerted: alerted,
        ),
        isEmpty,
      );
    });
  });

  group('special-instruction notes in the fire audio', () {
    test('detectFires unions member notes onto the alert', () {
      final List<FireAlert> fired = detectFires(
        dishes: <ScheduledDish>[
          _dish(
            dishId: 'burger',
            stationId: 'grill',
            fireAt: 0,
            name: 'Burger',
            kotIds: <String>['t1', 't2'],
            notes: <String, String>{'t1': 'no pickles', 't2': 'extra cheese'},
          ),
        ],
        stationsById: stations,
        elapsedMins: 0,
        started: true,
        alerted: <String>{},
      );
      expect(fired.single.notes, <String>['no pickles', 'extra cheese']);
      expect(fired.single.spokenText,
          'Grill — 1 Burger, note: no pickles; extra cheese');
    });

    test('a cook with no notes speaks plainly', () {
      const FireAlert a = FireAlert(
        stationId: 'grill',
        stationName: 'Grill',
        dishName: 'Burger',
        qty: 1,
      );
      expect(a.spokenText, 'Grill — 1 Burger');
    });

    test('batchSpokenText includes each item\'s note', () {
      const FireAlert a = FireAlert(
        stationId: 'grill',
        stationName: 'Grill',
        dishName: 'Burger',
        qty: 1,
        notes: <String>['no pickles'],
      );
      const FireAlert b = FireAlert(
        stationId: 'steam',
        stationName: 'Steam',
        dishName: 'Momo',
        qty: 1,
      );
      expect(
        batchSpokenText(<FireAlert>[a, b]),
        'Grill — 1 Burger, note: no pickles, and Steam — 1 Momo',
      );
    });
  });

  group('batchSpokenText', () {
    FireAlert alert(String station, String dish, int qty) => FireAlert(
          stationId: station.toLowerCase(),
          stationName: station,
          dishName: dish,
          qty: qty,
        );

    test('an empty batch speaks nothing', () {
      expect(batchSpokenText(const <FireAlert>[]), '');
    });

    test('a single fire reads exactly like its own spokenText', () {
      final FireAlert a = alert('Grill', 'Burger', 2);
      expect(batchSpokenText(<FireAlert>[a]), a.spokenText);
      expect(batchSpokenText(<FireAlert>[a]), 'Grill — 2 Burger');
    });

    test('two simultaneous fires are both named with an "and"', () {
      expect(
        batchSpokenText(<FireAlert>[
          alert('Grill', 'Burger', 2),
          alert('Steam', 'Momo', 1),
        ]),
        'Grill — 2 Burger, and Steam — 1 Momo',
      );
    });

    test('three or more name every item, joined with a final "and"', () {
      expect(
        batchSpokenText(<FireAlert>[
          alert('Grill', 'Burger', 2),
          alert('Steam', 'Momo', 1),
          alert('Fryer', 'Fries', 3),
        ]),
        'Grill — 2 Burger, Steam — 1 Momo, and Fryer — 3 Fries',
      );
      expect(
        batchSpokenText(<FireAlert>[
          alert('Grill', 'Burger', 2),
          alert('Steam', 'Momo', 1),
          alert('Fryer', 'Fries', 3),
          alert('Wok', 'Noodles', 4),
        ]),
        'Grill — 2 Burger, Steam — 1 Momo, Fryer — 3 Fries, '
        'and Wok — 4 Noodles',
      );
    });
  });
}
