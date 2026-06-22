import React, { useState, useMemo, useRef, useEffect } from "react";
import {
  ChefHat, Plus, Minus, X, Play, RotateCcw, Flame, Check,
  Gauge, Utensils, AlertTriangle, Layers, Timer, Camera, ScanLine, ChevronLeft,
} from "lucide-react";

/* ================================================================== */
/*  CONFIG                                                            */
/* ================================================================== */

const STATIONS = {
  grill:   { name: "Grill",   color: "#ef4444", cap: 2 },
  steam:   { name: "Steam",   color: "#0ea5e9", cap: 1 },
  wok:     { name: "Wok",     color: "#f59e0b", cap: 1 },
  fry:     { name: "Fry",     color: "#f97316", cap: 2 },
  curry:   { name: "Curry",   color: "#f43f5e", cap: 2 },
  soup:    { name: "Soup",    color: "#8b5cf6", cap: 1 },
  cold:    { name: "Cold",    color: "#10b981", cap: 3 },
  tandoor: { name: "Tandoor", color: "#eab308", cap: 1 },
  bar:     { name: "Bar",     color: "#14b8a6", cap: 2 },
};

// cook = predicted minutes · hold = can rest off-heat · batch = can cook together
const MENU = [
  { name: "Buff Sekuwa",          emoji: "🍢", station: "grill",   cook: 16, hold: true,  batch: false },
  { name: "Chicken Sizzler",      emoji: "🔥", station: "grill",   cook: 14, hold: true,  batch: false },
  { name: "Chicken Burger",       emoji: "🍔", station: "grill",   cook: 12, hold: true,  batch: false },
  { name: "Buff Momo",            emoji: "🥟", station: "steam",   cook: 12, hold: true,  batch: true  },
  { name: "Chicken Momo",         emoji: "🥟", station: "steam",   cook: 10, hold: true,  batch: true  },
  { name: "Veg Fried Rice",       emoji: "🍚", station: "wok",     cook: 9,  hold: true,  batch: false },
  { name: "Chicken Chowmein",     emoji: "🍜", station: "wok",     cook: 8,  hold: false, batch: false },
  { name: "Buff Sukuti",          emoji: "🥩", station: "fry",     cook: 7,  hold: true,  batch: false },
  { name: "French Fries",         emoji: "🍟", station: "fry",     cook: 6,  hold: false, batch: true  },
  { name: "Paneer Butter Masala", emoji: "🍛", station: "curry",   cook: 11, hold: true,  batch: false },
  { name: "Tomato Soup",          emoji: "🍲", station: "soup",    cook: 5,  hold: true,  batch: false },
  { name: "Greek Salad",          emoji: "🥗", station: "cold",    cook: 4,  hold: false, batch: false },
  { name: "Garlic Naan",          emoji: "🫓", station: "tandoor", cook: 4,  hold: false, batch: true  },
  { name: "Masala Lassi",         emoji: "🥛", station: "bar",     cook: 2,  hold: false, batch: false },
];
const M = (n) => MENU.find((x) => x.name === n);

const SLA = { dinein: 14, takeaway: 11, delivery: 9 }; // mins from order to plate
const TYPE = {
  dinein:   { label: "Dine-in",  short: "Dine",  color: "#3b82f6" },
  takeaway: { label: "Takeaway", short: "Take",  color: "#f59e0b" },
  delivery: { label: "Delivery", short: "Rider", color: "#f43f5e" },
};

// orderMin is minutes relative to "now" (negative = ordered earlier)
let _kid = 100;
const SAMPLE = () => [
  { id: ++_kid, table: "5",   type: "dinein",   orderMin: -2,
    items: [["Chicken Sizzler", 1], ["Buff Momo", 2], ["French Fries", 1]] },
  { id: ++_kid, table: "8",   type: "dinein",   orderMin: -1,
    items: [["Chicken Chowmein", 1], ["Chicken Momo", 1], ["Greek Salad", 1]] },
  { id: ++_kid, table: "3",   type: "takeaway", orderMin: 0,
    items: [["Veg Fried Rice", 1], ["Buff Momo", 1], ["Tomato Soup", 1]] },
  { id: ++_kid, table: "D21", type: "delivery", orderMin: 0,
    items: [["Chicken Burger", 1], ["French Fries", 1]] },
];

const C = (s) => STATIONS[s].color;
const fmt = (sec) => {
  sec = Math.max(0, Math.round(sec));
  return `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, "0")}`;
};
const codeOf = (m) => {
  const t = String(m.table);
  if (m.type === "delivery") return "D" + t.replace(/^D/, "");
  if (m.type === "takeaway") return "TA" + t.replace(/^TA/, "");
  return "T" + t.replace(/^T/, "");
};

