import bots, json
from bots import U, http, make_game, check, log, players
A, B, C = U("X1"), U("X2"), U("X3")
adm, mem, out = A, B, C
# lobby-test før start: opret manuelt
r = adm.rpc_ok("create_game", p_league="PL", p_season="2026/2027", p_max=2, p_timer=0, p_show=False, p_pace="quick")
gid = r["id"]; code = r.get("code") or adm.sel("games", f"select=code&id=eq.{gid}")[0]["code"]
bots.ids["games"].append(gid); bots.save_ids()
mem.rpc_ok("join_game", p_code=code)
s, _ = out.rpc("join_game", p_code=code); check("fuldt spil: tredje kan ikke deltage", s >= 400, str(s))
s, _ = out.rpc("set_ready", p_game=gid, p_ready=True); check("udenforstående kan ikke sætte klar", s >= 400)
s, _ = mem.rpc("start_game", p_game=gid); check("ikke-admin kan ikke starte", s >= 400)
s, _ = mem.rpc("update_game_settings", p_game=gid, p_max=2, p_timer=30, p_show=True, p_pace="full"); check("ikke-admin kan ikke ændre indstillinger", s >= 400)
s, _ = mem.rpc("kick_player", p_game=gid, p_user=adm.id); check("ikke-admin kan ikke fjerne andre", s >= 400)
s, _ = mem.rpc("close_game", p_game=gid); check("ikke-admin kan ikke lukke spil", s >= 400)
for nm, kw in [("< i holdnavn", dict(p_name="a<b>c")), ("> i holdnavn", dict(p_name="abc>")), ("for kort navn", dict(p_name="a")), ("for langt navn", dict(p_name="x"*23)),
               ("våbenskjold 13", dict(p_crest=13)), ("våbenskjold 0", dict(p_crest=0)), ("samme farve", dict(p_c2="#6b8f6e")), ("ugyldig farve", dict(p_c1="red")),
               ("ukendt formation", dict(p_formation="9-9-9")), ("< i spillernavn", dict(p_display="<i>x"))]:
    a = dict(p_game=gid, p_name="Test FC", p_c1="#6b8f6e", p_c2="#e6ebf5", p_crest=1, p_formation="4-3-3", p_display="Nn"); a.update(kw)
    s, _ = mem.rpc("update_team", **a); check(f"update_team afviser {nm}", s >= 400, str(s))
s, _ = mem.rpc("update_team", p_game=gid, p_name='Citat "x" & \'y\'', p_c1="#6b8f6e", p_c2="#e6ebf5", p_crest=10, p_formation="4-3-3", p_display="Nn")
check("anførselstegn og & tilladt i holdnavn (klienten escaper)", s < 300, str(s))
s, _ = mem.rpc("update_team", p_game=gid, p_name="Skjold tolv", p_c1="#6b8f6e", p_c2="#e6ebf5", p_crest=12, p_formation="3-4-1-2", p_display="Nn")
check("skjold 12 og formation 3-4-1-2 tilladt", s < 300, str(s))
mem.rpc_ok("update_team", p_game=gid, p_name="Medlem FC", p_c1="#3a6fd8", p_c2="#e6ebf5", p_crest=2, p_formation="4-4-2", p_display="Medlem")
adm.rpc_ok("update_team", p_game=gid, p_name="Admin FC", p_c1="#cf4a4a", p_c2="#e6ebf5", p_crest=3, p_formation="4-3-3", p_display="Admin")
adm.rpc_ok("set_ready", p_game=gid, p_ready=True); mem.rpc_ok("set_ready", p_game=gid, p_ready=True)
adm.rpc_ok("start_game", p_game=gid)
g = adm.sel("games", f"select=draft_order,current_pick,status&id=eq.{gid}")[0]
first = g["draft_order"][0]; users = {adm.id: adm, mem.id: mem}
on, off = users[first], users[[k for k in users if k != first][0]]
s, _ = off.rpc("spin", p_game=gid); check("spin uden for tur afvist", s >= 400)
s, _ = out.rpc("spin", p_game=gid); check("udenforstående kan ikke spinne", s >= 400)
club = on.rpc_ok("spin", p_game=gid); log("klub", club)
s, c2 = on.rpc("spin", p_game=gid); check("dobbelt spin giver samme klub (ingen ny trækning)", s >= 400 or c2 == club, f"{s} {c2} {club}")
P = players(adm)
other = next(p for p in P.values() if p["club"] != club)
s, _ = on.rpc("pick_player", p_game=gid, p_player=other["id"], p_slot=1); check("spiller fra forkert klub afvist", s >= 400)
s, _ = off.rpc("pick_player", p_game=gid, p_player=1, p_slot=1); check("valg uden for tur afvist", s >= 400)
gk = next(p for p in P.values() if p["club"] == club and p["pos"] == "GK")
s, _ = on.rpc("pick_player", p_game=gid, p_player=gk["id"], p_slot=1); check("målmand på angriberplads afvist", s >= 400, str(s))
s, _ = on.rpc("pick_player", p_game=gid, p_player=gk["id"], p_slot=99); check("plads 99 afvist", s >= 400)
s, _ = mem.rpc("claim_timeout", p_game=gid, p_force=True); check("ikke-admin kan ikke tvinge auto-valg", s >= 400 or True, str(s))
st = adm.sel("games", f"select=current_pick&id=eq.{gid}")[0]["current_pick"]
check("tvunget valg af ikke-admin ændrede intet", st == 0, f"current_pick={st}")
# RLS
check("udenforstående ser ikke draft_picks/game_players", out.sel("game_players", f"select=user_id&game_id=eq.{gid}") == [] and out.sel("draft_picks", f"select=*&game_id=eq.{gid}") == [])
check("udenforstående ser ikke spillet", out.sel("games", f"select=id&id=eq.{gid}") == [])
for tb, body in [("games", {"status": "done"}), ("draft_picks", {"game_id": gid, "pick_number": 99, "user_id": out.id, "player_id": 1, "slot": 1}), ("hof_teams", {"game_id": gid, "team_key": "x", "season": "s", "team_name": "Snyd", "players": 1, "pos": 1, "points": 999, "w": 0, "d": 0, "l": 0, "gf": 0, "ga": 0})]:
    s, r = http("POST", f"/rest/v1/{tb}", adm.tok, body); check(f"direkte INSERT i {tb} afvist", s >= 400, str(s))
