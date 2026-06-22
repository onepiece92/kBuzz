import 'dart:async';

import 'package:drift/drift.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:uuid/uuid.dart';

/// The only data API the app uses for kitchen config + tickets (AGENTS.md §2).
///
/// Backed by Drift (the local source of truth). It maps rows ↔ domain entities
/// and bundles them into a [DemoData] snapshot — the same shape the boards
/// already consume via `BoardData.from(...)` — so the UI is unchanged when it
/// switches from the in-memory demo cubit to this repository.
class KitchenRepository {
  KitchenRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  /// Reactive snapshot of stations + menu + tickets. Emits whenever any of the
  /// four tables changes (combine-latest over the table streams).
  Stream<DemoData> watchSnapshot() {
    final StreamController<DemoData> controller = StreamController<DemoData>();
    List<StationRow>? s;
    List<MenuItemRow>? m;
    List<KotRow>? k;
    List<OrderLineRow>? l;

    void maybeEmit() {
      if (s != null && m != null && k != null && l != null) {
        controller.add(_assemble(s!, m!, k!, l!));
      }
    }

    final List<StreamSubscription<dynamic>> subs = <StreamSubscription<dynamic>>[
      _db.watchStations().listen((List<StationRow> v) {
        s = v;
        maybeEmit();
      }),
      _db.watchMenu().listen((List<MenuItemRow> v) {
        m = v;
        maybeEmit();
      }),
      _db.watchKots().listen((List<KotRow> v) {
        k = v;
        maybeEmit();
      }),
      _db.watchOrderLines().listen((List<OrderLineRow> v) {
        l = v;
        maybeEmit();
      }),
    ];

    controller.onCancel = () async {
      for (final StreamSubscription<dynamic> sub in subs) {
        await sub.cancel();
      }
    };
    return controller.stream;
  }

  /// One-shot snapshot (used by tests / non-reactive callers).
  Future<DemoData> loadSnapshot() async {
    return _assemble(
      await _db.allStations(),
      await _db.allMenu(),
      await _db.allKots(),
      await _db.allOrderLines(),
    );
  }

  /// True once the stations/menu config has been seeded.
  Future<bool> get isSeeded async => (await _db.allStations()).isNotEmpty;

  /// Seed the prototype's stations/menu/tickets. Idempotent — no-op if already
  /// seeded. Returns the resulting snapshot.
  Future<DemoData> seedSampleData({required DateTime now}) async {
    if (await isSeeded) return loadSnapshot();
    await _db.transaction(() => _insertSnapshot(buildDemoData(now: now)));
    return loadSnapshot();
  }

  /// Replace the entire dataset (config + tickets) with [data] in one
  /// transaction. Used by the AI generator, which produces a brand-new
  /// stations/menu/tickets bundle each time (unlike the idempotent
  /// [seedSampleData]).
  Future<DemoData> replaceAll(DemoData data) async {
    await _db.transaction(() async {
      await _deleteAll();
      await _insertSnapshot(data);
    });
    return loadSnapshot();
  }

  /// Bulk-insert a whole snapshot. Caller must wrap this in a transaction.
  Future<void> _insertSnapshot(DemoData demo) async {
    await _db.batch((Batch b) {
      b.insertAll(_db.stations, <StationsCompanion>[
        for (final Station st in demo.stations)
          StationsCompanion.insert(
            id: st.id,
            name: st.name,
            color: st.color,
            capacity: st.capacity,
          ),
      ]);
      b.insertAll(_db.menuItems, <MenuItemsCompanion>[
        for (final Dish d in demo.menu)
          MenuItemsCompanion.insert(
            id: d.id,
            name: d.name,
            emoji: d.emoji,
            stationId: d.stationId,
            cookMins: d.cookMins,
            holdable: d.holdable,
            batchable: d.batchable,
          ),
      ]);
    });
    for (final Kot kot in demo.kots) {
      await _insertKot(kot);
    }
  }

