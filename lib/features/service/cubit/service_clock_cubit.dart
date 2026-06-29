import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/domain/scheduler/models.dart';

/// Live "service" clock — real kitchen time so the boards animate (AGENTS.md §9).
///
/// **Two time bases, by design:**
/// - The board [ServiceClockState.epoch] is an **immutable absolute wall** anchor
///   (the persisted board epoch) — it never moves, not even on a speed change, so
///   it survives a restart and keeps the live "now" line aligned with the
///   schedule's `now`.
/// - In-session [elapsed] advances from a **monotonic** clock
///   (`elapsed += Δmonotonic × speed`), so a device wall-clock change (NTP / DST /
///   manual edit) can't move the board mid-service.
///
/// On [start], [sync] (app resume) the monotonic base is re-anchored to the wall
/// clock — recovering real time that passed while backgrounded (a `Stopwatch` may
/// not advance during deep sleep), at the cost of absorbing a wall jump that
/// lands *while backgrounded*. A `ScheduledDish`'s live status is derived from
/// [ServiceClockState.elapsedMins] via [dishLiveStatus], never stored; the clock
/// never recomputes the schedule.
class ServiceClockCubit extends Cubit<ServiceClockState> {
  ServiceClockCubit({
    this.clock = const SystemClock(),
    MonotonicClock? monotonic,
    this._persistSpeed,
  })  : _mono = monotonic ?? StopwatchMonotonicClock(),
        super(const ServiceClockState());

  /// Wall clock — used only for the immutable board epoch and the resume
  /// reconciliation, never for in-session advance.
  @visibleForTesting
  final Clock clock;

  final MonotonicClock _mono;

  /// Persists the run speed (BoardMeta) so a restart resumes at the same rate.
  /// Null in tests / when there's no store.
  final Future<void> Function(int speed)? _persistSpeed;

  /// Selectable speed multipliers (kitchen-time : real-time). 1x is real time;
  /// the faster steps are a demo/replay convenience.
  static const List<int> speeds = <int>[1, 8, 30];

  /// Repaint cadence. Each tick recomputes elapsed from the monotonic clock, so
  /// a slow/skipped tick costs only a late repaint, never lost time.
  static const Duration _tick = Duration(seconds: 1);

  Timer? _timer;

  /// Immutable wall board epoch for this run (mirrors [ServiceClockState.epoch]).
  DateTime? _boardEpoch;

  /// Elapsed kitchen-time accrued up to [_baseMono] (the anchor for the next
  /// monotonic delta). Reset on start / sync / speed change.
  Duration _baseElapsed = Duration.zero;

  /// Monotonic reading at the last anchor.
  Duration _baseMono = Duration.zero;

  /// Wall time at the last anchor. [sync] uses the wall gap *since this* (scaled
  /// by the current speed) so each constant-speed segment is reconciled on its
  /// own terms — a speed change mid-run never re-scales the earlier segment.
  DateTime? _wallAnchor;

  /// Start the run, anchoring the immutable board epoch at [epoch] (the
  /// `DemoDataState.generatedAt`, so live status lines up with the schedule's
  /// `now`; defaults to wall-clock now). elapsed seeds to the true wall delta —
  /// so a restart with a past epoch resumes at real elapsed, not zero.
  void start({DateTime? epoch}) {
    _timer?.cancel();
    final DateTime now = clock.now(); // one read drives both epoch + elapsed
    _boardEpoch = epoch ?? now;
    _baseMono = _mono.elapsed();
    _wallAnchor = now;
    _baseElapsed = _wallElapsed(now);
    emit(state.copyWith(
      epoch: _boardEpoch,
      elapsed: _baseElapsed,
      running: true,
    ));
    _persistSpeed?.call(state.speed);
    _timer = Timer.periodic(_tick, (_) => tick());
  }

  /// Pause the auto-advancing view and fire alerts — but **not** wall time. The
  /// epoch is kept, so [resume] (or an app-foreground [sync]) reconciles to the
  /// true elapsed: a pause never stops the kitchen clock.
  void pause() {
    _timer?.cancel();
    emit(state.copyWith(running: false));
  }