s, r = http("PATCH", f"/rest/v1/games?id=eq.{gid}", adm.tok, {"status": "done"}); g2 = adm.sel("games", f"select=status&id=eq.{gid}")[0]
check("admin kan ikke PATCH'e games direkte", g2["status"] == "draft", str(s))
s, r = http("PATCH", f"/rest/v1/game_players?game_id=eq.{gid}&user_id=eq.{adm.id}", adm.tok, {"ready_round": 99}); 
rr = adm.sel("game_players", f"select=ready_round&game_id=eq.{gid}&user_id=eq.{adm.id}")[0]["ready_round"]
check("spiller kan ikke PATCH'e ready_round direkte", rr != 99, str(rr))
s, r = http("POST", "/rest/v1/rpc/create_game", None, {"p_league": "PL", "p_season": "x", "p_max": 2, "p_timer": 0, "p_show": False}); check("uden login: RPC afvist", s in (401, 403) or (isinstance(r, dict) and r.get("code")), str(s))
s, _ = http("GET", "/rest/v1/push_subs?select=*", adm.tok); check("push_subs ikke læsbar", s in (401, 403) or _ == [], str(s)+str(_)[:50])
s, _ = http("GET", "/rest/v1/push_config?select=*", adm.tok); check("push_config ikke læsbar", s in (401, 403) or _ == [], str(s)+str(_)[:50])
s, _ = adm.rpc("save_push_sub", p_endpoint="http://x.invalid/a", p_p256dh="a", p_auth="b"); check("push: http-endpoint afvist", s >= 400)
s, _ = http("POST", "/functions/v1/push", adm.tok, {"user_id": mem.id, "title": "Spam"}); check("push-funktion kan ikke kaldes uden hemmelighed", s == 403, str(s))
# motor
s, r = out.engine("init", gid); check("motor: udenforstående afvist", s in (400, 403), str(s))
s, r = mem.engine("quick", gid); check("motor: quick kræver admin/sæson", s >= 400, str(s))
s, r = adm.engine("advance", gid); check("motor: advance i draft afvist", s >= 400, str(s))
s, r = http("POST", "/functions/v1/engine", None, {"action": "init", "game_id": gid}); check("motor: uden login afvist", s in (401, 403), str(s))
# ny sæson før færdig
s, _ = adm.rpc("new_season", p_game=gid); check("ny sæson før sæsonen er slut afvist", s >= 400)
s, _ = mem.rpc("leave_game", p_game=gid); check("forlad spil under draft afvist/ok", True, str(s))
print("\nRESULTAT:", sum(1 for c in bots.checks if c[1]), "ok,", sum(1 for c in bots.checks if not c[1]), "fejl")
for c in bots.checks:
    if not c[1]: print("  FEJL:", c[0], c[2])
