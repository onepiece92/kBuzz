# TICKETS.md — kBuzz Ticket Page (Waiter)

> Spec for **one screen**: the waiter-facing Tickets page. Companion to `AGENTS.md` (stack,
> offline-first architecture, scheduler). Behaviour is mirrored from the React prototype
> (`MultiKOT.jsx` → `Tickets`, `LineRow`, `ItemSheet`, `DoneConfirm`); that prototype is the source
> of truth for layout/copy, this file for the rules.

## Role

kBuzz has two surfaces over the same tickets:
- **Kitchen** (Stations rail, Fire-next queue) — cooks; driven by the scheduler.
- **Ticket page** (this doc) — the **waiter**. Where orders are served, sent back, expedited, voided,
  rushed, and closed.

The waiter never edits the cook plan directly. Waiter actions either **create kitchen work** (recook,
fire-missing, rush, unserve, restore) or **clear it** (serve, void). The scheduler reacts.

---

## Data model

A ticket owns lines. A line carries a **state machine the waiter drives**; cooking progress is derived
from the clock and never stored. (Fields match `AGENTS.md` §4/§5; only ticket-page-relevant ones shown.)

```
Ticket {
  id, table, type: dinein|takeaway|delivery,
  orderedAt,                 // prototype: orderMin (mins vs now)
  status: 'active' | 'done',
  rush: bool,
  lines: Line[]
}

Line {
  id,                        // stable — every waiter action targets a line id
  name, qty, cook,           // cook = estimated minutes (editable at scan time)
  state: 'open' | 'served' | 'void',
  recook: int,               // how many times sent back (quality metric)
  reAt:   int | null,        // set => re-fired NOW (recook or expedite); the minute it was re-fired
  reason: string | null,     // recook reason; null on a plain expedite/fire-missing
  note:   string | null      // free-text special instruction (e.g. "no salt"); shown on
                             // Tickets + Stations and read aloud with the fire alert
}
```

Three orthogonal axes — keep them distinct:
1. **Line.state** (persistent, waiter-set): `open` / `served` / `void`.
2. **Cooking status** (derived from the clock, `open` lines only): `waiting → cooking → ready`.
3. **Re-fire** (persistent): `reAt != null` → this line fires *now* with priority; `reason` distinguishes
   a **recook** (sent back) from an **expedite / fire-missing**.

`RUSH_SLA = 7` · `RECOOK_REASONS = [Cold, Undercooked, Wrong dish, Dropped, Allergy]` ·
`READY_LIMIT = 4` (mins ready-but-unserved before the "under-lamp" warning).

---

## Item lifecycle

```
        ┌──────────── recook(reason) / fire-now ──────────┐   (sets reAt, re-prioritises)
        ▼                                                  │
  ┌──────────┐  serve / serveAll   ┌──────────┐            │
  │   OPEN   │ ──────────────────▶ │  SERVED  │ ───────────┘
  │ (cooking │ ◀────────────────── │          │
  │  status) │     unserve         └──────────┘
  └────┬─────┘
       │ void
       ▼
  ┌──────────┐  restore
  │   VOID   │ ──────────▶ OPEN
  └──────────┘
```

- `open` lines flow `waiting → cooking → held → ready` on the kitchen clock (status only, no state
  change). `held` = cooked early, waiting for the table (see strict coursing under *Derived values*).
- **Recook / fire-now** keep the line `open` but set `reAt = now` (+ `reason` for recook), which makes
  the scheduler fire it immediately with priority. Recook also bumps `recook`.

> **Plate-together (deliberate divergence from the prototype).** `MultiKOT.jsx` fires every dish from
> its own SLA target and flips it to `ready` on its own finish (fast items cook early and sit under the
> lamp). kBuzz pulls both ends toward plating a table together:
> - **Just-in-time firing** (`SchedulerConfig.justInTime`, on via `BoardData`): after placement, a
>   ticket's non-bottleneck dishes are *delayed* to finish at the ticket's realized plate time
>   (`max(finishAt)`), so they cook just in time instead of early. Re-fires (recook / fire-now) and
>   batched cooks are exempt; the bottleneck dish is untouched; firing never goes before now, never
>   exceeds a station's capacity, and never pushes a dish past its plate (so the plate never moves). The
>   pure prototype placement is preserved with `justInTime: false` (the golden test still pins it).
> - **Strict coursing** (waiter view): a line's `ready` / `under-lamp` is gated on the ticket's plate
>   time, so residual early finishes show as `held` rather than `ready`. The kitchen boards still show a
>   finished cook as `ready`.

