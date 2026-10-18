# Skærmbilleder af hele flowet (mobilstørrelse). Kræver: python3 -m venv v && v/bin/pip install playwright, og Chrome.
# Start først: python3 -m http.server 8765 i denne mappe. Kør: v/bin/python scripts/screenshots.py quick|full <udmappe>
# Opretter et rigtigt testspil i databasen; ryd det bagefter (spil + highscore).
import sys, os, time, json
from playwright.sync_api import sync_playwright

MODE = sys.argv[1]            # full | quick
OUT = sys.argv[2]
URL = "http://localhost:8765/index.html"
os.makedirs(OUT, exist_ok=True)
N = [0]
LOG = []
PFX = sys.argv[3] if len(sys.argv)>3 else ""

def shot(pg, name, note="", full=False):
    N[0] += 1
    fn = f"{N[0]:02d}-{MODE}-{name}.png"
    pg.screenshot(path=os.path.join(OUT, fn), full_page=full)
    h = pg.evaluate("document.documentElement.scrollHeight")
    LOG.append((fn, note, h))
    print(fn, h, flush=True)

def clk(pg, pattern, timeout=8000):
    pg.wait_for_function("""p=>{const re=new RegExp(p);return [...document.querySelectorAll('button')].some(b=>b.offsetParent&&re.test(b.textContent))}""", arg=pattern, timeout=timeout)
    pg.evaluate("""p=>{const re=new RegExp(p);[...document.querySelectorAll('button')].find(b=>b.offsetParent&&re.test(b.textContent)).click()}""", pattern)

def setv(pg, id, v):
    pg.evaluate("""([id,v])=>{const e=document.getElementById(id);e.value=v;e.dispatchEvent(new Event('input',{bubbles:true}))}""", [id, v])

