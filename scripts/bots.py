#!/usr/bin/env python3
"""Bot-test af DraftSpin FC mod produktionsdatabasen (kun egne testbrugere/-spil).
Kør: python3 bots.py <scenarie> ...   Scenarier: full6, quick4, solo, duo, conc
Gemmer testens spil-id'er og bruger-id'er i testids.json til oprydning."""
import json, random, sys, time, urllib.request, urllib.error, threading, os, collections

BASE = "https://apagcfedizgjnnuefzfo.supabase.co"
KEY = "sb_publishable_WhuPfaDfcTcZJhWwAcgvhg_YyhNG4lf"
IDS = os.path.join(os.path.dirname(__file__), "testids.json")
ids = json.load(open(IDS)) if os.path.exists(IDS) else {"games": [], "users": []}
def save_ids(): json.dump(ids, open(IDS, "w"))

def http(method, path, tok=None, body=None, extra=None):
    h = {"apikey": KEY, "Content-Type": "application/json"}
    if tok: h["Authorization"] = "Bearer " + tok
    if extra: h.update(extra)
    req = urllib.request.Request(BASE + path, method=method, headers=h, data=json.dumps(body).encode() if body is not None else None)
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            t = r.read().decode()
            return r.status, (json.loads(t) if t else None)
    except urllib.error.HTTPError as e:
        t = e.read().decode()
        try: return e.code, json.loads(t)
        except Exception: return e.code, t

class U:
    def __init__(self, name):
        s, r = http("POST", "/auth/v1/signup", body={})
        assert s == 200, (s, r)
        self.tok = r["access_token"]; self.id = r["user"]["id"]; self.name = name
        ids["users"].append(self.id); save_ids()
    def rpc(self, fn, **a):
        s, r = http("POST", "/rest/v1/rpc/" + fn, self.tok, a)
        return s, r
    def rpc_ok(self, fn, **a):
        s, r = self.rpc(fn, **a)
        if s >= 300: raise RuntimeError(f"{fn} {a} -> {s} {r}")
        return r
    def sel(self, table, q=""):
        s, r = http("GET", f"/rest/v1/{table}?{q}", self.tok)
        if s >= 300: raise RuntimeError(f"select {table}?{q} -> {s} {r}")
        return r
    def engine(self, action, gid, **x):
        return http("POST", "/functions/v1/engine", self.tok, dict(action=action, game_id=gid, **x))