## Ticket lifecycle

```
  ACTIVE ──── markDone (guard if open items) ────▶ DONE
     ▲                                              │
     └──────── reopen / any recook on a line ───────┘
```

A ticket is **resolvable** (Done without warning) once every line is `served` or `void`.

---

## Actions

| Action | Scope | Pre → Post | Effect on kitchen | Guard |
|---|---|---|---|---|
| **Serve** | line | open → served | removed from schedule (work done) | — |
| **Serve all** | ticket | all non-void → served | those lines leave the board | — |
| **Unserve** | line | served → open | re-enters schedule | — |
| **Recook** | line | non-void → open + `reAt=now`, `reason`, `recook++` | **re-fires now**, shows `RECOOK · reason` (red), jumps queue; reopens ticket if Done | pick a reason |
| **Fire now / expedite** (missing) | line | open → `reAt=now`, no reason | **re-fires now**, shows `FIRE NOW` (orange), jumps queue | — |
| **Void / 86** | line | open → void | excluded from schedule | — |
| **Restore** | line | void → open | re-enters schedule | — |
| **Set note** | line | set / clear `note` | shows on Stations (bar 📝 + detail) and is **read aloud** with the fire alert | — |
| **Rush** | ticket | toggle `rush` | SLA → `min(SLA, RUSH_SLA)` + all lines priority → whole ticket fires sooner, shows `RUSH` | — |
| **Mark Done** | ticket | active → done | ticket leaves active board | if any `open` line: confirm "N not served, close anyway?" |
| **Reopen** | ticket | done → active | back on the board | — |

