import 'dart:math';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kbuzz/core/clock.dart';
import 'package:kbuzz/core/logger.dart';
import 'package:kbuzz/core/result.dart';
import 'package:kbuzz/data/ai/demo_data_generator.dart';
import 'package:kbuzz/data/demo/demo_data.dart';
import 'package:kbuzz/data/repositories/kitchen_repository.dart';
import 'package:kbuzz/domain/entities/kitchen.dart';
import 'package:uuid/uuid.dart';

/// Holds the current board dataset (stations/menu/tickets) the UI watches.
///
/// State is emitted **synchronously** (optimistic, in-memory) so the UI updates
/// instantly, and each change is **written through** to Drift in the background
/// (AGENTS.md §2 write path). On construction it **hydrates** from Drift so data
/// survives restarts. The repository is optional — without it the cubit is a
/// pure in-memory store (used by tests).
class DemoDataCubit extends Cubit<DemoDataState> {
  DemoDataCubit({
    this._repository,
    this._generator,
    this._clock = const SystemClock(),
    this._random,
  }) : super(const DemoDataState()) {
    final KitchenRepository? repo = _repository;
    if (repo != null) {
      _pending = _hydrate(repo);
    }
  }

  final KitchenRepository? _repository;
  final DemoDataGenerator? _generator;
  final Clock _clock;

  /// Seeds the no-AI random rush. Tests pass a fixed [Random] for determinism;
  /// in the app it's null, so each tap produces a genuinely different rush.
  final Random? _random;
  static const Logger _log = Logger('demo-data');

  /// Whether live AI generation is available (a key was wired up). When false,
  /// [generate] falls back to the deterministic sample.
  bool get aiEnabled => _generator?.isConfigured ?? false;

  /// Short name of the active AI provider (`'Gemini'` or `'none'`).
  String get aiProvider => _generator?.providerLabel ?? 'none';

  Future<void>? _pending;

  /// Completes when the latest hydrate/persist op finishes. Tests only.
  @visibleForTesting
  Future<void> get settled => _pending ?? Future<void>.value();

  /// Restore any persisted data on startup (no-op if generate() already ran or
  /// the store is empty).
  Future<void> _hydrate(KitchenRepository repo) async {
    try {
      final DemoData data = await repo.loadSnapshot();
      if (state.hasData) return;
      if (data.stations.isEmpty && data.kots.isEmpty) return;
      emit(DemoDataState(data: data, generatedAt: _clock.now()));
    } on Object catch (e, st) {
      _log.error('hydrate failed', error: e, stackTrace: st);
    }
  }

  /// Generate (or regenerate) a fresh demo dataset.
  ///
  /// When AI is configured ([aiEnabled]), asks Gemini for a brand-new
  /// restaurant + rush; otherwise (or if the call fails) falls back to a
  /// **randomized** rush ([buildRandomDemoData]) — longer than the static sample
  /// and different every tap. Emits a `generating` state while a live request is
  /// in flight, then the resulting data (with [DemoDataState.error] set on
  /// fallback). The new dataset is written through to Drift.
  Future<void> generate() async {
    final DateTime now = _clock.now();
    final DemoDataGenerator? gen = _generator;

    if (gen == null || !gen.isConfigured) {
      _emitData(buildRandomDemoData(now: now, random: _random), now: now);
      return;
    }

    emit(state.copyWith(generating: true, clearError: true));
    final Result<DemoData> result = await gen.generate(now: now);
    if (isClosed) return;
    result.when(
      ok: (DemoData data) => _emitData(data, now: now),
      err: (AppFailure failure) {
        _log.warning('AI generation failed: ${failure.message}');
        _emitData(
          buildRandomDemoData(now: now, random: _random),
          now: now,
          error: failure.message,
        );
      },
    );
  }

  void _emitData(DemoData data, {required DateTime now, String? error}) {
    final DemoData withIds = _ensureLineIds(data);
    emit(DemoDataState(data: withIds, generatedAt: now, error: error));
    _persist((KitchenRepository repo) => repo.replaceAll(withIds));
  }

  /// Drop the demo data back to empty (config + tickets).
  void clear() {
    emit(const DemoDataState());
    _persist((KitchenRepository repo) => repo.clearAll());
  }

