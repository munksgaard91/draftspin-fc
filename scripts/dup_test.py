import bots, collections
from bots import U, make_game, draft, season_quick, check, log
u = U("DUP")
gid = make_game([u], "quick"); draft([u], gid, "manual"); season_quick([u], gid)
hof = u.sel("hof_players", f"select=player_id,goals,assists,clean_sheets,reds&game_id=eq.{gid}&limit=1000")
ms = {m["id"]: m for m in u.sel("matches", f"select=id,home_key,away_key&game_id=eq.{gid}&limit=1000")}
evs = u.sel("match_events", f"select=match_id,type,team,player_id,assist_id&game_id=eq.{gid}&limit=5000")
key = u.id
def mine(e): m = ms[e["match_id"]]; return (m["home_key"] if e["team"] == "h" else m["away_key"]) == key
lu = {x["player_id"] for x in u.sel("season_lineups", f"select=player_id&game_id=eq.{gid}&team_key=eq.{key}")}
# spillere fra min trup, der OGSÅ scorer for modstandere (dublet-tilfælde)
other = collections.Counter(e["player_id"] for e in evs if e["type"] == "goal" and e["player_id"] in lu and not mine(e))
log("min trups spillere, der også scorede for en AI-klub:", sum(other.values()), "mål fordelt på", len(other), "spillere")
goals = collections.Counter(e["player_id"] for e in evs if e["type"] == "goal" and mine(e))
bad = [(h["player_id"], h["goals"], goals.get(h["player_id"], 0)) for h in hof if h["goals"] != goals.get(h["player_id"], 0)]
check("Highscore-mål = kun mål for mit hold", not bad, str(bad[:5]))
check("scenariet indeholder rigtige dubletter", sum(other.values()) > 0, str(sum(other.values())))
tot = sum(h["goals"] for h in hof); team_goals = sum(1 for e in evs if e["type"] == "goal" and mine(e))
check("sum af spillermål ≤ holdets mål", tot <= team_goals, f"{tot} vs {team_goals}")
print(sum(1 for c in bots.checks if not c[1]), "fejl")
