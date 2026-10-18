// @ts-nocheck
// Serverfunktion "engine": starter sæsonen, spiller runder og kører hurtigt spil. Kører med service role, så den kan læse det hemmelige held.
import { createClient } from "npm:@supabase/supabase-js@2";
import * as E from "./engine.js";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (o, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
class Fejl extends Error {}
const chk = (r) => { if (r.error) throw new Error(r.error.message); return r.data; };

async function loadPlayers() {
  const rows = chk(await admin.from("players").select("id,club,name,pos,rating,alts,consistency,pen_taking,yellow_w,red_w").limit(2000));
  const byId = new Map(rows.map((p) => [p.id, p]));
  return { rows, byId };
}

async function chunked(table, rows, size = 400) {
  for (let i = 0; i < rows.length; i += size) chk(await admin.from(table).insert(rows.slice(i, i + size)));
}

// ---------- start sæsonen ----------
async function initSeason(game) {
  if (game.status !== "season") throw new Fejl("Draften er ikke færdig");
  const existing = chk(await admin.from("season_secret").select("game_id").eq("game_id", game.id));
  if (existing.length) return { already: true };

  const { rows: allPlayers, byId } = await loadPlayers();
  const gps = chk(await admin.from("game_players").select("*").eq("game_id", game.id));
  const picks = chk(await admin.from("draft_picks").select("*").eq("game_id", game.id));

  const teams = [];
  for (const gp of gps) {
    const xi = new Array(11);
    for (const pk of picks.filter((x) => x.user_id === gp.user_id)) {
      const pos = E.FORMS[gp.formation][pk.slot - 1], p = byId.get(pk.player_id);
      xi[pk.slot - 1] = { pos, p, f: E.fac(p, pos) ?? 0.6 };
    }
    if (xi.some((x) => !x)) throw new Fejl("Et hold er ikke komplet");
    teams.push({ key: gp.user_id, kind: "human", user_id: gp.user_id, name: gp.team_name, color1: gp.color1, color2: gp.color2, crest: gp.crest, formation: gp.formation, xi, strength: E.xiStrength(xi) });
  }
  const clubs = chk(await admin.from("clubs").select("code,name"));
  const ai = [];
  for (const c of clubs) {
    const pool = allPlayers.filter((p) => p.club === c.code), b = E.bestClubXI(pool);
    if (b) ai.push({ key: c.code, kind: "ai", club: c.code, name: c.name, formation: b.form, xi: b.xi, strength: b.strength });
  }
  ai.sort((a, b) => a.strength - b.strength);
  const field = ai.slice(teams.length).concat(teams); // de svageste AI-klubber fjernes, 1 pr. spiller
  const seed = crypto.randomUUID() + crypto.randomUUID();
  const { luck, dark, unlucky } = E.setupSeason(field.map((t) => ({ key: t.key, kind: t.kind, strength: t.strength })), seed);

  // først den hemmelige række: den der lykkes, vinder racet
  const ins = await admin.from("season_secret").insert({ game_id: game.id, seed, luck, dark, unlucky });
  if (ins.error) { if (ins.error.code === "23505") return { already: true }; throw new Error(ins.error.message); }

  const rng = E.makeRng(seed + "|order");
  const order = field.map((t) => ({ t, k: rng.next() })).sort((a, b) => a.k - b.k).map((x) => x.t);
  await chunked("season_teams", field.map((t) => ({ game_id: game.id, team_key: t.key, kind: t.kind, user_id: t.user_id ?? null, club: t.club ?? null, name: t.name, color1: t.color1 ?? null, color2: t.color2 ?? null, crest: t.crest ?? null, formation: t.formation })));
  await chunked("season_lineups", field.flatMap((t) => t.xi.map((x, i) => ({ game_id: game.id, team_key: t.key, slot: i + 1, player_id: x.p.id }))));
  const sched = E.schedule(order.length), mrows = [];
  sched.forEach((rd, ri) => rd.forEach(([h, a]) => mrows.push({ game_id: game.id, round: ri + 1, home_key: order[h].key, away_key: order[a].key })));
  await chunked("matches", mrows);
  return { already: false };
}

// ---------- spil runder ----------
async function loadCtx(gameId) {
  const { byId } = await loadPlayers();
  const secret = chk(await admin.from("season_secret").select("*").eq("game_id", gameId))[0];
  if (!secret) throw new Fejl("Sæsonen er ikke startet");
  const st = chk(await admin.from("season_teams").select("*").eq("game_id", gameId));
  const lu = chk(await admin.from("season_lineups").select("*").eq("game_id", gameId));
  const teams = {};
  for (const t of st) teams[t.team_key] = { kind: t.kind, xi: new Array(11) };
  for (const l of lu) {
    const t = teams[l.team_key], pos = E.FORMS[st.find((x) => x.team_key === l.team_key).formation][l.slot - 1], p = byId.get(l.player_id);
    t.xi[l.slot - 1] = { pos, p, f: E.fac(p, pos) ?? 0.6 };
  }
  return { secret, teams };
}

async function playRound(gameId, ctx, round) {
  const ms = chk(await admin.from("matches").select("*").eq("game_id", gameId).eq("round", round).eq("played", false));
  const upd = [], evs = [];
  for (const m of ms) {
    const th = ctx.teams[m.home_key], ta = ctx.teams[m.away_key];
    const lh = ctx.secret.luck[m.home_key], la = ctx.secret.luck[m.away_key];
    const res = E.simulateMatch({ xi: th.xi, shift: lh.season + lh.form[round - 1] }, { xi: ta.xi, shift: la.season + la.form[round - 1] }, `${ctx.secret.seed}|${round}|${m.home_key}`);
    upd.push({ id: m.id, game_id: gameId, round, home_key: m.home_key, away_key: m.away_key, home_goals: res.hg, away_goals: res.ag, played: true });
    if (th.kind === "human" || ta.kind === "human") {
      for (const e of res.events) {
        evs.push({ game_id: gameId, match_id: m.id, minute: e.m, type: e.type, team: e.s, player_id: e.pid ?? null, assist_id: e.aid ?? null, pen: !!e.pen, detail: e.detail ?? null });
      }
    }
  }
  for (let i = 0; i < upd.length; i += 200) chk(await admin.from("matches").upsert(upd.slice(i, i + 200), { onConflict: "id" }));
  await chunked("match_events", evs);
}

async function setRound(gameId, from, to, done) {
  const patch = { current_round: to };
  if (done) patch.status = "done";
  const r = await admin.from("games").update(patch).eq("id", gameId).eq("current_round", from).select("id");
  if (r.error) throw new Error(r.error.message);
  return r.data.length > 0;
}

async function runTo(game, target) {
  const ctx = await loadCtx(game.id);
  let r = game.current_round;
  // gør en evt. halvfærdig runde færdig (hvis en tidligere kørsel blev afbrudt)
  if (r >= 1) await playRound(game.id, ctx, r);
  while (r < target) {
    if (!(await setRound(game.id, r, r + 1, r + 1 === 38))) break; // en anden har allerede flyttet runden
    r++;
    await playRound(game.id, ctx, r);
  }
}

async function getGame(id) {
  const g = chk(await admin.from("games").select("*").eq("id", id))[0];
  if (!g) throw new Fejl("Spillet findes ikke");
  return g;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const jwt = (req.headers.get("Authorization") || "").replace("Bearer ", "");
    const { data: u } = await admin.auth.getUser(jwt);
    if (!u || !u.user) return json({ error: "Ikke logget ind" }, 401);
    const { action, game_id, force } = await req.json();
    let game = await getGame(game_id);
    const me = chk(await admin.from("game_players").select("*").eq("game_id", game_id).eq("user_id", u.user.id))[0];
    if (!me) return json({ error: "Du er ikke med i spillet" }, 403);
    const isAdmin = game.admin_id === u.user.id;

    if (action === "init") {
      const r = await initSeason(game);
      if (!r.already) {
        game = await getGame(game_id);
        await runTo(game, game.pace === "quick" ? 38 : 1);
      }
    } else if (action === "advance") {
      if (game.status !== "season") throw new Fejl("Sæsonen er ikke i gang");
      const gps = chk(await admin.from("game_players").select("user_id,ready_round").eq("game_id", game_id));
      const allReady = gps.every((g) => g.ready_round >= game.current_round);
      if (!allReady && !(force && isAdmin)) throw new Fejl("Ikke alle er klar");
      await runTo(game, game.current_round + 1);
    } else if (action === "quick") {
      if (!isAdmin) throw new Fejl("Kun admin kan køre hurtigt spil");
      await runTo(game, 38);
    } else throw new Fejl("Ukendt handling");
    game = await getGame(game_id);
    return json({ ok: true, current_round: game.current_round, status: game.status });
  } catch (e) {
    return json({ error: e.message }, e instanceof Fejl ? 400 : 500);
  }
});
