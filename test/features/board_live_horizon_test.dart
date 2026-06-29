import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/domain/scheduler/models.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

/// Regression for the auto-drip "stops after ~2h" bug: the schedule `now` is
/// pinned to the board epoch, so a ticket auto-added 125 min into the run maps
/// to relative minute 125 — past the scheduler's default 120-min horizon. The
/// live boards widen the horizon ([kLiveHorizonMins]) so such a ticket still
/// schedules into the live window instead of being clamped/aged out.
void main() {
  test(
      'a ticket ordered ~2h into the run schedules in the live window, past the '
      'old 120-min horizon', () {
    final DateTime epoch = DateTime(2026, 1, 1, 18);
    const Station grill =
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 1);
    const Dish soup = Dish(
      id: 'soup',
      name: 'Soup',
      emoji: '🍲',
      stationId: 'grill',
      cookMins: 5,
      holdable: true,
      batchable: false,
    );
    // Auto-dripped 125 min into the service: orderedAt = epoch + 125m.
    final Kot late = Kot(
      id: 'late',
      table: '9',
      type: KotType.dineIn,
      orderedAt: epoch.add(const Duration(minutes: 125)),
      lines: const <OrderLine>[OrderLine(id: 'l1', dishId: 'soup', qty: 1)],
    );
    final DemoData data = DemoData(
      stations: const <Station>[grill],
      menu: const <Dish>[soup],
      kots: <Kot>[late],
    );

    final BoardData board = BoardData.from(data, now: epoch);

    // Scheduled (not dropped) and placed in the live window past the old wall —
    // not clamped under minute 120.
    expect(board.schedule.dishes, hasLength(1));
    final ScheduledDish d = board.schedule.dishes.single;
    expect(d.fireAt, greaterThanOrEqualTo(120));
    expect(d.finishAt, greaterThan(120));

    // At elapsed 125 it reads as upcoming work (waiting/cooking), NOT as
    // already-cooked — the symptom the horizon raise fixes.
    final TicketStatus status = board.statusForKot('late');
    final DishLiveStatus stat =
        dishLiveStatus(d, 125.0, started: true, plateMins: status.plateMins);
    expect(
      stat == DishLiveStatus.ready || stat == DishLiveStatus.held,
      isFalse,
      reason: 'a freshly-arrived ticket must not present as already cooked',
    );
  });
}
