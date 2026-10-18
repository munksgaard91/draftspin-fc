import bots, re
from bots import U, make_game, draft, season_quick, check, log
u1, u2 = U("N1"), U("N2")
gid = make_game([u1, u2], "quick"); draft([u1, u2], gid, "manual"); season_quick([u1, u2], gid)
t = u1.sel("hof_teams", f"select=team_name,big_win_text,pos&game_id=eq.{gid}")
p = u1.sel("hof_players", f"select=team_name,best_match_text&game_id=eq.{gid}&limit=200")
ai = {x["name"] for x in u1.sel("season_teams", f"select=name,kind&game_id=eq.{gid}&kind=eq.ai")}
texts = [x["big_win_text"] for x in t if x["big_win_text"]] + [x["best_match_text"] for x in p if x["best_match_text"]]
leak = [x for x in texts if any(a in x for a in ai)]
check("ingen AI-holdnavne i Highscore-tekster", not leak, str(leak[:3]))
check("hold i Highscore er kun menneskehold", {x["team_name"] for x in t} <= {"Bot N1 FC", "Bot N2 FC"} and len(t) == 2, str([x["team_name"] for x in t]))
check("spillerrekorder tilhører kun menneskehold", {x["team_name"] for x in p} <= {"Bot N1 FC", "Bot N2 FC"}, str({x["team_name"] for x in p}))
log("eksempler:", texts[:4])
print(sum(1 for c in bots.checks if not c[1]), "fejl")
