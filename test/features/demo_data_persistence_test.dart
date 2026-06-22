import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/db/database.dart';
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
}