  /// Update a single station's concurrent [capacity] (the only station field the
  /// UI edits today). Marks the row dirty for the eventual sync engine.
  Future<void> updateStationCapacity(String stationId, int capacity) {
    return (_db.update(_db.stations)..where((t) => t.id.equals(stationId)))
        .write(
      StationsCompanion(
        capacity: Value<int>(capacity),
        dirty: const Value<bool>(true),
      ),
    );
  }

  // --- Waiter ticket actions (TICKETS.md) ------------------------------------
  // Each writes the line/ticket immediately and marks the row dirty for the
  // (future) sync engine. `reAtMins` is the board-relative minute the caller
  // (the cubit, from the service clock) re-fired at.

  Future<void> _writeLine(String lineId, OrderLinesCompanion patch) =>
      (_db.update(_db.orderLines)..where((t) => t.id.equals(lineId)))
          .write(patch.copyWith(dirty: const Value<bool>(true)));

  Future<void> _writeKot(String kotId, KotsCompanion patch) =>
      (_db.update(_db.kots)..where((t) => t.id.equals(kotId)))
          .write(patch.copyWith(dirty: const Value<bool>(true)));

  /// Mark a line served (leaves the schedule).
  Future<void> serveLine(String lineId) => _writeLine(
      lineId, const OrderLinesCompanion(state: Value<String>('served')));

  /// Re-open a served line (re-enters the schedule).
  Future<void> unserveLine(String lineId) => _writeLine(
      lineId, const OrderLinesCompanion(state: Value<String>('open')));

  /// 86 a line (excluded from the schedule, restorable).
  Future<void> voidLine(String lineId) => _writeLine(
      lineId, const OrderLinesCompanion(state: Value<String>('void')));

  /// Restore a voided line to open.
  Future<void> restoreLine(String lineId) => _writeLine(
      lineId, const OrderLinesCompanion(state: Value<String>('open')));

  /// Serve every non-void line of a ticket at once.
  Future<void> serveAll(String kotId) => (_db.update(_db.orderLines)
        ..where((t) =>
            t.kotId.equals(kotId) & t.state.equals('void').not()))
      .write(const OrderLinesCompanion(
        state: Value<String>('served'),
        dirty: Value<bool>(true),
      ));

  /// Send a line back: reopen it, bump the recook count, set `reAt`+reason so it
  /// re-fires now with priority, and auto-reopen the ticket if it was done.
  Future<void> recookLine(
    String lineId, {
    required String reason,
    required int reAtMins,
  }) =>
      _db.transaction(() async {
        final OrderLineRow? row = await (_db.select(_db.orderLines)
              ..where((t) => t.id.equals(lineId)))
            .getSingleOrNull();
        if (row == null) return;
        await _writeLine(
          lineId,
          OrderLinesCompanion(
            state: const Value<String>('open'),
            recook: Value<int>(row.recook + 1),
            reAtMins: Value<int?>(reAtMins),
            reason: Value<String?>(reason),
          ),
        );
        await _writeKot(
          row.kotId,
          const KotsCompanion(status: Value<String>('active')),
        );
      });

  /// Expedite / fire-missing: re-fire a line now with priority, no reason.
  Future<void> fireNowLine(String lineId, {required int reAtMins}) => _writeLine(
        lineId,
        OrderLinesCompanion(
          state: const Value<String>('open'),
          reAtMins: Value<int?>(reAtMins),
          reason: const Value<String?>(null),
        ),
      );

  /// Toggle a ticket's rush flag (tightens its SLA + prioritises all lines).
  Future<void> setRush(String kotId, {required bool on}) =>
      _writeKot(kotId, KotsCompanion(rush: Value<bool>(on)));

  /// Close a ticket.
  Future<void> markDone(String kotId) =>
      _writeKot(kotId, const KotsCompanion(status: Value<String>('done')));

