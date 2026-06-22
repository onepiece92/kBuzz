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
  });

  factory BoardData.from(DemoData data, {required DateTime now}) {
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
      // Cook each ticket's dishes to plate together (TICKETS.md), not all at once.
      config: const SchedulerConfig(justInTime: true),
    );
    return BoardData._(
      data: data,
      schedule: result,
      now: now,
      stationsById: stationsById,
      kotsById: kotsById,
    );
  }

  final DemoData data;
  final Schedule schedule;
  final DateTime now;
  final Map<String, Station> stationsById;
  final Map<String, Kot> kotsById;

  Station? stationOf(String stationId) => stationsById[stationId];

  /// All cooks in fire order (earliest [ScheduledDish.fireAt] first).
  List<ScheduledDish> get fireOrder {
    final List<ScheduledDish> sorted = List<ScheduledDish>.of(schedule.dishes);
    sorted.sort((ScheduledDish a, ScheduledDish b) {
      final int byFire = a.fireAt.compareTo(b.fireAt);
      return byFire != 0 ? byFire : a.uid.compareTo(b.uid);
    });
    return sorted;
  }

  /// Stations that actually have scheduled dishes, in declaration order, each
  /// paired with its lane-packed [StationLane].
  List<({Station station, StationLane lane})> get stationLanes {
    final List<({Station station, StationLane lane})> out =
        <({Station station, StationLane lane})>[];
    for (final Station station in data.stations) {
      final StationLane? lane = schedule.byStation[station.id];
      if (lane != null && lane.dishes.isNotEmpty) {
        out.add((station: station, lane: lane));
      }
    }
    return out;
  }

  /// Per-ticket plate roll-up (target vs plate time, lateness).
  TicketStatus statusOf(Kot kot) =>
      scheduler.ticketStatusFor(kot, schedule.dishes, now: now);

  /// Plate roll-up by ticket id — used to resolve a scheduled dish's
  /// [ScheduledMember]s (which carry only `kotId`) back to a [TicketStatus].
  /// Falls back to a degenerate status for an unknown id (shouldn't happen —
  /// every member id comes from a real [Kot]).
  TicketStatus statusForKot(String kotId) {
    final Kot? kot = kotsById[kotId];
    if (kot == null) {
      return const TicketStatus(
        dishes: <ScheduledDish>[],
        targetMins: 0,
        plateMins: 0,
        lateMins: 0,
      );
    }
    return statusOf(kot);
  }

  /// True when [stationId] is the bottleneck station.
  bool isBottleneck(String stationId) =>
      schedule.bottleneck?.stationId == stationId;
}
