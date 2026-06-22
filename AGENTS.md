# AGENTS.md — kBuzz (Flutter)

> Operating manual for the AI coding agent on this repo. Read this fully before writing code.
> Also valid as `CLAUDE.md` / `.cursorrules` — rename or symlink as needed.

kBuzz is an **offline-first** Kitchen Display System. A cook photographs a paper KOT
(Kitchen Order Ticket); a **vision AI model** (Google **Gemini** today; provider-pluggable — §8) reads
it into line items and suggests a cook time per dish, then the app schedules **fire times across the
whole kitchen** so that every dish on a ticket plates together — respecting each station's capacity,
holdable-vs-not dishes, batching, per-ticket SLAs, and **just-in-time firing** so non-bottleneck dishes
cook to finish *with* the table rather than early (§10).

**Brand:** kBuzz — primary `#ff6600` (orange), secondary `#274074` (navy). These are the app's
identity colors; the functional station colors (grill/steam/wok…) are separate and encode meaning,
not brand. See §3 (`theme.dart`) and §12.

**The UX and scheduling behaviour are already specified by the React prototype** (`MultiKOT.jsx`,
`KitchenSync.jsx`, the original prototype filename — the product is now kBuzz). Treat those as the
source of truth for screens, states, copy, and the scheduling algorithm. This document is the source
of truth for **architecture and conventions**. When they conflict, the prototype wins on behaviour,
this file wins on structure.

> **Companion spec:** `TICKETS.md` is the detailed spec for the **waiter Tickets page** (line/ticket
> state machine, serve/recook/fire-now/rush/void, plate-together). Read it alongside this file when
> touching `features/tickets/`, the ticket-state fields (§4), or the scheduler's waiter inputs (§10).
> Two kBuzz refinements over the prototype live there: **just-in-time firing** and **strict coursing**.

---

## 0. Non-negotiables (read these twice)

1. **Offline is the default, not a fallback.** Every feature must work with the network fully off,
   for hours, with no spinner-of-death. The kitchen wifi *will* drop mid-rush.
2. **The UI never touches Firestore or dio directly.** UI → **bloc (cubit/bloc)** → Repository →
   **Drift (local source of truth)**. The sync engine moves data between Drift and Firestore in the
   background. *(MVP: no Firestore yet — UI → cubit → repository → Drift; Firestore sync is post-MVP. See §0.5.)*
3. **The scheduler is pure Dart, deterministic, and unit-tested.** No Flutter imports, no `DateTime.now()`
   inside it (pass `now` in), no Firestore calls. It is the product's IP — protect its test coverage.
4. **Generated code is generated, never hand-edited.** `*.g.dart`, `*.freezed.dart`, Drift output.
   If it's wrong, fix the source + rerun build_runner.
5. **Small, reviewable changes.** One concern per change. Run `flutter analyze` + tests + build_runner
   before declaring done (see §13).
6. Don't add a dependency without a one-line justification in the PR. Prefer the packages already here.

---

## 0.5 MVP status — what's actually built right now (read this before §1+)

> Most of this document describes the **target architecture** for later milestones. The current
> codebase is an intentionally slim MVP skeleton. Where the sections below conflict with the spec,
> **this section wins for "what exists today."** Update both this section and the relevant spec
> section as features land.

**Decisions that override the spec for the MVP:**

| Area | Spec (target) | MVP (now) | Why |
|------|---------------|-----------|-----|
| State management | Riverpod (+ riverpod_generator) | **flutter_bloc / `Cubit`** (+ `equatable`) | Team chose bloc over Riverpod. DI via bloc's `MultiRepositoryProvider` + `MultiBlocProvider`. |
| Backend / sync | Cloud Firestore + Firebase Auth | **None — no Firebase in the MVP** | Runs fully offline / local-only. `main.dart` does **no** Firebase init. Sync (§6/§11) is deferred. |
| Local DB | Drift (SQLite) | **✅ wired** — local source of truth | `data/db/` (tables + `AppDatabase`) + `data/repositories/KitchenRepository`. The cubit writes through to Drift and hydrates on launch, so data survives restart. `data/demo/` is the deterministic seed. |
| Models | freezed + json_serializable | **plain immutable classes + `equatable`** | No codegen for models yet; entities live in `domain/entities/`. |
| Scan parse + cook-time | **Vision LLM** (Gemini, or Claude) | **✅ implemented** | `features/scan/` captures a photo (`image_picker`) → `data/ai/TicketScanner` (**Google Gemini** vision, `gemini-2.0-flash`, structured JSON) reads it into a draft against the menu → review → add KOT. Key comes from **Profile → Settings (in-app, persisted)** or `--dart-define=GEMINI_API_KEY` (fallback); falls back to manual entry. Gemini returns `{dishId|name, stationId?, qty, cookMins?}`: matched items use the **AI cook-time** suggestion; **off-menu items become ad-hoc dishes** (suggested station) added to the menu so real tickets schedule (§8). A separate AI **demo-data generator** (`data/ai/`, Gemini **or** Anthropic) shares the same in-app key. |
| Scheduler | pure Dart scheduler (§10) | **✅ ported & tested + extended** | `domain/scheduler/` (`scheduler.dart` + `models.dart`), 1:1 from `MultiKOT.jsx`; golden (Node-captured) + invariant tests. **Extended** with waiter-driven inputs (served/void skip, `reAt` re-fire priority, `rush` SLA, `PriorityKind` badges) and opt-in **just-in-time firing** (`SchedulerConfig.justInTime`, on via `BoardData`). Golden stays pinned with `justInTime: false`. |
| Waiter Tickets page | expo view (TICKETS.md) | **✅ implemented** | `features/tickets/` — tap a line → action sheet (serve / recook+reason / fire-now / void), footer (rush / serve-all / done+confirm). Drives a line/ticket state machine on Drift (write-through), reacts through the scheduler. **Strict coursing**: a line shows `held` until its whole ticket can plate. See `TICKETS.md`. |
| Settings | Profile → Settings | **✅ partial** | `features/profile/cubit/settings_cubit.dart` — fire-toast hold-time presets **and the in-app Gemini API key** (`SettingsCubit`/`SettingsState`), persisted via **`shared_preferences`** (injected by `main`; session-only in tests). The key drives **both** scan + AI demo-data (read live in `app/di.dart` via `*.resolved(apiKey: …)`). Announce on/off toggle is still TODO (§10.5). |
| Toasts | top toasts via `AppToast` | **✅ implemented** (`lib/core/widgets/app_toast.dart`) | Top-anchored overlay toast; never `SnackBar`. See §12. |
| Fire alerts | bold toast + audio announce on "fire next" | **✅ implemented** | `FireAlertCubit` (`features/service/`) detects fire-next crossings off the clock+schedule; the nav shell presents `AppToast.fire` (bold top toast) + `Announcer.announce` (on-device TTS via `flutter_tts` + system chime). See §10.5. |

