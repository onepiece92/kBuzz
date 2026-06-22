# Graph Report - .  (2026-06-21)

## Corpus Check
- cluster-only mode — file stats not available

## Summary
- 894 nodes · 1331 edges · 44 communities (43 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 2 edges (avg confidence: 0.85)
- Token cost: 0 input · 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Result & Failures|Result & Failures]]
- [[_COMMUNITY_Scheduler Algorithm|Scheduler Algorithm]]
- [[_COMMUNITY_Drift Database & Repository|Drift Database & Repository]]
- [[_COMMUNITY_Drift Tables|Drift Tables]]
- [[_COMMUNITY_Scheduler Models|Scheduler Models]]
- [[_COMMUNITY_Scan  KOT Draft|Scan / KOT Draft]]
- [[_COMMUNITY_Toast Overlay & Rail Widgets|Toast Overlay & Rail Widgets]]
- [[_COMMUNITY_Stations Rail View|Stations Rail View]]
- [[_COMMUNITY_React Prototype (MultiKOT)|React Prototype (MultiKOT)]]
- [[_COMMUNITY_Fire Alerts & UI Conventions (AGENTS.md)|Fire Alerts & UI Conventions (AGENTS.md)]]
- [[_COMMUNITY_AI Demo-Data Generator|AI Demo-Data Generator]]
- [[_COMMUNITY_Routing (go_router)|Routing (go_router)]]
- [[_COMMUNITY_App Shell & Entry|App Shell & Entry]]
- [[_COMMUNITY_Board UI Widgets|Board UI Widgets]]
- [[_COMMUNITY_Demo Data Cubit|Demo Data Cubit]]
- [[_COMMUNITY_Domain Entities|Domain Entities]]
- [[_COMMUNITY_Service Clock & Board Status|Service Clock & Board Status]]
- [[_COMMUNITY_Demo Data Seed|Demo Data Seed]]
- [[_COMMUNITY_DI & Wiring|DI & Wiring]]
- [[_COMMUNITY_Scheduler Tests|Scheduler Tests]]
- [[_COMMUNITY_Scan Stepper & Cards|Scan Stepper & Cards]]
- [[_COMMUNITY_Theme & Colors|Theme & Colors]]
- [[_COMMUNITY_Board Data Derivation|Board Data Derivation]]
- [[_COMMUNITY_Tickets View|Tickets View]]
- [[_COMMUNITY_Repository & Demo Tests|Repository & Demo Tests]]
- [[_COMMUNITY_Value Objects & Entities|Value Objects & Entities]]
- [[_COMMUNITY_Profile Page|Profile Page]]
- [[_COMMUNITY_Queue View|Queue View]]
- [[_COMMUNITY_Logger|Logger]]
- [[_COMMUNITY_Demo Data UI & Scan Flow|Demo Data UI & Scan Flow]]
- [[_COMMUNITY_Tickets Retain Test|Tickets Retain Test]]
- [[_COMMUNITY_Clock Abstraction|Clock Abstraction]]
- [[_COMMUNITY_Scan Flow Test|Scan Flow Test]]
- [[_COMMUNITY_Service Clock Test|Service Clock Test]]
- [[_COMMUNITY_App Root|App Root]]
- [[_COMMUNITY_AI Scan Layer (AGENTS.md)|AI Scan Layer (AGENTS.md)]]
- [[_COMMUNITY_Decision bloc over Riverpod|Decision: bloc over Riverpod]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]
- [[_COMMUNITY_Community 40|Community 40]]
- [[_COMMUNITY_Community 41|Community 41]]
- [[_COMMUNITY_Community 42|Community 42]]
- [[_COMMUNITY_Community 43|Community 43]]
- [[_COMMUNITY_Community 44|Community 44]]

## God Nodes (most connected - your core abstractions)
1. `DemoDataCubit` - 23 edges
2. `AGENTS.md — kBuzz (Flutter)` - 20 edges
3. `ServiceClockCubit` - 17 edges
4. `AppProviders` - 10 edges
5. `AppDatabase` - 9 edges
6. `DemoDataGenerator` - 8 edges
7. `build` - 7 edges
8. `KitchenRepository` - 7 edges
9. `C()` - 6 edges
10. `SyncCols` - 6 edges

