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
  "3-1-4-2": ["ST", "ST", "LM", "CM", "CM", "RM", "DM", "CB", "CB", "CB", "GK"],
  "4-4-2 (D)": ["ST", "ST", "LM", "CM", "DM", "RM", "LB", "CB", "CB", "RB", "GK"],
  "3-4-2-1 (D)": ["ST", "AM", "AM", "DM", "CM", "LWB", "CB", "CB", "CB", "RWB", "GK"],
  "4-2-3-1 (W)": ["ST", "LM", "AM", "RM", "DM", "DM", "LB", "CB", "CB", "RB", "GK"],
};
const WOFF = { LWB: 0.10, RWB: 0.10, ST: 0.24, LW: 0.16, RW: 0.16, LM: 0.12, RM: 0.12, AM: 0.16, CM: 0.10, DM: 0.04, LB: 0.04, RB: 0.04, CB: 0.02, GK: 0 };
const WDEF = { LWB: 0.07, RWB: 0.07, GK: 0.28, CB: 0.16, LB: 0.10, RB: 0.10, DM: 0.10, CM: 0.05, LM: 0.04, RM: 0.04, AM: 0.01, LW: 0.01, RW: 0.01, ST: 0.01 };
// v1.8: fladere målvægte (fløje og midtbane scorer mere, angriberen mindre dominerende)
const WGOAL = { LWB: 0.5, RWB: 0.5, ST: 1, LW: 0.85, RW: 0.85, LM: 0.65, RM: 0.65, AM: 0.75, CM: 0.45, DM: 0.3, LB: 0.22, RB: 0.22, CB: 0.25, GK: 0.0003 };
// v1.12: wingbacks bidrager mere offensivt (mål og assists); almindelige backs og stoppere assisterer sjældnere
const WASSIST = { LWB: 0.9, RWB: 0.9, AM: 1, LW: 1, RW: 1, LM: 0.9, RM: 0.9, CM: 0.75, LB: 0.4, RB: 0.4, ST: 0.45, DM: 0.35, CB: 0.06, GK: 0.02 };
// v1.12: selvmål (andel af modstanderens spillere på banen, der kan sparke bolden ind) og balance-regel (straf for skæv fordeling mellem angreb og forsvar)
const WOG = { CB: 3, LB: 1.5, RB: 1.5, LWB: 1.5, RWB: 1.5, DM: 1, CM: 0.6, GK: 0.3, LM: 0.2, RM: 0.2, AM: 0.2, LW: 0.2, RW: 0.2, ST: 0.2 };
const OG_RATE = 0.023, BAL_LAMBDA = 0.03;
export const ENGINE_VERSION = "1.14";
export const K = 40, MU_H = 1.32, MU_A = 1.01;
const SEASON_SD = 5, FORM_SD = 3, FORM_RHO = 0.8, TEAM_SD = 1.5, DARK_BONUS = 6, UNLUCKY_MALUS = 6;
// v1.13: svageste AI-klubber (svagest først) får fast sæson-straf, de bedste AI-klubber (stærkest først) en lille nedjustering
const TAIL = [-10, -8, -6], TOPCUT = [-4, -3, -2];
const PEN_RATE = 0.29, YELLOW_PER_TEAM = 2.0, RED_PER_TEAM = 0.065, YW_REF = 11.1, RW_REF = 10.75; // referencesummer for et gennemsnitshold
// v1.8 realisme: målscoreren afhænger mindre af rating, en spiller der lige har scoret scorer sjældnere igen i samme kamp, ekstreme holdstyrker dæmpes, og gule kort fordeles jævnere
const GOAL_RATING_DIV = 80, REPEAT_DECAY = 0.7, LAM_SOFT = 2.4, LAM_SLOPE = 0.6, YW_POW = 0.5;

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
  // v1.11: optimal tildeling (ungarsk metode, maksimerer sum af rating*faktor) i stedet for at fylde plads for plads
  const slots = FORMS[form], n = 11, m = players.length;
  if (m < n) return null;
  const w = slots.map((s) => players.map((p) => { const f = fac(p, s); return f === null ? -1e6 : p.rating * f; }));
  const INF = 1e12, u = new Array(n + 1).fill(0), v = new Array(m + 1).fill(0), pm = new Array(m + 1).fill(0), way = new Array(m + 1).fill(0);
  for (let i = 1; i <= n; i++) {
    pm[0] = i; let j0 = 0; const minv = new Array(m + 1).fill(INF), used = new Array(m + 1).fill(false);
    do {
      used[j0] = true; const i0 = pm[j0]; let d = INF, j1 = 0;
      for (let j = 1; j <= m; j++) if (!used[j]) { const cur = -w[i0 - 1][j - 1] - u[i0] - v[j]; if (cur < minv[j]) { minv[j] = cur; way[j] = j0; } if (minv[j] < d) { d = minv[j]; j1 = j; } }
      for (let j = 0; j <= m; j++) { if (used[j]) { u[pm[j]] += d; v[j] -= d; } else minv[j] -= d; }
      j0 = j1;
    } while (pm[j0] !== 0);
    do { const j1 = way[j0]; pm[j0] = pm[j1]; j0 = j1; } while (j0);
  }
  const xi = new Array(n);
  for (let j = 1; j <= m; j++) if (pm[j]) xi[pm[j] - 1] = j - 1;
  for (let i = 0; i < n; i++) if (w[i][xi[i]] < 0) return null;
  return xi.map((k, i) => ({ pos: slots[i], p: players[k], f: fac(players[k], slots[i]) }));
}
// v1.12: holdstyrke = gennemsnit af angrebs- og forsvarsstyrke (samme pladsvægte som i kampen) minus straffen for skæv fordeling
export function sideStrength(xi) {
  let so = 0, wo = 0, sd = 0, wd = 0;
  for (const x of xi) { const r = x.p.rating * x.f; so += WOFF[x.pos] * r; wo += WOFF[x.pos]; sd += WDEF[x.pos] * r; wd += WDEF[x.pos]; }
  return { off: so / wo, def: sd / wd };
}
export function xiStrength(xi) { const { off, def } = sideStrength(xi), tilt = (off - def) / 2; return (off + def) / 2 - BAL_LAMBDA * tilt * tilt; }
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
  const ais = ranked.filter((t) => t.kind === "ai");
  ais.slice(-3).reverse().forEach((t, i) => (luck[t.key].season += TAIL[i]));
  ais.slice(0, 3).forEach((t, i) => (luck[t.key].season += TOPCUT[i]));
  if (dark) luck[dark].season += DARK_BONUS;
  if (unlucky) luck[unlucky].season -= UNLUCKY_MALUS;
  return { luck, dark, unlucky };
}

