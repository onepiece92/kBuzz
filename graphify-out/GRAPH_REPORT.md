# Graph Report - .  (2026-06-25)

## Corpus Check
- 36 files · ~57,804 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1254 nodes · 1853 edges · 81 communities (64 shown, 17 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 9 edges (avg confidence: 0.89)
- Token cost: 60,000 input · 3,500 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Scheduler Algorithm|Scheduler Algorithm]]
- [[_COMMUNITY_Toast  Fire-Alert UI|Toast / Fire-Alert UI]]
- [[_COMMUNITY_Scan Page & File Input|Scan Page & File Input]]
- [[_COMMUNITY_AI Demo-Data Generator|AI Demo-Data Generator]]
- [[_COMMUNITY_Scheduler Models|Scheduler Models]]
- [[_COMMUNITY_Tickets Page UI|Tickets Page UI]]
- [[_COMMUNITY_Drift Tables|Drift Tables]]
- [[_COMMUNITY_Demo Data Cubit|Demo Data Cubit]]
- [[_COMMUNITY_Ticket Scanner (Claude)|Ticket Scanner (Claude)]]
- [[_COMMUNITY_Fire Alert Cubit|Fire Alert Cubit]]
- [[_COMMUNITY_Stations Page|Stations Page]]
- [[_COMMUNITY_Profile Page Cards|Profile Page Cards]]
- [[_COMMUNITY_Domain Entities (Kitchen)|Domain Entities (Kitchen)]]
- [[_COMMUNITY_Kitchen Repository|Kitchen Repository]]
- [[_COMMUNITY_Board Widgets|Board Widgets]]
- [[_COMMUNITY_React Prototype (MultiKOT)|React Prototype (MultiKOT)]]
- [[_COMMUNITY_Demo Data Sample|Demo Data Sample]]
- [[_COMMUNITY_Service Clock Cubit|Service Clock Cubit]]
- [[_COMMUNITY_App-Icon Prep Script|App-Icon Prep Script]]
- [[_COMMUNITY_ScanProfile Stateless Widgets|Scan/Profile Stateless Widgets]]
- [[_COMMUNITY_Routing (go_router)|Routing (go_router)]]
- [[_COMMUNITY_Announcer (TTS)|Announcer (TTS)]]
- [[_COMMUNITY_Result  Failure Types|Result / Failure Types]]
- [[_COMMUNITY_Settings Cubit|Settings Cubit]]
- [[_COMMUNITY_Drift Database|Drift Database]]
- [[_COMMUNITY_TicketsNotes Tests|Tickets/Notes Tests]]
- [[_COMMUNITY_Service Control Bar|Service Control Bar]]
- [[_COMMUNITY_Ticket-Retain Tests|Ticket-Retain Tests]]
- [[_COMMUNITY_Fire-ToastProfile Tests|Fire-Toast/Profile Tests]]
- [[_COMMUNITY_Service-Layer Wiring|Service-Layer Wiring]]
- [[_COMMUNITY_Scheduler Concepts|Scheduler Concepts]]
- [[_COMMUNITY_DI Wiring|DI Wiring]]
- [[_COMMUNITY_ScanStations Flow Tests|Scan/Stations Flow Tests]]
- [[_COMMUNITY_Board Data Projection|Board Data Projection]]
- [[_COMMUNITY_Value Models (Equatable)|Value Models (Equatable)]]
- [[_COMMUNITY_Scheduler Golden Tests|Scheduler Golden Tests]]
- [[_COMMUNITY_Theme  Colors|Theme / Colors]]
- [[_COMMUNITY_App Badge Widget|App Badge Widget]]
- [[_COMMUNITY_Demo-Generator Tests|Demo-Generator Tests]]
- [[_COMMUNITY_Architecture & Roadmap|Architecture & Roadmap]]
- [[_COMMUNITY_Ticket-Scanner Tests|Ticket-Scanner Tests]]
- [[_COMMUNITY_Scheduler Ticket Tests|Scheduler Ticket Tests]]
- [[_COMMUNITY_App Bootstrap & Widget Tests|App Bootstrap & Widget Tests]]
- [[_COMMUNITY_App Shell (nav bar)|App Shell (nav bar)]]
- [[_COMMUNITY_Announcer Tests|Announcer Tests]]
- [[_COMMUNITY_Logger|Logger]]
- [[_COMMUNITY_Queue (Fire-next) Page|Queue (Fire-next) Page]]
- [[_COMMUNITY_Web Manifest|Web Manifest]]
- [[_COMMUNITY_Clock Abstraction|Clock Abstraction]]
- [[_COMMUNITY_ScanCapacity Widgets|Scan/Capacity Widgets]]
- [[_COMMUNITY_Settings  API-Key UI|Settings / API-Key UI]]
- [[_COMMUNITY_Sponsors  Drop Capture|Sponsors / Drop Capture]]
- [[_COMMUNITY_Sync Engine (roadmap)|Sync Engine (roadmap)]]
- [[_COMMUNITY_Re-fire  Priority|Re-fire / Priority]]
- [[_COMMUNITY_Format Helpers|Format Helpers]]
- [[_COMMUNITY_Ticket-Command Tests|Ticket-Command Tests]]
- [[_COMMUNITY_Fire-Alert Tests|Fire-Alert Tests]]
- [[_COMMUNITY_Coming-Soon Widget|Coming-Soon Widget]]
- [[_COMMUNITY_AI Scan (Claude vision)|AI Scan (Claude vision)]]
- [[_COMMUNITY_Service-Clock Tests|Service-Clock Tests]]
- [[_COMMUNITY_Scan Flow State|Scan Flow State]]
- [[_COMMUNITY_App-Toast Tests|App-Toast Tests]]
- [[_COMMUNITY_Notes Tests|Notes Tests]]
- [[_COMMUNITY_Demo-Persistence Tests|Demo-Persistence Tests]]
- [[_COMMUNITY_Typed Routing|Typed Routing]]
- [[_COMMUNITY_Announcer|Announcer]]
- [[_COMMUNITY_AppDatabase|AppDatabase]]
- [[_COMMUNITY_Cubit|Cubit]]
- [[_COMMUNITY_DemoData|DemoData]]
- [[_COMMUNITY_DemoDataCubit|DemoDataCubit]]
- [[_COMMUNITY_DemoDataGenerator|DemoDataGenerator]]
- [[_COMMUNITY_DishLiveStatus|DishLiveStatus]]
- [[_COMMUNITY_KitchenRepository|KitchenRepository]]
- [[_COMMUNITY_KotType|KotType]]
- [[_COMMUNITY_OrderLine|OrderLine]]
- [[_COMMUNITY_Random|Random]]
- [[_COMMUNITY_ScheduledDish|ScheduledDish]]
- [[_COMMUNITY_ServiceClockState|ServiceClockState]]
- [[_COMMUNITY_Const Map|Const Map]]
- [[_COMMUNITY_TicketScanner|TicketScanner]]
- [[_COMMUNITY_Web Bootstrap (index.html)|Web Bootstrap (index.html)]]