/* ================================================================== */
/*  SCHEDULER — the engine                                            */
/* ================================================================== */
/*
  1. target  = orderMin + SLA(type)            (per ticket)
  2. ideal   = target − cookTime               (back-schedule each dish)
  3. batch   identical batchable dishes whose targets fall within a window
  4. sort    by ideal, then target, then longer-cook first
  5. place   each on its station respecting capacity (minute buckets):
       fits at ideal           -> on time
       station busy + holdable  -> fire earlier, HOLD the food
       station busy + can't hold -> fire later,  plate LATE
*/
function schedule(kots) {
  const HMAX = 120, BATCH_WIN = 2, floor = 0;

  // expand
  let raw = [];
  for (const k of kots) {
    const target = k.orderMin + SLA[k.type];
    for (const [name, qty, cookOv] of k.items) {
      const m = M(name);
      const cook = cookOv ?? m.cook;
      raw.push({
        key: m.station + "|" + name, station: m.station, name, emoji: m.emoji,
        cook, hold: m.hold, batch: m.batch,
        member: { kotId: k.id, table: k.table, type: k.type, qty }, target,
      });
    }
  }

  // batch
  const open = {}, dishes = [];
  for (const r of raw) {
    if (r.batch) {
      const g = (open[r.key] || []).find((b) => Math.abs(b.target - r.target) <= BATCH_WIN);
      if (g) { g.members.push(r.member); g.qty += r.member.qty; g.target = Math.min(g.target, r.target); continue; }
    }
    const d = { ...r, members: [r.member], qty: r.member.qty };
    delete d.member;
    dishes.push(d);
    if (r.batch) (open[r.key] = open[r.key] || []).push(d);
  }
  for (const d of dishes) d.ideal = d.target - d.cook;

  // sort
  dishes.sort((a, b) => a.ideal - b.ideal || a.target - b.target || b.cook - a.cook);

  // capacity buckets
  const occ = {};
  const feasible = (s, t, c) => {
    if (t < floor) return false;
    for (let i = 0; i < c; i++) {
      const b = t + i;
      if (b >= HMAX) return false;
      if (((occ[s] || [])[b] || 0) >= STATIONS[s].cap) return false;
    }
    return true;
  };
  const fill = (s, t, c) => { occ[s] = occ[s] || []; for (let i = 0; i < c; i++) occ[s][t + i] = (occ[s][t + i] || 0) + 1; };

  for (const d of dishes) {
    const want = Math.max(floor, d.ideal);
    let t = feasible(d.station, want, d.cook) ? want : null;
    for (let delta = 1; delta < HMAX && t === null; delta++) {
      const earlier = d.ideal - delta, later = want + delta;
      if (d.hold && earlier >= floor && feasible(d.station, earlier, d.cook)) t = earlier;
      else if (feasible(d.station, later, d.cook)) t = later;
      else if (!d.hold && earlier >= floor && feasible(d.station, earlier, d.cook)) t = earlier;
    }
    if (t === null) t = want;
    fill(d.station, t, d.cook);
    d.fire = t; d.finish = t + d.cook;
    d.hold = Math.max(0, d.target - d.finish);   // finishes early -> held mins
    d.late = Math.max(0, d.finish - d.target);   // finishes late  -> late mins
  }

  // lane packing per station (for the rail)
  const byStation = {};
  dishes.forEach((d) => (byStation[d.station] = byStation[d.station] || []).push(d));
  for (const s in byStation) {
    const arr = byStation[s].sort((a, b) => a.fire - b.fire);
    const ends = [];
    for (const d of arr) {
      let l = ends.findIndex((e) => e <= d.fire);
      if (l === -1) { l = ends.length; ends.push(d.finish); } else ends[l] = d.finish;
      d.lane = l;
    }
    byStation[s] = { dishes: arr, lanes: Math.max(1, ends.length) };
  }

  dishes.forEach((d, i) => (d.uid = i));
  const horizon = Math.max(1, ...dishes.map((d) => d.finish));
  return { dishes, byStation, horizon };
}

/* per-ticket roll-up */
function ticketStatus(k, dishes) {
  const mine = dishes.filter((d) => d.members.some((m) => m.kotId === k.id));
  const target = k.orderMin + SLA[k.type];
  const plate = mine.length ? Math.max(...mine.map((d) => d.finish)) : target;
  return { mine, target, plate, late: Math.max(0, plate - target) };
}

/* ================================================================== */
/*  APP                                                               */
/* ================================================================== */