  /// Append a scanned/created ticket to the board.
  ///
  /// No-op if no data has been generated yet. Keeps [DemoDataState.generatedAt]
  /// fixed so the board epoch — and therefore the schedule's `now` — doesn't
  /// shift.
  void addKot(Kot kot, {List<Dish> newDishes = const <Dish>[]}) {
    final DemoData? current = state.data;
    if (current == null) return;
    final Kot withIds = _ensureKotLineIds(kot);
    emit(
      DemoDataState(
        data: DemoData(
          stations: current.stations,
          // Off-menu (ad-hoc) scanned dishes join the menu so the scheduler can
          // place them (their lines reference these ids).
          menu: newDishes.isEmpty
              ? current.menu
              : <Dish>[...current.menu, ...newDishes],
          kots: <Kot>[...current.kots, withIds],
        ),
        generatedAt: state.generatedAt,
      ),
    );
    _persist((KitchenRepository repo) =>
        repo.addKot(withIds, newDishes: newDishes));
  }

  /// Set a station's concurrent [capacity] and reschedule.
  ///
  /// Emits a new dataset with that one station updated (the boards re-run the
  /// scheduler off it, so lanes/bottleneck update live) and writes through to
  /// Drift. Keeps [DemoDataState.generatedAt] fixed so the board epoch — and the
  /// schedule's `now` — doesn't shift. No-op if no data, or if the capacity is
  /// unchanged. Capacity is floored at 1 (a station must cook at least one dish).
  void setStationCapacity(String stationId, int capacity) {
    final DemoData? current = state.data;
    if (current == null) return;
    final int next = capacity < 1 ? 1 : capacity;
    final int idx =
        current.stations.indexWhere((Station s) => s.id == stationId);
    if (idx < 0 || current.stations[idx].capacity == next) return;

    final List<Station> stations = List<Station>.of(current.stations);
    stations[idx] = stations[idx].copyWith(capacity: next);
    emit(
      DemoDataState(
        data: DemoData(
          stations: stations,
          menu: current.menu,
          kots: current.kots,
        ),
        generatedAt: state.generatedAt,
      ),
    );
    _persist((KitchenRepository repo) =>
        repo.updateStationCapacity(stationId, next));
  }

  // --- Waiter ticket actions (TICKETS.md) ------------------------------------
  // Optimistic in-memory mutation + write-through, mirroring [addKot]. The
  // boards re-run the scheduler off the new state, so re-fires/rush/served
  // update live. `reAtMins` (recook/fireNow) is the board-relative minute the
  // caller derives from the live service clock.

  void serveLine(String lineId) {
    _updateLine(lineId, (OrderLine l) => l.copyWith(state: LineState.served));
    _persist((KitchenRepository r) => r.serveLine(lineId));
  }

  void unserveLine(String lineId) {
    _updateLine(lineId, (OrderLine l) => l.copyWith(state: LineState.open));
    _persist((KitchenRepository r) => r.unserveLine(lineId));
  }

  void voidLine(String lineId) {
    _updateLine(lineId, (OrderLine l) => l.copyWith(state: LineState.voided));
    _persist((KitchenRepository r) => r.voidLine(lineId));
  }

  void restoreLine(String lineId) {
    _updateLine(lineId, (OrderLine l) => l.copyWith(state: LineState.open));
    _persist((KitchenRepository r) => r.restoreLine(lineId));
  }

  void recookLine(String lineId, {required String reason, required int reAtMins}) {
    _updateLine(
      lineId,
      (OrderLine l) => l.copyWith(
        state: LineState.open,
        recook: l.recook + 1,
        reAt: reAtMins,
        reason: reason,
      ),
      reopenTicket: true,
    );
    _persist((KitchenRepository r) =>
        r.recookLine(lineId, reason: reason, reAtMins: reAtMins));
  }

  void fireNowLine(String lineId, {required int reAtMins}) {
    _updateLine(
      lineId,
      (OrderLine l) =>
          l.copyWith(state: LineState.open, reAt: reAtMins, clearReason: true),
    );
    _persist((KitchenRepository r) => r.fireNowLine(lineId, reAtMins: reAtMins));
  }