## God Nodes (most connected - your core abstractions)
1. `DemoDataCubit` - 26 edges
2. `ServiceClockCubit` - 19 edges
3. `SettingsCubit` - 15 edges
4. `Pure Dart scheduler` - 13 edges
5. `AppProviders` - 11 edges
6. `AppDatabase` - 9 edges
7. `KitchenRepository` - 8 edges
8. `Sync engine (outbox + delta pull)` - 8 edges
9. `build` - 7 edges
10. `DemoData` - 7 edges

## Surprising Connections (you probably didn't know these)
- `Sync engine + backend (headline project)` --references--> `Sync engine (outbox + delta pull)`  [INFERRED]
  JOB_DESCRIPTION.md → AGENTS.md
- `Scheduler input contract (skip/priority/rush)` --references--> `Pure Dart scheduler`  [EXTRACTED]
  TICKETS.md → AGENTS.md
- `Harden AI features for production` --references--> `Backend proxy (key never ships)`  [INFERRED]
  JOB_DESCRIPTION.md → AGENTS.md
- `Migrate equatable to freezed + json_serializable` --references--> `Domain entities (Station/Dish/OrderLine/Kot)`  [INFERRED]
  JOB_DESCRIPTION.md → AGENTS.md
- `Re-fire (reAt priority)` --references--> `PriorityKind (none/rush/fireNow/recook)`  [INFERRED]
  TICKETS.md → AGENTS.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Plate-together mechanism (JIT firing + strict coursing + cooking status)** — agents_just_in_time_firing, tickets_strict_coursing, tickets_plate_together, tickets_cooking_status [INFERRED 0.85]
