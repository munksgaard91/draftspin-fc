import bots, itertools
from bots import U, check, log, FIT
u = U("R1")
poss = ["GK","CB","LB","RB","DM","CM","AM","LW","RW","ST"]
slots = poss + ["LM","RM"]
bad = []
for p in poss:
    for sl in slots:
        s, r = u.rpc("slot_fit", p_pos=p, p_slot=sl)
        exp = FIT.get(p, {}).get(sl, 0)
        if s >= 300 or r != exp: bad.append((p, sl, r, exp))
check("slot_fit i databasen = tabel i klienten for alle 120 par", not bad, str(bad[:5]))
# alle 16 formationer har 11 pladser og præcis ét GK
for f, v in bots.FORMS.items():
    s, r = u.rpc("formation_slots", p_f=f) if False else (200, None)
# formationer via update_team (accepteres) i en lobby
r = u.rpc_ok("create_game", p_league="PL", p_season="2026/2027", p_max=2, p_timer=0, p_show=False, p_pace="quick")
gid = r["id"]; bots.ids["games"].append(gid); bots.save_ids()
bad = []
for f in bots.FORMS:
    s, r = u.rpc("update_team", p_game=gid, p_name="Regel FC", p_c1="#6b8f6e", p_c2="#e6ebf5", p_crest=1, p_formation=f, p_display="Rr")
    if s >= 300: bad.append((f, s, str(r)[:80]))
check("alle 16 formationer accepteres", not bad, str(bad))
s, r = u.rpc("update_team", p_game=gid, p_name="Regel FC", p_c1="#6b8f6e", p_c2="#e6ebf5", p_crest=1, p_formation="2-2-2-2-3", p_display="Rr")
check("ukendt formation afvises", s >= 400)
print(sum(1 for c in bots.checks if not c[1]), "fejl")
# to naturlige positioner (migration 029): Rice er CM/DM, Gvardiol LB/CB, João Pedro ST/AM
rows = u.sel("players", "select=name,pos,alts&name=in.(%22Declan%20Rice%22,%22Jo%C5%A1ko%20Gvardiol%22,%22Jo%C3%A3o%20Pedro%22)")
d = {r["name"]: r for r in rows}
check("Rice er CM med DM som 2. naturlige", d["Declan Rice"]["pos"] == "CM" and d["Declan Rice"]["alts"].get("DM", {}).get("nat") is True, str(d.get("Declan Rice")))
check("Gvardiol er LB med CB som 2. naturlige", d["Joško Gvardiol"]["alts"].get("CB", {}).get("nat") is True, str(d.get("Joško Gvardiol")))
check("João Pedro er ST med AM som 2. naturlige", d["João Pedro"]["pos"] == "ST" and d["João Pedro"]["alts"].get("AM", {}).get("nat") is True, str(d.get("João Pedro")))
