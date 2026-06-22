# Graph Report - .  (2026-06-22)

## Corpus Check
- 24 files · ~48,007 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 1143 nodes · 1699 edges · 51 communities (47 shown, 4 thin omitted)
- Extraction: 99% EXTRACTED · 1% INFERRED · 0% AMBIGUOUS · INFERRED: 12 edges (avg confidence: 0.86)
- Token cost: 24,000 input · 2,400 output

## Community Hubs (Navigation)
- [[_COMMUNITY_Toast & Station Rail|Toast & Station Rail]]
- [[_COMMUNITY_Scheduler Internals|Scheduler Internals]]
- [[_COMMUNITY_Service Clock & Result|Service Clock & Result]]
- [[_COMMUNITY_Scan Flow UI|Scan Flow UI]]
- [[_COMMUNITY_Icon Tool & Drift DB|Icon Tool & Drift DB]]
- [[_COMMUNITY_Scheduler Models|Scheduler Models]]
- [[_COMMUNITY_AI Demo Generators|AI Demo Generators]]
- [[_COMMUNITY_Drift Table Schema|Drift Table Schema]]
- [[_COMMUNITY_Demo Data Cubit|Demo Data Cubit]]
- [[_COMMUNITY_Profile & Settings|Profile & Settings]]
- [[_COMMUNITY_Tickets Page UI|Tickets Page UI]]
- [[_COMMUNITY_Architecture Concepts|Architecture Concepts]]
- [[_COMMUNITY_Stations Board UI|Stations Board UI]]
- [[_COMMUNITY_Ticket & Repo Tests|Ticket & Repo Tests]]
- [[_COMMUNITY_Announcer & Logging|Announcer & Logging]]
- [[_COMMUNITY_Kitchen Entities|Kitchen Entities]]
- [[_COMMUNITY_Ticket Scanner|Ticket Scanner]]
- [[_COMMUNITY_Kitchen Repository|Kitchen Repository]]
- [[_COMMUNITY_Board Widgets|Board Widgets]]
- [[_COMMUNITY_Fire Alert Cubit|Fire Alert Cubit]]
- [[_COMMUNITY_React Prototype|React Prototype]]
- [[_COMMUNITY_Plate-Together Concepts|Plate-Together Concepts]]
- [[_COMMUNITY_Demo Data Model|Demo Data Model]]
- [[_COMMUNITY_App Routing|App Routing]]
- [[_COMMUNITY_AI  Scanner Tests|AI / Scanner Tests]]
- [[_COMMUNITY_Scan Step Widgets|Scan Step Widgets]]
- [[_COMMUNITY_Fire Toast & Shell|Fire Toast & Shell]]
- [[_COMMUNITY_Bloc & Flow Tests|Bloc & Flow Tests]]
- [[_COMMUNITY_DI & Bootstrap|DI & Bootstrap]]
- [[_COMMUNITY_App Root & Material|App Root & Material]]
- [[_COMMUNITY_Theme & Colors|Theme & Colors]]
- [[_COMMUNITY_Board Data|Board Data]]
- [[_COMMUNITY_Scheduler Value Types|Scheduler Value Types]]
- [[_COMMUNITY_Ticket Scheduler Tests|Ticket Scheduler Tests]]
- [[_COMMUNITY_Scheduler Golden Tests|Scheduler Golden Tests]]
- [[_COMMUNITY_Domain Imports & Tests|Domain Imports & Tests]]
- [[_COMMUNITY_Tickets Retain Tests|Tickets Retain Tests]]
- [[_COMMUNITY_Logger|Logger]]
- [[_COMMUNITY_Web Manifest|Web Manifest]]
- [[_COMMUNITY_Clock Abstraction|Clock Abstraction]]
- [[_COMMUNITY_App State Bindings|App State Bindings]]
- [[_COMMUNITY_Coming Soon Placeholder|Coming Soon Placeholder]]
- [[_COMMUNITY_Test Harness & Entry|Test Harness & Entry]]
- [[_COMMUNITY_Providers & DI|Providers & DI]]
- [[_COMMUNITY_Service Control Bar|Service Control Bar]]
- [[_COMMUNITY_Tickets Bindings|Tickets Bindings]]
- [[_COMMUNITY_Demo Generator Impls|Demo Generator Impls]]
- [[_COMMUNITY_Station Timeline|Station Timeline]]
- [[_COMMUNITY_Announcer (thin)|Announcer (thin)]]
- [[_COMMUNITY_Cubit Base|Cubit Base]]
- [[_COMMUNITY_Clock State|Clock State]]

