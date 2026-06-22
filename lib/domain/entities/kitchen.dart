import 'package:equatable/equatable.dart';

/// Core kitchen domain entities (AGENTS.md §4), mirroring the `MultiKOT.jsx`
/// prototype.
///
/// This file is **Flutter-free by design** (AGENTS.md §3): no `package:flutter`
/// imports. Colours are stored as ARGB `int`s, not `Color`, so the domain layer
/// stays pure and unit-testable. The UI maps them to `Color(value)` at the
/// presentation boundary.

/// How a ticket is served — drives its SLA (mins from order to plate).
enum KotType {
  dineIn('Dine-in'),
  takeaway('Takeaway'),
  delivery('Delivery');

  const KotType(this.label);

  /// Human-readable label for chips/badges.
  final String label;
}

/// Waiter-driven persistent state of a ticket line (TICKETS.md). Distinct from
/// the *cooking* status (waiting/cooking/ready), which is derived from the clock.
enum LineState {
  open('open'),
  served('served'),
  voided('void'); // `void` is a Dart keyword; stored/labelled as "void".

  const LineState(this.wire);

  /// Stable storage/wire token.
  final String wire;

  static LineState fromWire(String w) => LineState.values
      .firstWhere((LineState s) => s.wire == w, orElse: () => LineState.open);
}

/// Waiter-driven lifecycle of a whole ticket (TICKETS.md).
enum TicketState {
  active('active'),
  done('done');

  const TicketState(this.wire);

  final String wire;

  static TicketState fromWire(String w) => TicketState.values
      .firstWhere((TicketState s) => s.wire == w, orElse: () => TicketState.active);
}

/// A cooking station with a finite concurrent [capacity].
class Station extends Equatable {
  const Station({
    required this.id,
    required this.name,
    required this.color,
    required this.capacity,
  });

  final String id;
  final String name;

  /// ARGB colour (e.g. `0xFFEF4444`). Encodes *station*, not brand (AGENTS.md §3).
  final int color;

  /// Max dishes that can cook concurrently at this station.
  final int capacity;

  /// A copy with selected fields replaced (e.g. an edited [capacity]).
  Station copyWith({String? id, String? name, int? color, int? capacity}) =>
      Station(
        id: id ?? this.id,
        name: name ?? this.name,
        color: color ?? this.color,
        capacity: capacity ?? this.capacity,
      );

  @override
  List<Object?> get props => <Object?>[id, name, color, capacity];
}

/// A menu item. [cookMins] is the predicted default; a line may override it.
class Dish extends Equatable {
  const Dish({
    required this.id,
    required this.name,
    required this.emoji,
    required this.stationId,
    required this.cookMins,
    required this.holdable,
    required this.batchable,
  });

  final String id;
  final String name;
  final String emoji;
  final String stationId;

  /// Predicted cook time in minutes.
  final int cookMins;

  /// Can rest off-heat after cooking (lets the scheduler fire it early).
  final bool holdable;

  /// Identical dishes can cook together within the batch window.
  final bool batchable;

  @override
  List<Object?> get props =>
      <Object?>[id, name, emoji, stationId, cookMins, holdable, batchable];
}

/// One line of a ticket: a dish + quantity, plus the waiter-driven state the
/// Tickets page mutates (TICKETS.md). New fields default to a plain open line,
/// so the scheduler behaves identically until a waiter acts.
class OrderLine extends Equatable {
  const OrderLine({
    required this.dishId,
    required this.qty,
    this.cookOverrideMins,
    this.id,
    this.state = LineState.open,
    this.recook = 0,
    this.reAt,
    this.reason,
  });

  /// Stable line id (assigned once persisted). Every waiter action targets it;
  /// null for lines not yet written to the store.
  final String? id;

  final String dishId;
  final int qty;

  /// Cook-time override (minutes) from the review screen; wins over
  /// [Dish.cookMins] when present.
  final int? cookOverrideMins;

  /// Waiter-set persistent state: open / served / void.
  final LineState state;

  /// How many times this line was sent back (quality metric).
  final int recook;

  /// Re-fire minute (board-relative): non-null ⇒ the scheduler fires it *now*
  /// with priority (a recook or an expedite/fire-missing).
  final int? reAt;

  /// Recook reason; null on a plain expedite/fire-missing.
  final String? reason;

  OrderLine copyWith({
    String? id,
    String? dishId,
    int? qty,
    int? cookOverrideMins,
    LineState? state,
    int? recook,
    int? reAt,
    String? reason,
    bool clearReAt = false,
    bool clearReason = false,
  }) =>
      OrderLine(
        id: id ?? this.id,
        dishId: dishId ?? this.dishId,
        qty: qty ?? this.qty,
        cookOverrideMins: cookOverrideMins ?? this.cookOverrideMins,
        state: state ?? this.state,
        recook: recook ?? this.recook,
        reAt: clearReAt ? null : (reAt ?? this.reAt),
        reason: clearReason ? null : (reason ?? this.reason),
      );

  @override
  List<Object?> get props =>
      <Object?>[id, dishId, qty, cookOverrideMins, state, recook, reAt, reason];
}

/// A Kitchen Order Ticket.
class Kot extends Equatable {
  const Kot({
    required this.id,
    required this.table,
    required this.type,
    required this.orderedAt,
    required this.lines,
    this.status = TicketState.active,
    this.rush = false,
  });

  final String id;

  /// Table label (e.g. `"5"`, `"D21"`). A string because delivery/takeaway use
  /// non-numeric codes.
  final String table;
  final KotType type;
  final DateTime orderedAt;
  final List<OrderLine> lines;

  /// Waiter lifecycle: active until closed (TICKETS.md).
  final TicketState status;

  /// Rushed: tightens the SLA and prioritises every line (TICKETS.md / §10).
  final bool rush;

  Kot copyWith({
    String? id,
    String? table,
    KotType? type,
    DateTime? orderedAt,
    List<OrderLine>? lines,
    TicketState? status,
    bool? rush,
  }) =>
      Kot(
        id: id ?? this.id,
        table: table ?? this.table,
        type: type ?? this.type,
        orderedAt: orderedAt ?? this.orderedAt,
        lines: lines ?? this.lines,
        status: status ?? this.status,
        rush: rush ?? this.rush,
      );

  @override
  List<Object?> get props =>
      <Object?>[id, table, type, orderedAt, lines, status, rush];
}