**Packages actually in `pubspec.yaml` today:** `go_router` + `go_router_builder` (typed routes),
`flutter_bloc` + `bloc` + `equatable`, `uuid`, `drift` + `sqlite3_flutter_libs` + `path` + `path_provider`
(local DB), `http` (AI generator + scanner), `image_picker` (scan capture), `flutter_tts` (fire-alert
announce), `shared_preferences` (settings persistence). Dev: `flutter_lints`, `build_runner`, `drift_dev`.
**Not present yet:** firebase_*, dio, retrofit, freezed, flutter_riverpod, connectivity_plus,
audioplayers, mocktail. Don't assume they're available — add (with justification) when the milestone needs them.

**What exists in `lib/` now:**
- `app/` — `app.dart` (`MaterialApp.router`), `router.dart` (+ generated `router.g.dart`), `di.dart`
  (`AppProviders`: bloc-based DI), `theme.dart`, `scaffold_with_nav_bar.dart`.
- `core/` — `result.dart` (`Result<T>`/`AppFailure`), `clock.dart`, `logger.dart`,
  `widgets/app_toast.dart` (top toast), `widgets/coming_soon.dart` (placeholder).
- `domain/entities/kitchen.dart` — `Station`, `Dish`, `OrderLine`, `Kot`, `KotType` plus the waiter
  state-machine types `LineState` (open/served/void) and `TicketState` (active/done), as immutable
  `Equatable` classes in one file. (`Station.color` is an ARGB `int`, not a `Color`.) `OrderLine` carries
  `id`/`state`/`recook`/`reAt`/`reason`; `Kot` carries `status`/`rush` (see §4 / TICKETS.md).
- `domain/scheduler/` — `scheduler.dart` (pure `schedule(...)` + `ticketStatusFor`) and `models.dart`
  (`Schedule`, `ScheduledDish` [+ `priority: PriorityKind`, `recookReason`], `SlaConfig`,
  `SchedulerConfig` [+ `justInTime`], `PriorityKind`, `Bottleneck`, `StationLane`, `TicketStatus`).
- `data/` — `db/` (Drift tables + `AppDatabase`), `repositories/kitchen_repository.dart` (the data API),
  `demo/demo_data.dart` (deterministic seed), `ai/demo_data_generator.dart` (opt-in Claude generator).
- `features/board/` — shared board projection: `BoardData.from(demo, now:)` runs the scheduler and
  exposes `fireOrder` / `stationLanes` / `statusOf` / `isBottleneck`; `board_widgets.dart` renders it.
- `features/` — `stations/`, `queue/`, `tickets/` render the live schedule via `features/board/`.
  `tickets/` is the **waiter expo** (action sheet + state machine + strict-coursing `held` status —
  TICKETS.md). `service/` (live `ServiceClockCubit` + run controls; boards animate
  waiting/cooking/**held**/ready; `FireAlertCubit`). `scan/` (capture/manual → review → add KOT).
  `profile/` (`cubit/demo_data_cubit.dart`: generate/clear; `cubit/settings_cubit.dart`: fire-toast
  hold-time, persisted via `shared_preferences`).

**Navigation:** there are **four** bottom tabs now, not three — `/stations`, `/queue`, `/tickets`,
**`/profile`** — in a `StatefulShellRoute.indexedStack`, plus `/scan` pushed full-screen above the shell.
The Profile tab hosts the demo-data generator (`DemoDataCubit.generate/clear`, Drift-backed; AI-generated when a key is set).

---

## 1. Stack

| Concern            | Choice                                   | Notes |
|--------------------|------------------------------------------|-------|
| Framework          | Flutter (stable channel)                 | Dart SDK `^3.12.2` |
| Routing            | **go_router** `^17.x` + go_router_builder | Typed routes, `StatefulShellRoute` for the tab bar |
| Local DB (truth)   | **Drift** (SQLite)                       | Relational, reactive streams, testable migrations |
| Backend / sync     | **Cloud Firestore** + Firebase Auth      | ⛔ **Post-MVP** — not in the build yet (see §0.5). Offline persistence on; mirror of Drift |
| Scan parse + cook-time | **Vision LLM** — Google **Gemini** (`gemini-2.0-flash`) today, or Claude; `http` client | 🟡 **Built (direct HTTPS); proxy pending.** Gemini reads the KOT photo into structured lines (§8). The key is entered **in-app (Profile → Settings, persisted on-device)** or via `--dart-define` (fallback). Returns matched + **off-menu (ad-hoc)** lines with an **AI cook-time** estimate. ⚠️ Still client-side — the **backend proxy so the key never leaves the server is TODO** (§8). |
| State management   | **bloc** (`flutter_bloc` + `Cubit`)      | Chosen over Riverpod. DI via `MultiRepositoryProvider`/`MultiBlocProvider`; state via `equatable` |
| Models             | **equatable** (MVP) → freezed + json_serializable (later) | Immutable, value equality. freezed/json codegen lands with the data layer |
| Connectivity       | connectivity_plus                        | Triggers sync; never gates writes |
| Audio / announce   | **flutter_tts** (on-device TTS) + bundled chime (`audioplayers`) | Spoken "fire next" alert (§10.5). On-device only — must work offline. Add when building the alert. |
| IDs                | uuid (v7 preferred — time-sortable)      | Client-generated so offline rows have stable keys |

Why these specifically:
- **Drift over Isar/Hive**: the domain is relational (ticket → lines → station; the scheduler joins
  across all of it) and needs complex queries + migrations. As of 2026 Isar is unmaintained for new
  projects; Drift is the maintained SQLite-ORM default with first-class reactive streams.
