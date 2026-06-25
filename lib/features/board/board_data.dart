import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/domain/scheduler/scheduler.dart' as scheduler;

/// Runs the real [schedule] over a demo bundle and indexes the result for the
/// boards.
///
/// The schedule is computed relative to [now] — pass the time the data was
/// generated (`DemoDataState.generatedAt`) so fire/finish minutes stay stable
/// for a static demo rather than drifting with the wall clock. A live service
/// clock (AGENTS.md §9) lands later.
class BoardData {
  BoardData._({
    required this.data,
    required this.schedule,
    required this.now,
    required this.stationsById,
    required this.kotsById,
    required this.statusByKotId,
    required this.fireOrder,
    required this.stationLanes,
  });

  factory BoardData.from(
    DemoData data, {
    required DateTime now,
    bool fireImmediately = false,
  }) {
    final Map<String, Dish> menu = <String, Dish>{
      for (final Dish d in data.menu) d.id: d,
    };
    final Map<String, Station> stationsById = <String, Station>{
      for (final Station s in data.stations) s.id: s,
    };
    final Map<String, Kot> kotsById = <String, Kot>{
      for (final Kot k in data.kots) k.id: k,
    };
    final Schedule result = scheduler.schedule(
      kots: data.kots,
      menu: menu,
      stations: stationsById,
      now: now,
      // User's cook-timing setting: fire ASAP (start now, no leading idle) or
      // back-schedule so a ticket's dishes plate together (TICKETS.md default).
      config: fireImmediately
          ? const SchedulerConfig(fireAsap: true)
          : const SchedulerConfig(justInTime: true),
    );
    // Roll up each ticket's plate status once here. The boards re-read it every
    // clock tick (sorting/filtering tickets); computing it per call would scan
    // all scheduled dishes each time — O(tickets² × dishes) on the tick path.
    final Map<String, TicketStatus> statusByKotId = <String, TicketStatus>{
      for (final Kot k in data.kots)
        k.id: scheduler.ticketStatusFor(k, result.dishes, now: now),
    };
    // All cooks in fire order — computed once here, not per access. The Fire-next
    // board re-reads this on every clock tick; a getter would re-copy+sort all
    // dishes each second.
    final List<ScheduledDish> fireOrder = List<ScheduledDish>.of(result.dishes)
      ..sort((ScheduledDish a, ScheduledDish b) {
        final int byFire = a.fireAt.compareTo(b.fireAt);
        return byFire != 0 ? byFire : a.uid.compareTo(b.uid);
      });
    // Stations with scheduled dishes, in declaration order, paired with their
    // lane-packed [StationLane] — likewise computed once.
    final List<({Station station, StationLane lane})> stationLanes =
        <({Station station, StationLane lane})>[];
    for (final Station station in data.stations) {
      final StationLane? lane = result.byStation[station.id];
      if (lane != null && lane.dishes.isNotEmpty) {
        stationLanes.add((station: station, lane: lane));
      }
    }
    return BoardData._(
      data: data,
      schedule: result,
      now: now,
      stationsById: stationsById,
      kotsById: kotsById,
      statusByKotId: statusByKotId,
      fireOrder: fireOrder,
      stationLanes: stationLanes,
    );
  }

  final DemoData data;
  final Schedule schedule;
  final DateTime now;
  final Map<String, Station> stationsById;
  final Map<String, Kot> kotsById;

  /// Per-ticket plate roll-up, precomputed once (see [BoardData.from]).
  final Map<String, TicketStatus> statusByKotId;

  /// All cooks in fire order (earliest [ScheduledDish.fireAt] first). Computed
  /// once in [BoardData.from]; the Fire-next board reads it on every clock tick.
  final List<ScheduledDish> fireOrder;

  /// Stations that actually have scheduled dishes, in declaration order, each
  /// paired with its lane-packed [StationLane]. Computed once in [BoardData.from].
  final List<({Station station, StationLane lane})> stationLanes;

  Station? stationOf(String stationId) => stationsById[stationId];

  /// Per-ticket plate roll-up (target vs plate time, lateness). O(1) — read from
  /// the map precomputed in [BoardData.from]; falls back to a live compute for a
  /// ticket not in this bundle (shouldn't happen).
  TicketStatus statusOf(Kot kot) =>
      statusByKotId[kot.id] ??
      scheduler.ticketStatusFor(kot, schedule.dishes, now: now);

  /// Plate roll-up by ticket id — used to resolve a scheduled dish's
  /// [ScheduledMember]s (which carry only `kotId`) back to a [TicketStatus].
  /// Falls back to a degenerate status for an unknown id (shouldn't happen —
  /// every member id comes from a real [Kot]).
  TicketStatus statusForKot(String kotId) =>
      statusByKotId[kotId] ??
      const TicketStatus(
        dishes: <ScheduledDish>[],
        targetMins: 0,
        plateMins: 0,
        lateMins: 0,
      );

  /// True when [stationId] is the bottleneck station.
  bool isBottleneck(String stationId) =>
      schedule.bottleneck?.stationId == stationId;
}