export default function MultiKOT() {
  const [kots, setKots] = useState(SAMPLE);
  const [tab, setTab] = useState("rail"); // rail | queue | tickets
  const [sel, setSel] = useState(null);
  const [adding, setAdding] = useState(false);

  const [running, setRunning] = useState(false);
  const [elapsed, setElapsed] = useState(0); // scaled kitchen-seconds
  const [speed, setSpeed] = useState(8);
  const baseRef = useRef(0), tRef = useRef(0);

  const plan = useMemo(() => schedule(kots), [kots]);
  const started = running || elapsed > 0;
  const horizonSec = plan.horizon * 60;

  useEffect(() => {
    if (!running) return;
    const id = setInterval(() => {
      const e = baseRef.current + ((performance.now() - tRef.current) / 1000) * speed;
      if (e >= horizonSec) { setElapsed(horizonSec); setRunning(false); }
      else setElapsed(e);
    }, 90);
    return () => clearInterval(id);
  }, [running, speed, horizonSec]);

  const start = () => { baseRef.current = 0; tRef.current = performance.now(); setElapsed(0); setRunning(true); };
  const reset = () => { setRunning(false); setElapsed(0); };
  const changeSpeed = (s) => { if (running) { baseRef.current = elapsed; tRef.current = performance.now(); } setSpeed(s); };
  const reload = () => { reset(); setKots(SAMPLE()); };
  const addKot = (k) => {
    setKots((ks) => [...ks, { ...k, id: ++_kid, orderMin: running ? Math.round(elapsed / 60) : 0 }]);
    setAdding(false);
  };

  // totals + insights
  const lateCount = plan.dishes.filter((d) => d.late > 0).length;
  const batched = plan.dishes.filter((d) => d.members.length > 1).length;
  const lateByStation = {};
  plan.dishes.forEach((d) => { if (d.late > 0) lateByStation[d.station] = Math.max(lateByStation[d.station] || 0, d.late); });
  const bottleneck = Object.entries(lateByStation).sort((a, b) => b[1] - a[1])[0];

  return (
    <div className="flex min-h-screen w-full items-center justify-center p-4"
      style={{ background: "radial-gradient(120% 120% at 50% 0%, #15202b 0%, #070a0f 55%)" }}>
      <div className="relative flex w-full max-w-sm flex-col overflow-hidden rounded-3xl border border-zinc-800 shadow-2xl"
        style={{ height: "min(880px, 95vh)", background: "#0a0e14" }}>

        {/* top bar */}
        <div className="flex items-center justify-between px-4 pb-2 pt-4">
          <div className="flex items-center gap-2">
            <ChefHat size={20} style={{ color: "#f97316" }} />
            <div>
              <h1 className="text-base font-bold leading-none text-zinc-100">KitchenSync</h1>
              <p className="text-[10px] text-zinc-500">{kots.length} tickets · {plan.dishes.length} dishes</p>
            </div>
          </div>
          {started ? (
            <SpeedToggle speed={speed} onSpeed={changeSpeed} />
          ) : (
            <span className="rounded-full px-2.5 py-1 text-[11px] font-semibold"
              style={{ color: lateCount ? "#fbbf24" : "#34d399", background: (lateCount ? "#fbbf24" : "#34d399") + "1f" }}>
              {lateCount ? `${lateCount} will run late` : "all on track"}
            </span>
          )}
        </div>

        {/* insight */}
        {bottleneck && (
          <div className="mx-4 mb-2 flex items-center gap-2 rounded-lg border px-3 py-2 text-[11px]"
            style={{ borderColor: C(bottleneck[0]) + "55", background: C(bottleneck[0]) + "12" }}>
            <AlertTriangle size={14} style={{ color: C(bottleneck[0]) }} />
            <span className="text-zinc-300">
              <b style={{ color: C(bottleneck[0]) }}>{STATIONS[bottleneck[0]].name}</b> is the bottleneck
              {" "}(+{bottleneck[1]}m). One {STATIONS[bottleneck[0]].name.toLowerCase()} can't clear the queue — batch or add a second.
            </span>
          </div>
        )}

        {/* tabs */}
        <div className="mx-4 mb-1 flex rounded-lg bg-zinc-900 p-0.5 text-[12px] font-semibold">
          {[["rail", "Stations"], ["queue", "Fire next"], ["tickets", "Tickets"]].map(([k, l]) => (
            <button key={k} onClick={() => setTab(k)}
              className={`flex-1 rounded-md py-1.5 transition ${tab === k ? "bg-zinc-100 text-zinc-900" : "text-zinc-400"}`}>
              {l}
            </button>
          ))}
        </div>

        {/* body */}
        <div className="flex-1 overflow-y-auto px-4 pb-2">
          {tab === "rail" && <Rail plan={plan} elapsed={elapsed} started={started} sel={sel} setSel={setSel} />}
          {tab === "queue" && <Queue plan={plan} elapsed={elapsed} started={started} />}
          {tab === "tickets" && <Tickets kots={kots} plan={plan} elapsed={elapsed} started={started} />}
        </div>

        {/* footer */}
        <div className="flex items-center gap-2 border-t border-zinc-800 bg-zinc-950/80 p-3">
          <button onClick={() => setAdding(true)}
            className="flex items-center gap-1.5 rounded-xl border border-zinc-700 px-3 py-3 text-sm font-semibold text-zinc-200 active:scale-95">
            <Camera size={16} /> KOT
          </button>
          <button onClick={reload}
            className="rounded-xl border border-zinc-700 p-3 text-zinc-400 active:scale-95" title="Reload sample rush">
            <RotateCcw size={16} />
          </button>
          {!started ? (
            <button onClick={start}
              className="flex flex-1 items-center justify-center gap-2 rounded-xl py-3 font-semibold text-white active:scale-[0.99]"
              style={{ background: "#10b981" }}>
              <Play size={18} fill="white" /> Start service
            </button>
          ) : (
            <button onClick={reset}
              className="flex flex-1 items-center justify-center gap-2 rounded-xl py-3 font-semibold text-zinc-100 active:scale-[0.99]"
              style={{ background: elapsed >= horizonSec ? "#10b981" : "#27272a" }}>
              {elapsed >= horizonSec ? <><Utensils size={16} /> Service done — reset</> : <><RotateCcw size={16} /> Stop service</>}
            </button>
          )}
        </div>

        {adding && <AddKOT onAdd={addKot} onClose={() => setAdding(false)} />}
      </div>
    </div>
  );
}

/* ================================================================== */
/*  RAIL — station columns w/ capacity lanes (contention made visible) */
/* ================================================================== */

