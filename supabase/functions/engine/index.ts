// @ts-nocheck
// Serverfunktion "engine": starter sæsonen, spiller runder og kører hurtigt spil. Kører med service role, så den kan læse det hemmelige held.
import { createClient } from "npm:@supabase/supabase-js@2";
import * as E from "./engine.js";

const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!, { auth: { persistSession: false } });
const CORS = { "Access-Control-Allow-Origin": "*", "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type", "Access-Control-Allow-Methods": "POST, OPTIONS" };
const json = (o, s = 200) => new Response(JSON.stringify(o), { status: s, headers: { ...CORS, "Content-Type": "application/json" } });
class Fejl extends Error {}
// hurtigt spil: første halvdel (19 runder) simuleres før klienten starter afspilningen, resten kører bagefter ("finish")
const QUICK_FIRST = 19;
const chk = (r) => { if (r.error) throw new Error(r.error.message); return r.data; };

async function loadPlayers() {
  const rows = chk(await admin.from("players").select("id,club,name,pos,rating,alts,consistency,pen_taking,yellow_w,red_w").limit(2000));
  const byId = new Map(rows.map((p) => [p.id, p]));
  return { rows, byId };
}

async function chunked(table, rows, size = 400) {
  for (let i = 0; i < rows.length; i += size) chk(await admin.from(table).insert(rows.slice(i, i + size)));
}
// hændelser: dubletter ignoreres (unik nøgle), så samtidige kørsler ikke kan skabe dobbelte hændelser
async function chunkedEvents(rows, size = 400) {
  for (let i = 0; i < rows.length; i += size) chk(await admin.from("match_events").upsert(rows.slice(i, i + size), { onConflict: "match_id,minute,type,team,player_id,pen", ignoreDuplicates: true }));
}

// ---------- start sæsonen ----------
async function initSeason(game) {
  if (game.status !== "season") throw new Fejl("The draft isn't finished");
  const existing = chk(await admin.from("season_secret").select("*").eq("game_id", game.id));
  let heal = null; // afbrudt start: byg videre med samme hemmelighed
  if (existing.length) {
    const mc = chk(await admin.from("matches").select("id").eq("game_id", game.id).limit(1));
    if (mc.length || Date.now() - new Date(existing[0].created_at).getTime() < 60000) return { already: true };
    heal = existing[0];
    chk(await admin.from("season_lineups").delete().eq("game_id", game.id).select("game_id"));
    chk(await admin.from("season_teams").delete().eq("game_id", game.id).select("game_id"));
  }

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
    if (xi.some((x) => !x)) throw new Fejl("A team isn't complete");
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
  const seed = heal ? heal.seed : crypto.randomUUID() + crypto.randomUUID();
  const { luck, dark, unlucky } = heal ? heal : E.setupSeason(field.map((t) => ({ key: t.key, kind: t.kind, strength: t.strength })), seed);

  // først den hemmelige række: den der lykkes, vinder racet
  if (!heal) {
    const ins = await admin.from("season_secret").insert({ game_id: game.id, seed, luck, dark, unlucky, engine_version: E.ENGINE_VERSION });
    if (ins.error) { if (ins.error.code === "23505") return { already: true }; throw new Error(ins.error.message); }
  }

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
  if (!secret) throw new Fejl("The season hasn't started");
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
  const all = chk(await admin.from("matches").select("*").eq("game_id", gameId).eq("round", round));
  // kun kampe der ikke er spillet, eller en menneskekamp uden hændelser (afbrudt kørsel). Færdige kampe røres aldrig, så et spillet resultat ikke kan ændre sig.
  const withEv = new Set(all.length ? chk(await admin.from("match_events").select("match_id").in("match_id", all.map((m) => m.id))).map((e) => e.match_id) : []);
  const ms = all.filter((m) => !m.played || ((ctx.teams[m.home_key].kind === "human" || ctx.teams[m.away_key].kind === "human") && !withEv.has(m.id)));
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
  await chunkedEvents(evs); // hændelser først, så en kamp aldrig står som spillet uden dem
  for (let i = 0; i < upd.length; i += 200) chk(await admin.from("matches").upsert(upd.slice(i, i + 200), { onConflict: "id" }));
}

