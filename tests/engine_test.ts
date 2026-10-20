// Automatiske tests af kampmotoren. Kør: deno test tests/
// @ts-nocheck
import * as E from "../supabase/functions/engine/engine.js";

const eq = (a: unknown, b: unknown, msg = "") => { if (a !== b) throw new Error(`${msg} forventede ${b}, fik ${a}`); };
const ok = (c: boolean, msg: string) => { if (!c) throw new Error(msg); };
const sha = async (t: string) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t)))].map((b) => b.toString(16).padStart(2, "0")).join("");
const mk = (o: number, form = "4-4-2") => E.FORMS[form].map((pos: string, i: number) => ({ pos, p: { id: o + i, rating: 140 + ((i * 7 + o) % 23), consistency: 8 + (i % 9), pen_taking: 6 + (i % 12), yellow_w: 0.9, red_w: 1 }, f: 1 }));

Deno.test("motoren er identisk med den udgivne (fingeraftryk + 40 faste kampe)", async () => {
  const parts = [E.ENGINE_VERSION, E.K, E.MU_H, E.MU_A, E.PEN_FACTOR, JSON.stringify(E.FORMS), JSON.stringify(E.AI_FORMS), E.makeRng.toString(), E.fac.toString(), E.bestXI.toString(), E.xiStrength.toString(), E.bestClubXI.toString(), E.schedule.toString(), E.setupSeason.toString(), E.simulateMatch.toString()].join("\n");
  const sims: string[] = [];
  for (let k = 0; k < 40; k++) { const r = E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 1 }, "selftest|" + k); sims.push(r.hg + "-" + r.ag + ":" + r.events.map((e: any) => e.m + e.type + e.s + (e.pid ?? "")).join(",")); }
  // Værdierne er målt på den udgivne edge function (version 1.8). Ændres motoren med vilje, opdateres de her og i SPEC.md.
  eq(await sha(parts), "671aae4f2d30b173448ddf372a15a1aad8a43f15fca80c519ca352ccc8865df2", "fingeraftryk");
  eq(await sha(sims.join("|")), "d554cacc790c730737a69a2ea6f007941184efaa4b02f6098e095de3d15cb9d0", "simulering");
});

Deno.test("samme seed giver samme kamp, forskellig seed giver forskellig", () => {
  const a = E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 0 }, "x"), b = E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 0 }, "x");
  eq(JSON.stringify(a), JSON.stringify(b), "determinisme");
  const diff = [...Array(20).keys()].some((i) => JSON.stringify(E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 0 }, "y" + i)) !== JSON.stringify(a));
  ok(diff, "forskellige seeds gav ens kampe");
});

Deno.test("alle formationer har 11 pladser, én målmand og kun kendte positioner", () => {
  const known = ["GK", "CB", "LB", "RB", "LWB", "RWB", "DM", "CM", "AM", "LM", "RM", "LW", "RW", "ST"];
  for (const [name, slots] of Object.entries(E.FORMS) as [string, string[]][]) {
    eq(slots.length, 11, name);
    eq(slots.filter((s) => s === "GK").length, 1, name + " målmænd");
    ok(slots.every((s) => known.includes(s)), name + " ukendt position");
  }
  ok(E.AI_FORMS.every((f: string) => f in E.FORMS), "AI-formation findes ikke");
});

Deno.test("programmet: 20 hold, 38 runder, alle spiller alle to gange, 19 hjemme og 19 ude", () => {
  const s = E.schedule(20);
  eq(s.length, 38, "runder");
  const home: Record<number, number> = {}, pairs = new Set<string>();
  for (const rd of s) {
    const seen = new Set<number>();
    for (const [h, a] of rd) { ok(!seen.has(h) && !seen.has(a), "hold to gange i samme runde"); seen.add(h); seen.add(a); home[h] = (home[h] || 0) + 1; pairs.add(h + ">" + a); }
    eq(seen.size, 20, "alle spiller hver runde");
  }
  eq(pairs.size, 380, "alle kombinationer (hjemme og ude)");
  ok(Object.values(home).every((n) => n === 19), "19 hjemmekampe pr. hold");
});

