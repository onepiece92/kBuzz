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
@DriftDatabase(tables: <Type>[Stations, MenuItems, Kots, OrderLines, BoardMeta])
class AppDatabase extends _$AppDatabase {
  /// Opens the on-disk database (default for the running app).
  AppDatabase() : super(_openOnDisk());

  /// In-memory database for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 4;

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
          // v2 → v3: per-line special instruction (note).
          if (from < 3) {
            await m.addColumn(orderLines, orderLines.note);
          }
          // v3 → v4: durable board epoch + run speed (additive — only creates the
          // new table; existing tickets/orderedAt are untouched).
          if (from < 4) {
            await m.createTable(boardMeta);
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

  // --- Board session meta (the durable board epoch + run speed) --------------
  // A single row keyed by the fixed id 'board'. Read/written through these
  // helpers so the epoch survives a restart (the schedule's `now` + the run
  // clock re-anchor to it instead of re-stamping wall-now).
  static const String _boardMetaId = 'board';

  Future<BoardMetaRow?> _boardMetaRow() =>
      (select(boardMeta)
            ..where((BoardMeta t) =>
                t.id.equals(_boardMetaId) & t.deleted.equals(false)))
          .getSingleOrNull();

  /// The persisted board epoch (null if never set / cleared).
  Future<DateTime?> loadEpoch() async {
    final int? ms = (await _boardMetaRow())?.epochMs;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// The persisted run-speed multiplier (null if never set).
  Future<int?> loadSpeed() async => (await _boardMetaRow())?.speed;

  /// Reactive board-meta row (null until first written / after clear).
  Stream<BoardMetaRow?> watchBoardMeta() => (select(boardMeta)
        ..where((BoardMeta t) =>
            t.id.equals(_boardMetaId) & t.deleted.equals(false)))
      .watchSingleOrNull();

  /// Upsert the board epoch, leaving any persisted speed untouched (partial
  /// companion ⇒ only `epochMs`/`deleted` are written on conflict).
  Future<void> saveEpoch(DateTime? epoch) =>
      into(boardMeta).insertOnConflictUpdate(
        BoardMetaCompanion.insert(
          id: _boardMetaId,
          epochMs: Value<int?>(epoch?.millisecondsSinceEpoch),
          deleted: const Value<bool>(false),
        ),
      );

  /// Upsert the run speed, leaving any persisted epoch untouched.
  Future<void> saveSpeed(int speed) => into(boardMeta).insertOnConflictUpdate(
        BoardMetaCompanion.insert(
          id: _boardMetaId,
          speed: Value<int>(speed),
          deleted: const Value<bool>(false),
        ),
      );

  /// Drop the board-meta row entirely (used by clear/replace so no stale epoch
  /// lingers).
  Future<void> deleteBoardMeta() => delete(boardMeta).go();
}

LazyDatabase _openOnDisk() {
  return LazyDatabase(() async {
    final Directory dir = await getApplicationDocumentsDirectory();
    final File file = File(p.join(dir.path, 'kbuzz.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
