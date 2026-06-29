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

  /// Short name of the active AI provider (`'Claude'` or `'none'`).
  String get aiProvider => _generator?.providerLabel ?? 'none';

  Future<void>? _pending;

  /// Completes when the latest hydrate/persist op finishes. Tests only.
  @visibleForTesting
  Future<void> get settled => _pending ?? Future<void>.value();

  /// Restore any persisted data on startup (no-op if generate() already ran or
  /// the store is empty).
  /// True once a non-empty board was restored from the store on startup — the
  /// shell uses this to auto-resume the run (only on a restart, never on a fresh
  /// generate).
  bool get restoredFromStore => _restoredFromStore;
  bool _restoredFromStore = false;

  Future<void> _hydrate(KitchenRepository repo) async {
    try {
      final DemoData data = await repo.loadSnapshot();
      if (state.hasData) return;
      if (data.stations.isEmpty && data.kots.isEmpty) return;
      // Resume the ORIGINAL board epoch (so the run continues at true wall time),
      // not _clock.now(). Fallbacks: a v3 DB upgraded in place has orders but no
      // persisted epoch yet → anchor to the earliest order; neither → now.
      _restoredFromStore = true;
      emit(DemoDataState(
        data: data,
        generatedAt:
            data.generatedAt ?? _earliestOrderedAt(data) ?? _clock.now(),
      ));
    } on Object catch (e, st) {
      _log.error('hydrate failed', error: e, stackTrace: st);
    }
  }

  /// Earliest order time across the board, or null when there are no tickets —
  /// the back-compat epoch fallback for a pre-v4 DB with no persisted epoch.
  static DateTime? _earliestOrderedAt(DemoData data) {
    DateTime? earliest;
    for (final Kot k in data.kots) {
      if (earliest == null || k.orderedAt.isBefore(earliest)) {
        earliest = k.orderedAt;
      }
    }
    return earliest;
  }

  /// Generate (or regenerate) a fresh demo dataset.
  ///
  /// When AI is configured ([aiEnabled]), asks Claude for a brand-new
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
    // Persist the epoch atomically with the snapshot so a restart resumes this
    // board's real timeline. Speed is owned/persisted by the run clock.
    _persist((KitchenRepository repo) =>
        repo.replaceAll(withIds.copyWith(generatedAt: now)));
  }

  /// Bootstrap a board from a scanned ticket when there's no demo data yet — the
  /// scanned (ad-hoc) dishes become the menu, the stations they use become the
  /// config, and the ticket is the first order. Backs the scan flow's "build the
  /// board from the scan" path, so a KOT can be scanned without generating demo
  /// data first. Sets a fresh board epoch ([now]) and writes through to Drift.
  void seedFromScan({
    required List<Station> stations,
    required List<Dish> menu,
    required Kot kot,
  }) {
    _emitData(
      DemoData(stations: stations, menu: menu, kots: <Kot>[kot]),
      now: _clock.now(),
    );
  }

  /// Drop the demo data back to empty (config + tickets).
  void clear() {
    _runSnapshot = null;
    emit(const DemoDataState());
    _persist((KitchenRepository repo) => repo.clearAll());
  }

  /// The board as it was when the run started — so [clearForFreshStart] (the
  /// Reset button) can recover the start-of-service station capacities.
  /// In-memory: a fresh run re-snapshots.
  DemoData? _runSnapshot;

  /// Capture the current board as the run's start state. Called when the service
  /// clock starts (manual *Start service* or the cold-start auto-resume).
  void snapshotForRun() {
    final DemoData? d = state.data;
    if (d == null) return;
    _runSnapshot = d.copyWith(generatedAt: state.generatedAt);
  }

  /// Reset = fresh start on the **same restaurant**: keep the stations and menu
  /// but drop every ticket and reset each station's capacity to its
  /// start-of-service value (undoing mid-run capacity bumps), then stamp a fresh
  /// board epoch so the next *Start* runs from zero. Falls back to [clear] when
  /// no run was ever started (no snapshot to take the defaults from).
  void clearForFreshStart() {
    final DemoData? snap = _runSnapshot;
    if (snap == null) {
      clear();
      return;
    }
    final DateTime now = _clock.now();
    // Same restaurant (start-of-service stations + menu), empty queue, fresh
    // epoch. Stations come from the snapshot so capacities revert to default.
    final DemoData fresh = DemoData(
      stations: snap.stations,
      menu: snap.menu,
      kots: const <Kot>[],
      generatedAt: now,
    );
    _runSnapshot = null; // the next Start re-snapshots this fresh board
    emit(DemoDataState(data: fresh, generatedAt: now));
    _persist((KitchenRepository repo) => repo.replaceAll(fresh));
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

  /// Inject **one** randomly-generated ticket "right now" — simulates real-world
  /// orders trickling in while the service runs. The ticket is ordered at the
  /// current service moment (board epoch + [elapsed], the live run time from the
  /// service clock) so it lands at the now-line and schedules forward, exactly
  /// like a KOT that just arrived. Keeps the board epoch fixed and writes through
  /// to Drift.
  ///
  /// Only orders dishes from stations **already on the board** so the drip never
  /// opens a new station mid-run — the station set stays stable for a clean test
  /// environment. Falls back to the full menu if the board has no dishes yet.
  ///
  /// Returns the added ticket, or null when there's no board yet / the menu is
  /// empty (nothing to order). Tests pass a seeded [Random] for determinism.
  Kot? addRandomKot({Duration elapsed = Duration.zero}) {
    final DemoData? current = state.data;
    if (current == null || current.menu.isEmpty) return null;
    final DateTime orderedAt = (state.generatedAt ?? _clock.now()).add(elapsed);
    // Restrict to dishes whose station is already open on the board.
    final Set<String> openStations = _openStationIds(current);
    final List<Dish> onBoard = openStations.isEmpty
        ? current.menu
        : current.menu
            .where((Dish d) => openStations.contains(d.stationId))
            .toList();
    final Kot kot = buildRandomKot(
      now: orderedAt,
      menu: onBoard.isEmpty ? current.menu : onBoard,
      id: const Uuid().v4(),
      random: _random,
    );
    addKot(kot);
    return kot;
  }

  /// The set of station ids that currently have at least one dish on the board
  /// (any ticket line) — i.e. the stations already "open". Used to keep the
  /// auto-drip within the existing station set.
  static Set<String> _openStationIds(DemoData data) {
    final Map<String, String> stationOfDish = <String, String>{
      for (final Dish d in data.menu) d.id: d.stationId,
    };
    return <String>{
      for (final Kot k in data.kots)
        for (final OrderLine l in k.lines)
          if (stationOfDish[l.dishId] != null) stationOfDish[l.dishId]!,
    };
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
        reFireSeq: l.reFireSeq + 1, // distinct cook so a repeat re-fire re-alerts
      ),
      reopenTicket: true,
    );
    _persist((KitchenRepository r) =>
        r.recookLine(lineId, reason: reason, reAtMins: reAtMins));
  }

  void fireNowLine(String lineId, {required int reAtMins}) {
    _updateLine(
      lineId,
      (OrderLine l) => l.copyWith(
        state: LineState.open,
        reAt: reAtMins,
        clearReason: true,
        reFireSeq: l.reFireSeq + 1, // distinct cook so a repeat re-fire re-alerts
      ),
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

  /// Set (or clear, when empty) a line's special instruction (e.g. "no salt").
  void setLineNote(String lineId, String? note) {
    final String? clean = (note ?? '').trim().isEmpty ? null : note!.trim();
    _updateLine(
      lineId,
      (OrderLine l) =>
          clean == null ? l.copyWith(clearNote: true) : l.copyWith(note: clean),
    );
    _persist((KitchenRepository r) => r.setLineNote(lineId, clean));
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
    _pending = _guardedPersist(op, repo);
  }

  /// Runs a write-through op, swallowing (logging) any failure so a Drift error
  /// never escapes as an unhandled async error. A plain `.catchError` here is a
  /// trap: most ops return `Future<DemoData>` (e.g. `replaceAll`), not
  /// `Future<void>`, so a void-returning error handler throws
  /// `ArgumentError` ("must return a value of the future's type") on the very
  /// failure it's meant to absorb. `try/await` sidesteps the typed return.
  Future<void> _guardedPersist(
    Future<void> Function(KitchenRepository repo) op,
    KitchenRepository repo,
  ) async {
    try {
      await op(repo);
    } on Object catch (e, st) {
      _log.error('persist failed', error: e, stackTrace: st);
    }
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