function Rail({ plan, elapsed, started, sel, setSel }) {
  const { byStation, horizon } = plan;
  const nowMin = elapsed / 60;
  const order = Object.keys(STATIONS).filter((s) => byStation[s]);
  const selD = plan.dishes.find((d) => d.uid === sel);

  return (
    <div className="space-y-2.5 pt-1">
      {order.map((s) => {
        const { dishes, lanes } = byStation[s];
        const cap = STATIONS[s].cap;
        const sat = lanes >= cap;
        return (
          <div key={s} className="rounded-xl border border-zinc-800 bg-zinc-900/40 p-2.5">
            <div className="mb-2 flex items-center justify-between">
              <div className="flex items-center gap-2">
                <span className="h-2.5 w-2.5 rounded-sm" style={{ background: C(s) }} />
                <span className="text-sm font-semibold text-zinc-100">{STATIONS[s].name}</span>
                <span className="text-[10px] text-zinc-500">cap {cap}</span>
              </div>
              <span className="rounded px-1.5 py-0.5 text-[10px] font-semibold"
                style={{ color: sat ? "#f87171" : "#71717a", background: sat ? "#f8717118" : "transparent" }}>
                {sat ? "saturated" : `${lanes}/${cap}`}
              </span>
            </div>

            <div className="relative" style={{ height: lanes * 26 }}>
              {/* now line */}
              {started && (
                <div className="absolute top-0 bottom-0 z-10 w-0.5"
                  style={{ left: `${Math.min(100, (nowMin / horizon) * 100)}%`, background: "#fafafa", boxShadow: "0 0 6px #fff" }} />
              )}
              {dishes.map((d) => {
                const st = liveStatus(d, elapsed, started);
                const left = (d.fire / horizon) * 100;
                const width = Math.max((d.cook / horizon) * 100, 7);
                const faded = st === "wait" || st === "plan";
                return (
                  <button key={d.uid} onClick={() => setSel(d.uid === sel ? null : d.uid)}
                    className="absolute flex items-center gap-1 whitespace-nowrap rounded px-1 text-[11px] font-semibold text-white"
                    style={{
                      left: `${left}%`, width: `${width}%`, top: d.lane * 26, height: 22,
                      background: C(s), opacity: faded ? 0.5 : 1,
                      outline: d.late > 0 ? "2px solid #f87171" : sel === d.uid ? "2px solid #fff" : "none",
                      outlineOffset: -2,
                      borderRight: d.hold > 0 ? "3px dashed #fde68a" : "none",
                    }}>
                    <span className="shrink-0">{d.emoji}</span>
                    <span className="shrink-0">{d.name}{d.qty > 1 ? ` ×${d.qty}` : ""}</span>
                    <span className="flex shrink-0 gap-0.5">
                      {d.members.map((m, i) => (
                        <span key={i} className="rounded px-1 text-[10px] leading-tight" style={{ background: "rgba(0,0,0,0.3)" }}>{codeOf(m)}</span>
                      ))}
                    </span>
                    {st === "cook" && <Flame size={10} className="shrink-0" />}
                    {st === "ready" && <Check size={10} className="shrink-0" />}
                  </button>
                );
              })}
            </div>
          </div>
        );
      })}

      {/* axis */}
      <div className="flex justify-between px-1 font-mono text-[10px] text-zinc-600">
        <span>0:00</span><span>{fmt(horizon * 30)}</span><span>{fmt(horizon * 60)}</span>
      </div>

      {/* legend + selected detail */}
      <div className="flex flex-wrap gap-x-3 gap-y-1 px-1 text-[10px] text-zinc-500">
        <span className="flex items-center gap-1"><span className="h-2.5 w-3.5 rounded-sm" style={{ background: "#52525b", borderRight: "3px dashed #fde68a" }} /> holding</span>
        <span className="flex items-center gap-1"><span className="h-2.5 w-3.5 rounded-sm" style={{ background: "#52525b", outline: "2px solid #f87171", outlineOffset: -1 }} /> plates late</span>
        <span className="flex items-center gap-1">tap a bar for tables</span>
      </div>

      {selD && <DetailCard d={selD} elapsed={elapsed} started={started} />}
    </div>
  );
}

function DetailCard({ d, elapsed, started }) {
  const st = liveStatus(d, elapsed, started);
  return (
    <div className="rounded-xl border bg-zinc-900 p-3" style={{ borderColor: C(d.station) + "66" }}>
      <div className="flex items-center gap-2">
        <span className="text-xl">{d.emoji}</span>
        <span className="font-semibold text-zinc-100">{d.name}</span>
        <span className="text-zinc-500">×{d.qty}</span>
        <span className="ml-auto"><Chip st={d.station} /></span>
      </div>
      <div className="mt-2 flex flex-wrap gap-2 text-[11px]">
        {d.members.map((m, i) => <TableTag key={i} m={m} />)}
      </div>
      <div className="mt-2 grid grid-cols-3 gap-2 font-mono text-[11px]">
        <Stat label="fire" v={d.fire === 0 ? "now" : `+${fmt(d.fire * 60)}`} />
        <Stat label="cook" v={`${d.cook}m`} />
        <Stat label={d.late > 0 ? "late by" : d.hold > 0 ? "holds" : "plate"}
          v={d.late > 0 ? `+${fmt(d.late * 60)}` : d.hold > 0 ? fmt(d.hold * 60) : "on time"}
          color={d.late > 0 ? "#f87171" : d.hold > 0 ? "#fbbf24" : "#34d399"} />
      </div>
    </div>
  );
}
const Stat = ({ label, v, color = "#e4e4e7" }) => (
  <div className="rounded-lg bg-zinc-800/60 px-2 py-1 text-center">
    <div className="text-[8px] uppercase tracking-wide text-zinc-500">{label}</div>
    <div className="font-semibold" style={{ color }}>{v}</div>
  </div>
);

/* ================================================================== */
/*  QUEUE — flat fire-order action feed                               */
/* ================================================================== */