  /// Resume ticking, first reconciling to the true current elapsed.
  void resume() {
    if (state.running || _boardEpoch == null) return;
    sync();
    emit(state.copyWith(running: true));
    _timer = Timer.periodic(_tick, (_) => tick());
  }

  /// Toggle running/paused.
  void toggle() => state.running ? pause() : resume();

  /// Stop and clear back to "not started".
  void reset() {
    _timer?.cancel();
    _boardEpoch = null;
    _baseElapsed = Duration.zero;
    _baseMono = Duration.zero;
    _wallAnchor = null;
    emit(const ServiceClockState());
  }

  /// Per-tick foreground update: advance elapsed from the **monotonic** clock so
  /// it ignores wall-clock jumps. Public so the run loop's ticker drives it (and
  /// tests can pump it without a real timer).
  @visibleForTesting
  void tick() {
    if (_boardEpoch == null) return;
    emit(state.copyWith(elapsed: _compute()));
  }

  /// Reconcile elapsed to the wall clock right now and re-seed the monotonic
  /// base — call on app resume to recover however much real time passed while
  /// backgrounded (a `Stopwatch` may not advance during deep sleep).
  ///
  /// Adds only the wall gap **since the last anchor** ([_wallAnchor]) scaled by
  /// the current speed, then re-anchors — so each constant-speed segment is
  /// reconciled on its own terms and a speed change earlier in the run is never
  /// retroactively re-scaled (which would lurch the clock forward on resume).
  void sync() {
    final DateTime? anchor = _wallAnchor;
    if (_boardEpoch == null || anchor == null) return;
    final DateTime now = clock.now();
    final Duration realGap = now.difference(anchor);
    if (!realGap.isNegative) _baseElapsed += realGap * state.speed;
    _baseMono = _mono.elapsed();
    _wallAnchor = now;
    emit(state.copyWith(elapsed: _baseElapsed));
  }

  /// Change the speed multiplier. Settles elapsed at the old speed, then switches
  /// — continuous across the change — and **leaves the board epoch untouched**.
  void setSpeed(int speed) {
    if (_boardEpoch == null) {
      emit(state.copyWith(speed: speed));
      _persistSpeed?.call(speed);
      return;
    }
    final Duration settled = _compute();
    _baseElapsed = settled;
    _baseMono = _mono.elapsed();
    _wallAnchor = clock.now(); // start a new constant-speed segment here
    emit(state.copyWith(elapsed: settled, speed: speed));
    _persistSpeed?.call(speed);
  }

  /// elapsed = base + Δmonotonic × speed, clamped at zero.
  Duration _compute() {
    final Duration e =
        _baseElapsed + (_mono.elapsed() - _baseMono) * state.speed;
    return e.isNegative ? Duration.zero : e;
  }

