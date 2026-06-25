# Flutter Engineer — kBuzz (Kitchen Operations Platform)

**Type:** Full-time · **Level:** Mid–Senior · **Stack:** Flutter / Dart
**Location:** _[remote / hybrid / on-site — fill in]_ · **Comp:** _[range — fill in]_

---

## About kBuzz

kBuzz is a **kitchen-expo / KOT (Kitchen Order Ticket) management app** for restaurants. It turns a stream of incoming tickets into a live, sequenced plan the line can actually cook to: when to **fire** each dish so plates land on time, where the **bottleneck** is, and what's **ready to serve** — with a fast "service clock" so the whole board animates through a dinner rush.

It's a real Flutter app (not a prototype): a pure scheduling engine, a live run clock, on-device "fire next" voice/alert announcements, AI ticket-photo scanning, AI demo-data generation, and a Drift (SQLite) data layer. It runs **fully offline today** (no backend yet) on **iOS, Android, macOS, and web**, and is backed by ~130 tests.

We're looking for an engineer to take it from a strong local-first MVP to a multi-device, synced, production product.

---

## What you'll build (the roadmap)

This is genuine greenfield-on-a-solid-base work. The biggest pieces ahead:

- **Sync engine + backend (the headline project).** Add **Cloud Firestore + Firebase Auth** as a mirror of the local Drift source of truth: an offline-first outbox/pull-delta sync engine with conflict resolution, so multiple stations and devices in one kitchen stay consistent — **without ever gating local writes on the network**. The architecture is already designed around this seam (`data/sync/`, soft-delete + version columns, connectivity-agnostic state layer).
- **Harden the AI features for production.** Move Claude ticket-scanning and demo-data generation behind a **backend proxy** so the API key never ships to the client; add retries/streaming, better off-menu (ad-hoc) dish handling, and camera capture.
- **Auth, roles & multi-station.** Sign-in, kitchen/station roles, and a real multi-device expo experience.
- **Model & data-layer maturity.** Migrate value models from `equatable` to **freezed + json_serializable**, evolve the Drift schema with migrations, and grow the repository layer.
- **Round out the live run.** Finish the announcer (on/off toggle, voice settings), richer fire/recook/rush flows, and analytics on lateness & bottlenecks.
- **Polish & platforms.** Accessibility, theming, tablet/desktop layouts, and release/CI pipelines.

You'll own features end-to-end: domain logic → cubit → repository → Drift → UI → tests.

---

## Tech stack

| Area | What we use |
|------|-------------|
| Language / SDK | Dart `^3.12.x`, Flutter (iOS · Android · macOS · web) |
| State management | **flutter_bloc / bloc** (Cubits), **equatable** (→ freezed later) |
| Routing | **go_router** + `go_router_builder` (typed routes, codegen) |
| Local persistence | **Drift** (SQLite) + `drift_dev`, `sqlite3_flutter_libs`, `path_provider` |
| Networking / AI | `http` → **Anthropic Claude** (vision scan + generation, Messages API); proxy TODO |
| Device | `flutter_tts` (on-device voice), `image_picker`, `file_picker`, `shared_preferences`, `url_launcher` |
| Backend (next) | **Cloud Firestore + Firebase Auth**, `connectivity_plus` |
| Tooling | `build_runner`, `flutter_lints`, `flutter_test` |

---

## Responsibilities

- Design and ship features across the full layered stack (domain → data → feature → UI).
- Build the **offline-first sync engine** and integrate Firebase, keeping the state layer connectivity-agnostic.
- Stand up a **backend proxy** for the AI endpoints and improve scan accuracy/robustness.
- Write **pure, unit-tested domain logic** and widget/integration tests for everything you build.
- Evolve the Drift schema with safe migrations; manage codegen (`build_runner`).
- Keep the codebase clean: follow the existing conventions in `AGENTS.md`, prefer reuse and small, well-named units, and keep the analyzer green (zero warnings).
- Collaborate on product/UX for kitchen-floor usability (glanceable, loud, fast).

---

## Must-have

- **2+ years of production Flutter/Dart**, with apps shipped to stores or comparable scale.
- Strong **BLoC/Cubit** (or equivalent) state-management experience; comfortable with streams and immutable state.
- Solid **local persistence** experience (Drift / SQLite / Moor / Room / Core Data — Drift a plus).
- Real **offline-first / sync** instincts: outbox patterns, eventual consistency, conflict resolution, optimistic UI.
- Disciplined **testing** — you write tests by default (unit + widget), and you isolate pure logic from I/O.
- Fluency with **async Dart**, code generation (`build_runner`), and `go_router`.
- Care for clean architecture, code review, and reading an existing codebase before changing it.

## Nice-to-have

- **Firebase** (Firestore offline persistence, Auth, security rules) and building sync layers.
- **freezed / json_serializable**, and migrating models to them.
- Experience integrating **LLM/vision APIs** (Gemini/Claude/OpenAI) and backend proxies for them.
- On-device **TTS/audio**, camera, or accessibility work.
- Multi-platform Flutter (desktop/web) and CI/CD for Flutter releases.
- Domain familiarity: restaurant/kitchen/POS/logistics or other real-time scheduling.

---

## How we work (engineering principles)

These aren't slogans — they're enforced in the codebase and in `AGENTS.md`:

- **Offline-first, local source of truth.** The UI reads/writes Drift; the network is a background mirror, never a gate on a write.
- **Layered & feature-first.** `domain/` is pure (no Flutter, no I/O); `data/` owns persistence + sync; `features/` own UI + cubits; `core/` holds cross-cutting utilities. Dependencies point inward.
- **Pure logic, heavily tested.** The scheduler and detectors are pure functions with golden tests; inject the clock and side-effecting services so everything is testable and CI stays silent.
- **Small, reviewable changes** that match the surrounding style; analyzer must be clean.
- **No premature dependencies** — we add packages per milestone, with justification.

---

## How to apply

Send a CV/portfolio and a short note on a **sync or offline-first** problem you've shipped. Bonus: clone the repo, run the tests (`flutter test`), and tell us one thing you'd improve in the scheduler or the sync design.

> _Read `AGENTS.md` in the repo for the full architecture, conventions, and milestone roadmap referenced above._
