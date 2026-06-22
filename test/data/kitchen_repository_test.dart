import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/domain/scheduler/models.dart';

void main() {
  late AppDatabase db;
  late KitchenRepository repo;
  final DateTime now = DateTime(2026, 1, 1, 12);

  setUp(() {
    db = AppDatabase.memory();
    repo = KitchenRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('starts empty', () async {
    final DemoData snap = await repo.loadSnapshot();
    expect(snap.stations, isEmpty);
    expect(snap.menu, isEmpty);
    expect(snap.kots, isEmpty);
    expect(await repo.isSeeded, isFalse);
  });

  test('seeds the prototype stations/menu/tickets', () async {
    final DemoData snap = await repo.seedSampleData(now: now);
    expect(snap.stations, hasLength(9));
    expect(snap.menu, hasLength(14));
    expect(snap.kots, hasLength(4));
    expect(snap.totalDishes, 12);
    expect(await repo.isSeeded, isTrue);
  });

  test('round-trips ticket lines and types through Drift', () async {
    await repo.seedSampleData(now: now);
    final DemoData snap = await repo.loadSnapshot();
    final Kot t5 = snap.kots.firstWhere((Kot k) => k.id == 'demo-kot-1');
    expect(t5.table, '5');
    expect(t5.type, KotType.dineIn);
    expect(t5.lines, hasLength(3));
    final Kot d21 = snap.kots.firstWhere((Kot k) => k.id == 'demo-kot-4');
    expect(d21.type, KotType.delivery);
  });

  test('seeding is idempotent', () async {
    await repo.seedSampleData(now: now);
    await repo.seedSampleData(now: now);
    final DemoData snap = await repo.loadSnapshot();
    expect(snap.stations, hasLength(9));
    expect(snap.kots, hasLength(4));
  });

  test('the Drift-sourced snapshot still produces the golden schedule', () async {
    final DemoData snap = await repo.seedSampleData(now: now);
    final BoardData board = BoardData.from(snap, now: now);
    expect(board.schedule.horizonMins, 22);
    final Bottleneck? b = board.schedule.bottleneck;
    expect(b?.stationId, 'steam');
    expect(b?.lateMins, 9);
  });

  test('addKot appends a ticket; clearKots keeps config', () async {
    await repo.seedSampleData(now: now);
    await repo.addKot(
      Kot(
        id: 'extra-1',
        table: '9',
        type: KotType.takeaway,
        orderedAt: now,
        lines: <OrderLine>[
          const OrderLine(dishId: 'french-fries', qty: 2),
        ],
      ),
    );
    expect((await repo.loadSnapshot()).kots, hasLength(5));

    await repo.clearKots();
    final DemoData cleared = await repo.loadSnapshot();
    expect(cleared.kots, isEmpty);
    expect(cleared.stations, hasLength(9)); // config preserved
    expect(cleared.menu, hasLength(14));
  });

  test('addKot with ad-hoc dishes adds them to the menu and they resolve',
      () async {
    await repo.seedSampleData(now: now);
    const Dish adhoc = Dish(
      id: 'adhoc-lobster',
      name: 'Lobster Bisque',
      emoji: '🍽️',
      stationId: 'grill',
      cookMins: 9,
      holdable: true,
      batchable: false,
    );
    await repo.addKot(
      Kot(
        id: 'scan-1',
        table: '12',
        type: KotType.dineIn,
        orderedAt: now,
        lines: <OrderLine>[const OrderLine(dishId: 'adhoc-lobster', qty: 1)],
      ),
      newDishes: <Dish>[adhoc],
    );

    final DemoData snap = await repo.loadSnapshot();
    // The off-menu dish joined the menu (14 seed + 1) and resolves on hydrate.
    expect(snap.menu, hasLength(15));
    final Kot kot = snap.kots.firstWhere((Kot k) => k.id == 'scan-1');
    final Dish resolved =
        snap.menu.firstWhere((Dish d) => d.id == kot.lines.single.dishId);
    expect(resolved.name, 'Lobster Bisque');
    expect(resolved.cookMins, 9);
  });

  test('updateStationCapacity persists and eases the bottleneck', () async {
    await repo.seedSampleData(now: now);
    final BoardData before = BoardData.from(await repo.loadSnapshot(), now: now);
    expect(before.schedule.bottleneck?.stationId, 'steam');
    final int beforeLate = before.schedule.bottleneck?.lateMins ?? 0;

    await repo.updateStationCapacity('steam', 2);

    final DemoData snap = await repo.loadSnapshot();
    expect(
      snap.stations.firstWhere((Station s) => s.id == 'steam').capacity,
      2,
    );
    // A second steamer lets the contended cooks run concurrently → less late.
    final BoardData after = BoardData.from(snap, now: now);
    final int afterLate = after.schedule.bottleneck?.lateMins ?? 0;
    expect(afterLate, lessThan(beforeLate));
  });

  test('watchSnapshot emits on seed', () async {
    final Future<DemoData> seeded =
        repo.watchSnapshot().firstWhere((DemoData d) => d.kots.isNotEmpty);
    await repo.seedSampleData(now: now);
    final DemoData snap = await seeded;
    expect(snap.kots, hasLength(4));
  });
}
