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
