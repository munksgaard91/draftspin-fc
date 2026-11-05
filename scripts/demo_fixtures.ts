// @ts-nocheck
// Bygger demo/fixtures.json: en komplet, opdigtet sæson (4 demo-hold + 16 AI-klubber), simuleret med den rigtige motor.
// Bruges af demotilstanden (index.html?demo=...). Ingen database: spillere og klubber læses fra eksporterede JSON-filer.
// Kør: deno run --allow-read --allow-write scripts/demo_fixtures.ts <players.json> <clubs.json>
// players.json: select id,club,number,name,pos,alts,rating,short_name,face_id,pen_taking,consistency,pen_rank,yellow_w,red_w from players
import * as E from "../supabase/functions/engine/engine.js";

const [pPath, cPath] = Deno.args;
const PLAYERS = JSON.parse(await Deno.readTextFile(pPath));
const CLUBS = JSON.parse(await Deno.readTextFile(cPath));
const OUT = new URL("../demo/fixtures.json", import.meta.url);

// klubstyrke (samme som serverens loadPlayers) bruges til straffeskytte ved lighed
const byClub = new Map();
PLAYERS.forEach((p) => { if (!byClub.has(p.club)) byClub.set(p.club, []); byClub.get(p.club).push(p.rating); });
const cstr = new Map([...byClub].map(([c, r]) => [c, r.sort((a, b) => b - a).slice(0, 14).reduce((a, b) => a + b, 0) / Math.min(14, r.length)]));
PLAYERS.forEach((p) => { p.cstr = cstr.get(p.club) || 0; });

const GID = "d0000000-0000-4000-8000-000000000001";
const HUMANS = [
  { uid: "d0000000-0000-4000-8000-0000000000a1", team: "Demo United", tag: "DEM", display: "Alex", c1: "#3a6fd8", c2: "#ffffff", crest: 2, form: "4-3-3", tier: 0 },
  { uid: "d0000000-0000-4000-8000-0000000000a2", team: "Sample Rovers", tag: "SAM", display: "Sam", c1: "#cf4a4a", c2: "#1a1c1a", crest: 5, form: "4-2-3-1", tier: 2 },
  { uid: "d0000000-0000-4000-8000-0000000000a3", team: "Pixel Athletic", tag: "PXL", display: "Kim", c1: "#2fa7a0", c2: "#e6ebf5", crest: 8, form: "4-4-2", tier: 5 },
  { uid: "d0000000-0000-4000-8000-0000000000a4", team: "Fixture Town", tag: "FXT", display: "Jo", c1: "#c29a3d", c2: "#2a1d44", crest: 11, form: "3-4-3", tier: 9 },
];