function Queue({ plan, elapsed, started }) {
  const dishes = [...plan.dishes].sort((a, b) => a.fire - b.fire);
  const waiting = dishes.filter((d) => elapsed < d.fire * 60);
  const next = waiting[0] || null;
  const justFired = dishes
    .filter((d) => d.fire * 60 <= elapsed && elapsed - d.fire * 60 <= 12)
    .sort((a, b) => b.fire - a.fire)[0];
  const allDone = started && dishes.every((d) => elapsed >= d.finish * 60);

  return (
    <div className="space-y-2 pt-1">
      {started && (
        allDone ? (
          <div className="flex items-center justify-center gap-2 rounded-xl bg-emerald-600 py-3 font-bold text-white">
            <Utensils size={18} /> All dishes ready
          </div>
        ) : justFired ? (
          <div className="flex items-center gap-3 rounded-xl px-4 py-3 text-white"
            style={{ background: C(justFired.station), animation: "kpulse 1s ease-in-out infinite" }}>
            <Flame size={22} />
            <div className="flex-1">
              <div className="text-[10px] font-bold uppercase tracking-widest opacity-90">Fire now</div>
              <div className="text-lg font-bold leading-tight">{justFired.emoji} {justFired.name}{justFired.qty > 1 && ` ×${justFired.qty}`}</div>
            </div>
            <div className="flex flex-col items-end gap-1">{justFired.members.map((m, i) => <TableTag key={i} m={m} small />)}</div>
            <style>{`@keyframes kpulse{0%,100%{opacity:1}50%{opacity:.78}}`}</style>
          </div>
        ) : next ? (
          <div className="flex items-center gap-3 rounded-xl border bg-zinc-900 px-4 py-3" style={{ borderColor: C(next.station) + "66" }}>
            <div className="font-mono text-2xl font-bold" style={{ color: C(next.station) }}>{fmt(next.fire * 60 - elapsed)}</div>
            <div className="flex-1">
              <div className="text-[10px] uppercase tracking-widest text-zinc-500">next fire</div>
              <div className="font-semibold text-zinc-100">{next.emoji} {next.name}</div>
            </div>
            <Chip st={next.station} />
          </div>
        ) : null
      )}

      {!started && <div className="px-1 pb-1 text-[11px] text-zinc-500">Fire order across all tickets — top fires first.</div>}

      {dishes.map((d, i) => <QueueRow key={d.uid} d={d} idx={i} elapsed={elapsed} started={started} />)}
    </div>
  );
}

function QueueRow({ d, idx, elapsed, started }) {
  const st = liveStatus(d, elapsed, started);
  const prog = st === "cook" ? (elapsed - d.fire * 60) / (d.cook * 60) : st === "ready" ? 1 : 0;
  return (
    <div className="relative flex items-center gap-2.5 overflow-hidden rounded-xl border bg-zinc-900/60 p-2.5"
      style={{ borderColor: st === "cook" ? C(d.station) : "#27272a" }}>
      <span className="absolute inset-y-0 left-0 w-1" style={{ background: C(d.station) }} />
      {!started && (
        <span className="flex h-6 w-6 shrink-0 items-center justify-center rounded-md font-mono text-[11px] font-bold text-white" style={{ background: C(d.station) }}>{idx + 1}</span>
      )}
      <span className="pl-1 text-2xl">{d.emoji}</span>
      <div className="min-w-0 flex-1">
        <div className="flex items-center gap-1.5">
          <span className="truncate text-sm font-semibold text-zinc-100">{d.name}{d.qty > 1 && <span className="text-zinc-500"> ×{d.qty}</span>}</span>
          {d.members.length > 1 && <Layers size={12} className="shrink-0 text-zinc-500" />}
        </div>
        <div className="mt-1 flex flex-wrap items-center gap-1.5">
          {d.members.map((m, i) => <TableTag key={i} m={m} small />)}
          {d.hold > 0 && <Badge color="#fbbf24" icon={Timer}>hold {d.hold}m</Badge>}
          {d.late > 0 && <Badge color="#f87171" icon={AlertTriangle}>late +{d.late}m</Badge>}
        </div>
        {st === "cook" && (
          <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-zinc-800">
            <div className="h-full rounded-full" style={{ width: `${prog * 100}%`, background: C(d.station) }} />
          </div>
        )}
      </div>
      <div className="w-16 shrink-0 text-right">
        {!started && <><div className="text-[8px] uppercase text-zinc-600">fire</div><div className="font-mono text-sm font-semibold" style={{ color: C(d.station) }}>{d.fire === 0 ? "now" : `+${fmt(d.fire * 60)}`}</div></>}
        {st === "wait" && <><div className="text-[8px] uppercase text-zinc-600">in</div><div className="font-mono text-sm font-semibold text-zinc-300">{fmt(d.fire * 60 - elapsed)}</div></>}
        {st === "cook" && <Badge color={C(d.station)} icon={Flame} solid>cook</Badge>}
        {st === "ready" && <Badge color="#10b981" icon={Check} solid>ready</Badge>}
      </div>
    </div>
  );
}

/* ================================================================== */
/*  TICKETS — table-centric expo view                                 */
/* ================================================================== */