## Surprising Connections (you probably didn't know these)
- `AppToast.fire bold toast variant` --references--> `AppToast`  [EXTRACTED]
  AGENTS.md → lib/core/widgets/app_toast.dart
- `AppToast top-anchored toast API (never SnackBar)` --references--> `AppToast`  [EXTRACTED]
  AGENTS.md → lib/core/widgets/app_toast.dart
- `AppProviders` --references--> `DemoDataGenerator`  [EXTRACTED]
  lib/app/di.dart → lib/data/ai/demo_data_generator.dart
- `AppProviders` --references--> `DemoDataCubit`  [EXTRACTED]
  lib/app/di.dart → lib/features/profile/cubit/demo_data_cubit.dart
- `AppProviders` --references--> `FireAlertCubit`  [EXTRACTED]
  lib/app/di.dart → lib/features/service/cubit/fire_alert_cubit.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Fire-alert flow (detect on service clock -> bold toast + spoken announce)** — agents_kbuzz_service_clock_layer, agents_kbuzz_firealert_model, agents_kbuzz_bloclistener_nav_shell, agents_kbuzz_apptoast_fire_variant, agents_kbuzz_announcer_service, agents_kbuzz_edge_triggered_fire_detection [EXTRACTED 1.00]
- **Announcer implementations (SystemAnnouncer + NoopAnnouncer)** — agents_kbuzz_announcer_service, agents_kbuzz_system_announcer, agents_kbuzz_noop_announcer [EXTRACTED 1.00]
- **MVP architecture decisions (bloc, no Firebase, pure scheduler, Drift truth)** — agents_kbuzz_bloc_over_riverpod, agents_kbuzz_no_firebase_mvp, agents_kbuzz_pure_scheduler, agents_kbuzz_drift_source_of_truth, agents_kbuzz_offline_first [EXTRACTED 1.00]

## Communities (44 total, 1 thin omitted)

### Community 0 - "Result & Failures"
Cohesion: 0.05
Nodes (44): bool get, AppFailure, CacheFailure, cause, Err, failure, isOk, message (+36 more)

### Community 1 - "Scheduler Algorithm"
Cohesion: 0.04
Nodes (45): Dish, required DateTime now,
  SlaConfig, batchWin, bottleneck, byStation, byUid, config, cook (+37 more)

### Community 2 - "Drift Database & Repository"
Cohesion: 0.05
Nodes (35): dart:async, dart:io, allKots, allMenu, allOrderLines, allStations, _openOnDisk, schemaVersion (+27 more)

### Community 3 - "Drift Tables"
Cohesion: 0.08
Nodes (33): @DataClassName, BoolColumn get, DateTimeColumn get, batchable, capacity, color, cookMins, cookOverrideMins (+25 more)

### Community 4 - "Scheduler Models"
Cohesion: 0.06
Nodes (33): Bottleneck?, batchable, batchWindowMins, byStation, cookMins, dishes, dishId, emoji (+25 more)

### Community 5 - "Scan / KOT Draft"
Cohesion: 0.06
Nodes (37): TicketScanner, package:image_picker/image_picker.dart, boardEpoch, cookMins, createState, dish, _Draft, _DraftLine (+29 more)

### Community 6 - "Toast Overlay & Rail Widgets"
Cohesion: 0.05
Nodes (39): Animation, AnimationController, SingleTickerProviderStateMixin, State, StatefulWidget, static OverlayEntry?, _StationsRail, _StationsRailState (+31 more)

### Community 7 - "Stations Rail View"
Cohesion: 0.06
Nodes (33): dart:math, static const double, static const int, Station, barHeight, board, _buildBar, _buildNowLine (+25 more)

### Community 8 - "React Prototype (MultiKOT)"
Cohesion: 0.11
Nodes (17): C(), Chip(), codeOf(), DetailCard(), fmt(), liveStatus(), M(), MENU (+9 more)

### Community 9 - "Fire Alerts & UI Conventions (AGENTS.md)"
Cohesion: 0.10
Nodes (25): Announcer service (on-device TTS + chime, injected), AppProviders bloc DI (MultiRepositoryProvider + MultiBlocProvider), AppToast.fire bold toast variant, AppToast top-anchored toast API (never SnackBar), BlocListener on nav shell (alerts surface on any tab), Clock abstraction (injected; never call now() directly), Combine/de-dupe simultaneous fires into one toast + announcement, Drift (SQLite) as local source of truth (+17 more)

