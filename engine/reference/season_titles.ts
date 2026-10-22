// usage: deno run -A season_titles.ts <antal sæsoner>  (kun AI-klubber; bruger motoren i supabase/functions/engine og spillerdata fra ../../../Arbejdsfiler/db_players.json)
// Skriver titel-% pr. klub, top 4-% og gennemsnitlige point. 2026-10-22, 3000 sæsoner: City 40 %, Arsenal 27 %, Liverpool 22 %, Chelsea 5 %.
const E = await import("file:///Users/munksgaard/Desktop/PL%20Draft/draftspin-fc/supabase/functions/engine/engine.js");
const P = JSON.parse(await Deno.readTextFile("/Users/munksgaard/Desktop/PL Draft/Arbejdsfiler/db_players.json"));
const N = +Deno.args[0] || 100;
const byClub: Record<string, any[]> = {};
P.forEach((p: any) => { (byClub[p.club] ||= []).push(p); });
const clubs = Object.keys(byClub);
const ai: any[] = [];
for (const c of clubs) { const b = E.bestClubXI(byClub[c]); if (b) ai.push({ key: c, kind: "ai", xi: b.xi, strength: b.strength }); }
ai.sort((a, b) => a.strength - b.strength);
const titles: Record<string, number> = {}, top4: Record<string, number> = {}, pts1: number[] = [], ptsL: number[] = [];
for (let s = 0; s < N; s++) {
  const seed = "sim" + s + "x" + Math.random();
  const { luck } = E.setupSeason(ai.map((t) => ({ key: t.key, kind: t.kind, strength: t.strength })), seed);
  const r = E.makeRng("o" + s);
  const order = ai.map((t) => ({ t, k: r.next() })).sort((a, b) => a.k - b.k).map((x) => x.t);
  const sched = E.schedule(order.length);
  const pts: Record<string, number> = {}, gd: Record<string, number> = {};
  order.forEach((t) => { pts[t.key] = 0; gd[t.key] = 0; });
  sched.forEach((rd: any, ri: number) => rd.forEach(([h, a]: number[]) => {
    const th = order[h], ta = order[a], lh = luck[th.key], la = luck[ta.key];
    const res = E.simulateMatch({ xi: th.xi, shift: lh.season + lh.form[ri] }, { xi: ta.xi, shift: la.season + la.form[ri] }, `${seed}|${ri + 1}|${th.key}`);
    gd[th.key] += res.hg - res.ag; gd[ta.key] += res.ag - res.hg;
    if (res.hg > res.ag) pts[th.key] += 3; else if (res.hg < res.ag) pts[ta.key] += 3; else { pts[th.key]++; pts[ta.key]++; }
  }));
  const tab = Object.keys(pts).sort((a, b) => pts[b] - pts[a] || gd[b] - gd[a]);
  titles[tab[0]] = (titles[tab[0]] || 0) + 1;
  tab.slice(0, 4).forEach((k) => top4[k] = (top4[k] || 0) + 1);
  pts1.push(pts[tab[0]]); ptsL.push(pts[tab[tab.length - 1]]);
}
console.log("engine", E.ENGINE_VERSION, "seasons", N, "clubs", ai.length);
console.log("strength rank (weak->strong):", ai.map((t) => t.key + ":" + t.strength.toFixed(1)).join(" "));
console.log("TITLES:", ai.slice().reverse().map((t) => t.key + " " + (titles[t.key]||0) + " (" + (100*(titles[t.key]||0)/N).toFixed(2) + "%)").join(", "));
console.log("TOP4 %:", Object.entries(top4).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([k, v]) => k + " " + (100 * v / N).toFixed(0) + "%").join(", "));
console.log("avg champion pts", (pts1.reduce((a, b) => a + b, 0) / N).toFixed(1), "avg last pts", (ptsL.reduce((a, b) => a + b, 0) / N).toFixed(1));