async function setRound(gameId, from, to, done) {
  const patch = { current_round: to };
  if (done) patch.status = "done";
  const r = await admin.from("games").update(patch).eq("id", gameId).eq("current_round", from).select("id");
  if (r.error) throw new Error(r.error.message);
  return r.data.length > 0;
}

async function runTo(game, target) {
  target = Math.min(target, 38);
  const ctx = await loadCtx(game.id);
  let r = game.current_round;
  // gør en evt. halvfærdig runde færdig (hvis en tidligere kørsel blev afbrudt)
  if (r >= 1) await playRound(game.id, ctx, r);
  while (r < target) {
    if (!(await setRound(game.id, r, r + 1, false))) break; // en anden har allerede flyttet runden
    r++;
    await playRound(game.id, ctx, r);
    if (r === 38) { await finalizeSeason(game.id); chk(await admin.from("games").update({ status: "done" }).eq("id", game.id).select("id")); }
  }
  // selvhelende afslutning: runde 38 er spillet, men en tidligere kørsel nåede ikke at gemme rekorder og sætte status
  if (r >= 38) {
    const g2 = await getGame(game.id);
    if (g2.status !== "done") { await finalizeSeason(game.id); chk(await admin.from("games").update({ status: "done" }).eq("id", game.id).select("id")); }
  }
}


