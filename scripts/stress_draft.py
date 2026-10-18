import bots, random, time
from bots import U, make_game, draft, check, log
users = [U(f"W{i}") for i in range(6)]
for rnd in range(3):
    random.seed(rnd + 7)
    try:
        gid = make_game(users, "quick")
        n = draft(users, gid, "manual")
        g = users[0].sel("games", f"select=status&id=eq.{gid}")[0]
        forms = [x["formation"] for x in users[0].sel("game_players", f"select=formation&game_id=eq.{gid}")]
        picks = users[0].sel("draft_picks", f"select=user_id&game_id=eq.{gid}")
        check(f"6 spillere, manuel draft #{rnd+1}: færdig med 66 valg", g["status"] == "season" and len(picks) == 66, f"{g} {len(picks)}; {forms}")
    except Exception as e:
        check(f"6 spillere, manuel draft #{rnd+1}", False, str(e)[:200])
print(sum(1 for c in bots.checks if not c[1]), "fejl")