- **go_router is feature-complete/stable** — fine to depend on long-term.
- **Vision LLM over a self-hosted OCR model** for scan: a single multimodal call reads the photo *and* proposes per-item cook times, and the model can be swapped (Claude ↔ a free tier) without an app release because the call goes through a backend proxy. It is *not* the data backend; Firestore is. A plain `dio`/`http` client is enough — no `retrofit` needed for one endpoint.

### pubspec — MVP (what's actually in `pubspec.yaml` today)

```yaml
environment:
  sdk: ^3.12.2

dependencies:
  flutter: { sdk: flutter }
  cupertino_icons: ^1.0.8
  go_router: ^17.3.0
  flutter_bloc: ^9.1.1
  bloc: ^9.2.1
  equatable: ^2.0.8
  uuid: ^4.5.3
  drift: ^2.34.0                # local source of truth (SQLite)
  sqlite3_flutter_libs: ^0.5    # bundled sqlite
  path: ^1.9                    # db path
  path_provider: ^2.1           # app docs dir for the db file
  http: ^1.2.2                  # vision-LLM scan + AI demo generator (no proxy yet)
  image_picker: ^1.2.2          # scan capture
  flutter_tts: ^4.2.5           # fire-alert spoken announce (on-device)
  shared_preferences: ^2.5.5    # settings persistence (fire-toast hold time)

dev_dependencies:
  flutter_test: { sdk: flutter }
  flutter_lints: ^6.0.0
  go_router_builder: ^4.3.0
  build_runner: ^2.15.0
  drift_dev: ^2.34.0
```

### pubspec — additions per later milestone (do **not** add until the milestone needs them; run `flutter pub outdated` for latest stable)

```yaml
# milestone 2 (Drift data layer):
#   drift, drift_dev, sqlite3_flutter_libs, path_provider, path
# milestone 3 (freezed models, if adopted):
#   freezed, freezed_annotation, json_annotation, json_serializable
# milestone 4 (live run — fire alerts, §10.5):
#   flutter_tts (on-device TTS), audioplayers (bundled chime asset)
# milestone 5 (AI scan — vision LLM via backend proxy, §8):
#   dio (or http), image_picker (or camera)   # no retrofit needed for one endpoint
# milestone 6 (sync + Firebase):
#   firebase_core, cloud_firestore, firebase_auth (via `flutterfire configure`), connectivity_plus
# testing:
#   mocktail
```

---

## 2. Architecture (offline-first, layered)

```
┌──────────────────────────────────────────────────────────────┐
│ Presentation   widgets + go_router screens (Stations/Queue/   │
│                Tickets/Scan). Dumb about data sources.        │
├──────────────────────────────────────────────────────────────┤
│ State          bloc cubits/blocs. Expose immutable states.    │
│                No business logic, no I/O — call repositories.  │
├──────────────────────────────────────────────────────────────┤
│ Domain         Pure Dart: entities + the Scheduler (§10).     │
│                Zero Flutter/Firebase imports. Fully testable.  │
├──────────────────────────────────────────────────────────────┤
│ Data           Repositories (the only API the app sees).      │
│   ├─ Drift  ── LOCAL SOURCE OF TRUTH. All reads are streams.  │
│   ├─ Sync   ── outbox push + delta pull, background, decoupled.│
│   └─ Remote ── Firestore + vision-LLM scan client (proxy).     │
└──────────────────────────────────────────────────────────────┘
```

**Read path:** UI watches a bloc cubit → repository → `Stream<List<T>>` from Drift.
Firestore changes land in Drift via the sync engine, so the same stream updates the UI. The UI has
no idea whether data came from cache or cloud.

**Write path:** UI calls a repository command → repository writes to Drift **immediately** (optimistic,
marks the row `dirty`, bumps `updatedAt`) and enqueues an outbox op → UI updates instantly from the
Drift stream → sync engine flushes the outbox to Firestore when online.

The state layer must stay connectivity-agnostic. `connectivity_plus` only nudges the sync engine; it
never blocks a write.

*(MVP: the State layer is bloc cubits over a Drift-backed repository (write-through + hydrate); the Sync/Remote rows below are
the post-MVP target — see §0.5.)*

---

## 3. Project structure (feature-first)

```
lib/
  app/
    app.dart                 # MaterialApp.router (KBuzzApp)
    router.dart              # GoRouter config (typed routes + StatefulShellRoute, 4 tabs + /scan)
    di.dart                  # AppProviders: bloc DI (MultiRepositoryProvider + MultiBlocProvider)
    scaffold_with_nav_bar.dart # bottom-tab shell wrapping the StatefulNavigationShell
    theme.dart               # KDS dark theme; brand #ff6600 / #274074; station colors; mono number style
  core/
    result.dart             # Result<T>/AppFailure (no throwing across layers)
    clock.dart              # Clock abstraction (inject into scheduler/sync; never call now() directly)
    logger.dart
    announce/announcer.dart # Announcer abstraction (SystemAnnouncer = on-device TTS + chime; NoopAnnouncer) — §10.5
    widgets/app_toast.dart  # top toast; AppToast.show/success/error/failure + AppToast.fire (bold fire alert, §10.5/§12)
  domain/
    entities/               # Kot, OrderLine, Dish, Station, ScheduledDish ...
    scheduler/
      scheduler.dart        # PURE. schedule(kots, menu, stations, sla, now) -> Schedule
      models.dart           # Schedule, ScheduledDish, value objects
  data/
    db/
      database.dart         # Drift @DriftDatabase, migrations
      tables.dart           # Drift table defs
      daos/                 # KotDao, MenuDao, StationDao, OutboxDao
    remote/
      firestore/            # collection refs, mappers (entity <-> Firestore map)
      api/
        scan_client.dart    # dio/http client → backend proxy → vision LLM (read KOT + suggest cook times, §8)
        dto/                # request/response DTOs (json_serializable)
        interceptors.dart   # auth header, logging, retry/backoff
    sync/
      sync_engine.dart      # push outbox + pull deltas; conflict resolution
      outbox.dart           # op model + queue semantics
    repositories/
      kot_repository.dart   # the ONLY data API features call
      menu_repository.dart
      station_repository.dart
  features/
    board/                  # shared projection: BoardData (runs schedule()) + board_widgets
    stations/               # station rail — lane-packed schedule (wired via features/board/)
    queue/                  # flat fire-next feed — schedule fire order (wired)
    tickets/                # table-centric expo view — plate-together status (wired)
    scan/                   # camera/picker -> OCR -> review -> create KOT (placeholder in MVP)
    profile/                # MVP: profile tab; cubit/ hosts the demo-data generator
    service/                # live run clock, speed control, shared board state; fire-alert detector (§10.5)
  data/
    demo/demo_data.dart     # MVP in-memory sample dataset (replaced by Drift later)
  main.dart                 # MVP: runApp(AppProviders(KBuzzApp)) — NO Firebase init yet
```

