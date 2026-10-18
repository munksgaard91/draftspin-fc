from engine_sim import *
rng=random.Random(3);npr=np.random.default_rng(5)
ai={c:best_club_xi(pl) for c,pl in clubs.items()}
tk=set();hum=draft(4,"fornuftig",rng,tk)
teams,nai=league_arrays(hum,ai,4)
for k,muh,mua in ((40,1.34,1.03),(40,1.38,1.06),(38,1.33,1.02),(42,1.35,1.04)):
    pts,m=simulate(teams,k,muh,mua,npr,seasons=400)
    ch=np.mean([max(p[0]) for p in pts]);la=np.mean([min(p[0]) for p in pts]);sd=np.concatenate([p[0] for p in pts]).std()
    print(f"k={k} muH={muh} muA={mua}: mål {m['goals']:.2f} H {100*m['H']:.1f}% U {100*m['D']:.1f}% B {100*m['A']:.1f}% mester {ch:.0f} sidst {la:.0f} sd {sd:.1f}")
# forventede mål/ points for Δ-forskelle (to hold, hjemme, uden støj)
import math
print("Ratingforskel Δ (OFF-DEF mod modstander, begge veje ens): forventede åbne mål hjemme/ude og sandsynligheder")
muh,mua,k=1.34,1.03,40
for d in (0,10,20,30):
    lh=muh*math.exp(d/k);la=mua*math.exp(-d/k)
    from math import exp,factorial
    pw=pd=pl=0
    for a in range(0,12):
        for b in range(0,12):
            p=exp(-lh)*lh**a/factorial(a)*exp(-la)*la**b/factorial(b)
            if a>b:pw+=p
            elif a==b:pd+=p
            else:pl+=p
    print(f"  Δ={d}: λ hjemme {lh:.2f}, λ ude {la:.2f}, hjemmesejr {100*pw:.0f}%, uafgjort {100*pd:.0f}%, udesejr {100*pl:.0f}%")
