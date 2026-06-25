import 'package:flutter_test/flutter_test.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/data/db/database.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';

class _FixedClock extends Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

/// A repository whose snapshot read always fails — simulates a corrupt/locked
/// Drift store on startup.
class _ThrowingRepository extends KitchenRepository {
  _ThrowingRepository(super.db);

  @override
  Future<DemoData> loadSnapshot() async => throw Exception('drift read failed');
}

/// Startup resilience: if hydrating persisted data throws, the cubit must land
/// in a safe empty state (not crash) and stay usable.
void main() {
  final DateTime now = DateTime(2026, 1, 1, 12);

  test('a failing hydrate leaves the cubit empty and still usable', () async {
    final AppDatabase db = AppDatabase.memory();
    final KitchenRepository repo = _ThrowingRepository(db);
    final DemoDataCubit cubit =
        DemoDataCubit(repository: repo, clock: _FixedClock(now));

    // Hydrate runs in the constructor; awaiting settled must not rethrow.
    await cubit.settled;
    expect(cubit.state.data, isNull, reason: 'failed hydrate → empty state');

    // The cubit recovers: generate() falls back to the random sample, and the
    // write-through error (replaceAll also fails) is swallowed by _persist.
    cubit.generate();
    expect(cubit.state.data, isNotNull);
    expect(cubit.state.data!.kots, isNotEmpty);
    await cubit.settled;

    await cubit.close();
    await db.close();
  });
}