with sync_playwright() as p:
    b = p.chromium.launch(channel="chrome", headless=True)
    ctx = b.new_context(viewport={"width": 375, "height": 812}, device_scale_factor=2, is_mobile=True, has_touch=True, locale="da-DK")
    pg = ctx.new_page()
    pg.goto(URL); pg.wait_for_timeout(2500)
    shot(pg, "start", "Startskærm")
    pg.evaluate("document.querySelector('[data-act=\"hofopen\"]').click()"); pg.wait_for_timeout(1500)
    shot(pg, "highscore-tom", "Highscore fra startskærm (tilbage-knap)")
    pg.evaluate("document.getElementById('hofBack').click()"); pg.wait_for_timeout(600)
    clk(pg, "Deltag i spil"); pg.wait_for_timeout(600)
    shot(pg, "deltag", "Deltag i spil (kode)")
    clk(pg, "Tilbage"); pg.wait_for_timeout(500)
    clk(pg, "Opret spil"); pg.wait_for_timeout(800)
    shot(pg, "hold-tomt", "Dit hold (tomt)")
    setv(pg, "pname", "Rasmus"); setv(pg, "tname", "Test FC" if MODE == "full" else "Quick FC"); pg.wait_for_timeout(300)
    shot(pg, "hold-udfyldt", "Dit hold udfyldt, fane Primær farve")
    pg.evaluate("document.querySelector('[data-ctab=\"s\"]').click()"); pg.wait_for_timeout(400)
    shot(pg, "hold-sekundaer", "Dit hold, fane Sekundær farve")
    pg.evaluate("document.querySelector('[data-crest=\"11\"]').click()"); pg.wait_for_timeout(300)
    shot(pg, "hold-skjold-12", "Dit hold, nyt våbenskjold valgt")
    clk(pg, "Fortsæt til formation"); pg.wait_for_timeout(1500)
    shot(pg, "formation", "Vælg formation (16)")
    pg.evaluate("document.querySelector('[data-f=\"3-4-1-2\"]').click()"); pg.wait_for_timeout(400)
    shot(pg, "formation-ny", "Formation 3-4-1-2 valgt")
    clk(pg, "Jeg er klar til draft"); pg.wait_for_timeout(3500)
    shot(pg, "lobby-standard", "Lobby med standardregler (4 spillere)")
    pg.evaluate("document.querySelector('[data-act=\"setmax\"][data-v=\"1\"]').click()"); pg.wait_for_timeout(1500)
    if MODE == "quick":
        pg.evaluate("document.querySelector('[data-act=\"lset\"][data-k=\"pace\"][data-v=\"quick\"]').click()"); pg.wait_for_timeout(1500)
    shot(pg, "lobby-solo", "Lobby solo (ingen kode)")
    clk(pg, "Start spillet"); pg.wait_for_timeout(5000)
    shot(pg, "draft-foer-spin", "Draft før spin (ingen rækkefølge-skærm i solo)")
    pg.evaluate("document.getElementById('spinBtn').click()"); pg.wait_for_timeout(1500)
    shot(pg, "draft-spinner", "Hjulet snurrer")
    first = True
    shown_club = False
    mine = lambda: pg.evaluate("(()=>{const m=document.getElementById('counts').innerText.match(/Dig\\s*(\\d+)\\/11/);return m?+m[1]:-1})()")
    picks = 0
    for n in range(80):
        if mine() >= 11: break
        if not pg.evaluate("document.querySelector('.screen.on').id.includes('draft')"): break
        sp = pg.evaluate("(()=>{const s=document.getElementById('spinBtn');return !!(s&&s.offsetParent&&!s.disabled)})()")
        if sp:
            pg.evaluate("document.getElementById('spinBtn').click()")
            try: pg.wait_for_function("document.querySelectorAll('#clubpanel .row').length>0", timeout=15000)
            except Exception: continue
            pg.wait_for_timeout(600)
        if first and not shown_club:
            shown_club = True
            pg.evaluate("window.scrollTo(0,0)")
            shot(pg, "draft-klub-valgt", "Klub valgt, spillerliste", full=False)
        before = mine()
        n_rows = pg.evaluate("[...document.querySelectorAll('#clubpanel .row')].filter(r=>r.offsetParent&&!/fyldt/.test(r.textContent)).length")
        for i in range(n_rows):
            pg.evaluate("(i)=>{[...document.querySelectorAll('#clubpanel .row')].filter(r=>r.offsetParent&&!/fyldt/.test(r.textContent))[i]?.click()}", i)
            pg.wait_for_timeout(300)
            hl = pg.evaluate("(()=>{const sh=document.getElementById('sheet');return !!(sh&&!sh.hidden&&[...sh.querySelectorAll('.slot.hl')].find(x=>x.offsetParent))})()")
            if hl:
                if first:
                    shot(pg, "draft-vaelg-plads", "Vælg plads på banen (grøn/gul/grå)")
                    first = False
                if picks == 6:
                    shot(pg, "draft-vaelg-plads-2", "Vælg plads, midt i draften")
                pg.evaluate("(()=>{const x=[...document.getElementById('sheet').querySelectorAll('.slot.hl')].find(x=>x.offsetParent);if(x)x.click()})()")
                pg.wait_for_timeout(1500)
                if mine() > before:
                    picks += 1
                    if picks == 5:
                        pg.evaluate("window.scrollTo(0,0)"); shot(pg, "draft-midt", "Draft midt i, top")
                        pg.evaluate("window.scrollTo(0,document.body.scrollHeight)"); shot(pg, "draft-midt-bund", "Draft midt i, bund (trupper + seneste valg)")
                    break
                else:
                    pg.evaluate("(()=>{const s=document.getElementById('sheet');})()")
        pg.wait_for_timeout(500)
    print("picks", picks, flush=True)

    if MODE == "full":
        pg.wait_for_function("document.querySelector('.screen.on').id==='s-match'", timeout=60000)
        pg.wait_for_timeout(9000)
        shot(pg, "kamp-spiller", "Kamp spilles (tidslinje under stilling)")
        pg.wait_for_timeout(22000)
        shot(pg, "kamp-slut", "Kamp slut, hændelser")
        pg.evaluate("document.querySelector('#mseg [data-mt=\"others\"]').click()"); pg.wait_for_timeout(400)
        shot(pg, "kamp-resten-af-runden", "Fane: resten af runden")
        for s, nm in [("table", "tabel"), ("stats", "stats"), ("hof", "highscore")]:
            pg.evaluate(f"document.querySelector('#nav [data-s=\"{s}\"]').click()"); pg.wait_for_timeout(1500)
            shot(pg, nm, nm)
        pg.evaluate("document.querySelector('#nav [data-s=\"stats\"]').click()"); pg.wait_for_timeout(600)
        for i, t in enumerate(pg.evaluate("[...document.querySelectorAll('#seg button')].map(b=>b.textContent)")):
            pg.evaluate("(i)=>document.querySelectorAll('#seg button')[i].click()", i); pg.wait_for_timeout(500)
            shot(pg, f"stats-{t.lower().replace(' ','-')}", f"Stats: {t}")
    else:
        pg.wait_for_function("document.querySelector('.screen.on').id==='s-sim'", timeout=60000)
        pg.wait_for_timeout(700)
        shot(pg, "sim-venter", "Sæsonen spilles, kamp i gang")
        for t in range(300):
            if pg.evaluate("document.querySelectorAll('.simtl .stl').length")>=3: break
            pg.wait_for_timeout(100)
        shot(pg, "sim-resultat-med-maal", "Sæsonen spilles, resultat + tidslinje")
        pg.evaluate("document.querySelector('[data-act=\"simskip\"]').click()"); pg.wait_for_timeout(800)
        shot(pg, "sim-faerdig", "Sæsonen er spillet")
        pg.evaluate("document.querySelector('[data-act=\"simend\"]').click()"); pg.wait_for_timeout(1500)
        shot(pg, "slut-slutstilling", "Slutskærm: Slutstilling")
        for et, nm in [("pris", "priser"), ("kampe", "dine-kampe")]:
            pg.evaluate(f"document.querySelector('[data-et=\"{et}\"]').click()"); pg.wait_for_timeout(500)
            shot(pg, f"slut-{nm}", f"Slutskærm: {nm}")
        for s, nm in [("match", "kamp"), ("table", "tabel"), ("stats", "stats")]:
            pg.evaluate(f"document.querySelector('#nav [data-s=\"{s}\"]').click()"); pg.wait_for_timeout(2500)
            shot(pg, f"efter-{nm}", f"Efter sæson: {nm}")
        for i, t in enumerate(pg.evaluate("[...document.querySelectorAll('#seg button')].map(b=>b.textContent)")):
            pg.evaluate("document.querySelector('#nav [data-s=\"stats\"]').click()"); pg.wait_for_timeout(300)
            pg.evaluate("(i)=>document.querySelectorAll('#seg button')[i].click()", i); pg.wait_for_timeout(500)
            shot(pg, f"stats-{t.lower().replace(' ','-')}", f"Stats: {t}")
        pg.evaluate("document.querySelector('#nav [data-s=\"hof\"]').click()"); pg.wait_for_timeout(2500)
        cats = pg.evaluate("[...document.querySelectorAll('.hcats button')].map(b=>b.textContent)")
        for i, t in enumerate(cats):
            pg.evaluate("(i)=>document.querySelectorAll('.hcats button')[i].click()", i); pg.wait_for_timeout(1200)
            shot(pg, f"highscore-{t.lower().replace(' ','-')}", f"Highscore: {t}")
    json.dump(LOG, open(os.path.join(OUT, f"log-{MODE}.json"), "w"))
    b.close()
