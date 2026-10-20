// usage: deno run -A sim.ts <engine.js> <seasons> <mode: ai|human|both>
const [engPath, nS, mode] = Deno.args;
const E = await import("file://" + engPath);
const P = JSON.parse(await Deno.readTextFile("/tmp/real/players.json"));
const clubs = [...new Set(P.map((p) => p.club))];
const byClub = Object.fromEntries(clubs.map((c) => [c, P.filter((p) => p.club === c)]));
const forms = Object.keys(E.FORMS).filter((f) => !f.startsWith("L") && f !== "3-5-2");
let seedN = 0;
function rngFor(s) { return E.makeRng("rs" + s); }
function humanTeam(r, smart) {
  const form = forms[r.int(forms.length)], slots = E.FORMS[form], xi = new Array(11).fill(null), taken = new Set();
  for (let pick = 0; pick < 11; pick++) {
    const open = slots.map((s, i) => [s, i]).filter(([, i]) => !xi[i]);
    // klubber med mindst en brugbar spiller
    const cands = clubs.filter((c) => byClub[c].some((p) => !taken.has(p.id) && open.some(([s]) => E.fac(p, s) !== null)));
    const c = cands[r.int(cands.length)];
    let best = null;
    for (const p of byClub[c]) { if (taken.has(p.id)) continue; for (const [s, i] of open) { const f = E.fac(p, s); if (f === null) continue; const v = (smart ? p.rating : p.rating * 0) * f + (smart ? 0 : r.next()); if (!best || v > best.v) best = { v, p, s, i, f }; } }
    xi[best.i] = { pos: best.s, p: best.p, f: best.f }; taken.add(best.p.id);
  }
  return { form, xi };
}
function season(smart, withHuman) {
  const r = rngFor(seedN++);
  const ai = [];
  for (const c of clubs) { const b = E.bestClubXI(byClub[c]); if (b) ai.push({ key: c, kind: "ai", xi: b.xi, strength: b.strength }); }
  ai.sort((a, b) => a.strength - b.strength);
  let teams;
  if (withHuman) { const h = humanTeam(r, smart); teams = ai.slice(1).concat([{ key: "H", kind: "human", xi: h.xi, strength: E.xiStrength(h.xi) }]); } else teams = ai.slice(0);
  const seed = "s" + seedN + Math.random();
  const { luck } = E.setupSeason(teams.map((t) => ({ key: t.key, kind: t.kind, strength: t.strength })), seed);
  const order = teams.map((t) => ({ t, k: r.next() })).sort((a, b) => a.k - b.k).map((x) => x.t);
  const sched = E.schedule(order.length);
  const goals = new Map(), assists = new Map(), cs = new Map(), yel = new Map(), tp = {}, tg = {}; let total = 0, matches = 0, hats = 0, pm = 0, reds = 0, ycount = 0, big5 = 0, big4 = 0, hw = 0, dr = 0, aw = 0;
  teams.forEach((t) => { tp[t.key] = 0; tg[t.key] = 0; });
  sched.forEach((rd, ri) => rd.forEach(([h, a]) => {
    const th = order[h], ta = order[a], lh = luck[th.key], la = luck[ta.key];
    const res = E.simulateMatch({ xi: th.xi, shift: lh.season + lh.form[ri] }, { xi: ta.xi, shift: la.season + la.form[ri] }, `${seed}|${ri + 1}|${th.key}`);
    tg[th.key] += res.hg; tg[ta.key] += res.ag; total += res.hg + res.ag; matches++;
    if (res.hg > res.ag) tp[th.key] += 3; else if (res.hg < res.ag) tp[ta.key] += 3; else { tp[th.key]++; tp[ta.key]++; }
    const mg = Math.abs(res.hg - res.ag); if (mg >= 5) big5++; if (mg >= 4) big4++; if (res.hg > res.ag) hw++; else if (res.hg === res.ag) dr++; else aw++;
    for (const e of res.events) { const k = (e.s === "h" ? th.key : ta.key) + "|" + e.pid; if (e.type === "goal" && e.aid) { const ka = (e.s === "h" ? th.key : ta.key) + "|" + e.aid; assists.set(ka, (assists.get(ka) || 0) + 1); } if (e.type === "clean_sheet") cs.set(k, (cs.get(k) || 0) + 1); if (e.type === "yellow") { yel.set(k, (yel.get(k) || 0) + 1); ycount++; } if (e.type === "red" || e.type === "second_yellow") reds++; }
    const per = new Map();
    for (const e of res.events) if (e.type === "goal") { const k = (e.s === "h" ? th.key : ta.key) + "|" + e.pid; per.set(k, (per.get(k) || 0) + 1); goals.set(k, (goals.get(k) || 0) + 1); }
    for (const v of per.values()) if (v >= 3) hats++;
  }));
  const top = [...goals.entries()].sort((a, b) => b[1] - a[1]);
  const [tk, tpid] = top[0][0].split("|"), tgoals = top[0][1];
  const champ = Object.entries(tp).sort((a, b) => b[1] - a[1])[0];
  const humanGoals = withHuman ? [...goals.entries()].filter(([k]) => k.startsWith("H|")).sort((a, b) => b[1] - a[1])[0] : null;
  const maxTeamGf = Math.max(...Object.values(tg));
  const mx = (m) => Math.max(...m.values()); const bottom = Math.min(...Object.values(tp)); return { topA: mx(assists), topCs: mx(cs), topY: mx(yel), ypm: ycount / 380, reds, big5, big4, hw, dr, aw, bottom, top: tgoals, topTeam: tk, topPlayer: P.find((p) => String(p.id) === tpid)?.name, champPts: champ[1], gpm: total / matches, hats, top3: top.slice(0, 3).map((x) => x[1]), maxTeamGf, humanTop: humanGoals ? humanGoals[1] : null, humanGf: withHuman ? tg["H"] : null, humanPts: withHuman ? tp["H"] : null, n30: top.filter((x) => x[1] >= 30).length };
}
function q(a, p) { const s = [...a].sort((x, y) => x - y); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; }
const N = +nS;
for (const [label, withHuman, smart] of [["AI-liga uden spillerhold", false, false], ["liga + SMART drafter (altid bedste spiller)", true, true]]) {
  if (mode === "ai" && withHuman) continue; if (mode === "human" && !withHuman) continue;
  const rs = []; for (let i = 0; i < N; i++) rs.push(season(smart, withHuman));
  const f = (k) => rs.map((r) => r[k]);
  const m = (a) => (a.reduce((x, y) => x + y, 0) / a.length);
  console.log(`\n== ${label} (${N} sæsoner)`);
  console.log(`topscorer mål: gns ${m(f("top")).toFixed(1)} | p10 ${q(f("top"), .1)} p50 ${q(f("top"), .5)} p90 ${q(f("top"), .9)} max ${Math.max(...f("top"))} | >=30: ${(100 * rs.filter((r) => r.top >= 30).length / N).toFixed(0)}% af sæsoner, >=40: ${(100 * rs.filter((r) => r.top >= 40).length / N).toFixed(0)}%, >=50: ${(100 * rs.filter((r) => r.top >= 50).length / N).toFixed(0)}%`);
  console.log(`mester point gns ${m(f("champPts")).toFixed(0)} (p90 ${q(f("champPts"), .9)}) | højeste holdmål gns ${m(f("maxTeamGf")).toFixed(0)} (max ${Math.max(...f("maxTeamGf"))}) | mål/kamp ${m(f("gpm")).toFixed(2)} | hattricks/sæson ${m(f("hats")).toFixed(1)}`);
  if (withHuman) console.log(`spillerhold: point gns ${m(f("humanPts")).toFixed(0)}, mål gns ${m(f("humanGf")).toFixed(0)} (max ${Math.max(...f("humanGf"))}) | bedste egne målscorer gns ${m(f("humanTop")).toFixed(1)} p90 ${q(f("humanTop"), .9)} max ${Math.max(...f("humanTop"))}`);
  console.log(`assists topscorer gns ${m(f("topA")).toFixed(1)} (max ${Math.max(...f("topA"))}) | clean sheets bedste målmand gns ${m(f("topCs")).toFixed(1)} | gule/kamp ${m(f("ypm")).toFixed(2)} | gule bedste ${m(f("topY")).toFixed(1)} | røde/sæson ${m(f("reds")).toFixed(1)} | dårligste hold point ${m(f("bottom")).toFixed(0)} | kampe >=4 mål forskel ${(100*m(f("big4"))/380).toFixed(1)}%, >=5: ${(100*m(f("big5"))/380).toFixed(1)}% | H/U/B ${(100*m(f("hw"))/380).toFixed(0)}/${(100*m(f("dr"))/380).toFixed(0)}/${(100*m(f("aw"))/380).toFixed(0)}`);
  const worst = rs.sort((a, b) => b.top - a.top)[0]; console.log(`største topscorer: ${worst.top} (${worst.topPlayer}, ${worst.topTeam})`);
}