Keep `domain/` import-clean: it must compile with zero `package:flutter`, `package:cloud_firestore`,
or `package:drift` imports. (A CI grep on `domain/scheduler/**` enforcing this is welcome.)

---

## 4. Domain model

Mirror the prototype. Core entities are immutable `Equatable` classes in `domain/entities/kitchen.dart`
(MVP — freezed later). The waiter ticket-state fields are specified in detail in **`TICKETS.md`**:

- **Station** `{ id, name, color, capacity }` — capacity = how many dishes can cook concurrently.
- **Dish** (menu item) `{ id, name, emoji, stationId, cookMins, holdable, batchable }`.
  `cookMins` is the *predicted* default; a ticket line may override it.
- **OrderLine** `{ id?, dishId, qty, cookOverrideMins?, state, recook, reAt?, reason? }` —
  `state: LineState` (open/served/void, waiter-driven); `recook` count; `reAt` = the minute it was
  re-fired (recook or fire-now → priority); `reason` = recook reason. (TICKETS.md §"Data model".)
- **Kot** `{ id, table, type (dineIn|takeaway|delivery), orderedAt, lines[], status, rush }` —
  `status: TicketState` (active/done); `rush` tightens the SLA + prioritises every line.
- **ScheduledDish** (scheduler output) `{ stationId, name, emoji, cookMins, holdable, members[],
  qty, target, fireAt, finishAt, holdMins, lateMins, lane, priority, recookReason }` —
  `priority: PriorityKind` (none/rush/fireNow/recook) drives the kitchen badge.
- **Schedule** `{ dishes[], byStation, horizonMins, bottleneck? }`.
- Enums: **`LineState`**, **`TicketState`**, **`PriorityKind`** — all with `.wire`/`fromWire` for Drift.

Stations / menu / SLA are **config data in Firestore + Drift**, not hardcoded constants. The prototype
hardcodes them; the app loads them so a restaurant can edit menu, stations, capacities, and SLAs.

---

## 5. Drift: tables + sync metadata

Every synced table carries the same trailer so the sync engine and conflict resolution are uniform:

```dart
// mix into every synced table
mixin SyncCols on Table {
  TextColumn get id => text()();                          // uuid v7, client-generated
  DateTimeColumn get updatedAt => dateTime()();           // server time once synced
  IntColumn get version => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))(); // tombstone
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();    // needs push
  @override Set<Column> get primaryKey => {id};
}
```

Tables: `Stations`, `MenuItems`, `Kots`, `OrderLines` (FK kotId, dishId), `Outbox`.
Never hard-delete a synced row — set `deleted = true` and let it tombstone. Reads filter
`deleted = false`.

DAOs expose **streams** (`Stream<List<Kot>> watchActiveKots()`), never one-shot reads, for anything
the UI displays. Migrations are versioned and tested — bump `schemaVersion`, write a migration step,
add a migration test. Ask before any destructive migration.

---

## 6. Sync engine

Outbox pattern. The engine is a background service with zero UI coupling.

**Outbox op:** `{ id, entity, entityId, opType (upsert|delete), payload, createdAt, attempts }`.
Writes append to `Outbox` in the **same Drift transaction** as the local mutation (atomic).

