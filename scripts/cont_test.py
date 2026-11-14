#!/usr/bin/env python3
"""Live-test af Continue game / kassér spil (migration 073) med egne gæste-testbrugere.
Kør: cd scripts && python3 cont_test.py   (id'er gemmes i testids.json til oprydning)"""
import bots
from bots import U, make_game, check, log, ids, save_ids

# solo: nyt spil efter bekræftelse sletter det gamle, først når det nye findes
s = U("C0")
g1 = make_game([s], "full")
mg = s.rpc_ok("my_game")
check("my_game giver det igangværende spil", mg and mg["id"] == g1, str(mg)[:200])
r = s.rpc_ok("create_game", p_league="PL", p_season="2026/2027", p_max=1, p_timer=0, p_show=False, p_pace="full")
g2 = r["id"]; ids["games"].append(g2); save_ids()
check("my_game giver det nyeste spil", s.rpc_ok("my_game")["id"] == g2)
s.rpc_ok("discard_game", p_game=g1)
check("solospil slettes ved kassering", s.sel("games", f"select=id&id=eq.{g1}") == [])
s.rpc_ok("discard_game", p_game=g2)
check("my_game er tomt bagefter", s.rpc_ok("my_game") is None)

# multiplayer i draften: spilleren forlader, admin går videre, AI vælger for det forladte hold
a, b, c = U("CA"), U("CB"), U("CC")
gm = make_game([a, b, c], "full")
st = a.sel("games", f"select=status,admin_id,current_pick&id=eq.{gm}")[0]
check("multispil er i draft", st["status"] == "draft", str(st))
b.rpc_ok("discard_game", p_game=gm)
check("forladt spiller: my_game tomt", b.rpc_ok("my_game") is None)
s0, r0 = b.rpc("touch_game", p_game=gm)
gp = a.sel("game_players", f"select=user_id,left_at,missed_rounds&game_id=eq.{gm}")
bb = [x for x in gp if x["user_id"] == b.id][0]
check("left_at og missed_rounds sat", bb["left_at"] is not None and bb["missed_rounds"] >= 99, str(bb))
check("forladt spiller kan ikke læse spillet", b.sel("games", f"select=id&id=eq.{gm}") == [])
a.rpc_ok("discard_game", p_game=gm)
st = c.sel("games", f"select=status,admin_id,current_pick,draft_order&id=eq.{gm}")[0]
check("admin går videre til sidste aktive spiller", st["admin_id"] == c.id, str(st)[:200])
# C er den eneste aktive: alle andre picks laves af serveren, så kun C's egne ture venter
picks_before = st["current_pick"]
order = st["draft_order"]
import math
def turn(p):
    n = len(order); r = p // n; i = p % n
    return order[n - 1 - i] if r % 2 else order[i]
check("draften står på C's tur (resten auto-valgt)", turn(st["current_pick"]) == c.id, f"pick {st['current_pick']} -> {turn(st['current_pick'])}")
c.rpc_ok("discard_game", p_game=gm)
check("sidste spiller kasserer: spillet slettes", c.sel("games", f"select=id&id=eq.{gm}") == [])

# gæstenavne
d = U("CD")
r1 = d.rpc_ok("create_game", p_league="PL", p_season="2026/2027", p_max=1, p_timer=0, p_show=False, p_pace="full")
ids["games"].append(r1["id"]); save_ids()
s1, e1 = d.rpc("update_team", p_game=r1["id"], p_name="Test FC", p_c1="#112233", p_c2="#445566", p_crest=1, p_formation="4-4-2", p_display="Deleted user")
check("gæst kan ikke hedde 'Deleted user'", s1 >= 300, str(e1)[:120])
s2, e2 = d.rpc("update_team", p_game=r1["id"], p_name="Test FC", p_c1="#112233", p_c2="#445566", p_crest=1, p_formation="4-4-2", p_display="Ra​s")
nm = d.sel("game_players", f"select=display_name&game_id=eq.{r1['id']}")[0]["display_name"]
check("usynlige tegn fjernes fra navne", s2 < 300 and nm == "Ras", f"{s2} {nm!r}")
print("\nRESULTAT:", sum(1 for x in bots.checks if x[1]), "ok,", sum(1 for x in bots.checks if not x[1]), "fejl")