// ---------- kamp ----------
// straffeskytte: højest pen_taking; ved lighed en udpeget straffeskytte (pen_rank) for den stærkeste klub (cstr = klubbens styrke), så laveste pen_rank, så id
const penOrder = (a, b) => (b.p.pen_taking || 8) - (a.p.pen_taking || 8) || ((a.p.pen_rank ? 0 : 1) - (b.p.pen_rank ? 0 : 1)) || ((b.p.cstr || 0) - (a.p.cstr || 0)) || ((a.p.pen_rank || 9) - (b.p.pen_rank || 9)) || (a.p.id - b.p.id);
// v1.14: straffespark. Skytten og målmanden vælger hver et af n hjørner (n afhænger af skyttens straffeevne og målmandens rating); samme hjørne = reddet.
// Derudover kan skytten skyde forbi/ramme stolpen (miss), oftere for en svag skytte mod en god målmand. Målt ca. 78 % scoret på tværs af ligaen (Premier League 2020-24: ca. 82 %).
export function penInfo(taker, gk) {
  const x = Math.max(-1.1, Math.min(1.25, ((taker.pen_taking || 10) - 10) / 8));
  const g = gk ? Math.max(-1.3, Math.min(1.3, (gk.rating - 129) / 30)) : 0;
  return { n: Math.max(2, Math.min(8, Math.round(5.6 + x - 1.6 * g))), miss: Math.max(0.01, Math.min(0.2, 0.03 - 0.025 * x + 0.075 * g)) };
}
export function penResult(info, spot, gkSpot, roll) { return spot === gkSpot ? "saved" : roll < info.miss ? "wide" : "goal"; }
// side: { xi: [{pos,p,f}], shift, human? }   p: { id, name, rating, consistency, pen_taking, yellow_w, red_w }
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
  for (const t of [h, a]) { const tilt = (t.off - t.def) / 2, pen = BAL_LAMBDA * tilt * tilt; t.off -= pen; t.def -= pen; }
  const cap = (l) => (l <= LAM_SOFT ? l : LAM_SOFT + (l - LAM_SOFT) * LAM_SLOPE);
  const lamH = cap(MU_H * Math.exp((h.off - a.def) / K)), lamA = cap(MU_A * Math.exp((a.off - h.def) / K));
  const sides = { h: { T: H, R: h.R, lam: lamH }, a: { T: A, R: a.R, lam: lamA } };
  const ev = [];
  const off = { h: {}, a: {} }; // spillerindeks -> minut for udvisning
  const sc = { h: {}, a: {} }; // spillerindeks -> mål scoret i denne kamp (til aftagende chance for at score igen)

  // kort: gule til forskellige spillere; røde (halvdelen som "2. gult") fordelt efter kortvægt
  for (const s of ["h", "a"]) {
    const T = sides[s].T, cards = [];
    const yw = T.xi.map((x) => Math.pow(x.p.yellow_w ?? 0.9, YW_POW)), rw = T.xi.map((x) => (x.pos === "GK" ? 0 : x.p.red_w ?? 1));
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

  // mål fra åbent spil, minut for minut (inkl. tilfældig tillægstid i 2. halvleg)
  const g = (m) => (m <= 45 ? 1 : m <= 90 ? 1.18 : 1.25);
  const added = Math.min(9, 1 + rng.poisson(3)); // v1.12: tillægstid 1-9 minutter, i snit 4
  let G = 0; for (let m = 1; m <= 90 + added; m++) G += g(m);
  for (let m = 1; m <= 90 + added; m++) {
    for (const s of ["h", "a"]) {
      const o = s === "h" ? "a" : "h";
      let rate = (sides[s].lam * g(m)) / G;
      rate *= Math.pow(0.75, redsBefore(s, m)) * Math.pow(1.3, redsBefore(o, m));
      if (rng.next() < 1 - Math.exp(-rate)) {
        const pitch = onPitch(s, m), T = sides[s].T;
        const w = T.xi.map((x, i) => (pitch[i] ? WGOAL[x.pos] * Math.pow(REPEAT_DECAY, sc[s][i] || 0) * Math.exp((sides[s].R[i] - 140) / GOAL_RATING_DIV) : 0));
        const si = rng.weighted(w);
        if (si < 0) continue;
        let aid = null;
        if (rng.next() < 0.75) {
          const aw = T.xi.map((x, i) => (pitch[i] && i !== si ? WASSIST[x.pos] : 0));
          const ai = rng.weighted(aw); if (ai >= 0) aid = T.xi[ai].p.id;
        }
        ev.push({ m, type: "goal", s, pid: T.xi[si].p.id, aid, pen: false });
        sc[s][si] = (sc[s][si] || 0) + 1;
      }
    }
  }

  // selvmål: tilskrives modstanderens spiller (detail 'og'), holdet der scorer står som s
  for (const s of ["h", "a"]) {
    const o = s === "h" ? "a" : "h", n = rng.poisson(OG_RATE);
    for (let k = 0; k < n; k++) {
      const m = 1 + rng.int(90 + added), pitch = onPitch(o, m), T = sides[o].T;
      const w = T.xi.map((x, i) => (pitch[i] ? WOG[x.pos] : 0)), i = rng.weighted(w);
      if (i < 0 || ev.some((x) => x.m === m && (x.type === "pen_miss" || x.pen))) continue;
      ev.push({ m, type: "goal", s, pid: T.xi[i].p.id, aid: null, pen: false, detail: "og" });
    }
  }

  // straffespark
  const nPen = rng.poisson(PEN_RATE);
  for (let k = 0; k < nPen; k++) {
    const s = rng.next() < sides.h.lam / (sides.h.lam + sides.a.lam) ? "h" : "a", o = s === "h" ? "a" : "h";
    const m = 1 + rng.int(90), pitch = onPitch(s, m), T = sides[s].T;
    // én fast skytte: 1) bedste straffe-egenskab blandt dem på banen; 2) ved lighed den udpegede straffeskytte for den stærkeste klub
    const cand = T.xi.map((x, i) => ({ i, x })).filter(({ i, x }) => pitch[i] && x.pos !== "GK").sort((a, b) => penOrder(a.x, b.x));
    if (!cand.length) continue;
    const taker = cand[0].x.p;
    if (ev.some((x) => x.m === m && (x.type === "pen_miss" || x.pen))) continue; // aldrig to straffe i samme minut (heller ikke for hver sit hold)
    const gk = sides[o].T.xi.find((x) => x.pos === "GK"), info = penInfo(taker, gk && gk.p);
    const res = penResult(info, rng.int(info.n), rng.int(info.n), rng.next()); // uden spillerens valg: tilfældigt hjørne mod tilfældig målmand
    if (res === "goal") ev.push({ m, type: "goal", s, pid: taker.id, aid: null, pen: true, pend: !!T.human });
    else ev.push({ m, type: "pen_miss", s, pid: taker.id, aid: res === "saved" && gk ? gk.p.id : null, detail: res, pend: !!T.human });
  }

  ev.sort((x, y) => x.m - y.m);
  const hg = ev.filter((e) => e.type === "goal" && e.s === "h").length, ag = ev.filter((e) => e.type === "goal" && e.s === "a").length;
  const gkH = H.xi.find((x) => x.pos === "GK"), gkA = A.xi.find((x) => x.pos === "GK");
  if (ag === 0 && gkH) ev.push({ m: 90, type: "clean_sheet", s: "h", pid: gkH.p.id });
  if (hg === 0 && gkA) ev.push({ m: 90, type: "clean_sheet", s: "a", pid: gkA.p.id });
  return { hg, ag, events: ev, lamH, lamA, added };
}