- **Offline-first write path (UI to Drift to sync engine via outbox)** — agents_offline_first, agents_drift, agents_outbox_pattern, agents_sync_engine, agents_kitchen_repository [INFERRED 0.85]
- **Fire-alert flow (clock to detector to toast + announcer)** — agents_service_clock_cubit, agents_fire_alert_cubit, agents_app_toast_fire, agents_announcer [INFERRED 0.85]

## Communities (81 total, 17 thin omitted)

### Community 0 - "Scheduler Algorithm"
Cohesion: 0.04
Nodes (49): Dish, required DateTime now,
  SlaConfig, batchWin, bottleneck, byStation, byUid, config, cook (+41 more)

### Community 1 - "Toast / Fire-Alert UI"
Cohesion: 0.04
Nodes (47): Animation, AnimationController, @immutable, Duration, SingleTickerProviderStateMixin, static OverlayEntry?, static VoidCallback?, VoidCallback? (+39 more)

### Community 2 - "Scan Page & File Input"
Cohesion: 0.04
Nodes (47): package:desktop_drop/desktop_drop.dart, package:file_picker/file_picker.dart, package:image_picker/image_picker.dart, boardEpoch, _browse, cookMins, createState, dish (+39 more)

### Community 3 - "AI Demo-Data Generator"
Cohesion: 0.05
Nodes (43): _apiVersion, _bodyAsUtf8, _client, content, _defaultModel, dishIds, _errorMessageFrom, fallback (+35 more)

### Community 4 - "Scheduler Models"
Cohesion: 0.05
Nodes (41): Bottleneck?, batchable, batchWindowMins, byStation, cookMins, dishes, dishId, effective (+33 more)

### Community 5 - "Tickets Page UI"
Cohesion: 0.05
Nodes (41): _ageLabel, _allReady, _allResolved, _amber, board, build, clock, _codeOf (+33 more)

### Community 6 - "Drift Tables"
Cohesion: 0.06
Nodes (40): @DataClassName, BoolColumn get, DateTimeColumn get, batchable, capacity, color, cookMins, cookOverrideMins (+32 more)

### Community 7 - "Demo Data Cubit"
Cohesion: 0.05
Nodes (38): addKot, aiEnabled, aiProvider, clear, _clock, copyWith, data, _emitData (+30 more)

### Community 8 - "Ticket Scanner (Claude)"
Cohesion: 0.05
Nodes (36): _apiVersion, _bodyAsUtf8, _build, _client, cookMins, _defaultModel, dishId, _errorMessageFrom (+28 more)

### Community 9 - "Fire Alert Cubit"
Cohesion: 0.06
Nodes (34): _alerted, _applyData, base, batchSpokenText, byDish, _clockSub, close, _dataSub (+26 more)

### Community 10 - "Stations Page"
Cohesion: 0.06
Nodes (33): DishLiveStatus, package:kbuzz/core/format.dart, static const double, Station, barHeight, board, _buildBar, _buildNowLine (+25 more)

### Community 11 - "Profile Page Cards"
Cohesion: 0.06
Nodes (33): package:url_launcher/url_launcher.dart, PageController, _AiBadge, _controller, createState, data, _DemoSummary, dispose (+25 more)

### Community 12 - "Domain Entities (Kitchen)"
Cohesion: 0.06
Nodes (32): batchable, capacity, color, cookMins, cookOverrideMins, copyWith, dishId, emoji (+24 more)

### Community 13 - "Kitchen Repository"
Cohesion: 0.06
Nodes (30): Future, package:uuid/uuid.dart, addKot, _assemble, async, clearAll, clearKots, _db (+22 more)

### Community 14 - "Board Widgets"
Cohesion: 0.07
Nodes (27): atMin, BoardEmptyState, BottleneckBanner, build, color, dish, holdMins, icon (+19 more)

### Community 15 - "React Prototype (MultiKOT)"
Cohesion: 0.11
Nodes (17): C(), Chip(), codeOf(), DetailCard(), fmt(), liveStatus(), M(), MENU (+9 more)