function build(seedNo) {
  const rng = E.makeRng("demo-draft|" + seedNo);
  const taken = new Set(), picks = [], xi = {};
  HUMANS.forEach((h) => (xi[h.uid] = new Array(11)));
  const order = HUMANS.map((h) => h.uid);
  for (let k = 0; k < 44; k++) {
    const rnd = Math.floor(k / 4), pos = k % 4, uid = order[rnd % 2 === 0 ? pos : 3 - pos], h = HUMANS.find((x) => x.uid === uid);
    const slots = E.FORMS[h.form];
    // klubhjulet: tilfældig klub med mindst én brugbar spiller til en ledig plads
    const cands = (club) => PLAYERS.filter((p) => p.club === club && !taken.has(p.id)).flatMap((p) => slots.map((sp, i) => (!xi[uid][i] && E.fac(p, sp) != null ? { p, i, v: p.rating * E.fac(p, sp) } : null)).filter(Boolean));
    const clubs = CLUBS.map((c) => c.code).filter((c) => cands(c).length);
    const club = clubs[rng.int(clubs.length)];
    const cs = cands(club).sort((a, b) => b.v - a.v);
    const c = cs[Math.min(h.tier, cs.length - 1)];
    taken.add(c.p.id);
    xi[uid][c.i] = { pos: slots[c.i], p: c.p, f: E.fac(c.p, slots[c.i]) };
    picks.push({ game_id: GID, pick_number: k, user_id: uid, player_id: c.p.id, slot: c.i + 1, club });
  }
  const teams = HUMANS.map((h) => ({ key: h.uid, kind: "human", user_id: h.uid, name: h.team, color1: h.c1, color2: h.c2, crest: h.crest, formation: h.form, xi: xi[h.uid], strength: E.xiStrength(xi[h.uid]) }));
  const ai = [];
  for (const c of CLUBS) {
    const b = E.bestClubXI(PLAYERS.filter((p) => p.club === c.code && !taken.has(p.id)));
    if (b) ai.push({ key: c.code, kind: "ai", club: c.code, name: c.name, formation: b.form, xi: b.xi, strength: b.strength });
  }
  ai.sort((a, b) => a.strength - b.strength);
  const field = ai.slice(teams.length).concat(teams);
  const seed = "demo-season|" + seedNo;
  const { luck } = E.setupSeason(field.map((t) => ({ key: t.key, kind: t.kind, strength: t.strength })), seed);
  const orng = E.makeRng(seed + "|order");
  const ord = field.map((t) => ({ t, k: orng.next() })).sort((a, b) => a.k - b.k).map((x) => x.t);
  const byKey = Object.fromEntries(field.map((t) => [t.key, t]));
  const matches = [], events = [];
  let mid = 9000, eid = 500000;
  E.schedule(ord.length).forEach((rd, ri) => rd.forEach(([h, a]) => {
    const th = ord[h], ta = ord[a], round = ri + 1, lh = luck[th.key], la = luck[ta.key];
    const r = E.simulateMatch({ xi: th.xi, shift: lh.season + lh.form[ri] }, { xi: ta.xi, shift: la.season + la.form[ri] }, `${seed}|${round}|${th.key}`);
    const id = mid++;
    matches.push({ id, game_id: GID, round, home_key: th.key, away_key: ta.key, home_goals: r.hg, away_goals: r.ag, played: true, added_time: r.added });
    if (th.kind === "human" || ta.kind === "human")
      for (const e of r.events) events.push({ id: eid++, game_id: GID, match_id: id, minute: e.m, type: e.type, team: e.s, player_id: e.pid ?? null, assist_id: e.aid ?? null, pen: !!e.pen, detail: e.detail ?? null, pending: false });
  }));
  // tabel
  const t = {};
  field.forEach((x) => (t[x.key] = { w: 0, d: 0, l: 0, gf: 0, ga: 0 }));
  for (const m of matches) {
    const h = t[m.home_key], a = t[m.away_key];
    h.gf += m.home_goals; h.ga += m.away_goals; a.gf += m.away_goals; a.ga += m.home_goals;
    if (m.home_goals > m.away_goals) { h.w++; a.l++; } else if (m.home_goals < m.away_goals) { a.w++; h.l++; } else { h.d++; a.d++; }
  }
  const table = Object.keys(t).map((k) => ({ k, p: t[k].w * 3 + t[k].d, gd: t[k].gf - t[k].ga, gf: t[k].gf })).sort((a, b) => b.p - a.p || b.gd - a.gd || b.gf - a.gf);
  const pos = {};
  table.forEach((x, i) => (pos[x.k] = i + 1));
  return { picks, field, byKey, matches, events, t, pos, order };
}

// find en sæson, hvor demo-holdene ender som mester, i den øvre halvdel, i midten og i nedrykningszonen
let S = null, seedNo = 0;
for (; seedNo < 400; seedNo++) {
  const s = build(seedNo), ps = HUMANS.map((h) => s.pos[h.uid]).sort((a, b) => a - b);
  if (ps[0] === 1 && ps[1] >= 4 && ps[1] <= 7 && ps[2] >= 9 && ps[2] <= 15 && ps[3] >= 18) { S = s; break; }
}
if (!S) throw new Error("ingen passende sæson fundet");
const { picks, field, matches, events, t, pos, order } = S;

// skærmvalg: hvilken runde viser et mål / et straffespark for hvert demo-hold
const meta = {};
for (const h of HUMANS) {
  const mine = matches.filter((m) => m.home_key === h.uid || m.away_key === h.uid);
  const side = (m) => (m.home_key === h.uid ? "h" : "a");
  const goalRound = mine.find((m) => m.round >= 6 && events.some((e) => e.match_id === m.id && e.type === "goal" && e.team === side(m) && !e.pen && e.detail !== "og"))?.round ?? null;
  const penRound = mine.find((m) => m.round >= 3 && events.some((e) => e.match_id === m.id && e.pen && e.team === side(m)))?.round ?? null;
  const isAi = (m) => !HUMANS.some((x) => x.uid === (m.home_key === h.uid ? m.away_key : m.home_key));
  const penAiRound = mine.find((m) => m.round >= 3 && isAi(m) && events.some((e) => e.match_id === m.id && e.pen && e.team === side(m)))?.round ?? null;
  meta[h.uid] = { pos: pos[h.uid], goalRound, penRound, penAiRound };
}

