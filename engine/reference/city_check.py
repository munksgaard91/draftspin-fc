from engine_sim import *
ai={c:best_club_xi(pl) for c,pl in clubs.items()}
def offdef(xi):
    r=np.array([x[1]*x[2] for x in xi]);wo=np.array([WOFF[x[0]] for x in xi]);wd=np.array([WDEF[x[0]] for x in xi])
    return (wo*r).sum()/wo.sum(),(wd*r).sum()/wd.sum(),r.mean()
for c in ("ARS","MCI","LIV","MUN","CHE"):
    o,d,m=offdef(ai[c]);f=[f for f in FORMS if [x[0] for x in ai[c]]==FORMS[f] or sorted(x[0] for x in ai[c])==sorted(FORMS[f])]
    print(c,"OFF %.1f DEF %.1f snit %.1f"%(o,d,m),"formation",f[0])
# samme 11 spillere i andre formationer for City og Arsenal: hvad giver de bedste formationer for OFF-DEF?
for c in ("MCI","ARS"):
    print(c,"formation: snit / OFF / DEF / OFF+DEF")
    for f in FORMS:
        x=best_xi(clubs[c],f)
        if x:
            o,d,m=offdef(x);print("  ",f,"%.1f %.1f %.1f %.1f"%(m,o,d,o+d))