function Tickets({ kots, plan, elapsed, started }) {
  const rows = kots.map((k) => ({ k, ...ticketStatus(k, plan.dishes) }))
    .sort((a, b) => a.target - b.target);

  return (
    <div className="space-y-2 pt-1">
      {rows.map(({ k, mine, target, plate, late }) => {
        const plateSec = plate * 60, doneAll = started && elapsed >= plateSec;
        const remain = plateSec - elapsed;
        const tm = TYPE[k.type];
        const accent = doneAll ? "#10b981" : late > 0 ? "#f87171" : "#27272a";
        return (
          <div key={k.id} className="overflow-hidden rounded-xl border bg-zinc-900/60 p-3" style={{ borderColor: accent }}>
            <div className="flex items-center gap-2">
              <span className="rounded-md px-2 py-0.5 text-sm font-bold text-zinc-100" style={{ background: tm.color + "26", color: tm.color }}>
                {codeOf(k)}
              </span>
              <span className="rounded px-1.5 py-0.5 text-[10px] font-semibold" style={{ color: tm.color }}>{tm.label}</span>
              <span className="ml-auto font-mono text-[11px] text-zinc-500">
                {k.orderMin <= 0 ? `${-k.orderMin}m ago` : `+${k.orderMin}m`}
              </span>
            </div>

            <div className="mt-2 flex flex-wrap gap-2">
              {mine.map((d) => {
                const ds = liveStatus(d, elapsed, started);
                return (
                  <span key={d.uid} className="flex items-center gap-1 rounded-lg bg-zinc-800/70 px-2 py-1 text-[12px]"
                    style={{ outline: ds === "cook" ? `1.5px solid ${C(d.station)}` : "none", outlineOffset: -1, opacity: ds === "ready" ? 0.55 : 1 }}>
                    <span>{d.emoji}</span>
                    <span className="text-zinc-200">{d.name.split(" ").slice(-1)[0]}</span>
                    {ds === "ready" && <Check size={11} className="text-emerald-500" />}
                  </span>
                );
              })}
            </div>

            <div className="mt-2 flex items-center justify-between border-t border-zinc-800 pt-2 text-[12px]">
              <span className="text-zinc-500">{k.type === "delivery" ? "Rider waiting" : "Plate together"}</span>
              {doneAll
                ? <span className="font-semibold text-emerald-400">ready to plate</span>
                : started
                  ? <span className="font-mono font-semibold" style={{ color: late > 0 ? "#f87171" : "#e4e4e7" }}>plate in {fmt(remain)}{late > 0 && ` · +${late}m late`}</span>
                  : <span className="font-mono font-semibold" style={{ color: late > 0 ? "#f87171" : "#34d399" }}>{late > 0 ? `+${late}m over SLA` : `on time · ${fmt(plate * 60)}`}</span>}
            </div>
          </div>
        );
      })}
    </div>
  );
}

/* ================================================================== */
/*  ADD KOT — scan a ticket, review predicted times, drop on board    */
/* ================================================================== */

function draftKOT() {
  const types = ["dinein", "takeaway", "delivery"];
  const type = types[Math.floor(Math.random() * types.length)];
  const table = type === "delivery" ? 20 + Math.floor(Math.random() * 30) : 2 + Math.floor(Math.random() * 18);
  const pool = [...MENU];
  const n = 2 + Math.floor(Math.random() * 3);
  const items = [];
  for (let k = 0; k < n && pool.length; k++) {
    const m = pool.splice(Math.floor(Math.random() * pool.length), 1)[0];
    items.push({ name: m.name, emoji: m.emoji, station: m.station, qty: 1 + (Math.random() < 0.2 ? 1 : 0), cook: m.cook });
  }
  return { type, table, items };
}