  /// Scaled wall elapsed since the immutable epoch, clamped at zero (used to
  /// seed/reconcile against the wall; assumes the current speed over the span —
  /// exact at a constant speed, the demo case where speed varies is approximate).
  Duration _wallElapsed(DateTime now) {
    final Duration real = now.difference(_boardEpoch!);
    return real.isNegative ? Duration.zero : real * state.speed;
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

/// Immutable state for [ServiceClockCubit].
class ServiceClockState extends Equatable {
  const ServiceClockState({
    this.epoch,
    this.elapsed = Duration.zero,
    this.speed = 1, // real time by default; 8x/30x are demo fast-forwards
    this.running = false,
  });

  /// Wall-clock anchor for `elapsed = 0` (the board epoch). Null until the run
  /// starts; [started] is derived from it.
  final DateTime? epoch;

  /// Scaled kitchen-time since [epoch] — a snapshot re-derived from the wall
  /// clock each tick (and on app resume), never accumulated.
  final Duration elapsed;

  /// Current speed multiplier (one of [ServiceClockCubit.speeds]).
  final int speed;

  /// Whether the view is auto-advancing. Wall time flows regardless — a paused
  /// run still reflects true elapsed once resumed/synced.
  final bool running;

  /// Elapsed kitchen-**minutes** — the unit the scheduler works in.
  double get elapsedMins => elapsed.inMilliseconds / Duration.millisecondsPerMinute;

  /// True once a run has started (has an [epoch]), whether running or paused.
  bool get started => epoch != null;

  ServiceClockState copyWith({
    DateTime? epoch,
    Duration? elapsed,
    int? speed,
    bool? running,
  }) =>
      ServiceClockState(
        epoch: epoch ?? this.epoch,
        elapsed: elapsed ?? this.elapsed,
        speed: speed ?? this.speed,
        running: running ?? this.running,
      );

  @override
  List<Object?> get props => <Object?>[epoch, elapsed, speed, running];
}

/// A scheduled dish's live status at a given elapsed time. [held] only occurs
/// under **strict coursing** (when a `plateMins` gate is supplied): the dish has
/// finished cooking but is waiting under the lamp for the rest of its ticket so
/// the whole table plates together.
enum DishLiveStatus { planned, waiting, cooking, held, ready }

/// Derive a dish's status from the clock (mirrors the prototype's `liveStatus`).
/// Before the run starts everything is [DishLiveStatus.planned].
///
/// Pass [plateMins] — the dish's ticket plate time (`max(finishAt)` across the
/// ticket, i.e. [TicketStatus.plateMins]) — to enable **strict coursing**: a
/// dish that finishes cooking before the rest of its table reports [held] until
/// `elapsedMins >= plateMins`, so every line of the ticket flips to [ready]
/// together. Omit it for the kitchen view, where a finished cook is genuinely
/// [ready] the moment it's done.
DishLiveStatus dishLiveStatus(
  ScheduledDish dish,
  double elapsedMins, {
  required bool started,
  int? plateMins,
}) {
  if (!started) return DishLiveStatus.planned;
  if (elapsedMins < dish.fireAt) return DishLiveStatus.waiting;
  if (elapsedMins < dish.finishAt) return DishLiveStatus.cooking;
  if (plateMins != null && elapsedMins < plateMins) return DishLiveStatus.held;
  return DishLiveStatus.ready;
}

/// A ticket's live lifecycle stage at a given elapsed time. Derived from its
/// per-ticket roll-up plus a retain window — never stored, mirroring
/// [dishLiveStatus].
enum TicketLiveStage { planned, active, allReady, served }

/// Derive a ticket's stage from the clock. It is [TicketLiveStage.active] until
/// its last dish is ready (`elapsedMins >= plateMins`), then [allReady] through
/// the retain window, then [served]. Half-open intervals match [dishLiveStatus],
/// so a ticket flips to [allReady] at the exact instant its last dish flips to
/// [DishLiveStatus.ready] (`plateMins == max(finishAt)`).
///
/// Dish-less tickets need no special case: `ticketStatusFor` sets
/// `plateMins == targetMins`, so they age out by their target time.
TicketLiveStage ticketLiveStage(
  TicketStatus status,
  double elapsedMins, {
  required bool started,
  required int retainMins,
}) {
  if (!started) return TicketLiveStage.planned;
  final int plate = status.plateMins;
  if (elapsedMins < plate) return TicketLiveStage.active;
  if (elapsedMins < plate + retainMins) return TicketLiveStage.allReady;
  return TicketLiveStage.served;
}

/// Whether a (possibly batched) cook is fully served and can drop off the
/// fire-next queue. A cook shared across tickets ([ScheduledDish.members])
/// stays until **every** member ticket is served — so a shared dish never
/// vanishes while another table still needs it. An unmembered dish is never
/// considered served here.
bool dishServed(
  ScheduledDish dish,
  TicketStatus Function(String kotId) statusForKot,
  double elapsedMins, {
  required bool started,
  required int retainMins,
}) {
  if (dish.members.isEmpty) return false;
  return dish.members.every((ScheduledMember m) =>
      ticketLiveStage(
        statusForKot(m.kotId),
        elapsedMins,
        started: started,
        retainMins: retainMins,
      ) ==
      TicketLiveStage.served);
}