## God Nodes (most connected - your core abstractions)
1. `ServiceClockCubit` - 19 edges
2. `DemoDataCubit` - 14 edges
3. `AppProviders` - 11 edges
4. `SettingsCubit` - 11 edges
5. `Scheduler (pure Dart)` - 10 edges
6. `build` - 7 edges
7. `DemoData` - 7 edges
8. `FireAlertCubit` - 7 edges
9. `Just-in-time Firing` - 7 edges
10. `C()` - 6 edges

## Surprising Connections (you probably didn't know these)
- `kBuzz Flutter web bootstrap (index.html)` --references--> `Kitchen Display System (kBuzz KDS)`  [INFERRED]
  web/index.html → AGENTS.md
- `_FakeTts` --implements--> `TtsEngine`  [EXTRACTED]
  test/core/announcer_test.dart → lib/core/announce/announcer.dart
- `_DrivableFireAlertCubit` --calls--> `FireAlertState`  [EXTRACTED]
  test/features/fire_toast_settings_e2e_test.dart → lib/features/service/cubit/fire_alert_cubit.dart
- `_DrivableFireAlertCubit` --inherits--> `FireAlertCubit`  [EXTRACTED]
  test/features/fire_toast_settings_e2e_test.dart → lib/features/service/cubit/fire_alert_cubit.dart
- `QueuePage` --references--> `DemoDataCubit`  [EXTRACTED]
  lib/features/queue/queue_page.dart → lib/features/profile/cubit/demo_data_cubit.dart

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Plate-together loop (strict coursing + JIT firing + scheduler + plate time)** — tickets_strict_coursing, tickets_just_in_time_firing, tickets_scheduler_contract, tickets_plate_time [INFERRED 0.85]
- **Re-fire priority flow (recook + fire-now + re-fire + scheduler contract)** — tickets_recook, tickets_fire_now_expedite, tickets_re_fire, tickets_scheduler_contract [EXTRACTED 1.00]
- **Two-way kitchen feedback loop (loop + schedule + priority badges + line state)** — tickets_two_way_loop, tickets_schedule_fn, tickets_priority_badges, tickets_line_state_machine [INFERRED 0.85]

## Communities (51 total, 4 thin omitted)

### Community 0 - "Toast & Station Rail"
Cohesion: 0.04
Nodes (48): Animation, AnimationController, @immutable, SingleTickerProviderStateMixin, State, StatefulWidget, static OverlayEntry?, static VoidCallback? (+40 more)

### Community 1 - "Scheduler Internals"
Cohesion: 0.04
Nodes (48): required DateTime now,
  SlaConfig, batchWin, bottleneck, byStation, byUid, config, cook, dish (+40 more)

### Community 2 - "Service Clock & Result"
Cohesion: 0.05
Nodes (43): bool get, AppFailure, CacheFailure, cause, Err, failure, isOk, message (+35 more)

### Community 3 - "Scan Flow UI"
Cohesion: 0.05
Nodes (42): TicketScanner, flush, main, pumpHost, Dish, package:image_picker/image_picker.dart, package:kbuzz/core/widgets/app_toast.dart, boardEpoch (+34 more)

### Community 4 - "Icon Tool & Drift DB"
Cohesion: 0.05
Nodes (42): dart:io, allKots, allMenu, allOrderLines, allStations, migration, _openOnDisk, schemaVersion (+34 more)

### Community 5 - "Scheduler Models"
Cohesion: 0.05
Nodes (41): Bottleneck?, KotType, batchable, batchWindowMins, byStation, cookMins, dishes, dishId (+33 more)

### Community 6 - "AI Demo Generators"
Cohesion: 0.05
Nodes (39): _anthropicSchema, _anthropicVersion, _apiKey, _client, dishIds, _endpoint, errorMessageFrom, fallback (+31 more)

### Community 7 - "Drift Table Schema"
Cohesion: 0.06
Nodes (39): @DataClassName, BoolColumn get, DateTimeColumn get, batchable, capacity, color, cookMins, cookOverrideMins (+31 more)

### Community 8 - "Demo Data Cubit"
Cohesion: 0.05
Nodes (38): addKot, aiEnabled, aiProvider, clear, _clock, copyWith, data, _emitData (+30 more)

### Community 9 - "Profile & Settings"
Cohesion: 0.06
Nodes (36): copyWith, defaultFireToastDuration, duration, fireToastDuration, _fireToastKey, FireToastPreset, kFireToastPresets, label (+28 more)

### Community 10 - "Tickets Page UI"
Cohesion: 0.05
Nodes (37): OrderLine, _ageLabel, _allReady, _allResolved, _amber, board, build, clock (+29 more)