Deno.test("kamphændelser stemmer med resultatet", () => {
  for (let k = 0; k < 200; k++) {
    const r = E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 0 }, "inv|" + k);
    eq(r.events.filter((e: any) => e.type === "goal" && e.s === "h").length, r.hg, "hjemmemål");
    eq(r.events.filter((e: any) => e.type === "goal" && e.s === "a").length, r.ag, "udemål");
    ok(r.events.every((e: any) => e.m >= 1 && e.m <= 94), "minut udenfor 1-94");
    const reds = r.events.filter((e: any) => e.type === "red" || e.type === "second_yellow");
    ok(new Set(reds.map((e: any) => e.s + e.pid)).size === reds.length, "samme spiller udvist to gange");
    for (const e of r.events.filter((e: any) => e.type === "goal" && e.aid != null)) ok(e.aid !== e.pid, "assist til sig selv");
    eq(r.events.some((e: any) => e.type === "clean_sheet" && e.s === "h"), r.ag === 0, "clean sheet hjemme");
    eq(r.events.some((e: any) => e.type === "clean_sheet" && e.s === "a"), r.hg === 0, "clean sheet ude");
  }
});

Deno.test("positionsregler: naturlig plads 1, nabo 0,9, ellers ikke tilladt", () => {
  const p = (pos: string, alts: unknown = undefined) => ({ pos, alts });
  eq(E.fac(p("ST"), "ST"), 1);
  eq(E.fac(p("ST"), "LW"), E.PEN_FACTOR);
  eq(E.fac(p("GK"), "ST"), null);
  eq(E.fac(p("CB"), "ST"), null);
  eq(E.fac(p("LW"), "LM"), 1, "LW kan spille LM naturligt");
  eq(E.fac(p("CM", { AM: { nat: true } }), "AM"), 1, "2. naturlig position");
});

Deno.test("sæsonopsætning: 38 form-værdier pr. hold, deterministisk, mørk hest er AI", () => {
  const teams = [...Array(20).keys()].map((i) => ({ key: "t" + i, kind: i < 2 ? "human" : "ai", strength: 100 + i }));
  const a = E.setupSeason(teams, "seed1"), b = E.setupSeason(teams, "seed1");
  eq(JSON.stringify(a), JSON.stringify(b), "determinisme");
  ok(Object.values(a.luck).every((l: any) => l.form.length === 38), "38 runder");
  ok(a.dark == null || !["t0", "t1"].includes(a.dark), "mørk hest må ikke være et menneskehold");
  ok(a.unlucky == null || !["t0", "t1"].includes(a.unlucky), "uheld må ikke ramme et menneskehold");
});

Deno.test("realisme: topscorer, hattricks og kort ligger i et rimeligt område", () => {
  // 20 hold med spredte ratings; 5 sæsoner. Ikke et præcist krav, kun en alarm hvis motoren ryger helt skævt.
  const teams = [...Array(20).keys()].map((i) => mk(i * 13, ["4-4-2", "4-3-3", "4-2-3-1"][i % 3]));
  const sched = E.schedule(20);
  let goals = 0, matches = 0, yellows = 0, reds = 0, topSum = 0;
  for (let s = 0; s < 5; s++) {
    const scorers: Record<string, number> = {};
    sched.forEach((rd: number[][], r: number) => rd.forEach(([h, a]) => {
      const res = E.simulateMatch({ xi: teams[h], shift: 0 }, { xi: teams[a], shift: 0 }, `real|${s}|${r}|${h}`);
      goals += res.hg + res.ag; matches++;
      for (const e of res.events) { if (e.type === "yellow") yellows++; if (e.type === "red" || e.type === "second_yellow") reds++; if (e.type === "goal") scorers[e.pid] = (scorers[e.pid] || 0) + 1; }
    }));
    topSum += Math.max(...Object.values(scorers));
  }
  const gpm = goals / matches, top = topSum / 5;
  ok(gpm > 2.3 && gpm < 3.3, `mål pr. kamp ${gpm.toFixed(2)} udenfor 2,3-3,3`);
  ok(top > 10 && top < 45, `topscorer ${top.toFixed(1)} udenfor 10-45`);
  ok(yellows / matches > 2.8 && yellows / matches < 5.2, `gule pr. kamp ${(yellows / matches).toFixed(2)}`);
  ok(reds / matches < 0.35, `røde pr. kamp ${(reds / matches).toFixed(2)}`);
});
