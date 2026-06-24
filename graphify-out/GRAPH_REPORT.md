# Graph Report - .  (2026-06-24)

## Corpus Check
- 20 files · ~52,868 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1191 nodes · 1770 edges · 63 communities (55 shown, 8 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS · INFERRED: 7 edges (avg confidence: 0.78)
- Token cost: 44,000 input · 3,500 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Scheduler Internals|Scheduler Internals]]
- [[_COMMUNITY_Architecture Concepts|Architecture Concepts]]
- [[_COMMUNITY_Icon Tool & Drift DB|Icon Tool & Drift DB]]
- [[_COMMUNITY_Toast & Fire Alert UI|Toast & Fire Alert UI]]
- [[_COMMUNITY_Scan Flow UI|Scan Flow UI]]
- [[_COMMUNITY_Scheduler Models|Scheduler Models]]
- [[_COMMUNITY_Drift Table Schema|Drift Table Schema]]
- [[_COMMUNITY_Tickets Page UI|Tickets Page UI]]
- [[_COMMUNITY_Demo Data Cubit|Demo Data Cubit]]
- [[_COMMUNITY_AI Demo Generator|AI Demo Generator]]
- [[_COMMUNITY_Demo Data & Theme|Demo Data & Theme]]
- [[_COMMUNITY_Ticket Scanner|Ticket Scanner]]
- [[_COMMUNITY_Fire Alert Cubit|Fire Alert Cubit]]
- [[_COMMUNITY_Stations Board UI|Stations Board UI]]
- [[_COMMUNITY_Profile Page UI|Profile Page UI]]
- [[_COMMUNITY_Kitchen Entities|Kitchen Entities]]
- [[_COMMUNITY_Kitchen Repository|Kitchen Repository]]
- [[_COMMUNITY_Board Widgets|Board Widgets]]
- [[_COMMUNITY_React Prototype|React Prototype]]
- [[_COMMUNITY_Plate-Together Concepts|Plate-Together Concepts]]
- [[_COMMUNITY_Service Clock & Status|Service Clock & Status]]
- [[_COMMUNITY_App Routing|App Routing]]
- [[_COMMUNITY_Board  Scan Widgets|Board / Scan Widgets]]
- [[_COMMUNITY_Bloc & Flow Tests|Bloc & Flow Tests]]
- [[_COMMUNITY_Tickets Tests|Tickets Tests]]
- [[_COMMUNITY_Result & Failures|Result & Failures]]
- [[_COMMUNITY_Settings Cubit|Settings Cubit]]
- [[_COMMUNITY_Announcer|Announcer]]
- [[_COMMUNITY_DI & Bootstrap|DI & Bootstrap]]
- [[_COMMUNITY_Domain & Repo Tests|Domain & Repo Tests]]
- [[_COMMUNITY_Fire-Next Queue UI|Fire-Next Queue UI]]
- [[_COMMUNITY_SchedulerSettings Value Types|Scheduler/Settings Value Types]]
- [[_COMMUNITY_Scheduler Golden Tests|Scheduler Golden Tests]]
- [[_COMMUNITY_Board Data|Board Data]]
- [[_COMMUNITY_Test Harness & Material|Test Harness & Material]]
- [[_COMMUNITY_Service Control Bar|Service Control Bar]]
- [[_COMMUNITY_Ticket Scheduler Tests|Ticket Scheduler Tests]]
- [[_COMMUNITY_Scanner Tests|Scanner Tests]]
- [[_COMMUNITY_Generator Tests|Generator Tests]]
- [[_COMMUNITY_Providers & DI|Providers & DI]]
- [[_COMMUNITY_Announcer Tests|Announcer Tests]]
- [[_COMMUNITY_Logger|Logger]]
- [[_COMMUNITY_Stateful UI Widgets|Stateful UI Widgets]]
- [[_COMMUNITY_Web Manifest|Web Manifest]]
- [[_COMMUNITY_App Shell (Fire alerts)|App Shell (Fire alerts)]]
- [[_COMMUNITY_Demo Data Tests|Demo Data Tests]]
- [[_COMMUNITY_App State Bindings|App State Bindings]]
- [[_COMMUNITY_Settings & Demo Cards|Settings & Demo Cards]]
- [[_COMMUNITY_Coming Soon Placeholder|Coming Soon Placeholder]]
- [[_COMMUNITY_Fire Alert Tests|Fire Alert Tests]]
- [[_COMMUNITY_Models  Service Tests|Models / Service Tests]]
- [[_COMMUNITY_Station Timeline|Station Timeline]]
- [[_COMMUNITY_Clock Abstraction|Clock Abstraction]]
- [[_COMMUNITY_Tickets Bindings|Tickets Bindings]]
- [[_COMMUNITY_TTS Engine|TTS Engine]]
- [[_COMMUNITY_Fire Toast Item|Fire Toast Item]]
- [[_COMMUNITY_Announcer (thin)|Announcer (thin)]]
- [[_COMMUNITY_Generator (thin)|Generator (thin)]]
- [[_COMMUNITY_Repository (thin)|Repository (thin)]]
- [[_COMMUNITY_Clock State|Clock State]]
- [[_COMMUNITY_Misc Map|Misc Map]]
- [[_COMMUNITY_Scanner (thin)|Scanner (thin)]]
- [[_COMMUNITY_Web Bootstrap|Web Bootstrap]]

