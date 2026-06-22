import 'package:drift/drift.dart';

/// Sync trailer carried by every synced table (AGENTS.md §5) so the (future)
/// sync engine and conflict resolution are uniform. Without Firebase yet, only
/// [id] is load-bearing; the rest are forward-compatible defaults.
mixin SyncCols on Table {
  TextColumn get id => text()(); // uuid / slug, client-generated
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
  IntColumn get version => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Cooking stations. Row class is `StationRow` to avoid colliding with the
/// domain `Station` (the repository maps between them).
@DataClassName('StationRow')
class Stations extends Table with SyncCols {
  TextColumn get name => text()();
  IntColumn get color => integer()(); // ARGB
  IntColumn get capacity => integer()();
}

/// Menu items. Row class `MenuItemRow` ↔ domain `Dish`.
@DataClassName('MenuItemRow')
class MenuItems extends Table with SyncCols {
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  TextColumn get stationId => text()();
  IntColumn get cookMins => integer()();
  BoolColumn get holdable => boolean()();
  BoolColumn get batchable => boolean()();
}

/// Tickets. Row class `KotRow` ↔ domain `Kot` (lines stored in [OrderLines]).
@DataClassName('KotRow')
class Kots extends Table with SyncCols {
  // `table` is awkward as a column name; store the label as `tableLabel`.
  TextColumn get tableLabel => text()();
  TextColumn get type => text()(); // KotType.name
  DateTimeColumn get orderedAt => dateTime()();
  // Waiter lifecycle (TICKETS.md): active|done + rush flag. Schema v2.
  TextColumn get status => text().withDefault(const Constant('active'))();
  BoolColumn get rush => boolean().withDefault(const Constant(false))();
}

/// Ticket lines. Row class `OrderLineRow` ↔ domain `OrderLine`.
@DataClassName('OrderLineRow')
class OrderLines extends Table with SyncCols {
  TextColumn get kotId => text()();
  TextColumn get dishId => text()();
  IntColumn get qty => integer()();
  IntColumn get cookOverrideMins => integer().nullable()();
  // Waiter line-state (TICKETS.md): open|served|void, recook count, re-fire
  // minute (board-relative) + recook reason. Schema v2.
  TextColumn get state => text().withDefault(const Constant('open'))();
  IntColumn get recook => integer().withDefault(const Constant(0))();
  IntColumn get reAtMins => integer().nullable()();
  TextColumn get reason => text().nullable()();
}
