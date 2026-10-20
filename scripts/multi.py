#!/usr/bin/env python3
"""Test af solo og multiplayer (åben lobby, 2-10 spillere, antal fastlagt ved Start) mod produktionen. Kun egne testbrugere/-spil (ids i testids.json).
Kør: python3 multi.py [solo|n2|n3|n10|alle]"""
import sys, random
import bots as B
from bots import U, check, log, ids, save_ids

def new_users(n): return [U(f"m{i+1}") for i in range(n)]

def lobby(users, pmax, pace="quick"):
    adm = users[0]
    r = adm.rpc_ok("create_game", p_league="PL", p_season="2026/2027", p_max=pmax, p_timer=0, p_show=False, p_pace=pace)
    gid, code = r["id"], r["code"]
    ids["games"].append(gid); save_ids()
    for u in users[1:]: u.rpc_ok("join_game", p_code=code)
    return gid, code

def setup_and_draft(users, gid):
    adm = users[0]
    cols = ["#6b8f6e", "#3a6fd8", "#c29a3d", "#c4688b", "#8c6bc4", "#cf4a4a", "#e08a2e", "#2fa7a0", "#7bc043", "#6ab7e6"]
    forms = list(B.FORMS)
    for i, u in enumerate(users):
        u.rpc_ok("update_team", p_game=gid, p_name=f"Bot {i+1} FC", p_c1=cols[i], p_c2="#e6ebf5", p_crest=1 + i % 10, p_formation=forms[(i * 3) % len(forms)], p_display=f"Bot{i+1}")
        u.rpc_ok("set_ready", p_game=gid, p_ready=True)
    g = adm.sel("games", f"select=status&id=eq.{gid}")[0]
    check("draften starter automatisk, når alle er klar", g["status"] == "draft", str(g))
    B.draft(users, gid, "mixed")

def finish(users, gid, label):
    B.season_quick(users, gid)
    B.verify(users, gid, label)

def t_solo():
    (u,) = new_users(1)
    gid, _ = lobby([u], 1)
    s, r = u.rpc("open_setup", p_game=gid)
    g = u.sel("games", f"select=max_players,setup&id=eq.{gid}")[0]
    check("solo: Start virker med 1 spiller, max_players forbliver 1", s < 300 and g["max_players"] == 1 and g["setup"], f"{s} {r} {g}")
    return [gid]

def t_n(n, full=True):
    users = new_users(n)
    gid, code = lobby(users[:1], 10)
    adm = users[0]
    s, r = adm.rpc("open_setup", p_game=gid)
    check(f"n={n}: Start afvises, når admin er alene", s >= 400 and "At least 2" in str(r), f"{s} {r}")
    for u in users[1:]: u.rpc_ok("join_game", p_code=code)
    g = adm.sel("games", f"select=max_players&id=eq.{gid}")[0]
    check(f"n={n}: lobbyen har stadig plads til 10 før Start", g["max_players"] == 10, str(g))
    if n == 10:
        extra = U("ekstra")
        s, r = extra.rpc("join_game", p_code=code)
        check("n=10: 11. spiller afvises (lobbyen er fuld)", s >= 400 and "full" in str(r), f"{s} {r}")
    adm.rpc_ok("open_setup", p_game=gid)
    g = adm.sel("games", f"select=max_players,setup&id=eq.{gid}")[0]
    check(f"n={n}: antal spillere fastlagt ved Start", g["max_players"] == n and g["setup"], str(g))
    if n == 10 or full:
        late = U("sen")
        s, r = late.rpc("join_game", p_code=code)
        check(f"n={n}: ingen kan joine efter Start", s >= 400, f"{s} {r}")
    setup_and_draft(users, gid)
    if full: finish(users, gid, f"n={n}")
    return [gid]

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "alle"
    made = []
    try:
        if what in ("solo", "alle"): made += t_solo()
        if what in ("n2", "alle"): made += t_n(2)
        if what in ("n3", "alle"): made += t_n(3)
        if what in ("n10", "alle"): made += t_n(10)
    finally:
        bad = [c for c in B.checks if not c[1]]
        log(f"{len(B.checks)-len(bad)}/{len(B.checks)} tjek OK", "FEJL: " + str(bad) if bad else "")
        log("testspil:", ids["games"])
