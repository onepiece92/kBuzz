import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);
  late AppDatabase db;
  late KitchenRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    repo = KitchenRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('generate() writes through to Drift', () async {
    final DemoDataCubit cubit =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));
    await cubit.settled; // hydrate (empty)
    cubit.generate();
    await cubit.settled; // write-through
    // Randomized fallback (no AI key) → a non-empty rush persisted to Drift.
    expect((await repo.loadSnapshot()).kots, isNotEmpty);
    await cubit.close();
  });

  test('a fresh cubit hydrates persisted data from Drift (survives restart)',
      () async {
    await repo.seedSampleData(now: now);
    final DemoDataCubit cubit =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));
    await cubit.settled; // hydrate
    expect(cubit.state.hasData, isTrue);
    expect(cubit.state.data!.kots, hasLength(4));
    await cubit.close();
  });

  test('addKot persists the new ticket', () async {
    final DemoDataCubit cubit =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));
    await cubit.settled;
    cubit.generate();
    await cubit.settled;
    final int before = (await repo.loadSnapshot()).kots.length;
    cubit.addKot(
      Kot(
        id: 'p1',
        table: '9',
        type: KotType.takeaway,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(dishId: 'french-fries', qty: 1)],
      ),
    );
    await cubit.settled;
    expect((await repo.loadSnapshot()).kots, hasLength(before + 1));
    await cubit.close();
  });

  test('clear() wipes Drift', () async {
    final DemoDataCubit cubit =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));
    await cubit.settled;
    cubit.generate();
    await cubit.settled;
    cubit.clear();
    await cubit.settled;
    expect((await repo.loadSnapshot()).stations, isEmpty);
    await cubit.close();
  });

  test('without a repository it is a pure in-memory store', () async {
    final DemoDataCubit cubit = DemoDataCubit(clock: _FixedClock(now));
    cubit.generate();
    expect(cubit.state.hasData, isTrue); // synchronous, no persistence
    cubit.close();
  });

  group('board-epoch durability (Phase 2)', () {
    test('replaceAll persists epoch + speed; loadSnapshot returns them', () async {
      final DemoData seed = buildDemoData(now: now).copyWith(
        generatedAt: now,
        speed: 8,
      );
      await repo.replaceAll(seed);

      expect(await repo.loadEpoch(), now);
      expect(await repo.loadSpeed(), 8);
      final DemoData back = await repo.loadSnapshot();
      expect(back.generatedAt, now);
      expect(back.speed, 8);
    });

    test('saveEpoch and saveSpeed are independent partial upserts', () async {
      await repo.saveSpeed(30); // speed first, no epoch yet
      expect(await repo.loadEpoch(), isNull);
      expect(await repo.loadSpeed(), 30);

      await repo.saveSpeed(1); // updating speed must not wipe... (none yet)
      final DateTime e = DateTime(2026, 1, 1, 18, 30);
      await repo.replaceAll(buildDemoData(now: now).copyWith(generatedAt: e));
      // replaceAll cleared then set epoch; speed was cleared with the board.
      expect(await repo.loadEpoch(), e);
    });

    test('a fresh cubit restores the persisted epoch — NOT the restart clock',
        () async {
      final DemoDataCubit cubit =
          DemoDataCubit(repository: repo, clock: _FixedClock(now));
      await cubit.settled;
      cubit.generate(); // stamps + persists epoch == now
      await cubit.settled;
      await cubit.close();

      // Restart an hour later: the board must resume at the ORIGINAL epoch.
      final DemoDataCubit reloaded = DemoDataCubit(
        repository: repo,
        clock: _FixedClock(now.add(const Duration(hours: 1))),
      );
      await reloaded.settled;
      expect(reloaded.state.generatedAt, now);
      expect(reloaded.restoredFromStore, isTrue);
      await reloaded.close();
    });

    test('v3 back-compat: no persisted epoch resumes at the earliest order',
        () async {
      // seedSampleData inserts orders WITHOUT writing an epoch (a pre-v4 board).
      await repo.seedSampleData(now: now);
      expect(await repo.loadEpoch(), isNull);

      final DemoDataCubit cubit = DemoDataCubit(
        repository: repo,
        clock: _FixedClock(now.add(const Duration(hours: 1))),
      );
      await cubit.settled;
      // Earliest sample order is now − 2 min (demo-kot-1).
      expect(cubit.state.generatedAt, now.subtract(const Duration(minutes: 2)));
      expect(cubit.state.hasData, isTrue);
      await cubit.close();
    });

    test('clear() removes the persisted epoch', () async {
      final DemoDataCubit cubit =
          DemoDataCubit(repository: repo, clock: _FixedClock(now));
      await cubit.settled;
      cubit.generate();
      await cubit.settled;
      expect(await repo.loadEpoch(), isNotNull);

      cubit.clear();
      await cubit.settled;
      expect(await repo.loadEpoch(), isNull);
      await cubit.close();
    });

    test('Reset clears all tickets + resets station capacities, keeps menu',
        () async {
      final DemoDataCubit cubit =
          DemoDataCubit(repository: repo, clock: _FixedClock(now));
      await cubit.settled;
      cubit.generate();
      await cubit.settled;
      final int stationCount = cubit.state.data!.stations.length;
      final int menuCount = cubit.state.data!.menu.length;
      final String firstStationId = cubit.state.data!.stations.first.id;
      final int startCap = cubit.state.data!.stations.first.capacity;

      cubit.snapshotForRun(); // pressed Start
      // Bump a station mid-run + drip a ticket in.
      cubit.setStationCapacity(firstStationId, startCap + 3);
      cubit.addKot(
        Kot(
          id: 'drip',
          table: '9',
          type: KotType.takeaway,
          orderedAt: now,
          lines: const <OrderLine>[OrderLine(dishId: 'french-fries', qty: 1)],
        ),
      );
      await cubit.settled;
      expect(cubit.state.data!.stations.first.capacity, startCap + 3);

      cubit.clearForFreshStart(); // pressed Reset
      await cubit.settled;
      // Tickets gone, restaurant kept, capacity back to the start-of-service value.
      expect(cubit.state.data!.kots, isEmpty);
      expect(cubit.state.data!.stations.length, stationCount);
      expect(cubit.state.data!.menu.length, menuCount);
      expect(cubit.state.data!.stations.first.capacity, startCap);

      final DemoData persisted = await repo.loadSnapshot();
      expect(persisted.kots, isEmpty); // wipe persisted
      expect(persisted.stations.length, stationCount);
      expect(
        persisted.stations
            .firstWhere((Station s) => s.id == firstStationId)
            .capacity,
        startCap,
      );
      await cubit.close();
    });
  });
}