### Community 11 - "Architecture Concepts"
Cohesion: 0.08
Nodes (35): Announcer (on-device TTS), AppToast (top toast), AppToast.fire variant, Backend proxy (key-holding), Batching (merge identical batchable dishes), bloc (flutter_bloc + Cubit) state management, Bottleneck (station with largest late), Claude Sonnet 4.6 (vision model) (+27 more)

### Community 12 - "Stations Board UI"
Cohesion: 0.06
Nodes (34): BoardData, DishLiveStatus, static const double, static const int, Station, barHeight, board, _buildBar (+26 more)

### Community 13 - "Ticket & Repo Tests"
Cohesion: 0.09
Nodes (28): @DriftDatabase, dart:math, db, main, now, repo, db, kotById (+20 more)

### Community 14 - "Announcer & Logging"
Cohesion: 0.07
Nodes (31): announce, Announcer, awaitCompletion, chime, _draining, _engine, _FlutterTtsEngine, _log (+23 more)

### Community 15 - "Kitchen Entities"
Cohesion: 0.06
Nodes (31): batchable, capacity, color, cookMins, cookOverrideMins, copyWith, dishId, emoji (+23 more)

### Community 16 - "Ticket Scanner"
Cohesion: 0.07
Nodes (29): _anthropicVersion, _apiKey, _build, _client, _defaultModel, dishId, _endpoint, _errorMessageFrom (+21 more)

### Community 17 - "Kitchen Repository"
Cohesion: 0.07
Nodes (29): Future, package:uuid/uuid.dart, addKot, _assemble, async, clearAll, clearKots, _db (+21 more)

### Community 18 - "Board Widgets"
Cohesion: 0.07
Nodes (26): atMin, BoardEmptyState, BottleneckBanner, build, color, dish, holdMins, icon (+18 more)

### Community 19 - "Fire Alert Cubit"
Cohesion: 0.07
Nodes (26): _alerted, _applyData, batchSpokenText, _clockSub, close, _dataSub, detectFires, _dishes (+18 more)

### Community 20 - "React Prototype"
Cohesion: 0.11
Nodes (17): C(), Chip(), codeOf(), DetailCard(), fmt(), liveStatus(), M(), MENU (+9 more)

### Community 21 - "Plate-Together Concepts"
Cohesion: 0.11
Nodes (26): BoardData, Cooking Status (waiting/cooking/held/ready), cookingStatus(line), dishLiveStatus, Fire Now / Expedite, Held Status (holding for table), Just-in-time Firing, Line State Machine (open/served/void) (+18 more)

### Community 22 - "Demo Data Model"
Cohesion: 0.08
Nodes (23): batch, buildDemoData, buildRandomDemoData, byName, cookMins, _demoMenu, _demoStations, _dish (+15 more)

### Community 23 - "App Routing"
Cohesion: 0.13
Nodes (22): @TypedGoRoute, appRouter, build, builder, MainShellRouteData, ProfileBranchData, ProfileRoute, QueueBranchData (+14 more)

### Community 24 - "AI / Scanner Tests"
Cohesion: 0.10
Nodes (21): dart:convert, dart:typed_data, _claudeResponse, _expectValidated, _geminiResponse, _input, kot, main (+13 more)

### Community 25 - "Scan Step Widgets"
Cohesion: 0.09
Nodes (23): _CaptureStep, _LineCard, _ReviewStep, _Stepper, _TableRow, _TypeSelector, StatelessWidget, _DetailCard (+15 more)

### Community 26 - "Fire Toast & Shell"
Cohesion: 0.11
Nodes (20): announcer, build, _goBranch, navigationShell, _onFireAlerts, ScaffoldWithNavBar, FireAlertCubit, FireAlertState (+12 more)

### Community 27 - "Bloc & Flow Tests"
Cohesion: 0.11
Nodes (18): main, _now, main, FilledButton, package:flutter_bloc/flutter_bloc.dart, package:kbuzz/features/board/board_widgets.dart, package:kbuzz/features/profile/cubit/demo_data_cubit.dart, package:kbuzz/features/scan/scan_page.dart (+10 more)

### Community 28 - "DI & Bootstrap"
Cohesion: 0.14
Nodes (15): child, database, prefs, main, main, prefs, Logger, package:flutter/widgets.dart (+7 more)

### Community 29 - "App Root & Material"
Cohesion: 0.15
Nodes (12): build, KBuzzApp, package:flutter/material.dart, package:kbuzz/app/router.dart, package:kbuzz/app/theme.dart, ValueChanged, duration, elapsed (+4 more)

### Community 30 - "Theme & Colors"
Cohesion: 0.15
Nodes (12): board, brandPrimary, brandSecondary, buildKBuzzTheme, KBuzzColors, kMonoNumberStyle, kStationColors, scheme (+4 more)