### Community 16 - "Demo Data Sample"
Cohesion: 0.08
Nodes (24): _random, batch, buildDemoData, buildRandomDemoData, byName, cookMins, _demoMenu, _demoNotes (+16 more)

### Community 17 - "Service Clock Cubit"
Cohesion: 0.08
Nodes (23): close, copyWith, dishServed, elapsed, elapsedMins, _onTick, pause, plate (+15 more)

### Community 18 - "App-Icon Prep Script"
Cohesion: 0.08
Nodes (23): Image, package:image/image.dart, Pixel, alphaTile, cr, cream, creamTile, fg (+15 more)

### Community 19 - "Scan/Profile Stateless Widgets"
Cohesion: 0.08
Nodes (24): ProfilePage, _CaptureStep, _LineCard, _ReviewStep, _Stepper, _TableRow, _TypeSelector, StatelessWidget (+16 more)

### Community 20 - "Routing (go_router)"
Cohesion: 0.13
Nodes (22): @TypedGoRoute, appRouter, build, builder, MainShellRouteData, ProfileBranchData, ProfileRoute, QueueBranchData (+14 more)

### Community 21 - "Announcer (TTS)"
Cohesion: 0.10
Nodes (21): announce, Announcer, awaitCompletion, chime, _draining, _engine, _FlutterTtsEngine, _log (+13 more)

### Community 22 - "Result / Failure Types"
Cohesion: 0.14
Nodes (19): bool get, AppFailure, CacheFailure, cause, Err, failure, isOk, message (+11 more)

### Community 23 - "Settings Cubit"
Cohesion: 0.11
Nodes (18): aiConfigured, claudeApiKey, claudeApiKeyPref, copyWith, defaultFireToastDuration, duration, fireToastDuration, _fireToastKey (+10 more)

### Community 24 - "Drift Database"
Cohesion: 0.11
Nodes (18): dart:io, allKots, allMenu, allOrderLines, allStations, migration, _openOnDisk, schemaVersion (+10 more)

### Community 25 - "Tickets/Notes Tests"
Cohesion: 0.15
Nodes (15): db, main, now, repo, main, _now, main, _now (+7 more)

### Community 26 - "Service Control Bar"
Cohesion: 0.12
Nodes (17): _DishStatusTrailing, ServiceClockCubit, ServiceClockState, package:kbuzz/app/theme.dart, _submit, _StationTimeline, _showLineSheet, TicketsPage (+9 more)

### Community 27 - "Ticket-Retain Tests"
Cohesion: 0.13
Nodes (14): BoardData, board, clock, demo, kitchenMins, main, pump, pumpAndSettle (+6 more)

### Community 28 - "Fire-Toast/Profile Tests"
Cohesion: 0.15
Nodes (12): drive, driveOneFire, main, main, main, package:kbuzz/app/scaffold_with_nav_bar.dart, package:kbuzz/core/announce/announcer.dart, package:kbuzz/data/ai/demo_data_generator.dart (+4 more)

### Community 29 - "Service-Layer Wiring"
Cohesion: 0.15
Nodes (14): Announcer (on-device TTS + chime), AppProviders DI (di.dart), AppToast (top toast), AppToast.fire (bold fire alert), flutter_bloc / Cubit state management, Clock abstraction (injected), DemoDataCubit (Drift-backed + waiter commands), AI demo-data generator (+6 more)

### Community 30 - "Scheduler Concepts"
Cohesion: 0.18
Nodes (14): Dish batching, BoardData projection, Bottleneck detection, Per-station capacity placement, Golden + invariant scheduler tests, Just-in-time firing, Lane packing (station rail), Pure Dart scheduler (+6 more)

### Community 31 - "DI Wiring"
Cohesion: 0.21
Nodes (13): DemoDataGenerator, @DriftDatabase, AppProviders, build, child, database, prefs, AppDatabase (+5 more)

### Community 32 - "Scan/Stations Flow Tests"
Cohesion: 0.15
Nodes (11): build, KBuzzApp, DateTime, main, _now, main, FilledButton, package:flutter/material.dart (+3 more)