FORMS = {'4-3-3': ['LW', 'ST', 'RW', 'CM', 'DM', 'CM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-4-2': ['ST', 'ST', 'LM', 'CM', 'CM', 'RM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-2-3-1': ['ST', 'LW', 'AM', 'RW', 'DM', 'DM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-1-4-1': ['ST', 'LM', 'CM', 'CM', 'RM', 'DM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-1-2-1-2': ['ST', 'ST', 'AM', 'CM', 'CM', 'DM', 'LB', 'CB', 'CB', 'RB', 'GK'], '3-5-2': ['ST', 'ST', 'LM', 'CM', 'DM', 'CM', 'RM', 'CB', 'CB', 'CB', 'GK'], '3-4-3': ['LW', 'ST', 'RW', 'CM', 'CM', 'LB', 'CB', 'CB', 'CB', 'RB', 'GK'], '5-3-2': ['ST', 'ST', 'CM', 'DM', 'CM', 'LB', 'CB', 'CB', 'CB', 'RB', 'GK'], '5-4-1': ['ST', 'LM', 'CM', 'CM', 'RM', 'LB', 'CB', 'CB', 'CB', 'RB', 'GK'], '4-5-1': ['ST', 'LM', 'CM', 'DM', 'CM', 'RM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-4-1-1': ['ST', 'AM', 'LM', 'CM', 'CM', 'RM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-3-1-2': ['ST', 'ST', 'AM', 'CM', 'DM', 'CM', 'LB', 'CB', 'CB', 'RB', 'GK'], '4-2-2-2': ['ST', 'ST', 'AM', 'AM', 'DM', 'DM', 'LB', 'CB', 'CB', 'RB', 'GK'], '3-4-2-1': ['ST', 'AM', 'AM', 'CM', 'CM', 'LB', 'CB', 'CB', 'CB', 'RB', 'GK'], '4-3-2-1': ['ST', 'AM', 'AM', 'CM', 'DM', 'CM', 'LB', 'CB', 'CB', 'RB', 'GK']}
PLAYERS = None
def players(u):
    global PLAYERS
    if PLAYERS is None:
        PLAYERS = {}
        off = 0
        while True:
            rows = u.sel("players", f"select=id,club,pos,alts,rating&order=id&limit=1000&offset={off}")
            for p in rows: PLAYERS[p["id"]] = p
            if len(rows) < 1000: break
            off += 1000
    return PLAYERS
FIT = {"GK": {"GK": 2}, "CB": {"CB": 2}, "LB": {"LB": 2, "RB": 1}, "RB": {"RB": 2, "LB": 1}, "DM": {"DM": 2, "CM": 1}, "CM": {"CM": 2, "DM": 1, "AM": 1},
       "AM": {"AM": 2, "CM": 1}, "LW": {"LW": 2, "LM": 2, "ST": 1, "RW": 1}, "RW": {"RW": 2, "RM": 2, "ST": 1, "LW": 1}, "ST": {"ST": 2, "LW": 1, "RW": 1}}
def slot_ok(p, slot):
    return FIT.get(p["pos"], {}).get(slot, 0) > 0

def log(*a): print(time.strftime("%H:%M:%S"), *a, flush=True)
checks = []
def check(name, ok, info=""):
    checks.append((name, bool(ok), info)); log(("OK   " if ok else "FEJL ") + name, info if not ok else "")

def make_game(users, pace, timer=0):
    adm = users[0]
    r = adm.rpc_ok("create_game", p_league="PL", p_season="2026/2027", p_max=len(users), p_timer=timer, p_show=False, p_pace=pace)
    gid = r["id"] if isinstance(r, dict) and "id" in r else (r[0]["id"] if isinstance(r, list) else r)
    code = (r.get("code") if isinstance(r, dict) else None)
    if code is None: code = adm.sel("games", f"select=code&id=eq.{gid}")[0]["code"]
    ids["games"].append(gid); save_ids()
    for u in users[1:]: u.rpc_ok("join_game", p_code=code)
    forms = list(FORMS)  # alle 15 formationer, så de alle bliver prøvet
    cols = ["#6b8f6e", "#3a6fd8", "#c29a3d", "#c4688b", "#8c6bc4", "#cf4a4a", "#e08a2e", "#2fa7a0"]
    for i, u in enumerate(users):
        u.rpc_ok("update_team", p_game=gid, p_name=f"Bot {u.name} FC", p_c1=cols[i], p_c2="#e6ebf5", p_crest=1 + (i * 3) % 10, p_formation=forms[(i * 4 + len(ids["games"])) % len(forms)], p_display=f"Bot{i+1}")
        u.rpc_ok("set_ready", p_game=gid, p_ready=True)
    adm.rpc_ok("start_game", p_game=gid)
    return gid

def draft(users, gid, mode="mixed"):
    """mode: manual (alle vælger selv), auto (admin tvinger auto-valg), mixed"""
    adm = users[0]; byid = {u.id: u for u in users}
    P = players(adm)
    t0 = time.time(); steps = 0
    while True:
        g = adm.sel("games", f"select=status,current_pick,current_club,draft_order&id=eq.{gid}")[0]
        if g["status"] != "draft": break
        n = len(g["draft_order"]); cp = g["current_pick"]; rnd, pos = divmod(cp, n)
        uid = g["draft_order"][pos if rnd % 2 == 0 else n - 1 - pos]
        u = byid[uid]
        use_auto = mode == "auto" or (mode == "mixed" and random.random() < 0.3)
        if use_auto:
            s, r = adm.rpc("claim_timeout", p_game=gid, p_force=True)
            if s >= 300: raise RuntimeError(f"claim_timeout force -> {s} {r}")
        else:
            club = g["current_club"]
            if not club:
                club = u.rpc_ok("spin", p_game=gid)
            gp = u.sel("game_players", f"select=formation&game_id=eq.{gid}&user_id=eq.{u.id}")[0]
            slots = FORMS.get(gp["formation"]) or None
            picks = adm.sel("draft_picks", f"select=player_id,slot,user_id&game_id=eq.{gid}")
            taken = {p["player_id"] for p in picks}; mine = {p["slot"] for p in picks if p["user_id"] == uid}
            cands = []
            for si, sp in enumerate(slots, 1):
                if si in mine: continue
                for p in P.values():
                    if p["club"] == club and p["id"] not in taken and slot_ok(p, sp): cands.append((p["id"], si))
            if not cands: raise RuntimeError(f"ingen kandidater klub {club} for {u.name} (spin skulle have undgået det)")
            pid, si = random.choice(cands)
            u.rpc_ok("pick_player", p_game=gid, p_player=pid, p_slot=si)
        steps += 1
        if steps > 11 * len(users) * 3: raise RuntimeError("draft hænger")
    log(f"draft færdig på {time.time()-t0:.1f}s, {steps} trin")
    return steps

def season_full(users, gid, concurrent=False):
    adm = users[0]
    s, r = adm.engine("init", gid); assert s == 200, (s, r)
    errs = []
    for rnd in range(1, 38):
        g = adm.sel("games", f"select=current_round,status&id=eq.{gid}")[0]
        if g["status"] == "done": break
        cr = g["current_round"]
        for u in users: u.rpc_ok("ready_round", p_game=gid, p_round=cr)
        if concurrent and rnd % 5 == 0:   # to samtidige advance-kald
            res = []
            def go(u): res.append(u.engine("advance", gid))
            th = [threading.Thread(target=go, args=(u,)) for u in users[:3]]
            [t.start() for t in th]; [t.join() for t in th]
            bad = [x for x in res if x[0] >= 500]
            if bad: errs.append((rnd, bad))
        else:
            s, r = adm.engine("advance", gid)
            if s >= 500: errs.append((rnd, s, r))
    g = adm.sel("games", f"select=current_round,status&id=eq.{gid}")[0]
    # sidste runde
    for _ in range(3):
        if g["status"] == "done": break
        for u in users: u.rpc("ready_round", p_game=gid, p_round=g["current_round"])
        adm.engine("advance", gid)
        g = adm.sel("games", f"select=current_round,status&id=eq.{gid}")[0]
    return errs

def season_quick(users, gid):
    adm = users[0]
    s, r = adm.engine("init", gid); assert s == 200, (s, r)
    for _ in range(40):
        g = adm.sel("games", f"select=current_round,status&id=eq.{gid}")[0]
        if g["status"] == "done": break
        s, r = adm.engine("quick", gid)
        if s >= 500: log("quick fejl", s, r)
        time.sleep(0.3)

def verify(users, gid, label):
    adm = users[0]
    g = adm.sel("games", f"select=status,current_round,pace&id=eq.{gid}")[0]
    check(f"{label}: status done", g["status"] == "done", str(g))
    ms = []
    off = 0
    while True:
        rows = adm.sel("matches", f"select=id,round,home_key,away_key,home_goals,away_goals,played&game_id=eq.{gid}&order=id&limit=1000&offset={off}")
        ms += rows
        if len(rows) < 1000: break
        off += 1000
    check(f"{label}: 380 kampe", len(ms) == 380, str(len(ms)))
    check(f"{label}: alle spillet", all(m["played"] for m in ms), str(sum(1 for m in ms if not m["played"])) + " ikke spillet")
    per = collections.Counter()
    for m in ms: per[m["home_key"]] += 1; per[m["away_key"]] += 1
    check(f"{label}: 20 hold à 38 kampe", len(per) == 20 and set(per.values()) == {38}, str(dict(per)))
    rounds = collections.Counter(m["round"] for m in ms)
    check(f"{label}: 38 runder à 10 kampe", len(rounds) == 38 and set(rounds.values()) == {10}, str(sorted(rounds.items())[:3]))
    # hændelser mod resultater
    evs = []; off = 0
    while True:
        rows = adm.sel("match_events", f"select=id,match_id,minute,type,team,player_id,pen&game_id=eq.{gid}&order=id&limit=1000&offset={off}")
        evs += rows
        if len(rows) < 1000: break
        off += 1000
    goals = collections.Counter()
    for e in evs:
        if e["type"] == "goal": goals[e["match_id"]] += 1
    hk = {t["team_key"] for t in adm.sel("season_teams", f"select=team_key&game_id=eq.{gid}&kind=eq.human")}
    hm = [m for m in ms if m["home_key"] in hk or m["away_key"] in hk]
    mism = [m["id"] for m in hm if goals.get(m["id"], 0) != m["home_goals"] + m["away_goals"]]
    check(f"{label}: mål-hændelser = resultater (kampe med menneskehold: {len(hm)})", not mism, f"{len(mism)} kampe afviger")
    outside = [e for e in evs if e["match_id"] not in {m["id"] for m in hm}]
    log(f"   hændelser uden for menneskekampe: {len(outside)}")
    keys = collections.Counter((e["match_id"], e["minute"], e["type"], e["team"], e["player_id"], e["pen"]) for e in evs)
    check(f"{label}: ingen dublerede hændelser", max(keys.values() or [1]) == 1)
    tg = sum(m["home_goals"] + m["away_goals"] for m in ms) / 380
    check(f"{label}: mål/kamp 2.3-3.4", 2.3 <= tg <= 3.4, f"{tg:.2f}")
    yc = sum(1 for e in evs if e["type"] == "yellow") / max(1, len(hm)); rc = sum(1 for e in evs if e["type"] in ("red", "second_yellow")) / max(1, len(hm))
    log(f"   mål/kamp {tg:.2f}, gule {yc:.2f}, røde {rc:.2f}, hændelser {len(evs)}")
    # hall of fame
    hof = adm.sel("hof_teams", f"select=team_name,pos,points&game_id=eq.{gid}")
    check(f"{label}: Highscore-rækker = antal hold", len(hof) == len(users), f"{len(hof)} af {len(users)}")
    # hemmeligt
    s, r = http("GET", f"/rest/v1/season_secret?game_id=eq.{gid}", adm.tok)
    check(f"{label}: season_secret ikke læsbar", s in (401, 403) or r == [] , f"{s} {str(r)[:80]}")
    # tabel fra kampe
    pts = collections.Counter()
    for m in ms:
        h, a = m["home_goals"], m["away_goals"]
        pts[m["home_key"]] += 3 if h > a else (1 if h == a else 0); pts[m["away_key"]] += 3 if a > h else (1 if h == a else 0)
    hp = {x["team_name"]: x["points"] for x in hof}
    st = adm.sel("season_teams", f"select=team_key,name,kind&game_id=eq.{gid}")
    nm = {t["team_key"]: t["name"] for t in st}
    okp = all(pts[k] == hp[nm[k]] for k in pts if nm[k] in hp)
    check(f"{label}: Highscore-point = tabel fra kampe", okp)
    return ms

def run(scn):
    random.seed(hash(scn) & 0xffff)
    if scn == "full6":
        users = [U(f"A{i}") for i in range(6)]
        gid = make_game(users, "full"); draft(users, gid, "mixed")
        errs = season_full(users, gid, concurrent=True)
        check("full6: ingen 5xx under samtidige advance", not errs, str(errs)[:300])
        verify(users, gid, "full6")
        # ny sæson
        ng = users[0].rpc_ok("new_season", p_game=gid)
        ng = ng if isinstance(ng, str) else ng
        ids["games"].append(ng); save_ids()
        g2 = users[0].sel("games", f"select=status,season_no,max_players&id=eq.{ng}")[0]
        gp2 = users[0].sel("game_players", f"select=user_id&game_id=eq.{ng}")
        check("full6: ny sæson med samme gruppe", g2["status"] == "draft" and g2["season_no"] == 2 and len(gp2) == 6, str(g2))
        s, r = users[0].rpc("new_season", p_game=gid)   # idempotent
        check("full6: new_season idempotent", s < 300 and r == ng, f"{s} {r}")
        json.dump([u.id for u in users], open(os.path.join(os.path.dirname(__file__), "users6.json"), "w"))
    elif scn == "quick4":
        users = [U(f"B{i}") for i in range(4)]
        gid = make_game(users, "quick"); draft(users, gid, "manual"); season_quick(users, gid); verify(users, gid, "quick4")
    elif scn == "solo":
        users = [U("S0")]
        gid = make_game(users, "quick"); draft(users, gid, "auto"); season_quick(users, gid); verify(users, gid, "solo")
    elif scn == "duo":
        users = [U(f"D{i}") for i in range(2)]
        gid = make_game(users, "full"); draft(users, gid, "auto"); season_full(users, gid); verify(users, gid, "duo")
    print("\nRESULTAT:", sum(1 for c in checks if c[1]), "ok,", sum(1 for c in checks if not c[1]), "fejl")
    for c in checks:
        if not c[1]: print("  FEJL:", c[0], c[2])

if __name__ == "__main__":
    for s in sys.argv[1:]: run(s)