// ---------- Highscore: gem rekorder, når sæsonen er slut ----------
async function allRows(table, gameId) {
  let rows = [];
  for (let from = 0; ; from += 1000) {
    const d = chk(await admin.from(table).select("*").eq("game_id", gameId).order("id").range(from, from + 999));
    rows = rows.concat(d);
    if (d.length < 1000) break;
  }
  return rows;
}
async function finalizeSeason(gameId) {
  const game = await getGame(gameId);
  const st = chk(await admin.from("season_teams").select("*").eq("game_id", gameId));
  const gps = chk(await admin.from("game_players").select("user_id,display_name,missed_rounds").eq("game_id", gameId));
  const lu = chk(await admin.from("season_lineups").select("*").eq("game_id", gameId));
  const matches = await allRows("matches", gameId), events = await allRows("match_events", gameId);
  const nameOf = (k) => (st.find((x) => x.team_key === k) || {}).name || k;
  // modstanderen i rekordteksterne (også AI-hold, som Rasmus ønsker 2026-10-19)
  const vs = (k) => "vs " + ((st.find((y) => y.team_key === k) || {}).name || k);
  const t = {};
  st.forEach((x) => (t[x.team_key] = { w: 0, d: 0, l: 0, gf: 0, ga: 0 }));
  for (const m of matches) {
    if (!m.played) continue;
    const h = t[m.home_key], a = t[m.away_key];
    h.gf += m.home_goals; h.ga += m.away_goals; a.gf += m.away_goals; a.ga += m.home_goals;
    if (m.home_goals > m.away_goals) { h.w++; a.l++; } else if (m.home_goals < m.away_goals) { a.w++; h.l++; } else { h.d++; a.d++; }
  }
  const order = Object.keys(t).map((k) => ({ k, p: t[k].w * 3 + t[k].d, gd: t[k].gf - t[k].ga, gf: t[k].gf })).sort((a, b) => b.p - a.p || b.gd - a.gd || b.gf - a.gf);
  const pos = {};
  order.forEach((x, i) => (pos[x.k] = i + 1));
  // hold, der var væk i for mange runder, udgår af Highscore (sæsonen er stadig spillet færdig)
  const MAX_MISSED = 8;
  const humans = st.filter((x) => x.kind === "human" && ((gps.find((g) => g.user_id === x.user_id) || {}).missed_rounds || 0) < MAX_MISSED);
  const owner = (uid) => (gps.find((g) => g.user_id === uid) || {}).display_name || null;
  const season = String(game.season).replace(/^(\d{4})\/\d{2}(\d{2})$/, "$1/$2");
  // mesterholdets opstilling gemmes med rekorden, så Hall of Fame kan vise holdet
  const champ = humans.find((h) => pos[h.team_key] === 1);
  let champLineup = null;
  if (champ) {
    const slots = lu.filter((l) => l.team_key === champ.team_key).sort((a, b) => a.slot - b.slot);
    const pl = chk(await admin.from("players").select("id,name,short_name").in("id", slots.map((l) => l.player_id)));
    champLineup = slots.map((l) => { const p = pl.find((x) => x.id === l.player_id); return p ? { n: p.name, s: p.short_name || "" } : null; });
  }
  const teamRows = humans.map((h) => {
    const mine = matches.filter((m) => m.played && (m.home_key === h.team_key || m.away_key === h.team_key)).sort((a, b) => a.round - b.round);
    let streak = 0, best = 0, bigM = 0, bigScore = null, bigText = null;
    for (const m of mine) {
      const home = m.home_key === h.team_key, gf = home ? m.home_goals : m.away_goals, ga = home ? m.away_goals : m.home_goals;
      if (gf > ga) { streak++; best = Math.max(best, streak); if (gf - ga > bigM) { bigM = gf - ga; bigScore = gf + "–" + ga; bigText = vs(home ? m.away_key : m.home_key); } }
      else streak = 0;
    }
    const s = t[h.team_key];
    return { game_id: gameId, team_key: h.team_key, league: "PL", season, season_no: game.season_no, user_id: h.user_id, team_name: h.name, owner: owner(h.user_id), players: humans.length, pos: pos[h.team_key], points: s.w * 3 + s.d, w: s.w, d: s.d, l: s.l, gf: s.gf, ga: s.ga, win_streak: best, big_win_margin: bigM, big_win_score: bigScore, big_win_text: bigText, champion: pos[h.team_key] === 1, formation: champ && champ.team_key === h.team_key ? h.formation : null, lineup: champ && champ.team_key === h.team_key ? champLineup : null };
  });
  const own = {};
  lu.forEach((l) => { const tm = humans.find((x) => x.team_key === l.team_key); if (tm) own[l.player_id] = tm; });
  const stats = {}, pm = {}, mById = new Map(matches.map((m) => [m.id, m]));
  const ens = (pid) => (stats[pid] = stats[pid] || { goals: 0, assists: 0, cs: 0, reds: 0, yellows: 0 });
  // en spiller kan stå på både et menneskehold og en AI-klub: tæl kun hændelser for det hold, der ejer ham
  const evTeam = (e) => { const m = mById.get(e.match_id); return m ? (e.team === "h" ? m.home_key : m.away_key) : null; };
  const mineEv = (e, pid) => !!pid && !!own[pid] && evTeam(e) === own[pid].team_key;
  for (const e of events) {
    if (e.type === "goal" && mineEv(e, e.player_id)) { ens(e.player_id).goals++; const k = e.match_id + "|" + e.player_id; pm[k] = (pm[k] || 0) + 1; }
    if (e.type === "goal" && e.assist_id && mineEv(e, e.assist_id)) ens(e.assist_id).assists++;
    if (e.type === "clean_sheet" && mineEv(e, e.player_id)) ens(e.player_id).cs++;
    if ((e.type === "red" || e.type === "second_yellow") && mineEv(e, e.player_id)) ens(e.player_id).reds++;
    if (e.type === "yellow" && mineEv(e, e.player_id)) ens(e.player_id).yellows++;
  }
  const bm = {};
  for (const k of Object.keys(pm)) {
    const [mid, pid] = k.split("|"), m = mById.get(Number(mid)), tm = own[pid];
    if (!m || !tm) continue;
    if (!bm[pid] || pm[k] > bm[pid].n) bm[pid] = { n: pm[k], text: vs(m.home_key === tm.team_key ? m.away_key : m.home_key) };
  }
  const playerRows = Object.keys(stats).map((pid) => {
    const tm = own[pid], s = stats[pid];
    return { game_id: gameId, player_id: Number(pid), league: "PL", season, season_no: game.season_no, user_id: tm.user_id, team_name: tm.name, owner: owner(tm.user_id), goals: s.goals, assists: s.assists, clean_sheets: s.cs, reds: s.reds, yellows: s.yellows, best_match_goals: bm[pid] ? bm[pid].n : 0, best_match_text: bm[pid] ? bm[pid].text : null };
  });
  if (teamRows.length) chk(await admin.from("hof_teams").upsert(teamRows, { onConflict: "game_id,team_key" }));
  if (playerRows.length) chk(await admin.from("hof_players").upsert(playerRows, { onConflict: "game_id,player_id" }));
}

