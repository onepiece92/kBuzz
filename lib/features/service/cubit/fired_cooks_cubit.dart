import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/features/board/board_data.dart';
import 'package:kbuzz/features/profile/cubit/demo_data_cubit.dart';
import 'package:kbuzz/features/profile/cubit/settings_cubit.dart';
import 'package:kbuzz/features/service/cubit/fire_alert_cubit.dart'
    show fireKey, firableDishes;
import 'package:kbuzz/features/service/cubit/service_clock_cubit.dart';
import 'package:kbuzz/domain/scheduler/models.dart';

/// The fire minutes of cooks that have already **fired** in the live run, keyed
/// by the reschedule-stable [cookKey]. The boards pass this into the scheduler
/// (via [BoardData.from]) so an in-flight cook's fire time is locked and adding a
/// ticket can't re-time a dish already on the pass. In-memory only (cleared on
/// reset; not persisted — a mid-cook app restart re-derives from scratch).
class FiredCooksState extends Equatable {
  const FiredCooksState({this.pinnedFireMins = const <String, int>{}});

  final Map<String, int> pinnedFireMins;

  @override
  List<Object?> get props => <Object?>[pinnedFireMins];
}

/// Captures a cook's fire minute the instant the live clock crosses its `fireAt`,
/// and holds those pins so the boards can keep started cooks from moving on a
/// reschedule.
///
/// Watches only the run clock: a pin is captured on a running tick, pruned once
/// its ticket is done (it drops out of [firableDishes]), and the whole set is
/// cleared when the run isn't started (so Reset re-arms). Data/settings changes
/// don't move pins — adding a ticket fires nothing — so the boards simply rebuild
/// with the existing pins and started cooks stay put.
class FiredCooksCubit extends Cubit<FiredCooksState> {
  FiredCooksCubit({
    required ServiceClockCubit clock,
    required this._data,
    required this._settings,
  }) : super(const FiredCooksState()) {
    _clockSub = clock.stream.listen(_onClock);
  }

  final DemoDataCubit _data;
  final SettingsCubit _settings;
  StreamSubscription<ServiceClockState>? _clockSub;

  final Map<String, int> _pinned = <String, int>{};

  void _onClock(ServiceClockState clock) {
    if (isClosed) return;
    // Not started (fresh / after Reset) → drop every pin so the run re-arms.
    if (!clock.started) {
      _clearPins();
      return;
    }
    // Paused → the kitchen isn't advancing; capture nothing.
    if (!clock.running) return;
    _capture(clock.elapsedMins);
  }

  void _clearPins() {
    if (_pinned.isEmpty) return;
    _pinned.clear();
    emit(const FiredCooksState());
  }

  /// Pin any firable cook the clock has reached, and prune pins whose cook is no
  /// longer firable (its ticket is done, or its identity drifted).
  void _capture(double elapsedMins) {
    final DemoData? data = _data.state.data;
    final DateTime? now = _data.state.generatedAt;
    if (data == null || now == null) {
      _clearPins();
      return;
    }
    final BoardData board = BoardData.from(
      data,
      now: now,
      fireImmediately: _settings.state.fireImmediately,
      pinnedFireMins: _pinned,
    );
    final Set<String> liveKeys = <String>{};
    bool changed = false;
    for (final ScheduledDish d
        in firableDishes(board.schedule.dishes, board.kotsById)) {
      final String key = fireKey(d);
      liveKeys.add(key);
      if (elapsedMins >= d.fireAt && !_pinned.containsKey(key)) {
        _pinned[key] = d.fireAt; // lock it at the minute it fired
        changed = true;
      }
    }
    final int before = _pinned.length;
    _pinned.removeWhere((String k, int _) => !liveKeys.contains(k));
    if (_pinned.length != before) changed = true;

    if (changed) {
      emit(FiredCooksState(
        pinnedFireMins: Map<String, int>.unmodifiable(_pinned),
      ));
    }
  }

  @override
  Future<void> close() {
    _clockSub?.cancel();
    return super.close();
  }
}