### Community 10 - "AI Demo-Data Generator"
Cohesion: 0.05
Nodes (39): _anthropicSchema, _anthropicVersion, _apiKey, _client, dishIds, _endpoint, errorMessageFrom, fallback (+31 more)

### Community 11 - "Routing (go_router)"
Cohesion: 0.12
Nodes (24): @TypedGoRoute, appRouter, build, builder, MainShellRouteData, ProfileBranchData, ProfileRoute, QueueBranchData (+16 more)

### Community 12 - "App Shell & Entry"
Cohesion: 0.23
Nodes (9): main, package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:kbuzz/app/app.dart, package:kbuzz/app/di.dart, package:kbuzz/core/announce/announcer.dart, package:kbuzz/data/db/database.dart, main (+1 more)

### Community 13 - "Board UI Widgets"
Cohesion: 0.08
Nodes (23): atMin, BoardEmptyState, BottleneckBanner, build, color, dish, holdMins, icon (+15 more)

### Community 14 - "Demo Data Cubit"
Cohesion: 0.08
Nodes (23): addKot, aiEnabled, aiProvider, clear, _clock, copyWith, data, _emitData (+15 more)

### Community 15 - "Domain Entities"
Cohesion: 0.09
Nodes (21): batchable, capacity, color, cookMins, cookOverrideMins, copyWith, dishId, emoji (+13 more)

### Community 16 - "Service Clock & Board Status"
Cohesion: 0.13
Nodes (16): _DishStatusTrailing, ServiceClockCubit, ServiceClockState, QueuePage, _submit, _StationTimeline, TicketsPage, ValueChanged (+8 more)

### Community 17 - "Demo Data Seed"
Cohesion: 0.12
Nodes (16): batch, buildDemoData, byName, cookMins, _dish, emoji, hold, id (+8 more)

### Community 18 - "DI & Wiring"
Cohesion: 0.19
Nodes (13): _, @DriftDatabase, announcer, AppProviders, build, child, database, AppDatabase (+5 more)

### Community 19 - "Scheduler Tests"
Cohesion: 0.14
Nodes (13): DemoData, demo, _goldenJson, kot, main, menuById, menuByName, now (+5 more)

### Community 20 - "Scan Stepper & Cards"
Cohesion: 0.12
Nodes (16): _CaptureStep, _LineCard, _ReviewStep, _Stepper, _TableRow, _TypeSelector, StatelessWidget, _DetailCard (+8 more)

### Community 21 - "Theme & Colors"
Cohesion: 0.15
Nodes (12): board, brandPrimary, brandSecondary, buildKBuzzTheme, KBuzzColors, kMonoNumberStyle, kStationColors, scheme (+4 more)

### Community 22 - "Board Data Derivation"
Cohesion: 0.14
Nodes (13): BoardData, data, from, isBottleneck, kotsById, now, schedule, stationOf (+5 more)

### Community 23 - "Tickets View"
Cohesion: 0.13
Nodes (14): TicketStatus, board, build, _byTargetThenPlate, _colorFor, config, kot, _partition (+6 more)

### Community 24 - "Repository & Demo Tests"
Cohesion: 0.11
Nodes (21): db, main, now, repo, DateTime, db, main, _now (+13 more)

### Community 25 - "Value Objects & Entities"
Cohesion: 0.17
Nodes (12): FireAlert, Dish, Kot, OrderLine, Station, Equatable, Bottleneck, Schedule (+4 more)

### Community 26 - "Profile Page"
Cohesion: 0.09
Nodes (23): DemoDataCubit, DemoDataState, _AiBadge, build, data, _DemoDataCard, _DemoSummary, enabled (+15 more)

### Community 27 - "Queue View"
Cohesion: 0.20
Nodes (9): package:kbuzz/features/board/board_widgets.dart, board, build, config, dish, _FireRow, rank, BoardConfig (+1 more)

### Community 28 - "Logger"
Cohesion: 0.18
Nodes (10): debug, error, info, _levelValue, _log, Logger, LogLevel, name (+2 more)

