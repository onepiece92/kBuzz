import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:kbuzz/data/db/tables.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// The app's Drift database — the local source of truth (AGENTS.md §0.2 / §5).
///
/// DAO-style watch/query methods live here for the four tables. Reads filter
/// `deleted = false` (tombstone pattern). Use [AppDatabase.memory] in tests.
@DriftDatabase(tables: <Type>[Stations, MenuItems, Kots, OrderLines])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-disk database (default for the running app).
  AppDatabase() : super(_openOnDisk());

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          // v1 → v2: waiter ticket-state columns (TICKETS.md).
          if (from < 2) {
            await m.addColumn(orderLines, orderLines.state);
            await m.addColumn(orderLines, orderLines.recook);
            await m.addColumn(orderLines, orderLines.reAtMins);
            await m.addColumn(orderLines, orderLines.reason);
            await m.addColumn(kots, kots.status);
            await m.addColumn(kots, kots.rush);
          }
        },
      );

  Stream<List<StationRow>> watchStations() =>
      (select(stations)..where((Stations t) => t.deleted.equals(false)))
          .watch();

  Stream<List<MenuItemRow>> watchMenu() =>
      (select(menuItems)..where((MenuItems t) => t.deleted.equals(false)))
          .watch();

  Stream<List<KotRow>> watchKots() =>
      (select(kots)..where((Kots t) => t.deleted.equals(false))).watch();

  Stream<List<OrderLineRow>> watchOrderLines() =>
      (select(orderLines)..where((OrderLines t) => t.deleted.equals(false)))
          .watch();

  Future<List<StationRow>> allStations() =>
      (select(stations)..where((Stations t) => t.deleted.equals(false))).get();

  Future<List<MenuItemRow>> allMenu() =>
      (select(menuItems)..where((MenuItems t) => t.deleted.equals(false)))
          .get();

  Future<List<KotRow>> allKots() =>
      (select(kots)..where((Kots t) => t.deleted.equals(false))).get();

  Future<List<OrderLineRow>> allOrderLines() =>
      (select(orderLines)..where((OrderLines t) => t.deleted.equals(false)))
          .get();
}

LazyDatabase _openOnDisk() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'kbuzz.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
