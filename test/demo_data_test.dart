import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';

/// A clock pinned to a fixed instant, so demo data is fully deterministic.
class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  final DateTime now = DateTime(2026, 6, 21, 12);

  group('buildDemoData', () {
    final DemoData data = buildDemoData(now: now);

    test('seeds the prototype stations, menu and tickets', () {
      expect(data.stations, hasLength(9));
      expect(data.menu, hasLength(14));
      expect(data.kots, hasLength(4));
      expect(data.totalDishes, 12); // 4 + 3 + 3 + 2 line quantities
    });

    test('is deterministic for a fixed now', () {
      expect(buildDemoData(now: now).kots, buildDemoData(now: now).kots);
    });

    test('anchors order times relative to now', () {
      final Kot first = data.kots.firstWhere((Kot k) => k.id == 'demo-kot-1');
      expect(first.orderedAt, now.subtract(const Duration(minutes: 2)));
    });

    test('every line references a known dish', () {
      final Set<String> dishIds = data.menu.map((Dish d) => d.id).toSet();
      for (final Kot kot in data.kots) {
        for (final OrderLine line in kot.lines) {
          expect(dishIds, contains(line.dishId));
        }
      }
    });
  });

  group('BoardData (scheduler-backed)', () {
    final BoardData board = BoardData.from(buildDemoData(now: now), now: now);

    test('produces a non-empty schedule', () {
      expect(board.schedule.dishes, isNotEmpty);
    });

    test('fireOrder is sorted by fire time', () {
      final List<ScheduledDish> order = board.fireOrder;
      expect(order, isNotEmpty);
      for (int i = 1; i < order.length; i++) {
        expect(order[i - 1].fireAt, lessThanOrEqualTo(order[i].fireAt));
      }
    });

    test('station lanes only include stations with dishes, within capacity', () {
      final List<({Station station, StationLane lane})> sections =
          board.stationLanes;
      expect(sections, isNotEmpty);
      for (final ({Station station, StationLane lane}) s in sections) {
        expect(s.lane.dishes, isNotEmpty);
        expect(s.lane.lanes, lessThanOrEqualTo(s.station.capacity));
      }
    });

    test('every ticket has a plate status', () {
      for (final Kot kot in board.data.kots) {
        expect(board.statusOf(kot).dishes, isNotEmpty);
      }
    });
  });

  group('DemoDataCubit', () {
    test('starts empty, generates, and clears', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
      expect(cubit.state.hasData, isFalse);

      cubit.generate();
      expect(cubit.state.hasData, isTrue);
      // No AI key in tests → the randomized fallback, which is longer than the
      // old static 4-ticket sample.
      expect(cubit.state.data!.kots.length, greaterThanOrEqualTo(6));
      expect(cubit.state.data!.stations, hasLength(9)); // fixed config kept
      expect(cubit.state.generatedAt, now);

      cubit.clear();
      expect(cubit.state.hasData, isFalse);
    });

    test('seedFromScan bootstraps a board when there is none', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
      expect(cubit.state.hasData, isFalse);

      const Station grill =
          Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 2);
      const Dish stew = Dish(
        id: 'adhoc-1',
        name: 'Mystery Stew',
        emoji: '🍲',
        stationId: 'grill',
        cookMins: 9,
        holdable: true,
        batchable: false,
      );
      final Kot kot = Kot(
        id: 'k1',
        table: '7',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(dishId: 'adhoc-1', qty: 2)],
      );

      cubit.seedFromScan(
        stations: <Station>[grill],
        menu: <Dish>[stew],
        kot: kot,
      );

      expect(cubit.state.hasData, isTrue);
      expect(cubit.state.data!.stations.single.id, 'grill');
      expect(cubit.state.data!.menu.single.id, 'adhoc-1');
      expect(cubit.state.data!.kots.single.table, '7');
      expect(cubit.state.generatedAt, now);
      cubit.close();
    });

    test('setStationCapacity updates one station, clamped to ≥1', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
      cubit.generate();
      int capOf(String id) =>
          cubit.state.data!.stations.firstWhere((Station s) => s.id == id).capacity;

      expect(capOf('steam'), 1);
      cubit.setStationCapacity('steam', 3);
      expect(capOf('steam'), 3);
      expect(capOf('grill'), 2); // others untouched

      cubit.setStationCapacity('steam', 0); // floored at 1
      expect(capOf('steam'), 1);
      cubit.close();
    });

    test('setStationCapacity is a no-op without data', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
      cubit.setStationCapacity('steam', 3);
      expect(cubit.state.hasData, isFalse);
      cubit.close();
    });

    test('setLineNote sets (trimmed) and clears a line note in memory', () {
      final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
      cubit.generate();
      final String id = cubit.state.data!.kots
          .expand((Kot k) => k.lines)
          .firstWhere((OrderLine l) => l.id != null)
          .id!;
      OrderLine lineNow() => cubit.state.data!.kots
          .expand((Kot k) => k.lines)
          .firstWhere((OrderLine l) => l.id == id);

      cubit.setLineNote(id, '  no salt  ');
      expect(lineNow().note, 'no salt'); // trimmed

      cubit.setLineNote(id, '   '); // whitespace-only clears it
      expect(lineNow().note, isNull);
      cubit.close();
    });
  });
}
