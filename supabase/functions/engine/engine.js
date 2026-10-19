// DraftSpin FC kampmotor. Ren JavaScript uden afhængigheder, så den kan testes i en browser og køre i en Supabase edge function.
// Kalibreret mod Python-referencen i engine/reference. v1.2: nye positionsregler (fast straf 0,90) og 15 formationer med LM/RM.

export const FORMS = {
  "4-3-3": ["LW", "ST", "RW", "CM", "DM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "4-3-3 (D)": ["LW", "ST", "RW", "CM", "DM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "4-3-3 (O)": ["LW", "ST", "RW", "CM", "AM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "4-3-3 (F)": ["LW", "ST", "RW", "CM", "CM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "4-5-1 (F)": ["ST", "LM", "CM", "CM", "CM", "RM", "LB", "CB", "CB", "RB", "GK"],
  "4-2-4": ["LW", "ST", "ST", "RW", "CM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "3-5-2 (F)": ["ST", "ST", "CM", "CM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "4-4-2": ["ST", "ST", "LM", "CM", "CM", "RM", "LB", "CB", "CB", "RB", "GK"],
  "4-2-3-1": ["ST", "LW", "AM", "RW", "DM", "DM", "LB", "CB", "CB", "RB", "GK"],
  "4-1-4-1": ["ST", "LM", "CM", "CM", "RM", "DM", "LB", "CB", "CB", "RB", "GK"],
  "4-1-2-1-2": ["ST", "ST", "AM", "CM", "CM", "DM", "LB", "CB", "CB", "RB", "GK"],
  "3-5-2": ["ST", "ST", "LWB", "CM", "DM", "CM", "RWB", "CB", "CB", "CB", "GK"],
  "3-4-3": ["LW", "ST", "RW", "CM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "5-3-2": ["ST", "ST", "CM", "DM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "5-3-2 (D)": ["ST", "ST", "CM", "DM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "5-3-2 (O)": ["ST", "ST", "CM", "AM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "5-3-1-1": ["ST", "AM", "CM", "DM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "4-2-1-3": ["LW", "ST", "RW", "AM", "DM", "DM", "LB", "CB", "CB", "RB", "GK"],
  "4-1-3-2": ["ST", "ST", "LM", "CM", "RM", "DM", "LB", "CB", "CB", "RB", "GK"],
  "5-4-1": ["ST", "LM", "CM", "CM", "RM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "4-5-1": ["ST", "LM", "CM", "DM", "CM", "RM", "LB", "CB", "CB", "RB", "GK"],
  "4-4-1-1": ["ST", "AM", "LM", "CM", "CM", "RM", "LB", "CB", "CB", "RB", "GK"],
  "4-3-1-2": ["ST", "ST", "AM", "CM", "DM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "4-2-2-2": ["ST", "ST", "AM", "AM", "DM", "DM", "LB", "CB", "CB", "RB", "GK"],
  "3-4-2-1": ["ST", "AM", "AM", "CM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "4-3-2-1": ["ST", "AM", "AM", "CM", "DM", "CM", "LB", "CB", "CB", "RB", "GK"],
  "3-4-1-2": ["ST", "ST", "AM", "CM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "L3-5-2": ["ST", "ST", "LM", "CM", "DM", "CM", "RM", "CB", "CB", "CB", "GK"],
  "L3-4-3": ["LW", "ST", "RW", "CM", "CM", "LB", "CB", "CB", "CB", "RB", "GK"],
  "L5-3-2": ["ST", "ST", "CM", "DM", "CM", "LB", "CB", "CB", "CB", "RB", "GK"],
  "L5-4-1": ["ST", "LM", "CM", "CM", "RM", "LB", "CB", "CB", "CB", "RB", "GK"],
};
const WOFF = { LWB: 0.07, RWB: 0.07, ST: 0.24, LW: 0.16, RW: 0.16, LM: 0.12, RM: 0.12, AM: 0.16, CM: 0.10, DM: 0.04, LB: 0.04, RB: 0.04, CB: 0.02, GK: 0 };
const WDEF = { LWB: 0.07, RWB: 0.07, GK: 0.28, CB: 0.16, LB: 0.10, RB: 0.10, DM: 0.10, CM: 0.05, LM: 0.04, RM: 0.04, AM: 0.01, LW: 0.01, RW: 0.01, ST: 0.01 };
const WGOAL = { LWB: 0.25, RWB: 0.25, ST: 1, LW: 0.65, RW: 0.65, LM: 0.4, RM: 0.4, AM: 0.55, CM: 0.25, DM: 0.15, LB: 0.12, RB: 0.12, CB: 0.15, GK: 0.002 };
const WASSIST = { LWB: 0.75, RWB: 0.75, AM: 1, LW: 1, RW: 1, LM: 0.9, RM: 0.9, CM: 0.75, LB: 0.6, RB: 0.6, ST: 0.45, DM: 0.35, CB: 0.12, GK: 0.02 };
export const ENGINE_VERSION = "1.7";
export const K = 40, MU_H = 1.32, MU_A = 1.01;
const SEASON_SD = 5, FORM_SD = 3, FORM_RHO = 0.8, TEAM_SD = 1.5, DARK_BONUS = 6, UNLUCKY_MALUS = 6;
const PEN_RATE = 0.29, YELLOW_PER_TEAM = 2.0, RED_PER_TEAM = 0.065, YW_REF = 11.4, RW_REF = 10.75; // referencesummer for et gennemsnitshold

// ---------- tilfældighed (deterministisk ud fra et seed) ----------
function xmur3(str) {
  let h = 1779033703 ^ str.length;
  for (let i = 0; i < str.length; i++) { h = Math.imul(h ^ str.charCodeAt(i), 3432918353); h = (h << 13) | (h >>> 19); }
  return function () { h = Math.imul(h ^ (h >>> 16), 2246822507); h = Math.imul(h ^ (h >>> 13), 3266489909); return (h ^= h >>> 16) >>> 0; };
}
function mulberry32(a) {
  return function () { a |= 0; a = (a + 0x6D2B79F5) | 0; let t = Math.imul(a ^ (a >>> 15), 1 | a); t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t; return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
}
export function makeRng(seedStr) {
  const r = mulberry32(xmur3(String(seedStr))());
  return {
    next: r,
    normal() { let u = 0; while (u === 0) u = r(); const v = r(); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); },
    poisson(l) { const L = Math.exp(-l); let k = 0, p = 1; do { k++; p *= r(); } while (p > L); return k - 1; },
    int(n) { return Math.floor(r() * n); },
    weighted(w) { const t = w.reduce((a, b) => a + b, 0); if (t <= 0) return -1; let x = r() * t; for (let i = 0; i < w.length; i++) { x -= w[i]; if (x <= 0) return i; } return w.length - 1; },
  };
}

// ---------- opstilling ----------
// Positionsregler: spillerens position -> plads. Naturlig plads = 1, plads med straf = PEN_FACTOR, ellers null (kan ikke spille der).
// Skal være identisk med slot_fit() i databasen (migration 020/021). v1.3: spillere kan have en 2. naturlig position (alts.<pos>.nat).
export const PEN_FACTOR = 0.90;
const PENALTY_SLOTS = { LB: ["RB", "LWB"], RB: ["LB", "RWB"], LWB: ["LB", "LM", "LW"], RWB: ["RB", "RM", "RW"], DM: ["CM"], CM: ["DM", "AM"], AM: ["CM"], LW: ["ST", "RW"], RW: ["ST", "LW"], ST: ["LW", "RW"] };
const NATURAL_EXTRA = { LW: ["LM"], RW: ["RM"] };
export function fac(p, slotPos) {
  if (p.pos === slotPos || (NATURAL_EXTRA[p.pos] || []).includes(slotPos) || p.alts?.[slotPos]?.nat === true) return 1;
  if ((PENALTY_SLOTS[p.pos] || []).includes(slotPos)) return PEN_FACTOR;
  return null;
}
export function bestXI(players, form) {
  const slots = FORMS[form], used = new Set(), xi = new Array(11);
  const order = [...Array(11).keys()].sort((a, b) => (slots[a] !== "GK") - (slots[b] !== "GK") || (slots[a] < slots[b] ? -1 : slots[a] > slots[b] ? 1 : 0));
  for (const i of order) {
    let best = null, bk = -1;
    players.forEach((p, k) => { if (used.has(k)) return; const f = fac(p, slots[i]); if (f === null) return; const v = p.rating * f; if (best === null || v > best) { best = v; bk = k; } });
    if (bk < 0) return null;
    used.add(bk); xi[i] = { pos: slots[i], p: players[bk], f: fac(players[bk], slots[i]) };
  }
  return xi;
}
export function xiStrength(xi) { return xi.reduce((a, x) => a + x.p.rating * x.f, 0) / 11; }
// AI-klubberne vælger kun blandt de oprindelige ni formationer (uden wingbacks, 'L'-nøglerne), så ligaens styrkebalance bevares
export const AI_FORMS = ["4-3-3", "4-4-2", "4-2-3-1", "4-1-4-1", "4-1-2-1-2", "L3-5-2", "L3-4-3", "L5-3-2", "L5-4-1"];
export function bestClubXI(players, forms = AI_FORMS) {
  let b = null, bf = null;
  for (const f of forms) { const x = bestXI(players, f); if (x && (b === null || xiStrength(x) > xiStrength(b))) { b = x; bf = f; } }
  return b ? { form: bf, xi: b, strength: xiStrength(b) } : null;
}

// ---------- program: dobbelt runde (cirkelmetoden). Returnerer 38 runder af [hjemmeindeks, udeindeks] ----------
export function schedule(n) {
  let teams = [...Array(n).keys()];
  const first = [];
  for (let r = 0; r < n - 1; r++) {
    const pairs = [];
    for (let i = 0; i < n / 2; i++) pairs.push([teams[i], teams[n - 1 - i]]);
    first.push(r % 2 === 0 ? pairs : pairs.map(([a, b]) => [b, a]));
    teams = [teams[0], teams[n - 1], ...teams.slice(1, n - 1)];
  }
  return first.concat(first.map((rd) => rd.map(([a, b]) => [b, a])));
}

// ---------- sæsonopsætning: skjult held, mørk hest og uheld ----------
// teams: [{ key, kind: 'human' | 'ai', strength }]
export function setupSeason(teams, seed) {
  const rng = makeRng(seed + "|setup");
  const luck = {};
  for (const t of teams) {
    const form = [];
    let prev = 0;
    for (let r = 0; r < 38; r++) {
      const e = rng.normal();
      prev = r === 0 ? FORM_SD * e : FORM_RHO * prev + Math.sqrt(1 - FORM_RHO * FORM_RHO) * FORM_SD * e;
      form.push(Math.round(prev * 1000) / 1000);
    }
    luck[t.key] = { season: Math.round(rng.normal() * SEASON_SD * 1000) / 1000, form };
  }
  const ranked = [...teams].sort((a, b) => b.strength - a.strength);
  const top = ranked.slice(0, 10).filter((t) => t.kind === "ai");
  const low = ranked.slice(10).filter((t) => t.kind === "ai");
  const dark = low.length ? low[rng.int(low.length)].key : null;
  const unlucky = top.length ? top[rng.int(top.length)].key : null;
  if (dark) luck[dark].season += DARK_BONUS;
  if (unlucky) luck[unlucky].season -= UNLUCKY_MALUS;
  return { luck, dark, unlucky };
}

// ---------- kamp ----------
// side: { xi: [{pos,p,f}], shift }   p: { id, name, rating, consistency, pen_taking, yellow_w, red_w }
export function simulateMatch(H, A, seed) {
  const rng = makeRng(seed);
  const prep = (T) => {
    const team = rng.normal() * TEAM_SD + T.shift;
    const R = T.xi.map((x) => (x.p.rating + rng.normal() * (6 - 0.25 * ((x.p.consistency || 12) - 1))) * x.f + team);
    let so = 0, sd = 0, wo = 0, wd = 0;
    T.xi.forEach((x, i) => { so += WOFF[x.pos] * R[i]; wo += WOFF[x.pos]; sd += WDEF[x.pos] * R[i]; wd += WDEF[x.pos]; });
    return { R, off: so / wo, def: sd / wd };
  };
  const h = prep(H), a = prep(A);
  const lamH = MU_H * Math.exp((h.off - a.def) / K), lamA = MU_A * Math.exp((a.off - h.def) / K);
  const sides = { h: { T: H, R: h.R, lam: lamH }, a: { T: A, R: a.R, lam: lamA } };
  const ev = [];
  const off = { h: {}, a: {} }; // spillerindeks -> minut for udvisning

  // kort: gule til forskellige spillere; røde (halvdelen som "2. gult") fordelt efter kortvægt
  for (const s of ["h", "a"]) {
    const T = sides[s].T, cards = [];
    const yw = T.xi.map((x) => x.p.yellow_w ?? 0.9), rw = T.xi.map((x) => (x.pos === "GK" ? 0 : x.p.red_w ?? 1));
    const nY = Math.min(10, rng.poisson((YELLOW_PER_TEAM * yw.reduce((p, c) => p + c, 0)) / YW_REF));
    const wy = yw.slice();
    for (let k = 0; k < nY; k++) { const i = rng.weighted(wy); if (i < 0) break; wy[i] = 0; cards.push({ m: 1 + rng.int(90), i, k: "y" }); }
    const nR = rng.poisson((RED_PER_TEAM * rw.reduce((p, c) => p + c, 0)) / RW_REF);
    for (let k = 0; k < nR; k++) {
      const i = rng.weighted(rw), m = 1 + rng.int(90);
      if (i < 0) continue;
      if (m > 1 && rng.next() < 0.5) {
        const ex = cards.find((c) => c.i === i && c.k === "y"); // genbrug et allerede trukket gult, så man ikke får tre kort
        if (ex) { if (ex.m >= m) ex.m = 1 + rng.int(m - 1); } else cards.push({ m: 1 + rng.int(m - 1), i, k: "y" });
        cards.push({ m, i, k: "r2" });
      }
      else cards.push({ m, i, k: "r" });
    }
    cards.sort((x, y) => x.m - y.m || (x.k === "y" ? -1 : 1));
    for (const c of cards) {
      if (off[s][c.i] !== undefined) continue;
      const pid = T.xi[c.i].p.id;
      if (c.k === "y") ev.push({ m: c.m, type: "yellow", s, pid });
      else { off[s][c.i] = c.m; ev.push({ m: c.m, type: c.k === "r2" ? "second_yellow" : "red", s, pid }); }
    }
  }
  const onPitch = (s, m) => sides[s].T.xi.map((_, i) => off[s][i] === undefined || off[s][i] >= m);
  const redsBefore = (s, m) => Object.values(off[s]).filter((x) => x < m).length;

  // mål fra åbent spil, minut for minut (inkl. 4 tillægsminutter i 2. halvleg)
  const g = (m) => (m <= 45 ? 1 : m <= 90 ? 1.18 : 1.25);
  let G = 0; for (let m = 1; m <= 94; m++) G += g(m);
  for (let m = 1; m <= 94; m++) {
    for (const s of ["h", "a"]) {
      const o = s === "h" ? "a" : "h";
      let rate = (sides[s].lam * g(m)) / G;
      rate *= Math.pow(0.75, redsBefore(s, m)) * Math.pow(1.3, redsBefore(o, m));
      if (rng.next() < 1 - Math.exp(-rate)) {
        const pitch = onPitch(s, m), T = sides[s].T;
        const w = T.xi.map((x, i) => (pitch[i] ? WGOAL[x.pos] * Math.exp((sides[s].R[i] - 140) / 25) : 0));
        const si = rng.weighted(w);
        if (si < 0) continue;
        let aid = null;
        if (rng.next() < 0.75) {
          const aw = T.xi.map((x, i) => (pitch[i] && i !== si ? WASSIST[x.pos] : 0));
          const ai = rng.weighted(aw); if (ai >= 0) aid = T.xi[ai].p.id;
        }
        ev.push({ m, type: "goal", s, pid: T.xi[si].p.id, aid, pen: false });
      }
    }
  }

  // straffespark
  const nPen = rng.poisson(PEN_RATE);
  for (let k = 0; k < nPen; k++) {
    const s = rng.next() < sides.h.lam / (sides.h.lam + sides.a.lam) ? "h" : "a", o = s === "h" ? "a" : "h";
    const m = 1 + rng.int(90), pitch = onPitch(s, m), T = sides[s].T;
    const cand = T.xi.map((x, i) => ({ i, x })).filter(({ i, x }) => pitch[i] && x.pos !== "GK").sort((p, q) => (q.x.p.pen_taking || 8) - (p.x.p.pen_taking || 8)).slice(0, 3);
    if (!cand.length) continue;
    const ci = rng.weighted([0.7, 0.2, 0.1].slice(0, cand.length)), taker = cand[ci].x.p;
    if (ev.some((x) => x.m === m && x.s === s && x.pid === taker.id && (x.type === "pen_miss" || x.pen))) continue; // samme taker, samme minut: ville give samme hændelsesnøgle
    const pScore = Math.max(0.6, Math.min(0.92, 0.8 + 0.012 * ((taker.pen_taking || 12) - 12)));
    if (rng.next() < pScore) ev.push({ m, type: "goal", s, pid: taker.id, aid: null, pen: true });
    else {
      const gk = sides[o].T.xi.find((x) => x.pos === "GK");
      const saved = rng.next() < 0.6;
      ev.push({ m, type: "pen_miss", s, pid: taker.id, aid: saved && gk ? gk.p.id : null, detail: saved ? "saved" : "wide" });
    }
  }

  ev.sort((x, y) => x.m - y.m);
  const hg = ev.filter((e) => e.type === "goal" && e.s === "h").length, ag = ev.filter((e) => e.type === "goal" && e.s === "a").length;
  const gkH = H.xi.find((x) => x.pos === "GK"), gkA = A.xi.find((x) => x.pos === "GK");
  if (ag === 0 && gkH) ev.push({ m: 90, type: "clean_sheet", s: "h", pid: gkH.p.id });
  if (hg === 0 && gkA) ev.push({ m: 90, type: "clean_sheet", s: "a", pid: gkA.p.id });
  return { hg, ag, events: ev, lamH, lamA };
}