// Hall of Fame (samme regler som serverens finalizeSeason, forenklet til én sæson)
const SEASON = "2026/27", nameOf = (k) => field.find((x) => x.key === k).name;
const hof_teams = HUMANS.map((h, i) => {
  const mine = matches.filter((m) => m.home_key === h.uid || m.away_key === h.uid).sort((a, b) => a.round - b.round);
  let streak = 0, best = 0, bigM = 0, bigScore = null, bigText = null;
  for (const m of mine) {
    const home = m.home_key === h.uid, gf = home ? m.home_goals : m.away_goals, ga = home ? m.away_goals : m.home_goals;
    if (gf > ga) { streak++; best = Math.max(best, streak); if (gf - ga > bigM) { bigM = gf - ga; bigScore = gf + "–" + ga; bigText = "vs " + nameOf(home ? m.away_key : m.home_key); } } else streak = 0;
  }
  const s = t[h.uid], champ = pos[h.uid] === 1;
  const lineup = champ ? field.find((x) => x.key === h.uid).xi.map((x) => ({ n: x.p.name, s: x.p.short_name || "" })) : null;
  return { id: 70001 + i, game_id: GID, team_key: h.uid, league: "PL", season: SEASON, season_no: 1, user_id: h.uid, team_name: h.team, owner: h.display, players: 4, pos: pos[h.uid], points: s.w * 3 + s.d, w: s.w, d: s.d, l: s.l, gf: s.gf, ga: s.ga, win_streak: best, big_win_margin: bigM, big_win_score: bigScore, big_win_text: bigText, champion: champ, created_at: "2026-11-01T12:00:00Z", formation: champ ? h.form : null, lineup, respins: 0 };
});
const own = {};
field.filter((x) => x.kind === "human").forEach((tm) => tm.xi.forEach((x) => (own[x.p.id] = tm)));
const mById = new Map(matches.map((m) => [m.id, m])), stats = {}, pm = {};
const ens = (pid) => (stats[pid] = stats[pid] || { goals: 0, assists: 0, cs: 0, reds: 0, yellows: 0 });
const evTeam = (e) => { const m = mById.get(e.match_id); return e.team === "h" ? m.home_key : m.away_key; };
const mineEv = (e, pid) => !!pid && !!own[pid] && evTeam(e) === own[pid].key;
for (const e of events) {
  if (e.type === "goal" && e.detail !== "og" && mineEv(e, e.player_id)) { ens(e.player_id).goals++; const k = e.match_id + "|" + e.player_id; pm[k] = (pm[k] || 0) + 1; }
  if (e.type === "goal" && e.detail !== "og" && e.assist_id && mineEv(e, e.assist_id)) ens(e.assist_id).assists++;
  if (e.type === "clean_sheet" && mineEv(e, e.player_id)) ens(e.player_id).cs++;
  if ((e.type === "red" || e.type === "second_yellow") && mineEv(e, e.player_id)) ens(e.player_id).reds++;
  if (e.type === "yellow" && mineEv(e, e.player_id)) ens(e.player_id).yellows++;
}
const bm = {};
for (const k of Object.keys(pm)) {
  const [m0, pid] = k.split("|"), m = mById.get(Number(m0)), tm = own[pid];
  if (!bm[pid] || pm[k] > bm[pid].n) bm[pid] = { n: pm[k], text: "vs " + nameOf(m.home_key === tm.key ? m.away_key : m.home_key) };
}
let hid = 80001;
const hof_players = Object.keys(stats).map((pid) => {
  const tm = own[pid], s = stats[pid], h = HUMANS.find((x) => x.uid === tm.key);
  return { id: hid++, game_id: GID, player_id: Number(pid), league: "PL", season: SEASON, season_no: 1, user_id: tm.key, team_name: tm.name, owner: h.display, goals: s.goals, assists: s.assists, clean_sheets: s.cs, reds: s.reds, yellows: s.yellows, best_match_goals: bm[pid] ? bm[pid].n : 0, best_match_text: bm[pid] ? bm[pid].text : null, created_at: "2026-11-01T12:00:00Z", respins: 0 };
});

const fx = {
  note: "Opdigtede demodata til index.html?demo=... Genereres af scripts/demo_fixtures.ts. Ret ikke i hånden.",
  engine: E.ENGINE_VERSION, seedNo, gid: GID, code: "DEMO42",
  humans: HUMANS.map((h) => ({ uid: h.uid, team: h.team, tag: h.tag, display: h.display, c1: h.c1, c2: h.c2, crest: h.crest, form: h.form, ...meta[h.uid] })),
  order,
  players: PLAYERS.map(({ cstr, consistency, pen_rank, yellow_w, red_w, ...p }) => p),
  picks: picks.map(({ club, ...p }) => ({ ...p, picked_at: "2026-11-01T12:00:00Z" })),
  pickClubs: picks.map((p) => p.club),
  season_teams: field.map((x) => ({ game_id: GID, team_key: x.key, kind: x.kind, user_id: x.user_id ?? null, club: x.club ?? null, name: x.name, color1: x.color1 ?? null, color2: x.color2 ?? null, crest: x.crest ?? null, formation: x.formation })),
  season_lineups: field.flatMap((x) => x.xi.map((s, i) => ({ game_id: GID, team_key: x.key, slot: i + 1, player_id: s.p.id }))),
  matches, events, hof_teams, hof_players,
};
await Deno.mkdir(new URL("../demo/", import.meta.url), { recursive: true });
await Deno.writeTextFile(OUT, JSON.stringify(fx));
console.log(`demo/fixtures.json: sæson ${seedNo}, ${matches.length} kampe, ${events.length} hændelser`);
for (const h of fx.humans) console.log(`  ${h.team}: plads ${h.pos}, mål i runde ${h.goalRound}, straffe i runde ${h.penRound} (mod AI: ${h.penAiRound})`);