  /// Re-open a closed ticket.
  Future<void> reopenTicket(String kotId) =>
      _writeKot(kotId, const KotsCompanion(status: Value<String>('active')));

  /// Append a ticket and its lines. [newDishes] are off-menu (scanned ad-hoc)
  /// dishes the lines reference — inserted into the menu first (ignore-on-exist)
  /// in the same transaction so the rows resolve on hydrate and the FK holds.
  Future<void> addKot(Kot kot, {List<Dish> newDishes = const <Dish>[]}) =>
      _db.transaction(() async {
        for (final Dish d in newDishes) {
          await _db.into(_db.menuItems).insert(
                MenuItemsCompanion.insert(
                  id: d.id,
                  name: d.name,
                  emoji: d.emoji,
                  stationId: d.stationId,
                  cookMins: d.cookMins,
                  holdable: d.holdable,
                  batchable: d.batchable,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
        await _insertKot(kot);
      });

  Future<void> _insertKot(Kot kot) async {
    await _db.into(_db.kots).insert(
          KotsCompanion.insert(
            id: kot.id,
            tableLabel: kot.table,
            type: kot.type.name,
            orderedAt: kot.orderedAt,
          ),
        );
    await _db.batch((Batch b) {
      b.insertAll(_db.orderLines, <OrderLinesCompanion>[
        for (final OrderLine line in kot.lines)
          OrderLinesCompanion.insert(
            id: line.id ?? _uuid.v4(),
            kotId: kot.id,
            dishId: line.dishId,
            qty: line.qty,
            cookOverrideMins: Value<int?>(line.cookOverrideMins),
          ),
      ]);
    });
  }

  /// Remove all tickets + lines (keeps the stations/menu config).
  Future<void> clearKots() => _db.transaction(() async {
        await _db.delete(_db.orderLines).go();
        await _db.delete(_db.kots).go();
      });

  /// Wipe everything (config + tickets).
  Future<void> clearAll() => _db.transaction(_deleteAll);

  /// Delete every row across all four tables. Caller must wrap in a transaction.
  Future<void> _deleteAll() async {
    await _db.delete(_db.orderLines).go();
    await _db.delete(_db.kots).go();
    await _db.delete(_db.menuItems).go();
    await _db.delete(_db.stations).go();
  }

  DemoData _assemble(
    List<StationRow> s,
    List<MenuItemRow> m,
    List<KotRow> k,
    List<OrderLineRow> l,
  ) {
    final List<Station> stations = <Station>[
      for (final StationRow r in s)
        Station(id: r.id, name: r.name, color: r.color, capacity: r.capacity),
    ];
    final List<Dish> menu = <Dish>[
      for (final MenuItemRow r in m)
        Dish(
          id: r.id,
          name: r.name,
          emoji: r.emoji,
          stationId: r.stationId,
          cookMins: r.cookMins,
          holdable: r.holdable,
          batchable: r.batchable,
        ),
    ];
    final Map<String, List<OrderLine>> linesByKot = <String, List<OrderLine>>{};
    for (final OrderLineRow r in l) {
      (linesByKot[r.kotId] ??= <OrderLine>[]).add(
        OrderLine(
          id: r.id,
          dishId: r.dishId,
          qty: r.qty,
          cookOverrideMins: r.cookOverrideMins,
          state: LineState.fromWire(r.state),
          recook: r.recook,
          reAt: r.reAtMins,
          reason: r.reason,
        ),
      );
    }
    final List<Kot> kots = <Kot>[
      for (final KotRow r in k)
        Kot(
          id: r.id,
          table: r.tableLabel,
          type: KotType.values.byName(r.type),
          orderedAt: r.orderedAt,
          lines: linesByKot[r.id] ?? const <OrderLine>[],
          status: TicketState.fromWire(r.status),
          rush: r.rush,
        ),
    ];
    return DemoData(stations: stations, menu: menu, kots: kots);
  }
}