Rules:
- **Serving removes kitchen work; recook/fire-now/restore/unserve add it; void removes it.**
- A **recook auto-reopens** a Done ticket (there's new work).
- Actions are available offline and before/after "service start" — each is just a state transition.

---

## Two-way loop with the kitchen

A waiter action mutates the line/ticket → the schedule recomputes → the kitchen views update.

What the **kitchen** sees after each action:

- **Recook** → red `RECOOK · {reason}` badge on Fire-next + Stations, item fires now, sorts first.
- **Fire now / expedite** → orange `FIRE NOW` badge, fires now, sorts first.
- **Rush** → orange `RUSH` badge on every line of the ticket; the ticket's items fire earlier.
- **Serve / Void** → the item disappears from Stations + Fire-next (no pending work).

### Scheduler contract (how this page feeds `schedule()`)

Per `AGENTS.md` §10 — the ticket page changes inputs, not the algorithm:
- A line with `state ∈ {served, void}` is **skipped**.
- A line with `reAt != null` (recook/expedite): `target = reAt + cook` (fires now), `priority = true`.
- A ticket with `rush`: SLA = `min(SLA[type], RUSH_SLA)`, all its lines `priority = true`.
- **Priority lines sort before normal** lines and **never batch**.

Capacity, batching, hold-vs-late, and lane-packing are unchanged.

---

## UI

### Ticket card
- **Header:** code (`T5` / `TA3` / `D21`), type label, `RUSH` badge if rushed, `DONE`/`all ready`
  status, order age (`3m ago`). Border colour: done = grey · rush = orange · all-ready = green ·
  late = red · else neutral. Done cards dim to ~60%.
- **Line rows** (tap → item sheet): emoji, name `×qty`, station chip, and per state:
  - `open` → `fire {…} → ready {…}` (the cook-ready minute; the table's plate-together time is on the
    card subtitle), estimated **cook** on the right, live status (cooking flame / **holding** / ready).
    Under **strict coursing** a line that finishes cooking before the rest of its ticket shows the amber
    `holding for table` state until the whole ticket can plate — so the lines flip to ready *together*.
    `RECOOK·reason` or `FIRE NOW` badge if re-fired. `+Nm late` and `● under lamp` when relevant.
  - `served` → dimmed, "served (· recooked N×)", `served` tag.
  - `void` → struck-through, greyed, "void / 86'd", `void` tag.
- **Footer:** `Rush` toggle · `Serve all` (if any open) · `Done` (green when resolvable, else neutral;
  fires the guard). Done state shows `Reopen` instead.

Sort: **active tickets by plate target ascending; Done tickets last.**

### Item action sheet (bottom sheet, contextual)
- `void` line → **Restore** only.
- `served` line → **Mark unserved**, **Recook (send back)…**.
- `open` line → **Mark served**, **Recook (send back)…**, **Fire now — missing / expedite**,
  **Add / Edit note**, **Void / 86**.
- **Recook** opens a reason sub-step (`RECOOK_REASONS`) → applies the recook with that reason.
- **Add / Edit note** opens a small dialog (free text, ≤80 chars; "Clear" removes it) → writes
  `note` via `setLineNote`. The note renders in amber under the line, on the Stations bar/detail, and
  is spoken with the fire alert.

### Done-confirm dialog
Shown only when closing a ticket with unserved items: "N items not served yet. Close it anyway?" →
**Keep open** / **Close anyway**.

---

## Derived values (compute, don't store)

- `cookingStatus(line)` = waiting | cooking | **held** | ready, from the clock vs the line's scheduled
  dish. **Strict coursing:** `ready` is gated on the ticket's `plateMins` (= `max(finishAt)` over the
  ticket's open lines), not the line's own `finishAt`; a cook that finishes early is `held` (under the
  lamp, waiting for its table) until `elapsed ≥ plateMins`, so a whole ticket flips to ready at once.
  *(The kitchen views deliberately keep the un-gated status — a finished cook is `ready` there.)*
- `allResolved(ticket)` = every line served or void → Done is warning-free.
- `allReady(ticket)` = started ∧ has an open line ∧ `elapsed ≥ plateMins` (equivalently: every open line
  `ready` under the coursing gate) — so the header never contradicts a line still `holding`.
- `late(ticket)` = max line lateness among open lines.
- `underLamp(line)` = ticket platable (`elapsed ≥ plateMins`) ∧ unserved for > `READY_LIMIT` mins —
  i.e. the lamp clock starts when the *table* is up, so lines warn together, not piecemeal.

---

## Offline-first & events

This page is pure local-first state transitions (see `AGENTS.md` §2/§6). Every action: write the
line/ticket in Drift immediately (optimistic), append an outbox op, bump `updatedAt`. The UI updates
from the Drift stream; sync pushes later. No action blocks on the network.

Emit one event per action (these are both the **sync ops** and the **audit timeline** the kitchen and
waiter share):

```
ItemServed{ticketId, lineId}        ItemUnserved{ticketId, lineId}
ItemVoided{ticketId, lineId}        ItemRestored{ticketId, lineId}
ItemRecooked{ticketId, lineId, reason}   ItemFiredNow{ticketId, lineId}
TicketRushed{ticketId, on}          TicketDone{ticketId}    TicketReopened{ticketId}
```

All carry a server timestamp. Conflict resolution is last-write-wins on `updatedAt` (§6). Events are
idempotent by `(lineId, action, timestamp)`.

---

## Flutter notes (aligns with AGENTS.md §3/§9)

- Lives in `features/tickets/`. Reads a `StreamProvider` of active tickets (Drift stream) → `AsyncValue`.
- Each action = a **repository command** (`serve`, `unserve`, `void`, `restore`, `recook(reason)`,
  `fireNow`, `setRush`, `setLineNote`, `markDone`, `reopen`) that writes Drift + outbox in one
  transaction. **No business logic in widgets.**
- The action sheet, reason picker, and done-confirm are UI-only; they call repo commands.
- Cooking status + derived flags come from the schedule provider; the page never recomputes the plan.

---

## Acceptance criteria

- [x] Each line is tappable; the sheet shows exactly the actions valid for its state.
- [x] Serve/serve-all remove items from the kitchen views; void hides + is restorable.
- [x] Recook requires a reason, re-fires the item **now** as priority, increments the recook count,
      and reopens a Done ticket.
- [x] Fire-now expedites without a reason and shows as priority on the kitchen.
- [x] Rush tightens the ticket SLA and prioritises all its lines; the kitchen shows `RUSH`.
- [x] Mark Done warns when items are unserved; Reopen restores the ticket.
- [x] Under-lamp warning appears for ready-but-unserved items past `READY_LIMIT`.
- [x] A line's special instruction (`note`) can be added / edited / cleared from the item sheet, shows
      on the Tickets + Stations boards, and is read aloud with the fire alert.
- [~] Every action works offline and the kitchen views reflect it (✓ via Drift write-through +
      reschedule + priority badges). **Sync events** (`ItemServed`, …) are deferred with the sync
      engine (§6, post-MVP).

## Out of scope (v1)

- **Coursing** (hold next course → "Fire mains").
- **Add item** to an existing ticket from the waiter side.
- Substitute-on-void flow (today: void, then add a new item once add-item lands).