### Community 31 - "Board Data"
Cohesion: 0.15
Nodes (12): BoardData, data, from, isBottleneck, kotsById, now, schedule, stationOf (+4 more)

### Community 32 - "Scheduler Value Types"
Cohesion: 0.15
Nodes (13): FireAlert, Dish, Kot, OrderLine, Station, Equatable, Bottleneck, Schedule (+5 more)

### Community 33 - "Ticket Scheduler Tests"
Cohesion: 0.15
Nodes (12): DemoData, demo, idOf, kot, line, main, menuById, menuByName (+4 more)

### Community 34 - "Scheduler Golden Tests"
Cohesion: 0.15
Nodes (12): demo, _goldenJson, kot, main, menuById, menuByName, now, ol (+4 more)

### Community 35 - "Domain Imports & Tests"
Cohesion: 0.17
Nodes (11): _dish, dishes, main, stations, _dish, main, _member, _ticket (+3 more)

### Community 36 - "Tickets Retain Tests"
Cohesion: 0.15
Nodes (12): board, clock, demo, kitchenMins, main, pump, pumpAndSettle, _Pumped (+4 more)

### Community 37 - "Logger"
Cohesion: 0.18
Nodes (10): debug, error, info, _levelValue, _log, Logger, LogLevel, name (+2 more)

### Community 38 - "Web Manifest"
Cohesion: 0.18
Nodes (10): background_color, description, display, icons, name, orientation, prefer_related_applications, short_name (+2 more)

### Community 39 - "Clock Abstraction"
Cohesion: 0.22
Nodes (8): Clock, Clock, now, SystemClock, _FixedClock, _FixedClock, _FixedClock, _FixedClock

### Community 40 - "App State Bindings"
Cohesion: 0.22
Nodes (9): DemoDataCubit, DemoDataState, build, _NeedsData, ScanPage, _submit, build, _CapacityStepper (+1 more)

### Community 41 - "Coming Soon Placeholder"
Cohesion: 0.29
Nodes (6): IconData, build, ComingSoon, icon, subtitle, title

### Community 42 - "Test Harness & Entry"
Cohesion: 0.38
Nodes (5): package:flutter_test/flutter_test.dart, package:kbuzz/app/app.dart, package:kbuzz/app/di.dart, main, main

### Community 43 - "Providers & DI"
Cohesion: 0.47
Nodes (6): AppProviders, build, AppDatabase, DemoDataGenerator?, KitchenRepository, StateStreamableSource

### Community 44 - "Service Control Bar"
Cohesion: 0.33
Nodes (6): _DishStatusTrailing, ServiceClockCubit, ServiceClockState, QueuePage, build, ServiceControlBar

### Community 45 - "Tickets Bindings"
Cohesion: 0.33
Nodes (6): DemoDataCubit, _DemoDataCard, _generate, _showLineSheet, _TicketCard, TicketsPage

### Community 46 - "Demo Generator Impls"
Cohesion: 0.50
Nodes (4): AnthropicDemoDataGenerator, DemoDataGenerator, DisabledDemoDataGenerator, GeminiDemoDataGenerator

## Knowledge Gaps
- **724 isolated node(s):** `STATIONS`, `MENU`, `SLA`, `TYPE`, `build` (+719 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `ServiceClockCubit` connect `Service Control Bar` to `Service Clock & Result`, `Scan Flow UI`, `Tickets Retain Tests`, `App State Bindings`, `Tickets Page UI`, `Providers & DI`, `Tickets Bindings`, `Fire Toast & Shell`, `DI & Bootstrap`, `App Root & Material`?**
  _High betweenness centrality (0.017) - this node is a cross-community bridge._
- **Why does `AppDatabase` connect `Ticket & Repo Tests` to `Kitchen Repository`, `Icon Tool & Drift DB`?**
  _High betweenness centrality (0.012) - this node is a cross-community bridge._
- **Why does `DemoData` connect `Ticket Scheduler Tests` to `Scheduler Golden Tests`, `Demo Data Cubit`, `Profile & Settings`, `Kitchen Repository`, `Demo Data Model`, `Board Data`?**
  _High betweenness centrality (0.009) - this node is a cross-community bridge._
- **What connects `STATIONS`, `MENU`, `SLA` to the rest of the system?**
  _725 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Toast & Station Rail` be split into smaller, more focused modules?**
  _Cohesion score 0.04251700680272109 - nodes in this community are weakly interconnected._
- **Should `Scheduler Internals` be split into smaller, more focused modules?**
  _Cohesion score 0.04081632653061224 - nodes in this community are weakly interconnected._
- **Should `Service Clock & Result` be split into smaller, more focused modules?**
  _Cohesion score 0.05454545454545454 - nodes in this community are weakly interconnected._