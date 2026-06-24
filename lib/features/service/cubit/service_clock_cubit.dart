import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/domain/scheduler/models.dart';

/// Live "service" clock — simulates kitchen time so the boards animate, mirroring
/// the prototype's *Start service* + speed toggle (AGENTS.md §9).
///
/// Time is the only thing this holds; a `ScheduledDish`'s live status
/// (waiting/cooking/ready) is **derived** from [ServiceClockState.elapsedMins]
/// via [dishLiveStatus], never stored. The clock never recomputes the schedule —
/// it only advances [elapsed]; the schedule is fixed relative to its board epoch.
class ServiceClockCubit extends Cubit<ServiceClockState> {
  ServiceClockCubit() : super(const ServiceClockState());

  /// Selectable speed multipliers (kitchen-time : real-time), as in the prototype.
  static const List<int> speeds = <int>[1, 8, 30];

  /// Real-time granularity of the ticker. 1s is plenty for a board that shows
  /// `M:SS` and minute-granular cook statuses, and cuts per-tick rebuilds from
  /// 10/s to 1/s. (Fast-forward speeds step more coarsely but stay readable.)
  static const Duration _tick = Duration(seconds: 1);

  Timer? _timer;

  /// Start a fresh run from 0 and begin ticking.
  void start() {
    _timer?.cancel();
    emit(state.copyWith(elapsed: Duration.zero, running: true));
    _timer = Timer.periodic(_tick, _onTick);
  }

  /// Pause without losing elapsed time.
  void pause() {
    _timer?.cancel();
    emit(state.copyWith(running: false));
  }

  /// Resume from the current elapsed time.
  void resume() {
    if (state.running) return;
    emit(state.copyWith(running: true));
    _timer = Timer.periodic(_tick, _onTick);
  }

  /// Toggle running/paused.
  void toggle() => state.running ? pause() : resume();

  /// Stop and clear back to 0.
  void reset() {
    _timer?.cancel();
    emit(const ServiceClockState());
  }

  /// Change the speed multiplier (keeps running state and elapsed).
  void setSpeed(int speed) => emit(state.copyWith(speed: speed));

  void _onTick(Timer _) =>
      emit(state.copyWith(elapsed: state.elapsed + _tick * state.speed));

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}

/// Immutable state for [ServiceClockCubit].
class ServiceClockState extends Equatable {
  const ServiceClockState({
    this.elapsed = Duration.zero,
    this.speed = 8,
    this.running = false,
  });

  /// Scaled kitchen-time since the run started.
  final Duration elapsed;

  /// Current speed multiplier (one of [ServiceClockCubit.speeds]).
  final int speed;

  /// Whether the ticker is advancing.
  final bool running;

  /// Elapsed kitchen-**minutes** — the unit the scheduler works in.
  double get elapsedMins => elapsed.inMilliseconds / Duration.millisecondsPerMinute;

  /// True once a run has begun (running, or paused mid-run).
  bool get started => running || elapsed > Duration.zero;

  ServiceClockState copyWith({Duration? elapsed, int? speed, bool? running}) =>
      ServiceClockState(
        elapsed: elapsed ?? this.elapsed,
        speed: speed ?? this.speed,
        running: running ?? this.running,
      );

  @override
  List<Object?> get props => <Object?>[elapsed, speed, running];
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
