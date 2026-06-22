import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

ScheduledDish _dish({
  required int fireAt,
  required int finishAt,
  List<ScheduledMember> members = const <ScheduledMember>[],
}) =>
    ScheduledDish(
      uid: 0,
      stationId: 'grill',
      dishId: 'x',
      name: 'X',
      emoji: '🍢',
      cookMins: finishAt - fireAt,
      holdable: true,
      batchable: false,
      members: members,
      qty: 1,
      targetMins: finishAt,
      fireAt: fireAt,
      finishAt: finishAt,
      holdMins: 0,
      lateMins: 0,
      lane: 0,
    );

TicketStatus _ticket({required int plateMins, int? targetMins}) => TicketStatus(
      dishes: const <ScheduledDish>[],
      targetMins: targetMins ?? plateMins,
      plateMins: plateMins,
      lateMins: 0,
    );

ScheduledMember _member(String kotId) =>
    ScheduledMember(kotId: kotId, table: kotId, type: KotType.dineIn, qty: 1);

void main() {
  group('dishLiveStatus', () {
    final ScheduledDish d = _dish(fireAt: 5, finishAt: 12);

    test('is planned before the run starts (regardless of elapsed)', () {
      expect(dishLiveStatus(d, 99, started: false), DishLiveStatus.planned);
    });

    test('waiting → cooking → ready as elapsed crosses fire/finish', () {
      expect(dishLiveStatus(d, 0, started: true), DishLiveStatus.waiting);
      expect(dishLiveStatus(d, 4.9, started: true), DishLiveStatus.waiting);
      expect(dishLiveStatus(d, 5, started: true), DishLiveStatus.cooking);
      expect(dishLiveStatus(d, 11.9, started: true), DishLiveStatus.cooking);
      expect(dishLiveStatus(d, 12, started: true), DishLiveStatus.ready);
      expect(dishLiveStatus(d, 50, started: true), DishLiveStatus.ready);
    });

    test('strict coursing: held between own finish and the ticket plate time', () {
      // Cook finishes at 12, but the table doesn't plate until 15.
      expect(dishLiveStatus(d, 11.9, started: true, plateMins: 15),
          DishLiveStatus.cooking);
      expect(dishLiveStatus(d, 12, started: true, plateMins: 15),
          DishLiveStatus.held); // cooked, waiting under the lamp for siblings
      expect(dishLiveStatus(d, 14.9, started: true, plateMins: 15),
          DishLiveStatus.held);
      expect(dishLiveStatus(d, 15, started: true, plateMins: 15),
          DishLiveStatus.ready); // whole ticket plates together
    });

    test('plateMins == own finish never holds (the slowest line of its ticket)', () {
      expect(dishLiveStatus(d, 12, started: true, plateMins: 12),
          DishLiveStatus.ready);
    });

    test('omitting plateMins keeps the kitchen behaviour (ready at own finish)', () {
      expect(dishLiveStatus(d, 12, started: true), DishLiveStatus.ready);
    });
  });

  group('ticketLiveStage', () {
    // plate at 12, retain 3 → allReady in [12, 15), served at/after 15.
    final TicketStatus t = _ticket(plateMins: 12);

    test('is planned before the run starts (regardless of elapsed)', () {
      expect(
        ticketLiveStage(t, 99, started: false, retainMins: 3),
        TicketLiveStage.planned,
      );
    });

    test('active → allReady → served as elapsed crosses plate/retain', () {
      expect(ticketLiveStage(t, 0, started: true, retainMins: 3),
          TicketLiveStage.active);
      expect(ticketLiveStage(t, 11.9, started: true, retainMins: 3),
          TicketLiveStage.active);
      expect(ticketLiveStage(t, 12, started: true, retainMins: 3),
          TicketLiveStage.allReady);
      expect(ticketLiveStage(t, 14.9, started: true, retainMins: 3),
          TicketLiveStage.allReady);
      expect(ticketLiveStage(t, 15, started: true, retainMins: 3),
          TicketLiveStage.served);
      expect(ticketLiveStage(t, 99, started: true, retainMins: 3),
          TicketLiveStage.served);
    });

    test('flips to allReady exactly when the last dish flips to ready', () {
      // plateMins == max(finishAt); both use the same half-open boundary.
      final ScheduledDish last = _dish(fireAt: 5, finishAt: 12);
      expect(dishLiveStatus(last, 11.9, started: true), DishLiveStatus.cooking);
      expect(ticketLiveStage(t, 11.9, started: true, retainMins: 3),
          TicketLiveStage.active);
      expect(dishLiveStatus(last, 12, started: true), DishLiveStatus.ready);
      expect(ticketLiveStage(t, 12, started: true, retainMins: 3),
          TicketLiveStage.allReady);
    });

    test('retainMins: 0 goes straight from active to served at plate', () {
      expect(ticketLiveStage(t, 11.9, started: true, retainMins: 0),
          TicketLiveStage.active);
      expect(ticketLiveStage(t, 12, started: true, retainMins: 0),
          TicketLiveStage.served);
    });

    test('dish-less ticket ages out by its target time', () {
      // ticketStatusFor sets plateMins == targetMins when there are no dishes.
      final TicketStatus empty = _ticket(plateMins: 9, targetMins: 9);
      expect(ticketLiveStage(empty, 8.9, started: true, retainMins: 3),
          TicketLiveStage.active);
      expect(ticketLiveStage(empty, 9, started: true, retainMins: 3),
          TicketLiveStage.allReady);
      expect(ticketLiveStage(empty, 12, started: true, retainMins: 3),
          TicketLiveStage.served);
    });
  });

  group('dishServed', () {
    // A batched cook shared by tickets A (plate 5) and B (plate 20).
    final ScheduledDish shared = _dish(
      fireAt: 0,
      finishAt: 5,
      members: <ScheduledMember>[_member('A'), _member('B')],
    );
    final Map<String, TicketStatus> status = <String, TicketStatus>{
      'A': _ticket(plateMins: 5),
      'B': _ticket(plateMins: 20),
    };
    TicketStatus lookup(String id) => status[id]!;

    test('not served before the run starts', () {
      expect(
        dishServed(shared, lookup, 99, started: false, retainMins: 3),
        isFalse,
      );
    });

    test('stays until EVERY member ticket is served', () {
      // A served at 8 (5+3); B not until 23 (20+3). At 10, B still active.
      expect(dishServed(shared, lookup, 10, started: true, retainMins: 3),
          isFalse);
      // Past B's plate+retain, both are served.
      expect(dishServed(shared, lookup, 23, started: true, retainMins: 3),
          isTrue);
    });

    test('an unmembered cook is never served', () {
      final ScheduledDish orphan = _dish(fireAt: 0, finishAt: 5);
      expect(dishServed(orphan, lookup, 99, started: true, retainMins: 3),
          isFalse);
    });
  });

  group('ServiceClockState', () {
    test('elapsedMins converts duration to minutes', () {
      const ServiceClockState s =
          ServiceClockState(elapsed: Duration(seconds: 90));
      expect(s.elapsedMins, 1.5);
    });

    test('started is true while running or after any elapsed', () {
      expect(const ServiceClockState().started, isFalse);
      expect(const ServiceClockState(running: true).started, isTrue);
      expect(
        const ServiceClockState(elapsed: Duration(seconds: 1)).started,
        isTrue,
      );
    });
  });

  group('ServiceClockCubit', () {
    test('starts at zero, default speed 8, not running', () {
      final ServiceClockCubit cubit = ServiceClockCubit();
      expect(cubit.state.elapsed, Duration.zero);
      expect(cubit.state.speed, 8);
      expect(cubit.state.running, isFalse);
      cubit.close();
    });

    test('start runs from zero; pause stops; reset clears; setSpeed updates', () {
      final ServiceClockCubit cubit = ServiceClockCubit();

      cubit.setSpeed(30);
      expect(cubit.state.speed, 30);

      cubit.start();
      expect(cubit.state.running, isTrue);
      expect(cubit.state.elapsed, Duration.zero);
      expect(cubit.state.speed, 30); // start keeps the chosen speed

      cubit.pause(); // cancels the ticker
      expect(cubit.state.running, isFalse);

      cubit.reset();
      expect(cubit.state, const ServiceClockState());

      cubit.close();
    });
  });
}
