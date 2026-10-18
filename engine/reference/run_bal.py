from engine_sim import *
import sys
rng=random.Random(21);npr=np.random.default_rng(22)
K=40;MUH,MUA=1.34,1.03
# kalibrér til ~2.78 mål med fast forhold
ai0={c:best_club_xi(pl) for c,pl in clubs.items()}
def mod_xi(xi,fn): return [(p,fn(r),f,c) for p,r,f,c in xi]
def scenario(rule,mode,aiscale=1.0,aishift=0.0,hboost=0.0,nd=120,sea=3,nh=4):
    res=[];stats=[]
    for _ in range(nd):
        tk=set();hum=draft(nh,mode,rng,tk)
        ai={}
        for c,pl in clubs.items():
            pool=pl if rule=="behold" else [p for p in pl if p['name'] not in tk]
            ai[c]=(best_club_xi(pool) or ai0[c]) if rule=="fjern" else ai0[c]
        ai={c:mod_xi(x,lambda r:148+aiscale*(r-148)+aishift) for c,x in ai.items()}
        hum=[mod_xi(x,lambda r:r+hboost) for x in hum]
        teams,nai=league_arrays(hum,ai,nh)
        pts,m=simulate(teams,K,MUH,MUA,npr,seasons=sea)
        for p,gd in pts:
            key=p-0+gd*1e-3
            order=np.argsort(-key);rank=np.empty(len(teams),int);rank[order]=np.arange(1,len(teams)+1)
            hr=rank[nai:]
            res.append((hr.min(),np.mean(hr),(hr<=4).mean(),p[nai:].max(),p.max()))
        stats.append(m['goals'])
    a=np.array(res)
    return dict(bestwin=100*(a[:,0]==1).mean(),bestTop4=100*(a[:,0]<=4).mean(),avgrank=a[:,1].mean(),bestpts=a[:,3].mean(),champpts=a[:,4].mean(),goals=np.mean(stats))
rows=[("Basis: AI behold, fornuftig",dict(rule="behold",mode="fornuftig")),
("Basis: AI behold, grådig",dict(rule="behold",mode="best")),
("A: fjern draftede, fornuftig",dict(rule="fjern",mode="fornuftig")),
("D: +4 til menneskehold (Argon), behold",dict(rule="behold",mode="fornuftig",hboost=4)),
("D: +4 og fjern",dict(rule="fjern",mode="fornuftig",hboost=4)),
("B: AI komprimeret x0.8",dict(rule="behold",mode="fornuftig",aiscale=0.8)),
("B: AI komprimeret x0.6",dict(rule="behold",mode="fornuftig",aiscale=0.6)),
("B: AI -5 (Normal)",dict(rule="behold",mode="fornuftig",aishift=-5)),
("B: AI -10 (Let)",dict(rule="behold",mode="fornuftig",aishift=-10)),
("B: komprimeret x0.8 og fjern",dict(rule="fjern",mode="fornuftig",aiscale=0.8)),
("B: komprimeret x0.6 og fjern",dict(rule="fjern",mode="fornuftig",aiscale=0.6)),
]
print(f"k={K}, muH={MUH}, muA={MUA}; 4 spillere, 120 drafts x 3 sæsoner")
print("Scenarie | bedste menneske vinder ligaen | bedste i top 4 | gns. placering (alle 4) | point bedste/mester | mål pr. kamp")
for name,kw in rows:
    r=scenario(**kw)
    print(f"{name} | {r['bestwin']:.0f}% | {r['bestTop4']:.0f}% | {r['avgrank']:.1f} | {r['bestpts']:.0f}/{r['champpts']:.0f} | {r['goals']:.2f}")
    sys.stdout.flush()