async function getGame(id) {
  const g = chk(await admin.from("games").select("*").eq("id", id))[0];
  if (!g) throw new Fejl("The game doesn't exist");
  return g;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS });
  try {
    const jwt = (req.headers.get("Authorization") || "").replace("Bearer ", "");
    const { data: u } = await admin.auth.getUser(jwt);
    if (!u || !u.user) return json({ error: "Not signed in" }, 401);
    const { action, game_id, force } = await req.json();
    if (action === "hash") {
      // kontrol af at den udgivne motor er identisk med filen i repoet: fingeraftryk af eksporterne + en fast testkamp
      const sha = async (t) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t)))].map((b) => b.toString(16).padStart(2, "0")).join("");
      const parts = [E.ENGINE_VERSION, E.K, E.MU_H, E.MU_A, E.PEN_FACTOR, JSON.stringify(E.FORMS), JSON.stringify(E.AI_FORMS), E.makeRng.toString(), E.fac.toString(), E.bestXI.toString(), E.xiStrength.toString(), E.bestClubXI.toString(), E.schedule.toString(), E.setupSeason.toString(), E.simulateMatch.toString()].join("\n");
      const mk = (o) => E.FORMS["4-4-2"].map((pos, i) => ({ pos, p: { id: o + i, rating: 140 + ((i * 7 + o) % 23), consistency: 8 + (i % 9), pen_taking: 6 + (i % 12), yellow_w: 0.9, red_w: 1 }, f: 1 }));
      const sims = [];
      for (let k = 0; k < 40; k++) { const r = E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 1 }, "selftest|" + k); sims.push(r.hg + "-" + r.ag + ":" + r.events.map((e) => e.m + e.type + e.s + (e.pid ?? "")).join(",")); }
      return json({ ok: true, fingerprint: await sha(parts), simulation: await sha(sims.join("|")) });
    }
    let game = await getGame(game_id);
    const me = chk(await admin.from("game_players").select("*").eq("game_id", game_id).eq("user_id", u.user.id))[0];
    if (!me) return json({ error: "You're not in the game" }, 403);
    const isAdmin = game.admin_id === u.user.id;

    if (action === "init") {
      const r = await initSeason(game);
      if (!r.already) {
        game = await getGame(game_id);
        await runTo(game, game.pace === "quick" ? QUICK_FIRST : 1);
      }
    } else if (action === "advance") {
      if (game.status !== "season") throw new Fejl("The season isn't in progress");
      const gps = chk(await admin.from("game_players").select("user_id,ready_round,last_seen_at").eq("game_id", game_id));
      // en spiller, der ikke er set i 90 sekunder, regnes som klar (reglen om fraværende spillere)
      const allReady = gps.every((g) => g.ready_round >= game.current_round || Date.now() - Date.parse(g.last_seen_at) > 90000);
      if (!allReady && !(force && isAdmin)) throw new Fejl("Not everyone is ready");
      // spillere, der ikke var klar og blev sprunget over, tæller som "væk" i runden (idempotent pr. runde)
      const absent = gps.filter((g) => g.ready_round < game.current_round && Date.now() - Date.parse(g.last_seen_at) > 90000).map((g) => g.user_id);
      if (absent.length) chk(await admin.rpc("bump_missed", { p_game: game_id, p_round: game.current_round, p_users: absent }));
      await runTo(game, game.current_round + 1);
    } else if (action === "finish") {
      // alle i spillet må bede om resten af et hurtigt spil; kørslen er idempotent (runden flyttes kun af én ad gangen)
      if (game.pace !== "quick") throw new Fejl("Quick games only");
      if (game.status !== "season") throw new Fejl("The season isn't in progress");
      await runTo(game, 38);
    } else if (action === "quick") {
      if (!isAdmin) throw new Fejl("Only the admin can run a quick game");
      if (game.status !== "season") throw new Fejl("The season isn't in progress");
      await runTo(game, 38);
    } else throw new Fejl("Unknown action");
    game = await getGame(game_id);
    return json({ ok: true, current_round: game.current_round, status: game.status, engine_version: E.ENGINE_VERSION });
  } catch (e) {
    return json({ error: e.message }, e instanceof Fejl ? 400 : 500);
  }
});
