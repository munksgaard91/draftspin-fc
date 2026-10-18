import bots, time
from bots import U, make_game, draft, check, log
A, B = U("Z1"), U("Z2")
gid = make_game([A, B], "full"); draft([A, B], gid, "auto")
log("venter 100 s, så B tæller som væk"); time.sleep(100)
A.rpc("touch_game", p_game=gid)
s, r = A.engine("init", gid); assert s == 200, (s, r)
for i in range(40):
    g = A.sel("games", f"select=current_round,status&id=eq.{gid}")[0]
    if g["status"] == "done": break
    A.rpc("touch_game", p_game=gid)
    A.rpc_ok("ready_round", p_game=gid, p_round=g["current_round"])
    s, r = A.engine("advance", gid)
    if s >= 400: log("advance", s, r)
g = A.sel("games", f"select=current_round,status&id=eq.{gid}")[0]
gp = {x["user_id"]: x for x in A.sel("game_players", f"select=user_id,missed_rounds&game_id=eq.{gid}")}
log("missed A/B:", gp[A.id]["missed_rounds"], gp[B.id]["missed_rounds"], g)
check("sæsonen spilles færdig trods fraværende spiller", g["status"] == "done", str(g))
check("fraværende hold tæller væk", gp[B.id]["missed_rounds"] >= 8, str(gp[B.id]))
check("tilstedeværende hold tæller ikke væk", gp[A.id]["missed_rounds"] == 0, str(gp[A.id]))
hof = A.sel("hof_teams", f"select=team_name,user_id&game_id=eq.{gid}")
check("kun det tilstedeværende hold i Highscore", len(hof) == 1 and hof[0]["user_id"] == A.id, str(hof))
hp = A.sel("hof_players", f"select=user_id&game_id=eq.{gid}")
check("kun tilstedeværende holds spillere i Highscore", all(x["user_id"] == A.id for x in hp) and len(hp) > 0, str(len(hp)))
ms = A.sel("matches", f"select=id&game_id=eq.{gid}&played=eq.true&limit=1000")
check("alle 380 kampe spillet", len(ms) == 380, str(len(ms)))
print([c for c in bots.checks if not c[1]] or "ALT OK")