## God Nodes (most connected - your core abstractions)
1. `DemoDataCubit` - 22 edges
2. `SettingsCubit` - 15 edges
3. `schedule() — Pure Deterministic Scheduler` - 15 edges
4. `ServiceClockCubit` - 11 edges
5. `AppProviders` - 11 edges
6. `KitchenRepository` - 8 edges
7. `Just-in-time Firing` - 7 edges
8. `build` - 7 edges
9. `FireAlertCubit` - 7 edges
10. `C()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `_FakeTts` --implements--> `TtsEngine`  [EXTRACTED]
  test/core/announcer_test.dart → lib/core/announce/announcer.dart
- `_DrivableFireAlertCubit` --inherits--> `FireAlertCubit`  [EXTRACTED]
  test/features/fire_toast_settings_e2e_test.dart → lib/features/service/cubit/fire_alert_cubit.dart
- `_DrivableFireAlertCubit` --calls--> `FireAlertState`  [EXTRACTED]
  test/features/fire_toast_settings_e2e_test.dart → lib/features/service/cubit/fire_alert_cubit.dart
- `QueuePage` --references--> `DemoDataCubit`  [EXTRACTED]
  lib/features/queue/queue_page.dart → lib/features/profile/cubit/demo_data_cubit.dart
- `QueuePage` --references--> `ServiceClockCubit`  [EXTRACTED]
  lib/features/queue/queue_page.dart → lib/features/service/cubit/service_clock_cubit.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Plate-Together Loop (JIT + strict coursing + scheduler contract + plate time)** — agents_just_in_time_firing, agents_strict_coursing, agents_schedule_fn, agents_plate_together, agents_dish_live_status [EXTRACTED 1.00]
- **Offline-First Write Path (UI → cubit → repository → Drift → outbox → sync)** — agents_offline_first, agents_state_layer_bloc, agents_data_layer, agents_drift, agents_outbox, agents_sync_engine [EXTRACTED 1.00]
- **Vision-LLM Scan Flow (TicketScanner → Gemini → proxy/key → OrderLine)** — agents_ticket_scanner, agents_gemini, agents_backend_proxy, agents_settings_cubit, agents_order_line [EXTRACTED 1.00]

## Communities (63 total, 8 thin omitted)

### Community 0 - "Scheduler Internals"
Cohesion: 0.04
Nodes (48): required DateTime now,
  SlaConfig, batchWin, bottleneck, byStation, byUid, config, cook, dish (+40 more)

### Community 1 - "Architecture Concepts"
Cohesion: 0.07
Nodes (46): Announcer (on-device TTS abstraction), AppToast.fire (bold top toast variant), Backend Proxy (key-never-ships, TODO), batchSpokenText (de-duped combined announce), Batching (same station/dish within window), BoardData (shared board projection), Bottleneck Station, Clock (injected time abstraction) (+38 more)

### Community 2 - "Icon Tool & Drift DB"
Cohesion: 0.05
Nodes (41): dart:io, allKots, allMenu, allOrderLines, allStations, migration, _openOnDisk, schemaVersion (+33 more)

### Community 3 - "Toast & Fire Alert UI"
Cohesion: 0.05
Nodes (41): Animation, AnimationController, static OverlayEntry?, static VoidCallback?, accent, _activeClose, AppToast, AppToastType (+33 more)

### Community 4 - "Scan Flow UI"
Cohesion: 0.05
Nodes (40): TicketScanner, Dish, package:image_picker/image_picker.dart, boardEpoch, cookMins, createState, dish, _Draft (+32 more)

### Community 5 - "Scheduler Models"
Cohesion: 0.05
Nodes (40): Bottleneck?, batchable, batchWindowMins, byStation, cookMins, dishes, dishId, effective (+32 more)

### Community 6 - "Drift Table Schema"
Cohesion: 0.06
Nodes (39): @DataClassName, BoolColumn get, DateTimeColumn get, batchable, capacity, color, cookMins, cookOverrideMins (+31 more)

### Community 7 - "Tickets Page UI"
Cohesion: 0.05
Nodes (38): Color, OrderLine, _ageLabel, _allReady, _allResolved, _amber, board, build (+30 more)

### Community 8 - "Demo Data Cubit"
Cohesion: 0.05
Nodes (38): addKot, aiEnabled, aiProvider, clear, _clock, copyWith, data, _emitData (+30 more)

### Community 9 - "AI Demo Generator"
Cohesion: 0.05
Nodes (37): _bodyAsUtf8, _client, _defaultModel, dishIds, _errorMessageFrom, fallback, fromEnvironment, generate (+29 more)

### Community 10 - "Demo Data & Theme"
Cohesion: 0.05
Nodes (36): board, brandPrimary, brandSecondary, buildKBuzzTheme, KBuzzColors, kMonoNumberStyle, kStationColors, scheme (+28 more)

### Community 11 - "Ticket Scanner"
Cohesion: 0.06
Nodes (32): _bodyAsUtf8, _build, _client, cookMins, _defaultModel, dishId, _errorMessageFrom, fromEnvironment (+24 more)

### Community 12 - "Fire Alert Cubit"
Cohesion: 0.06
Nodes (32): Cubit, _alerted, _applyData, base, batchSpokenText, byDish, _clockSub, close (+24 more)

### Community 13 - "Stations Board UI"
Cohesion: 0.06
Nodes (32): DishLiveStatus, static const double, Station, barHeight, board, _buildBar, _buildNowLine, capacity (+24 more)

### Community 14 - "Profile Page UI"
Cohesion: 0.06
Nodes (32): package:url_launcher/url_launcher.dart, PageController, _AiBadge, _controller, createState, data, _DemoSummary, dispose (+24 more)

### Community 15 - "Kitchen Entities"
Cohesion: 0.06
Nodes (31): batchable, capacity, color, cookMins, cookOverrideMins, copyWith, dishId, emoji (+23 more)

### Community 16 - "Kitchen Repository"
Cohesion: 0.06
Nodes (30): DemoData, Future, package:uuid/uuid.dart, addKot, _assemble, async, clearAll, clearKots (+22 more)

### Community 17 - "Board Widgets"
Cohesion: 0.07
Nodes (26): atMin, BoardEmptyState, BottleneckBanner, build, color, dish, holdMins, icon (+18 more)

### Community 18 - "React Prototype"
Cohesion: 0.11
Nodes (17): C(), Chip(), codeOf(), DetailCard(), fmt(), liveStatus(), M(), MENU (+9 more)

### Community 19 - "Plate-Together Concepts"
Cohesion: 0.11
Nodes (26): BoardData, Cooking Status (waiting/cooking/held/ready), cookingStatus(line), dishLiveStatus, Fire Now / Expedite, Held Status (holding for table), Just-in-time Firing, Line State Machine (open/served/void) (+18 more)

### Community 20 - "Service Clock & Status"
Cohesion: 0.08
Nodes (24): close, copyWith, DishLiveStatus, dishServed, elapsed, elapsedMins, _onTick, pause (+16 more)

### Community 21 - "App Routing"
Cohesion: 0.13
Nodes (23): @TypedGoRoute, appRouter, build, builder, MainShellRouteData, ProfileBranchData, ProfileRoute, QueueBranchData (+15 more)

### Community 22 - "Board / Scan Widgets"
Cohesion: 0.08
Nodes (24): _SponsorBanner, _StatChip, _CaptureStep, _LineCard, _ReviewStep, _Stepper, _TableRow, _TypeSelector (+16 more)

### Community 23 - "Bloc & Flow Tests"
Cohesion: 0.13
Nodes (17): drive, driveOneFire, main, main, main, _now, main, FilledButton (+9 more)

### Community 24 - "Tickets Tests"
Cohesion: 0.11
Nodes (18): BoardData, dart:math, main, _now, board, clock, demo, kitchenMins (+10 more)

### Community 25 - "Result & Failures"
Cohesion: 0.15
Nodes (19): bool get, AppFailure, CacheFailure, cause, Err, failure, isOk, message (+11 more)

### Community 26 - "Settings Cubit"
Cohesion: 0.10
Nodes (19): aiConfigured, copyWith, defaultFireToastDuration, duration, fireToastDuration, _fireToastKey, geminiApiKey, geminiApiKeyPref (+11 more)

### Community 27 - "Announcer"
Cohesion: 0.12
Nodes (18): announce, Announcer, awaitCompletion, chime, _draining, _engine, _log, maxQueued (+10 more)

### Community 28 - "DI & Bootstrap"
Cohesion: 0.15
Nodes (14): child, database, prefs, main, main, prefs, Logger, package:flutter/widgets.dart (+6 more)

### Community 29 - "Domain & Repo Tests"
Cohesion: 0.14
Nodes (14): @DriftDatabase, db, kotById, lineById, main, now, repo, AppDatabase (+6 more)

### Community 30 - "Fire-Next Queue UI"
Cohesion: 0.12
Nodes (14): build, KBuzzApp, package:kbuzz/app/router.dart, package:kbuzz/app/theme.dart, package:kbuzz/features/board/board_widgets.dart, board, build, config (+6 more)

### Community 31 - "Scheduler/Settings Value Types"
Cohesion: 0.14
Nodes (14): FireAlert, FireToastPreset, Dish, Kot, OrderLine, Station, Equatable, Bottleneck (+6 more)

### Community 32 - "Scheduler Golden Tests"
Cohesion: 0.14
Nodes (13): dart:convert, demo, _goldenJson, kot, main, menuById, menuByName, now (+5 more)

### Community 33 - "Board Data"
Cohesion: 0.15
Nodes (12): BoardData, data, from, isBottleneck, kotsById, now, schedule, stationOf (+4 more)

### Community 34 - "Test Harness & Material"
Cohesion: 0.19
Nodes (10): flush, main, pumpHost, package:flutter/material.dart, package:flutter_test/flutter_test.dart, package:kbuzz/app/app.dart, package:kbuzz/app/di.dart, package:kbuzz/core/widgets/app_toast.dart (+2 more)

### Community 35 - "Service Control Bar"
Cohesion: 0.18
Nodes (12): ServiceClockCubit, ServiceClockState, cubit, ValueChanged, duration, build, elapsed, _ElapsedReadout (+4 more)

### Community 36 - "Ticket Scheduler Tests"
Cohesion: 0.15
Nodes (12): DemoData, demo, idOf, kot, line, main, menuById, menuByName (+4 more)

### Community 37 - "Scanner Tests"
Cohesion: 0.17
Nodes (11): dart:typed_data, _geminiResponse, _image, main, _menu, _resp, _scanner, _stations (+3 more)

### Community 38 - "Generator Tests"
Cohesion: 0.17
Nodes (11): _claudeResponse, _expectValidated, _geminiResponse, _input, kot, main, now, _ok (+3 more)

### Community 39 - "Providers & DI"
Cohesion: 0.24
Nodes (11): DemoDataGenerator, AppProviders, build, AppDatabase, Clock, _FixedClock, _FixedClock, _FixedClock (+3 more)

### Community 40 - "Announcer Tests"
Cohesion: 0.18
Nodes (10): bool?, awaitCompletion, awaitSet, finish, _inFlight, main, speak, spoken (+2 more)

### Community 41 - "Logger"
Cohesion: 0.18
Nodes (10): debug, error, info, _levelValue, _log, Logger, LogLevel, name (+2 more)

### Community 42 - "Stateful UI Widgets"
Cohesion: 0.24
Nodes (11): _ApiKeyCard, _ApiKeyCardState, _SponsorsCard, _SponsorsCardState, SingleTickerProviderStateMixin, State, StatefulWidget, _StationsRail (+3 more)

### Community 43 - "Web Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 44 - "App Shell (Fire alerts)"
Cohesion: 0.24
Nodes (9): announcer, build, _goBranch, navigationShell, _onFireAlerts, ScaffoldWithNavBar, package:kbuzz/features/service/cubit/fire_alert_cubit.dart, package:kbuzz/features/service/widgets/service_control_bar.dart (+1 more)

### Community 45 - "Demo Data Tests"
Cohesion: 0.22
Nodes (8): db, main, now, repo, DateTime, package:kbuzz/data/demo/demo_data.dart, main, _now

### Community 46 - "App State Bindings"
Cohesion: 0.22
Nodes (9): DemoDataCubit, DemoDataState, _generate, build, _NeedsData, ScanPage, build, _CapacityStepper (+1 more)

### Community 47 - "Settings & Demo Cards"
Cohesion: 0.29
Nodes (7): SettingsCubit, SettingsState, build, _DemoDataCard, initState, _save, _SettingsCard

### Community 48 - "Coming Soon Placeholder"
Cohesion: 0.29
Nodes (6): IconData, build, ComingSoon, icon, subtitle, title

### Community 49 - "Fire Alert Tests"
Cohesion: 0.33
Nodes (5): _dish, dishes, main, stations, List

### Community 50 - "Models / Service Tests"
Cohesion: 0.33
Nodes (5): _dish, main, _member, _ticket, package:kbuzz/domain/scheduler/models.dart

### Community 51 - "Station Timeline"
Cohesion: 0.50
Nodes (4): _DishStatusTrailing, _submit, ServiceClockCubit, _StationTimeline

### Community 52 - "Clock Abstraction"
Cohesion: 0.50
Nodes (3): Clock, now, SystemClock

### Community 53 - "Tickets Bindings"
Cohesion: 0.50
Nodes (4): DemoDataCubit, _showLineSheet, _TicketCard, TicketsPage

### Community 54 - "TTS Engine"
Cohesion: 0.67
Nodes (3): _FlutterTtsEngine, TtsEngine, _FakeTts

## Knowledge Gaps
- **754 isolated node(s):** `STATIONS`, `MENU`, `SLA`, `TYPE`, `build` (+749 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `DemoDataCubit` connect `App State Bindings` to `Scan Flow UI`, `Providers & DI`, `Demo Data Cubit`, `Fire Alert Cubit`, `Stations Board UI`, `Profile Page UI`, `Settings & Demo Cards`, `Station Timeline`, `Tickets Tests`, `DI & Bootstrap`, `Fire-Next Queue UI`?**
  _High betweenness centrality (0.011) - this node is a cross-community bridge._
- **Why does `SettingsCubit` connect `Settings & Demo Cards` to `Providers & DI`, `Stateful UI Widgets`, `Fire Alert Cubit`, `App Shell (Fire alerts)`, `Profile Page UI`, `Settings Cubit`, `DI & Bootstrap`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **Why does `AppDatabase` connect `Domain & Repo Tests` to `Icon Tool & Drift DB`?**
  _High betweenness centrality (0.005) - this node is a cross-community bridge._
- **What connects `STATIONS`, `MENU`, `SLA` to the rest of the system?**
  _754 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Scheduler Internals` be split into smaller, more focused modules?**
  _Cohesion score 0.04081632653061224 - nodes in this community are weakly interconnected._
- **Should `Architecture Concepts` be split into smaller, more focused modules?**
  _Cohesion score 0.06763285024154589 - nodes in this community are weakly interconnected._
- **Should `Icon Tool & Drift DB` be split into smaller, more focused modules?**
  _Cohesion score 0.046511627906976744 - nodes in this community are weakly interconnected._