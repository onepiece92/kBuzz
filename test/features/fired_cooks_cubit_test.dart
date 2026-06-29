import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fired_cooks_cubit.dart';
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

class _FakeMono extends MonotonicClock {
  Duration _e = Duration.zero;
  void advance(Duration d) => _e += d;
  @override
  Duration elapsed() => _e;
}

/// Flush the cubit stream microtask(s) so a clock emit reaches FiredCooksCubit.
Future<void> _settle() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final DateTime now = DateTime(2026, 1, 1, 18);

  // One dineIn soup (cook 5): JIT leaves the lone plate-defining dish at its
  // back-scheduled fire (target 14 − cook 5 = 9). So it "fires" at minute 9.
  ({
    DemoDataCubit demo,
    ServiceClockCubit clock,
    FiredCooksCubit fired,
    _FakeMono mono,
  }) harness() {
    final DemoDataCubit demo = DemoDataCubit(clock: _FixedClock(now));
    demo.seedFromScan(
      stations: const <Station>[
        Station(id: 'grill', name: 'Grill', color: 0xFFEF4444, capacity: 1),
      ],
      menu: const <Dish>[
        Dish(
          id: 'soup',
          name: 'Soup',
          emoji: '🍲',
          stationId: 'grill',
          cookMins: 5,
          holdable: true,
          batchable: false,
        ),
      ],
      kot: Kot(
        id: 'k1',
        table: '5',
        type: KotType.dineIn,
        orderedAt: now,
        lines: const <OrderLine>[OrderLine(id: 'l1', dishId: 'soup', qty: 1)],
      ),
    );
    final _FakeMono mono = _FakeMono();
    final ServiceClockCubit clock =
        ServiceClockCubit(clock: _FixedClock(now), monotonic: mono)
          ..setSpeed(1);
    final FiredCooksCubit fired = FiredCooksCubit(
      clock: clock,
      data: demo,
      settings: SettingsCubit(),
    );
    addTearDown(demo.close);
    addTearDown(clock.close);
    addTearDown(fired.close);
    return (demo: demo, clock: clock, fired: fired, mono: mono);
  }

  test('pins a cook once the clock crosses its fireAt, then clears on reset',
      () async {
    final h = harness();
    h.clock.start(epoch: h.demo.state.generatedAt);
    await _settle();
    // Not yet fired (fireAt 9) → no pin.
    expect(h.fired.state.pinnedFireMins, isEmpty);

    // Advance past the fire minute.
    h.mono.advance(const Duration(minutes: 10));
    h.clock.tick();
    await _settle();
    expect(h.fired.state.pinnedFireMins['grill|soup|k1'], 9);

    // Reset → every pin re-arms.
    h.clock.reset();
    await _settle();
    expect(h.fired.state.pinnedFireMins, isEmpty);
  });

  test('prunes the pin once the ticket is done', () async {
    final h = harness();
    h.clock.start(epoch: h.demo.state.generatedAt);
    h.mono.advance(const Duration(minutes: 10));
    h.clock.tick();
    await _settle();
    expect(h.fired.state.pinnedFireMins, contains('grill|soup|k1'));

    // Ticket served + closed → its cook drops out of the firable set → pruned.
    h.demo.markTicketDone('k1');
    h.mono.advance(const Duration(minutes: 1));
    h.clock.tick();
    await _settle();
    expect(h.fired.state.pinnedFireMins, isEmpty);
  });
}