### Community 33 - "Board Data Projection"
Cohesion: 0.14
Nodes (13): BoardData, data, from, isBottleneck, kotsById, now, schedule, stationOf (+5 more)

### Community 34 - "Value Models (Equatable)"
Cohesion: 0.14
Nodes (14): FireAlert, FireToastPreset, Dish, Kot, OrderLine, Station, Equatable, Bottleneck (+6 more)

### Community 35 - "Scheduler Golden Tests"
Cohesion: 0.14
Nodes (13): dart:convert, demo, _goldenJson, kot, main, menuById, menuByName, now (+5 more)

### Community 36 - "Theme / Colors"
Cohesion: 0.15
Nodes (12): board, brandPrimary, brandSecondary, buildKBuzzTheme, KBuzzColors, kMonoNumberStyle, kStationColors, scheme (+4 more)

### Community 37 - "App Badge Widget"
Cohesion: 0.15
Nodes (12): Color, alpha, AppBadge, build, color, fontSize, fontWeight, horizontal (+4 more)

### Community 38 - "Demo-Generator Tests"
Cohesion: 0.15
Nodes (12): _claudeEnvelope, _expectValidated, _input, kot, main, now, _ok, _resp (+4 more)

### Community 39 - "Architecture & Roadmap"
Cohesion: 0.21
Nodes (12): Domain entities (Station/Dish/OrderLine/Kot), Layered architecture (Presentation/State/Domain/Data), MVP status (no Firebase, bloc, equatable), Offline-first architecture, React prototype (MultiKOT.jsx / KitchenSync.jsx), Flutter Engineer role, Migrate equatable to freezed + json_serializable, kBuzz kitchen-expo platform (+4 more)

### Community 40 - "Ticket-Scanner Tests"
Cohesion: 0.17
Nodes (11): dart:typed_data, _claudeResponse, _image, main, _menu, _resp, _scanner, _stations (+3 more)

### Community 41 - "Scheduler Ticket Tests"
Cohesion: 0.17
Nodes (11): DemoData, demo, idOf, kot, line, main, menuById, menuByName (+3 more)

### Community 42 - "App Bootstrap & Widget Tests"
Cohesion: 0.21
Nodes (9): main, prefs, package:flutter_test/flutter_test.dart, package:kbuzz/app/app.dart, package:kbuzz/app/di.dart, package:kbuzz/data/db/database.dart, SharedPreferences?, main (+1 more)

### Community 43 - "App Shell (nav bar)"
Cohesion: 0.22
Nodes (10): announcer, build, _goBranch, navigationShell, _onFireAlerts, ScaffoldWithNavBar, package:go_router/go_router.dart, package:kbuzz/app/router.dart (+2 more)

### Community 44 - "Announcer Tests"
Cohesion: 0.18
Nodes (10): bool?, awaitCompletion, awaitSet, finish, _inFlight, main, speak, spoken (+2 more)

### Community 45 - "Logger"
Cohesion: 0.18
Nodes (10): debug, error, info, _levelValue, _log, Logger, LogLevel, name (+2 more)

### Community 46 - "Queue (Fire-next) Page"
Cohesion: 0.18
Nodes (10): package:kbuzz/features/board/board_widgets.dart, board, build, config, dish, _FireRow, QueuePage, rank (+2 more)

### Community 47 - "Web Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 48 - "Clock Abstraction"
Cohesion: 0.20
Nodes (9): Clock, Clock, now, SystemClock, _FixedClock, _FixedClock, _FixedClock, _FixedClock (+1 more)

### Community 49 - "Scan/Capacity Widgets"
Cohesion: 0.20
Nodes (10): DemoDataCubit, DemoDataState, _generate, build, _NeedsData, ScanPage, build, _CapacityStepper (+2 more)

### Community 50 - "Settings / API-Key UI"
Cohesion: 0.20
Nodes (10): SettingsCubit, SettingsState, MaterialPageRoute, _ApiKeyCard, _ApiKeyCardState, build, _DemoDataCard, initState (+2 more)

### Community 51 - "Sponsors / Drop Capture"
Cohesion: 0.27
Nodes (10): _SponsorsCard, _SponsorsCardState, _DropCaptureStep, _DropCaptureStepState, State, StatefulWidget, _StationsRail, _StationsRailState (+2 more)

