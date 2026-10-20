import * as E from "../../supabase/functions/engine/engine.js";
const sha = async (t) => [...new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(t)))].map((b) => b.toString(16).padStart(2, "0")).join("");
const parts = [E.ENGINE_VERSION, E.K, E.MU_H, E.MU_A, E.PEN_FACTOR, JSON.stringify(E.FORMS), JSON.stringify(E.AI_FORMS), E.makeRng.toString(), E.fac.toString(), E.bestXI.toString(), E.xiStrength.toString(), E.bestClubXI.toString(), E.schedule.toString(), E.setupSeason.toString(), E.simulateMatch.toString()].join("\n");
const mk = (o) => E.FORMS["4-4-2"].map((pos, i) => ({ pos, p: { id: o + i, rating: 140 + ((i * 7 + o) % 23), consistency: 8 + (i % 9), pen_taking: 6 + (i % 12), yellow_w: 0.9, red_w: 1 }, f: 1 }));
const sims = [];
for (let k = 0; k < 40; k++) { const r = E.simulateMatch({ xi: mk(0), shift: 0 }, { xi: mk(100), shift: 1 }, "selftest|" + k); sims.push(r.hg + "-" + r.ag + ":" + r.events.map((e) => e.m + e.type + e.s + (e.pid ?? "")).join(",")); }
console.log(JSON.stringify({ fingerprint: await sha(parts), simulation: await sha(sims.join("|")) }));
