# data/ — the only API the features see

Lands in later milestones (AGENTS.md §15 milestones 2 / 6).

- `db/` — Drift database, tables (`SyncCols` mixin), DAOs exposing watch
  streams. **Local source of truth** (§5).
- `remote/` — Firestore client + retrofit OCR/predict client and DTOs (§8/§11).
- `sync/` — outbox push + delta pull + LWW conflict resolution (§6).
- `repositories/` — `KotRepository`, `MenuRepository`, `StationRepository`;
  return `Result<T>` (see `core/result.dart`), never throw across boundaries.

UI/state never touch Firestore or dio directly — they go through repositories.