### Community 52 - "Sync Engine (roadmap)"
Cohesion: 0.33
Nodes (9): Drift (SQLite) local source of truth, Firebase Auth, Cloud Firestore backend, Last-write-wins conflict resolution, Outbox pattern, SyncCols mixin (sync metadata), Sync engine (outbox + delta pull), Repository commands (serve/void/recook/...) (+1 more)

### Community 53 - "Re-fire / Priority"
Cohesion: 0.33
Nodes (7): PriorityKind (none/rush/fireNow/recook), ScheduledDish (scheduler output), Fire now / expedite, Re-fire (reAt priority), Recook (send back with reason), Rush (tighten SLA, prioritise lines), Scheduler input contract (skip/priority/rush)

### Community 54 - "Format Helpers"
Cohesion: 0.29
Nodes (6): _dPrefix, _taPrefix, ticketCode, _tPrefix, package:kbuzz/domain/entities/kitchen.dart, RegExp

### Community 55 - "Ticket-Command Tests"
Cohesion: 0.29
Nodes (6): db, kotById, lineById, main, now, repo

### Community 56 - "Fire-Alert Tests"
Cohesion: 0.29
Nodes (6): _dish, dishes, main, stations, Map, package:kbuzz/features/service/cubit/fire_alert_cubit.dart

### Community 57 - "Coming-Soon Widget"
Cohesion: 0.29
Nodes (6): IconData, build, ComingSoon, icon, subtitle, title

### Community 58 - "AI Scan (Claude vision)"
Cohesion: 0.40
Nodes (6): Off-menu ad-hoc dishes, Backend proxy (key never ships), Anthropic Claude (claude-opus-4-8), TicketScanner (Claude vision), Vision LLM KOT scan, Harden AI features for production

### Community 59 - "Service-Clock Tests"
Cohesion: 0.33
Nodes (5): _dish, main, _member, _ticket, package:kbuzz/domain/scheduler/models.dart

### Community 60 - "Scan Flow State"
Cohesion: 0.40
Nodes (5): TicketScanner, _ensureKey, _processFile, _ScanFlow, _ScanFlowState

### Community 61 - "App-Toast Tests"
Cohesion: 0.40
Nodes (4): flush, main, pumpHost, package:kbuzz/core/widgets/app_toast.dart

### Community 62 - "Notes Tests"
Cohesion: 0.40
Nodes (4): dart:math, main, now, package:kbuzz/domain/scheduler/scheduler.dart

### Community 63 - "Demo-Persistence Tests"
Cohesion: 0.40
Nodes (4): db, main, _now, repo

## Knowledge Gaps
- **802 isolated node(s):** `STATIONS`, `MENU`, `SLA`, `TYPE`, `build` (+797 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **17 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `AppDatabase` connect `DI Wiring` to `Kitchen Repository`, `Ticket-Command Tests`, `Drift Database`, `Tickets/Notes Tests`, `Demo-Persistence Tests`?**
  _High betweenness centrality (0.030) - this node is a cross-community bridge._
- **Why does `DemoDataCubit` connect `Scan/Capacity Widgets` to `Scan Page & File Input`, `Tickets Page UI`, `Demo Data Cubit`, `Fire Alert Cubit`, `Stations Page`, `Profile Page Cards`, `Queue (Fire-next) Page`, `Settings / API-Key UI`, `Service Control Bar`, `Ticket-Retain Tests`, `Scan Flow State`, `DI Wiring`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `ServiceClockCubit` connect `Service Control Bar` to `Scan Page & File Input`, `Tickets Page UI`, `Fire Alert Cubit`, `App Shell (nav bar)`, `Queue (Fire-next) Page`, `Service Clock Cubit`, `Scan Flow State`, `DI Wiring`?**
  _High betweenness centrality (0.008) - this node is a cross-community bridge._
- **What connects `STATIONS`, `MENU`, `SLA` to the rest of the system?**
  _805 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Scheduler Algorithm` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Toast / Fire-Alert UI` be split into smaller, more focused modules?**
  _Cohesion score 0.0425531914893617 - nodes in this community are weakly interconnected._
- **Should `Scan Page & File Input` be split into smaller, more focused modules?**
  _Cohesion score 0.041666666666666664 - nodes in this community are weakly interconnected._