**Push:** when online, drain the outbox FIFO → batched Firestore writes → on success clear ops and set
`dirty = false`. Idempotent (op id + `entityId`), so re-running after a crash is safe. Exponential
backoff with jitter on failure; cap attempts then surface a sync-error state (don't drop data).

**Pull:** per collection, query `where updatedAt > lastPulledAt` (delta sync), write results into Drift,
advance the per-collection `lastPulledAt` cursor. Use Firestore `serverTimestamp()` for `updatedAt`.

**Conflict resolution:** last-write-wins by `updatedAt` (server time). If remote `updatedAt` >= local,
remote wins; else keep local and re-push. `version` increments on each write for debugging/ordering.
LWW is acceptable here because a KOT is edited by one station at a time; document this assumption and
revisit only if multi-device simultaneous edits become real.

**Triggers:** run push on (a) app foreground, (b) connectivity regained (`connectivity_plus`),
(c) after any local write, (d) a periodic timer while foregrounded. Pull on foreground + connectivity +
periodic. Everything debounced.

> Firestore's own offline persistence is enabled too (free cache + queued writes), but Drift is still
> the source of truth — we don't read Firestore in widgets. Firestore offline is the transport's safety
> net; the outbox is ours.

---

## 7. Routing (go_router)

- Typed routes via **go_router_builder** (`@TypedGoRoute`, `*.g.dart` part files).
- A **`StatefulShellRoute.indexedStack`** hosts the persistent tabs: `/stations`, `/queue`,
  `/tickets`, and **`/profile`** (four tabs in the MVP). Each keeps its own navigation state.
- `/scan` is a full-screen pushed route (camera → review → add to board), matching the prototype's
  `AddKOT` overlay.
- Auth via `redirect` + `refreshListenable` bound to the Firebase Auth state provider. Unauthed →
  `/sign-in`. Keep redirect logic pure and total (handle unknown routes). *(Post-MVP — there is no
  auth/redirect in the MVP since Firebase isn't wired yet.)*
- Navigate with generated methods (`const StationsRoute().go(context)`), not raw string paths.

---

## 8. AI scan layer — vision LLM reads the KOT + suggests cook times

> 🟡 **Partly built.** The scan flow is **implemented today against Google Gemini** (`gemini-2.0-flash`,
> `data/ai/TicketScanner`) — capture → vision read → review → add KOT, with manual fallback. It returns
> matched menu items **and off-menu (ad-hoc) items** (with a suggested station, turned into menu dishes on
> add) plus a **per-item cook-time estimate** (advisory; editable on review, falls back to the dish
> default). What's **still the plan**: routing the call through a **backend proxy** so the key never ships
> (it's client-side now). This section also **replaces** the earlier self-hosted GLM-OCR + retrofit
> design. The request shapes below show Claude; the wired client uses Gemini's equivalent
> (`responseSchema`) — same idea.

A **single vision-capable LLM call** does both jobs: read the photographed KOT into structured lines
(item name + qty) **and** suggest a cook time per item. One multimodal request, one parseable JSON
response — no separate OCR and predict services.

**Model choice (configurable per flavor; pick by cost vs. accuracy):**

| Provider | Model id | Notes |
|----------|----------|-------|
| **Gemini (wired today)** | `gemini-2.0-flash` | What `TicketScanner` uses now: vision + structured JSON via `responseSchema`, no-cost tier. Good default while validating. |
| **Claude (quality option)** | `claude-sonnet-4-6` | Vision + structured JSON; `$3 / $15` per 1M tok, ~1.6K tok/image. Swap in for hardest scans (`claude-opus-4-8`) or cheapest (`claude-haiku-4-5`). Use the latest Claude vision model. |

> 🔑 **The provider API key must NEVER ship in the Flutter app.** Mobile binaries are trivially
> unpacked; an embedded key is a leaked key. **Route the call through a thin backend proxy** (the
> chessdream.app infra) that holds the key server-side. The app calls *your* proxy endpoint, not
> `api.anthropic.com` / Gemini directly. The proxy can also switch providers (Claude ↔ Gemini) and
> rotate keys without an app release. Dev points at the dev proxy, prod at the prod proxy — never
> hardcode URLs in feature code; pass the base URL via `--dart-define` per flavor.

**Request shape (what the proxy forwards to the vision model — Claude Messages API):**

```jsonc
// POST <proxy>/scan-kot   →  proxy adds x-api-key, forwards to /v1/messages
{
  "model": "claude-sonnet-4-6",
  "max_tokens": 1024,
  "messages": [{
    "role": "user",
    "content": [
      { "type": "image", "source": { "type": "base64",
        "media_type": "image/jpeg", "data": "<base64 of the KOT photo>" } },
      { "type": "text", "text": "Read this kitchen order ticket. Return each line item with quantity and a suggested cook time in minutes." }
    ]
  }],
  // Structured outputs → guaranteed-parseable JSON (Sonnet 4.6 / Opus 4.8 / Haiku 4.5):
  "output_config": { "format": { "type": "json_schema", "schema": {
    "type": "object", "additionalProperties": false,
    "required": ["lines"],
    "properties": { "lines": { "type": "array", "items": {
      "type": "object", "additionalProperties": false,
      "required": ["name", "qty"],
      "properties": {
        "name":     { "type": "string" },
        "qty":      { "type": "integer" },
        "cookMins": { "type": "integer" }   // model's suggestion; advisory
      }
    }}}
  }}}
}
```

The first text block of the response is valid JSON matching that schema. (Gemini: same idea via its
structured-output / `responseSchema` parameter.) Image goes in a content block **before** the text;
base64 must be newline-free.

**Client (Flutter) side — `data/remote/api/`:**

- `image_picker` (or `camera` for a live viewfinder) captures the photo → base64.
- A plain `dio`/`http` client `POST`s it to the proxy. **No `retrofit` needed** for one endpoint.
- DTOs in `data/remote/api/dto/` (json_serializable), kept separate from domain entities — map to
  `OrderLine` (and a per-line `cookOverrideMins` from the suggested `cookMins`) at the repository boundary.
- Interceptors: app/Firebase auth token to the proxy, debug-only request/response logging, retry with
  backoff on 5xx/timeout, sane timeouts.

**Degradation (non-negotiable, §0.1):**

- If the scan call is unreachable or the kitchen is offline, the user builds the KOT **manually** on the
  review screen (full manual entry already exists in the prototype). **Never block ticket creation on the
  network.**
- Cook-time suggestions are **advisory**. Missing/failed → fall back to `Dish.cookMins` (and any line
  override). The cook can always correct the time on the review screen, and that correction — not the
  model's guess — is what feeds the scheduler (§10).
- Treat model output as untrusted: validate `qty`/`cookMins` ranges and map unknown item names to the
  closest menu `Dish` (or flag for manual pick) before creating the KOT.

---

## 9. State management (bloc) conventions

kBuzz uses **`flutter_bloc`** (chosen over Riverpod). Prefer `Cubit` for simple state; reach for a
full `Bloc` (events) only when you need an event log / complex transitions.

- One cubit/bloc per concern. State classes are **immutable and `Equatable`** (`props` lists every
  field) so rebuilds are minimal and tests can assert on equality. Example: `DemoDataCubit` /
  `DemoDataState` in `features/profile/cubit/`.
- **DI lives in `app/di.dart`** (`AppProviders`): shared services go in `MultiRepositoryProvider`
  (`Clock`, `Logger` today; repositories later); feature cubits/blocs go in `MultiBlocProvider`.
  Widgets read deps with `context.read<T>()` / `context.watch<T>()` and **never construct them inline**.
- In widgets, select state with `BlocBuilder`/`BlocSelector` (rebuild only on the slice you use) and
  side-effects with `BlocListener` (e.g. show an `AppToast` on error — §12). No business logic in widgets.
- **Later (with the data layer):** lists come from streams — wrap a Drift DAO `Stream` in a cubit via
  `emit.forEach` / `stream.listen`, exposing an explicit `loading | data | error` state union (no `!`
  on nullable data). The live **service clock** (elapsed, speed, running — see prototype) is its own
  cubit driven by a single ticker; `ScheduledDish` status (waiting/cooking/**held**/ready) is **derived**
  from `elapsed` vs `fireAt`/`finishAt` via `dishLiveStatus(...)`, not stored. In the waiter view that
  call is passed the ticket's plate time (`max(finishAt)`) so a finished-early line reports `held` until
  its table can plate (**strict coursing**, TICKETS.md); the kitchen views omit it (a finished cook is
  `ready`). The schedule cubit depends on active-KOTs + menu + stations and calls the pure
  `schedule(...)` — recompute on data change, **not** every clock tick.

---

## 10. The scheduler (port the prototype exactly)

Location: `domain/scheduler/scheduler.dart`. **Pure function. Deterministic. No I/O. No `now()` inside.**

```dart
Schedule schedule({
  required List<Kot> kots,
  required Map<String, Dish> menu,
  required Map<String, Station> stations,   // id -> {capacity, ...}
  required DateTime now,                     // caller passes the clock; mins are relative to this
  SlaConfig sla = const SlaConfig.standard(),     // mins per ticket type (+ RUSH cap)
  SchedulerConfig config = const SchedulerConfig(), // horizonMins, batchWindowMins, justInTime
});
```

Algorithm (identical to `MultiKOT.jsx > schedule`):

1. **Target per ticket:** `target = orderedAtMins + sla[type]`. (dine-in/takeaway/delivery are config.)
2. **Ideal fire per dish:** back-schedule — `ideal = target - cookMins`. Slowest dish fires first.
   A line's `cookOverrideMins` (from the review screen) takes precedence over `Dish.cookMins`.
3. **Batch:** merge dishes with the same `(stationId, dishId)` whose targets fall within `batchWindow`
   (default 2 min) **only if** `batchable`. Merged dish keeps all members; `target` = tightest member;
   recompute `ideal`.
4. **Sort** pending dishes by `ideal`, then `target`, then longer `cookMins` first.
5. **Place under capacity** using per-station minute buckets (capacity = max concurrent):
   - fits at `ideal` → on time;
   - station busy + `holdable` → fire **earlier** into a free slot → finishes early → `holdMins > 0`;
   - station busy + not holdable → fire **later** → plates late → `lateMins > 0`.
   - never fire before now (minute `0` in the relative frame).
6. Per dish: `finishAt = fireAt + cookMins`; `holdMins = max(0, target - finishAt)`;
   `lateMins = max(0, finishAt - target)`.
7. **Lane-pack** each station's dishes for the rail view (first lane whose last finish ≤ this fire;
   else new lane). Guaranteed ≤ capacity lanes.
8. Return `{ dishes, byStation, horizonMins = max(finishAt), bottleneck }`.

### 10.1 Waiter-driven inputs (TICKETS.md scheduler contract)

The waiter page changes the scheduler's **inputs**, not the algorithm. Per ticket/line:
- A line with `state ∈ {served, void}` carries no kitchen work — **skipped**.
- A line with `reAt != null` (recook/fire-now): `target = reAt + cook` (fires *now*), `priority = true`,
  and it **never batches**. `PriorityKind` (recook > fireNow > rush) is surfaced on `ScheduledDish` for the
  kitchen badge.
- A `rush` ticket: `SLA = min(SLA[type], RUSH_SLA)` and **all** its lines `priority = true`.
- **Priority dishes sort before normal ones** (step 4) and never merge into a batch (step 3).

### 10.2 Just-in-time firing (`SchedulerConfig.justInTime`)

A deliberate refinement over the prototype, **on via `BoardData`** (off by default so the golden test
still pins the pure placement). After placement, each ticket's **non-bottleneck** dishes are *delayed* so
they **finish at the ticket's realized plate time** (`max(finishAt)`) instead of cooking early and waiting
under the lamp — so a table plates together for real. Re-fires (recook/fire-now) and batched cooks are
exempt; the move is capacity-checked; nothing fires before now; no dish is pushed past its plate (so the
plate never moves). The **bottleneck** is captured *pre-JIT* so delayed fast dishes don't masquerade as the
constraint. (Display complement — **strict coursing** — lives in the waiter view: a line reports `held`
until its ticket can plate; see TICKETS.md / §9.)

Invariants to assert in tests:
- All dishes on one ticket finish ≤ each other within hold/late tolerance (they "plate together"); with
  `justInTime` they actively converge on the realized plate time.
- No station exceeds `capacity` concurrent dishes at any minute — **including** under just-in-time firing.
- A dish never fires before now (`fireAt >= 0` in the relative frame).
- Identical batchable dishes inside the window collapse to one cook; a priority/re-fired line splits them.
- Just-in-time firing never delays a ticket's plate vs. plain placement, and never moves the bottleneck.
- Deterministic: same inputs → identical output (no set/iteration-order nondeterminism).

The scheduler also surfaces the **bottleneck** (station with the largest induced `lateMins`) — keep that,
it's the feature's punchline ("steamer can't keep up → add a second").

---

## 10.5 Fire alerts — bold toast + audio announce on "fire next"

When the live run clock crosses a dish's `fireAt` ("fire next now"), the chef must notice **without
looking closely at the screen** — hands are full, the screen may be across the line. So two synchronized
outputs fire together: a **large, bold top toast held 5–10s** and a **spoken announcement over the
speaker**.

**Trigger lives in the state layer, NOT the scheduler.** The scheduler stays pure (§0.3, §10) — it only
emits `fireAt` per `ScheduledDish`. Fire detection is **derived in the service-clock layer**
(`features/service/`): on each tick the cubit compares `elapsedMins` against every scheduled dish's
`fireAt` and emits the dishes that *just crossed* it. It is **edge-triggered and once-only** — keep a
`Set<scheduledDishId>` of already-announced ids so a dish fires exactly once, not on every tick; clear
the set when the run resets/restarts. No `DateTime.now()` in the detector — it reads the injected
clock's `elapsed`, same rule as §9.

```dart
// emitted by the fire-alert detector in features/service/
class FireAlert {
  final String stationId, stationName, dishName;  // e.g. "Grill", "Cheeseburger"
  final String? emoji;
  final int qty;
  String get spokenText => 'Fire $stationName — $qty $dishName';
}
```

**Presentation lives at the app shell.** A `BlocListener<FireAlertCubit, …>` mounted on the nav shell
(`scaffold_with_nav_bar.dart`) — so alerts surface on **any** tab (Stations/Queue/Tickets/Scan) — reacts
to each new `FireAlert` by calling **both**:

1. **`AppToast.fire(context, alert)`** — a dedicated **bold/large** variant of the top toast (§12):
   big monospace qty + dish + station, brand-orange (`#ff6600`) accent, high contrast, held **~7s**
   (configurable 5–10s), tappable to dismiss. Top-anchored like every toast — **never** `SnackBar`,
   never a hand-rolled `OverlayEntry`; it is a new method on `AppToast`, not a new widget (§12).
2. **`Announcer.announce(alert.spokenText)`** — speaks the fire over the speaker
   (e.g. *"Fire grill — two cheeseburgers"*), optionally preceded by a short attention **chime**.

**Announcer = injected, offline, testable.** Audio is a side-effecting platform concern, so wrap it
behind an abstraction provided in DI (`MultiRepositoryProvider`, alongside `Clock`/`Logger`):

```dart
abstract class Announcer { Future<void> announce(String text); Future<void> chime(); }
class SystemAnnouncer implements Announcer { /* on-device TTS (flutter_tts) + bundled chime asset */ }
class NoopAnnouncer  implements Announcer { /* tests / CI / muted — does nothing */ }
```

- **On-device only — offline (§0.1).** Use `flutter_tts` (platform TTS engine, works with no network)
  and a **bundled chime asset** (`audioplayers`/`just_audio`). **Do not** call a cloud TTS API — the
  kitchen wifi *will* drop mid-rush, and the announce must still fire.
- **Combine / de-dupe simultaneous fires.** ✅ Implemented: dishes that cross `fireAt` on the same tick
  are emitted as one batch; the shell shows a single `AppToast.fire(items: …)` and speaks one combined
  line via `batchSpokenText(...)` ("Fire Grill — 2 Cheeseburger, and Steam — 1 …, and N more") rather
  than overlapping toasts or talking over the TTS. Never silently drop an alert.
- **Settings (Profile tab):** ✅ `SettingsCubit` exposes the **fire-toast hold time** (presets
  `kFireToastPresets`, default 3 min), persisted via `shared_preferences` and passed to `AppToast.fire`.
  _Still TODO:_ an announce on/off toggle + volume (on by default; mute kills audio, keeps the toast).

**Why this shape:** the scheduler stays pure; detection is unit-testable (feed `elapsed` values, assert the
emitted alerts and once-only behaviour); audio is mockable (`NoopAnnouncer` in widget/unit tests — no real
TTS in CI); and the alert is visible from every tab because it lives at the shell, not inside one board.

---

## 11. Firebase

> ⛔ **Post-MVP.** Firebase is **not** in the current build — `main.dart` does no Firebase init and the
> app runs fully local. This section is the target for the sync milestone (§15.6); don't add Firebase
> until then. The §0.5 decision (no Firebase in the MVP) overrides this section for "what exists today."

- Init in `main.dart`; enable Firestore offline persistence (default on mobile — keep it on, set a
  reasonable cache size). Then `runApp`.
- Firestore layout (mirror Drift): tenant-scoped, e.g.
  `restaurants/{rid}/menu/{dishId}`, `/stations/{stationId}`, `/kots/{kotId}`,
  `/kots/{kotId}/lines/{lineId}`. Every doc carries `updatedAt (serverTimestamp)`, `version`, `deleted`.
- Auth: `firebase_auth`; the agent must **not** implement password/credential entry flows beyond the
  standard Firebase Auth UI calls — no custom credential capture.
- Security rules and composite indexes are part of the deliverable (commit `firestore.rules` and
  `firestore.indexes.json`). Default-deny; scope reads/writes to the user's restaurant. Don't generate
  rules that allow open reads/writes.

---

## 12. Coding conventions

- Dart style + `flutter_lints` (or `very_good_analysis`). `flutter analyze` must be clean — zero warnings.
- Immutable models (freezed). No mutable public fields on entities.
- **No exceptions across layer boundaries** — repositories return `Result<T>` / `AppFailure`. Map dio /
  Firestore / Drift errors into typed failures at the data layer.
- No `print` — use `logger`. No business logic in widgets. No magic numbers in the scheduler (use the
  config object).
- **Toasts always pop up at the TOP.** Show every transient message via `AppToast`
  (`lib/core/widgets/app_toast.dart`) — `AppToast.show/success/error`, or `AppToast.failure(context, f)`
  to surface an `AppFailure`. It renders into the root overlay (floats above the tab shell, full-screen
  routes and dialogs). **Never** use `ScaffoldMessenger`/`SnackBar` (those anchor to the bottom) and never
  hand-roll an `OverlayEntry` for a toast — extend `AppToast` instead.
- **Fire alerts use `AppToast.fire(...)`** — the one deliberately **big/bold/long** toast variant
  (5–10s, large monospace text, brand-orange, high-contrast, readable from across the line). It is a new
  method *on `AppToast`* (still top-anchored, still the root overlay) — do not build a separate widget,
  and do not use it for ordinary messages. Pairs with the spoken `Announcer` (§10.5).
- Files: `snake_case.dart`; types `UpperCamel`; providers `lowerCamel` ending in `Provider`/the gen name.
- Keep widgets small; extract anything over ~150 lines or with branching logic.
- **Theme/brand:** dark KDS board. Brand primary `#ff6600` drives primary actions, the scan shutter,
  and CTA/selected accents (it replaces the prototype's `#f97316`). Brand secondary `#274074` (navy)
  is for branded chrome — app bar, sign-in screen, elevated/light surfaces — **not** for text or fills
  on the near-black board (contrast too low there). Keep the **functional station colors** (grill red,
  steam blue, wok amber, …) exactly as the prototype; they encode station, not brand. Monospace for all
  times/clocks/quantities. Match the prototype's UX copy.

---

## 13. Build, run, test

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # MVP: go_router_builder only (drift + retrofit + freezed land later)
# during development:
dart run build_runner watch --delete-conflicting-outputs

flutter analyze
flutter test
flutter run                                                 # MVP: no flavors/Firebase yet — plain run
# later: flutter run --flavor dev --dart-define=ENV=dev
```

- **Flavors:** `dev` / `prod`. API base URLs and Firebase configs differ per flavor; pass via
  `--dart-define` (or `--dart-define-from-file`). Never commit secrets. *(Post-MVP — not set up yet.)*
- `flutterfire configure` generates `firebase_options.dart` per flavor. *(Post-MVP.)*
- A `Makefile`/`melos` target wrapping the above is welcome.

### Testing priorities (in order)
1. **Scheduler** — exhaustive unit tests (the invariants in §10, the prototype's sample rush as a
   golden case, edge cases: empty, single dish, all-same-station, impossible SLA, capacity 1).
2. **Sync engine** — outbox drain, idempotent re-push, LWW conflict, tombstone propagation, offline→online.
3. **Repositories** — against an in-memory Drift db (`NativeDatabase.memory()`), with mocked remote.
4. Widget tests for the three boards + scan/review flow. Golden tests optional.

Use `mocktail`. Core logic (scheduler + sync) should sit near 100% line coverage.

---

## 14. Agent operating rules

- **Plan before large changes.** State the files you'll touch and why; keep the diff scoped to one concern.
- Before marking work done: `build_runner build` succeeds, `flutter analyze` is clean, relevant tests pass,
  and you've run the app path you changed (or a widget test for it).
- Don't edit generated files. Don't commit `*.g.dart`/`*.freezed.dart` churn unrelated to your change.
- Don't add packages without justification. Prefer what's listed in §1.
- **Schema or sync-protocol changes require an explicit migration + test, and a heads-up in the PR.**
- Respect the layer boundaries (§2/§3). A widget importing `cloud_firestore` or `drift` is a bug.
- Never weaken Firestore rules or auth to "make it work." Never implement raw credential/password capture.
- If reality diverges from this file (a package API changed, an assumption broke), **update this file in
  the same PR** and call it out — keep AGENTS.md true.
- Conventional commits (`feat:`, `fix:`, `refactor:`, `test:`, `chore:`).

### Definition of done (PR checklist)
- [ ] Works fully offline for the touched feature (tested with network off).
- [ ] Reads via Drift streams; writes are local-first + outbox. *(MVP: n/a until the data layer lands — read from cubits/demo data.)*
- [ ] No direct Firestore/dio calls from UI or state layers. *(MVP: trivially true — neither exists yet.)*
- [ ] `flutter analyze` clean; tests added/updated and green; build_runner runs.
- [ ] Scheduler invariants hold (if touched); no new magic numbers. *(Scheduler is ported — keep the golden + invariant tests green.)*
- [ ] Transient messages use `AppToast` (top), never `SnackBar` (§12).
- [ ] AGENTS.md / rules updated if conventions or assumptions changed.

---

## 15. Build order (suggested first milestones)

1. Skeleton ✅ (current MVP): app, theme, go_router shell with the four tabs (incl. Profile), bloc DI,
   top toasts, in-memory demo data — **no Firebase** (deferred to milestone 6).
2. ✅ Drift schema (stations, menu, kots, lines) + `KitchenRepository` with watch streams + the
   deterministic sample seed. `DemoDataCubit` writes through to Drift and hydrates on launch (data
   survives restart). Schema is at v2 (the waiter ticket-state columns; migration tested). _Remaining:_
   the `Outbox` table + sync metadata land with milestone 6.
3. ✅ Domain entities + the **scheduler** (pure Dart, ported `MultiKOT.jsx` 1:1) with golden +
   invariant tests (`test/domain/scheduler_test.dart`).
4. ✅ Boards wired to the schedule: `features/board/BoardData` runs `schedule()` and the
   Stations/Queue/Tickets pages render it (lane packing, fire order, plate-together, bottleneck); the
   live `ServiceClockCubit` + speed control animate them; **fire alerts** fire (`AppToast.fire` +
   on-device announce via `Announcer`, §10.5). _Remaining refinement:_ a reactive Drift-stream
   `ScheduleCubit` (boards currently read the Drift-backed `DemoDataCubit` snapshot).
5. ✅ Scan flow: `image_picker` camera → **Gemini vision** (`TicketScanner`, §8) reads the KOT into a
   draft (matched + **off-menu ad-hoc** items, with **AI cook-time** suggestions) → review screen
   (editable) → create KOT (ad-hoc dishes join the menu). _Remaining:_ key-holding **backend proxy** (§8).
6. ✅ Waiter **Tickets** page (TICKETS.md): line/ticket state machine on Drift (serve / recook+reason /
   fire-now / void / rush / serve-all / done+reopen), `PriorityKind` kitchen badges, **strict coursing**
   (`held` status), and **just-in-time firing** in the scheduler. _Remaining:_ emit sync events per
   action (lands with milestone 7); announce on/off setting.
7. Sync engine: outbox push + delta pull + LWW; Firebase + Firestore rules + indexes (first Firebase milestone).
8. Auth gate + flavors + polish.

---

## 16. Architecture map — god nodes (from graphify)

> Generated by `/gods` over `graphify-out/graph.json` (1143 nodes, 1699 edges, 51 communities; 2026-06-22).
> The **god nodes** are the most-connected nodes — the core abstractions to orient by. Degree here is
> dominated by **file** nodes (each links all its symbols + imports), so read it as "biggest, most-wired
> files." Regenerate with `/graphify --update` then `/gods` after large structural changes; treat this
> table as a snapshot, not a contract.

| # | Node | Degree | What it is |
|---|------|--------|-----------|
| 1 | `scan_page.dart` | 69 | Scan capture → review → add-KOT flow (largest screen). |
| 2 | `stations_page.dart` | 69 | Station rail — lane-packed live Gantt. |
| 3 | `tickets_page.dart` | 63 | **Waiter expo** — line state machine, action sheet, strict coursing (TICKETS.md). |
| 4 | `demo_data_cubit.dart` | 62 | Drift-backed demo state + all waiter commands (serve/recook/rush/…). |
| 5 | `scheduler.dart` | 61 | Pure `schedule()` — placement, batching, priority, just-in-time firing (§10). |
| 6 | `demo_data_generator.dart` | 59 | AI demo-data generator (Gemini **or** Anthropic). |
| 7 | `app_toast.dart` | 58 | **Top toast** — the single transient-message API + `AppToast.fire` (§12). |
| 8 | `models.dart` | 57 | Scheduler value types — `ScheduledDish`, `SlaConfig`, `SchedulerConfig`, `PriorityKind`. |
| 9 | `fire_alert_cubit.dart` | 42 | Fire-next detector + `batchSpokenText` (§10.5). |

By symbol (not file), the most-connected abstractions are `ServiceClockCubit` (the live-clock spine every
board subscribes to), `DemoDataCubit`, `AppProviders`/`di.dart`, `SettingsCubit`, and the pure
`Scheduler`. A "Plate-Together Concepts" community (just-in-time firing + strict coursing + cooking
status) and a "Profile & Settings" community now exist in the graph — the two recent feature areas.
Still absent from the top ranks: any Firebase/Riverpod node — consistent with the §0.5 MVP stack.