function AddKOT({ onAdd, onClose }) {
  const [step, setStep] = useState("scan");   // scan | review
  const [scanning, setScanning] = useState(false);
  const [draft, setDraft] = useState(draftKOT);
  const [line, setLine] = useState(0);
  const [picker, setPicker] = useState(false);

  useEffect(() => {
    if (!scanning) { setLine(0); return; }
    const id = setInterval(() => setLine((l) => l + 1), 230);
    return () => clearInterval(id);
  }, [scanning]);

  const scan = () => { setScanning(true); setTimeout(() => { setScanning(false); setStep("review"); }, 1900); };
  const tableStr = draft.type === "delivery" ? "D" + draft.table : String(draft.table);

  const setQty = (i, d) => setDraft((dr) => ({ ...dr, items: dr.items.map((it, j) => j === i ? { ...it, qty: Math.max(1, it.qty + d) } : it) }));
  const setCook = (i, d) => setDraft((dr) => ({ ...dr, items: dr.items.map((it, j) => j === i ? { ...it, cook: Math.max(1, it.cook + d) } : it) }));
  const rm = (i) => setDraft((dr) => ({ ...dr, items: dr.items.filter((_, j) => j !== i) }));
  const addDish = (m) => setDraft((dr) => ({ ...dr, items: [...dr.items, { name: m.name, emoji: m.emoji, station: m.station, qty: 1, cook: m.cook }] }));

  const submit = () => draft.items.length && onAdd({ table: tableStr, type: draft.type, items: draft.items.map((it) => [it.name, it.qty, it.cook]) });

  return (
    <div className="absolute inset-0 z-30 flex flex-col" style={{ background: "#0a0e14" }}>
      <div className="flex items-center gap-2 px-3 py-3">
        {step === "review"
          ? <button onClick={() => setStep("scan")} className="p-1 text-zinc-300 active:scale-90"><ChevronLeft size={22} /></button>
          : <button onClick={onClose} className="p-1 text-zinc-300 active:scale-90"><X size={22} /></button>}
        <div className="flex-1">
          <h2 className="text-base font-bold leading-tight text-zinc-100">{step === "scan" ? "Scan KOT" : "Review KOT"}</h2>
          <p className="text-[11px] text-zinc-500">{step === "scan" ? "Point at the ticket and capture" : "Fix any predicted time, then add"}</p>
        </div>
        {step === "review" && draft.items[0] && <Chip st={draft.items[0].station} />}
      </div>

      {step === "scan" ? (
        <div className="flex flex-1 flex-col">
          <div className="relative mx-4 flex-1 overflow-hidden rounded-2xl border border-zinc-800 bg-black">
            <div className="absolute inset-0 opacity-40" style={{ backgroundImage: "repeating-linear-gradient(0deg,#111 0 2px,transparent 2px 22px),repeating-linear-gradient(90deg,#111 0 2px,transparent 2px 22px)" }} />
            {["left-3 top-3 border-l-2 border-t-2", "right-3 top-3 border-r-2 border-t-2", "left-3 bottom-3 border-l-2 border-b-2", "right-3 bottom-3 border-r-2 border-b-2"].map((c) => (
              <div key={c} className={`absolute h-7 w-7 ${c}`} style={{ borderColor: "#f97316" }} />
            ))}
            <div className="absolute inset-0 flex items-center justify-center p-6">
              <div className="w-44 rotate-[-3deg] rounded-sm bg-zinc-100 p-3 font-mono text-[10px] leading-tight text-zinc-900 shadow-xl">
                <div className="text-center font-bold tracking-widest">*** KOT ***</div>
                <div className="mt-1 flex justify-between border-b border-dashed border-zinc-400 pb-1">
                  <span>{draft.type === "delivery" ? "DELIV" : draft.type === "takeaway" ? "TAKE" : "TBL"} {tableStr}</span>
                  <span>{new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })}</span>
                </div>
                {draft.items.map((it, i) => (
                  <div key={i} className="flex justify-between pt-1"><span className="truncate pr-1">{it.name}</span><span>x{it.qty}</span></div>
                ))}
              </div>
            </div>
            {scanning && (
              <>
                <div className="absolute left-0 right-0 h-12" style={{ top: 0, background: "linear-gradient(180deg,transparent,#f9731633,#f9731600)", animation: "scank 1.4s linear infinite" }} />
                <div className="absolute inset-x-3 bottom-3 rounded-lg bg-black/80 p-3 font-mono text-[11px] text-emerald-400 backdrop-blur">
                  <div className="mb-1 flex items-center gap-1 text-zinc-400"><ScanLine size={12} /> reading items…</div>
                  {draft.items.slice(0, line).map((it, i) => (
                    <div key={i} className="flex justify-between"><span>+ {it.name}</span><span className="text-zinc-500">~{it.cook}m</span></div>
                  ))}
                </div>
              </>
            )}
            {!scanning && <div className="absolute inset-x-0 bottom-4 text-center text-[11px] text-zinc-400">Position the ticket inside the frame</div>}
          </div>

          <div className="flex items-center justify-between px-8 py-6">
            <button onClick={() => setDraft(draftKOT())} disabled={scanning} className="flex flex-col items-center gap-1 text-zinc-400 active:scale-95 disabled:opacity-40">
              <RotateCcw size={20} /><span className="text-[10px]">New ticket</span>
            </button>
            <button onClick={scan} disabled={scanning} className="flex items-center justify-center rounded-full border-4 border-zinc-700 active:scale-95 disabled:opacity-50" style={{ width: 72, height: 72 }}>
              <span className="flex h-14 w-14 items-center justify-center rounded-full" style={{ background: "#f97316" }}><Camera size={26} className="text-white" /></span>
            </button>
            <div className="flex w-12 flex-col items-center gap-1 text-zinc-600"><Utensils size={20} /><span className="text-[10px]">{draft.items.length} items</span></div>
          </div>
          <style>{`@keyframes scank{0%{top:0}100%{top:88%}}`}</style>
        </div>
      ) : (
        <div className="flex flex-1 flex-col overflow-hidden">
          <div className="px-4">
            <div className="mb-2 flex rounded-lg bg-zinc-900 p-0.5 text-[12px] font-semibold">
              {Object.entries(TYPE).map(([k, v]) => (
                <button key={k} onClick={() => setDraft((dr) => ({ ...dr, type: k }))} className={`flex-1 rounded-md py-1.5 ${draft.type === k ? "text-zinc-900" : "text-zinc-400"}`} style={draft.type === k ? { background: v.color } : {}}>{v.short}</button>
              ))}
            </div>
            <div className="mb-2 flex items-center justify-between rounded-lg bg-zinc-900 px-3 py-2">
              <span className="text-sm text-zinc-400">{draft.type === "delivery" ? "Order #" : "Table"}</span>
              <div className="flex items-center gap-3">
                <button onClick={() => setDraft((dr) => ({ ...dr, table: Math.max(1, dr.table - 1) }))} className="flex h-7 w-7 items-center justify-center rounded-md bg-zinc-700 text-zinc-100"><Minus size={14} /></button>
                <span className="w-10 text-center font-mono font-semibold text-zinc-100">{tableStr}</span>
                <button onClick={() => setDraft((dr) => ({ ...dr, table: dr.table + 1 }))} className="flex h-7 w-7 items-center justify-center rounded-md bg-zinc-700 text-zinc-100"><Plus size={14} /></button>
              </div>
            </div>
          </div>

          <div className="flex-1 space-y-2 overflow-y-auto px-4 pb-2">
            {draft.items.map((it, i) => (
              <div key={i} className="relative overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/60 p-2.5">
                <span className="absolute inset-y-0 left-0 w-1" style={{ background: C(it.station) }} />
                <div className="flex items-center gap-2.5 pl-1">
                  <span className="text-2xl">{it.emoji}</span>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-sm font-semibold text-zinc-100">{it.name}</div>
                    <div className="mt-1"><Chip st={it.station} /></div>
                  </div>
                  <button onClick={() => rm(i)} className="p-1 text-zinc-600 active:scale-90"><X size={16} /></button>
                </div>
                <div className="mt-2 flex items-center gap-2 pl-1">
                  <Step label="Qty" value={`×${it.qty}`} onMinus={() => setQty(i, -1)} onPlus={() => setQty(i, 1)} />
                  <Step label="Cook" value={`${it.cook}m`} accent={C(it.station)} onMinus={() => setCook(i, -1)} onPlus={() => setCook(i, 1)} />
                </div>
              </div>
            ))}

            {picker ? (
              <div className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-2">
                <div className="mb-1 flex items-center justify-between px-1">
                  <span className="text-[11px] uppercase tracking-wide text-zinc-500">Add dish</span>
                  <button onClick={() => setPicker(false)} className="text-zinc-500"><X size={14} /></button>
                </div>
                <div className="max-h-44 space-y-1 overflow-y-auto">
                  {MENU.map((m) => (
                    <button key={m.name} onClick={() => { addDish(m); setPicker(false); }} className="flex w-full items-center gap-2 rounded-lg px-2 py-1.5 text-left active:bg-zinc-800">
                      <span className="text-lg">{m.emoji}</span><span className="flex-1 text-sm text-zinc-100">{m.name}</span><Chip st={m.station} /><span className="w-7 text-right font-mono text-[11px] text-zinc-500">{m.cook}m</span>
                    </button>
                  ))}
                </div>
              </div>
            ) : (
              <button onClick={() => setPicker(true)} className="flex w-full items-center justify-center gap-2 rounded-xl border border-dashed border-zinc-700 py-2.5 text-sm text-zinc-400 active:scale-[0.99]"><Plus size={16} /> Add dish</button>
            )}
          </div>

          <div className="border-t border-zinc-800 bg-zinc-950/80 p-4">
            <button onClick={submit} disabled={!draft.items.length} className="w-full rounded-xl py-3.5 font-semibold text-white disabled:opacity-40" style={{ background: "#f97316" }}>Add to board</button>
          </div>
        </div>
      )}
    </div>
  );
}

