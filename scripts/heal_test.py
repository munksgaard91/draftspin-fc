#!/usr/bin/env python3
"""Test af selvhelende sæsonstart: efterlad hemmelighed uden kampprogram (SQL udefra) og kald init igen."""
import os, time
from bots import U, make_game, draft, check
u = U("heal")
gid = make_game([u], "full"); draft([u], gid, "manual")
print("init 1:", u.engine("init", gid), flush=True)
open("/tmp/heal_gid.txt", "w").write(gid)
print("READY", gid, flush=True)
while not os.path.exists("/tmp/heal_go"): time.sleep(1)
r = u.engine("init", gid); print("init 2:", r, flush=True)
m = len(u.sel("matches", f"select=id&game_id=eq.{gid}&limit=1000")); t = len(u.sel("season_teams", f"select=team_key&game_id=eq.{gid}"))
check("heal: 380 kampe og 20 hold efter selvheling", m == 380 and t == 20, f"{m}/{t}")
r = u.engine("advance", gid); print("advance:", r, flush=True)

# del 2: kamp markeret spillet, men hændelserne mangler (afbrudt kørsel) -> næste runde skal genskabe dem uden at ændre resultatet
import json
gid2 = gid
mm = u.sel("matches", f"select=id,home_key,away_key,home_goals,away_goals,played&game_id=eq.{gid}&round=eq.1&limit=20")
mine = [m for m in mm if u.id in (m["home_key"], m["away_key"])][0]
print("MATCH", json.dumps(mine), flush=True)
open("/tmp/heal_go2_ready", "w").write(json.dumps(mine))
while not os.path.exists("/tmp/heal_go2"): time.sleep(1)
u.rpc_ok("ready_round", p_game=gid, p_round=1)
print("advance2:", u.engine("advance", gid), flush=True)
mm2 = u.sel("matches", f"select=id,home_goals,away_goals,played&id=eq.{mine['id']}")
ev = u.sel("match_events", f"select=id&match_id=eq.{mine['id']}")
check("replay: resultat uændret", mm2[0]["home_goals"] == mine["home_goals"] and mm2[0]["away_goals"] == mine["away_goals"], str(mm2))
check("replay: hændelser genskabt", len(ev) > 0, str(len(ev)))