### Community 29 - "Demo Data UI & Scan Flow"
Cohesion: 0.08
Nodes (25): Cubit, _alerted, _applyData, _clockSub, close, _dataSub, detectFires, _dishes (+17 more)

### Community 31 - "Tickets Retain Test"
Cohesion: 0.20
Nodes (9): clock, demo, main, pumpAndSettle, pumpWidget, _pumpWithDemo, package:kbuzz/features/queue/queue_page.dart, package:kbuzz/features/tickets/tickets_page.dart (+1 more)

### Community 32 - "Clock Abstraction"
Cohesion: 0.25
Nodes (7): Clock, Clock, now, SystemClock, _FixedClock, _FixedClock, _FixedClock

### Community 33 - "Scan Flow Test"
Cohesion: 0.08
Nodes (24): 0.5 MVP status — what's actually built right now (read this before §1+), 0. Non-negotiables (read these twice), 10.5 Fire alerts — bold toast + audio announce on "fire next", 10. The scheduler (port the prototype exactly), 11. Firebase, 12. Coding conventions, 13. Build, run, test, 14. Agent operating rules (+16 more)

### Community 34 - "Service Clock Test"
Cohesion: 0.33
Nodes (5): _dish, main, _member, _ticket, package:kbuzz/domain/scheduler/models.dart

### Community 35 - "App Root"
Cohesion: 0.40
Nodes (4): build, KBuzzApp, package:kbuzz/app/router.dart, package:kbuzz/app/theme.dart

### Community 36 - "AI Scan Layer (AGENTS.md)"
Cohesion: 1.00
Nodes (3): AI scan layer (vision LLM reads KOT + suggests cook times), Backend proxy holds API key server-side (no key in app binary), Claude Sonnet vision model (claude-sonnet-4-6) for scan

### Community 38 - "Community 38"
Cohesion: 0.09
Nodes (23): announce, Announcer, chime, _log, NoopAnnouncer, SystemAnnouncer, _tts, Announcer (+15 more)

### Community 39 - "Community 39"
Cohesion: 0.07
Nodes (29): _anthropicVersion, _apiKey, _build, _client, _defaultModel, dishId, _endpoint, _errorMessageFrom (+21 more)

### Community 40 - "Community 40"
Cohesion: 0.10
Nodes (21): dart:convert, dart:typed_data, _claudeResponse, _expectValidated, _geminiResponse, _input, kot, main (+13 more)

### Community 41 - "Community 41"
Cohesion: 0.29
Nodes (6): _dish, dishes, main, stations, List, Map

### Community 42 - "Community 42"
Cohesion: 0.29
Nodes (6): IconData, build, ComingSoon, icon, subtitle, title

### Community 43 - "Community 43"
Cohesion: 0.50
Nodes (4): AnthropicDemoDataGenerator, DemoDataGenerator, DisabledDemoDataGenerator, GeminiDemoDataGenerator

### Community 44 - "Community 44"
Cohesion: 0.50
Nodes (3): main, package:flutter_bloc/flutter_bloc.dart, package:kbuzz/features/service/cubit/service_clock_cubit.dart

## Knowledge Gaps
- **547 isolated node(s):** `STATIONS`, `MENU`, `SLA`, `TYPE`, `build` (+542 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppToast` connect `Fire Alerts & UI Conventions (AGENTS.md)` to `Toast Overlay & Rail Widgets`?**
  _High betweenness centrality (0.049) - this node is a cross-community bridge._
- **Why does `AppDatabase` connect `DI & Wiring` to `Repository & Demo Tests`, `Drift Database & Repository`?**
  _High betweenness centrality (0.031) - this node is a cross-community bridge._
- **What connects `STATIONS`, `MENU`, `SLA` to the rest of the system?**
  _550 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Result & Failures` be split into smaller, more focused modules?**
  _Cohesion score 0.05314009661835749 - nodes in this community are weakly interconnected._
- **Should `Scheduler Algorithm` be split into smaller, more focused modules?**
  _Cohesion score 0.043478260869565216 - nodes in this community are weakly interconnected._
- **Should `Drift Database & Repository` be split into smaller, more focused modules?**
  _Cohesion score 0.05405405405405406 - nodes in this community are weakly interconnected._
- **Should `Drift Tables` be split into smaller, more focused modules?**
  _Cohesion score 0.0784313725490196 - nodes in this community are weakly interconnected._