function Step({ label, value, onMinus, onPlus, accent = "#a1a1aa" }) {
  return (
    <div className="flex flex-1 items-center justify-between rounded-lg bg-zinc-800/70 px-2 py-1.5">
      <button onClick={onMinus} className="flex h-6 w-6 items-center justify-center rounded-md bg-zinc-700 text-zinc-200 active:scale-90"><Minus size={14} /></button>
      <div className="text-center">
        <div className="text-[9px] uppercase tracking-wide text-zinc-500">{label}</div>
        <div className="font-mono text-sm font-semibold" style={{ color: accent }}>{value}</div>
      </div>
      <button onClick={onPlus} className="flex h-6 w-6 items-center justify-center rounded-md bg-zinc-700 text-zinc-200 active:scale-90"><Plus size={14} /></button>
    </div>
  );
}

/* ================================================================== */
/*  shared bits                                                       */
/* ================================================================== */

function liveStatus(d, elapsed, started) {
  if (!started) return "plan";
  if (elapsed < d.fire * 60) return "wait";
  if (elapsed < d.finish * 60) return "cook";
  return "ready";
}

const Chip = ({ st }) => (
  <span className="inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 text-[9px] font-semibold uppercase tracking-wide"
    style={{ color: C(st), background: C(st) + "1f" }}>
    <span className="h-1.5 w-1.5 rounded-full" style={{ background: C(st) }} />{STATIONS[st].name}
  </span>
);

const TableTag = ({ m, small }) => (
  <span className={`inline-flex items-center gap-1 rounded ${small ? "px-1.5 py-0.5 text-[10px]" : "px-2 py-1 text-[11px]"} font-semibold`}
    style={{ color: TYPE[m.type].color, background: TYPE[m.type].color + "1f" }}>
    {codeOf(m)}{m.qty > 1 && <span className="opacity-70">×{m.qty}</span>}
  </span>
);

const Badge = ({ children, color, icon: Icon, solid }) => (
  <span className="inline-flex items-center gap-1 rounded-md px-1.5 py-0.5 text-[10px] font-bold"
    style={solid ? { background: color, color: "#fff" } : { color, background: color + "1f" }}>
    {Icon && <Icon size={10} />}{children}
  </span>
);

function SpeedToggle({ speed, onSpeed }) {
  return (
    <div className="flex items-center gap-1 rounded-lg border border-zinc-700 bg-zinc-900 p-0.5">
      <Gauge size={12} className="ml-1 text-zinc-500" />
      {[1, 8, 30].map((s) => (
        <button key={s} onClick={() => onSpeed(s)}
          className={`rounded-md px-2 py-1 font-mono text-[11px] font-semibold ${speed === s ? "bg-zinc-100 text-zinc-900" : "text-zinc-400"}`}>{s}×</button>
      ))}
    </div>
  );
}