  void serveAll(String kotId) {
    _updateKot(
      kotId,
      (Kot k) => k.copyWith(
        lines: <OrderLine>[
          for (final OrderLine l in k.lines)
            l.state == LineState.voided
                ? l
                : l.copyWith(state: LineState.served),
        ],
      ),
    );
    _persist((KitchenRepository r) => r.serveAll(kotId));
  }

  void setRush(String kotId, {required bool on}) {
    _updateKot(kotId, (Kot k) => k.copyWith(rush: on));
    _persist((KitchenRepository r) => r.setRush(kotId, on: on));
  }

  void markTicketDone(String kotId) {
    _updateKot(kotId, (Kot k) => k.copyWith(status: TicketState.done));
    _persist((KitchenRepository r) => r.markDone(kotId));
  }

  void reopenTicket(String kotId) {
    _updateKot(kotId, (Kot k) => k.copyWith(status: TicketState.active));
    _persist((KitchenRepository r) => r.reopenTicket(kotId));
  }

  /// Apply [f] to the line [lineId] across all tickets (optimistic). When
  /// [reopenTicket] is set, also flips that line's ticket back to active.
  void _updateLine(
    String lineId,
    OrderLine Function(OrderLine line) f, {
    bool reopenTicket = false,
  }) {
    final DemoData? current = state.data;
    if (current == null) return;
    final List<Kot> kots = <Kot>[
      for (final Kot k in current.kots)
        if (k.lines.any((OrderLine l) => l.id == lineId))
          k.copyWith(
            status: reopenTicket ? TicketState.active : null,
            lines: <OrderLine>[
              for (final OrderLine l in k.lines) l.id == lineId ? f(l) : l,
            ],
          )
        else
          k,
    ];
    emit(DemoDataState(
      data: DemoData(stations: current.stations, menu: current.menu, kots: kots),
      generatedAt: state.generatedAt,
    ));
  }

  void _updateKot(String kotId, Kot Function(Kot kot) f) {
    final DemoData? current = state.data;
    if (current == null) return;
    emit(DemoDataState(
      data: DemoData(
        stations: current.stations,
        menu: current.menu,
        kots: <Kot>[
          for (final Kot k in current.kots) k.id == kotId ? f(k) : k,
        ],
      ),
      generatedAt: state.generatedAt,
    ));
  }

  /// Assign a stable id to any line that lacks one, so in-memory lines match
  /// their persisted Drift ids (waiter actions target line ids).
  DemoData _ensureLineIds(DemoData data) => DemoData(
        stations: data.stations,
        menu: data.menu,
        kots: <Kot>[for (final Kot k in data.kots) _ensureKotLineIds(k)],
      );

  Kot _ensureKotLineIds(Kot kot) {
    if (kot.lines.every((OrderLine l) => l.id != null)) return kot;
    return kot.copyWith(
      lines: <OrderLine>[
        for (final OrderLine l in kot.lines)
          l.id == null ? l.copyWith(id: const Uuid().v4()) : l,
      ],
    );
  }

  void _persist(Future<void> Function(KitchenRepository repo) op) {
    final KitchenRepository? repo = _repository;
    if (repo == null) return;
    _pending = op(repo).catchError((Object e, StackTrace st) {
      _log.error('persist failed', error: e, stackTrace: st);
    });
  }
}

/// State for [DemoDataCubit]: the current [data] (null when empty), the board
/// epoch ([generatedAt]) used as the schedule's `now`, whether a live AI
/// [generating] request is in flight, and the last fallback [error] (set when an
/// AI call failed and the deterministic sample was used instead).
class DemoDataState extends Equatable {
  const DemoDataState({
    this.data,
    this.generatedAt,
    this.generating = false,
    this.error,
  });

  final DemoData? data;
  final DateTime? generatedAt;
  final bool generating;
  final String? error;

  bool get hasData => data != null;

  DemoDataState copyWith({
    DemoData? data,
    DateTime? generatedAt,
    bool? generating,
    bool clearError = false,
  }) {
    return DemoDataState(
      data: data ?? this.data,
      generatedAt: generatedAt ?? this.generatedAt,
      generating: generating ?? this.generating,
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => <Object?>[data, generatedAt, generating, error];
}
