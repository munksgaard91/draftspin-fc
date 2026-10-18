from engine_sim import *
import sys
rng=random.Random(5);npr=np.random.default_rng(6)
K,MUH,MUA=40,1.37,1.05
def circle(N):
    teams=list(range(N));rounds=[]
    for r in range(N-1):
        pairs=[(teams[i],teams[N-1-i]) for i in range(N//2)]
        rounds.append(pairs if r%2==0 else [(b,a) for a,b in pairs])
        teams=[teams[0]]+[teams[-1]]+teams[1:-1]
    return rounds+[[(b,a) for a,b in rd] for rd in rounds]
def sim_league(teams,seasons,season_sd,form_sd,rho,match_sd=1.5,bonus=None):
    N=len(teams);A=[to_arrays(t) for t in teams]
    R=np.stack([a[0] for a in A]);F=np.stack([a[1] for a in A]);S=np.stack([a[2] for a in A]);WO=np.stack([a[3] for a in A]);WD=np.stack([a[4] for a in A])
    sched=circle(N);hh=[];aa=[];rr=[]
    for r,rd in enumerate(sched):
        for h,a in rd: hh.append(h);aa.append(a);rr.append(r)
    hh=np.array(hh);aa=np.array(aa);rr=np.array(rr);M=len(hh)
    init=np.array([ (R[t]*F[t]).mean() for t in range(N)])
    out=[];out2=[]
    for _ in range(seasons):
        seas=npr.normal(0,season_sd,N)
        if bonus is not None: seas=seas+bonus
        form=np.zeros((N,38));e=npr.normal(0,1,(N,38))
        form[:,0]=e[:,0]*form_sd
        for r in range(1,38): form[:,r]=rho*form[:,r-1]+np.sqrt(1-rho**2)*form_sd*e[:,r]
        def side(t):
            eps=npr.normal(0,1,(M,11))*S[t]
            Rm=(R[t]+eps)*F[t]+npr.normal(0,match_sd,(M,1))+(seas[t]+form[t,rr])[:,None]
            return (WO[t]*Rm).sum(1)/WO[t].sum(1),(WD[t]*Rm).sum(1)/WD[t].sum(1)
        oH,dH=side(hh);oA,dA=side(aa)
        lH=MUH*np.exp((oH-dA)/K);lA=MUA*np.exp((oA-dH)/K)
        gH=npr.poisson(lH);gA=npr.poisson(lA)
        npen=npr.poisson(0.29,M);forH=npr.random(M)<lH/(lH+lA);sc=npr.binomial(npen,0.8)
        gH=gH+np.where(forH,sc,0);gA=gA+np.where(~forH,sc,0)
        pts=np.zeros(N);w=gH>gA;d=gH==gA;l=gH<gA
        np.add.at(pts,hh,3*w+d);np.add.at(pts,aa,3*l+d)
        gd=np.zeros(N);np.add.at(gd,hh,gH-gA);np.add.at(gd,aa,gA-gH)
        key=pts+gd*1e-3;champ=int(np.argmax(key))
        prank=int((init>init[champ]).sum())+1  # forhåndsrang på papiret
        out.append((prank,pts.max(),pts.min(),np.std(pts),(gH+gA).mean()));out2.append(pts.copy())
    a=np.array(out)
    return out2,init,dict(fav=100*(a[:,0]==1).mean(),top3=100*(a[:,0]<=3).mean(),r5=100*(a[:,0]>=5).mean(),r8=100*(a[:,0]>=8).mean(),r12=100*(a[:,0]>=12).mean(),champ=a[:,1].mean(),last=a[:,2].mean(),sd=a[:,3].mean(),goals=a[:,4].mean())



NAMES={"ARS":"Arsenal","AVL":"Aston Villa","BOU":"Bournemouth","BRE":"Brentford","BHA":"Brighton","CHE":"Chelsea","COV":"Coventry","CRY":"Crystal Palace","EVE":"Everton","FUL":"Fulham","HUL":"Hull","IPS":"Ipswich","LEE":"Leeds","LIV":"Liverpool","MCI":"Man City","MUN":"Man United","NEW":"Newcastle","NFO":"Forest","SUN":"Sunderland","TOT":"Tottenham"}
ai={c:best_club_xi(pl) for c,pl in clubs.items()}
from collections import Counter
def run(dark_b,unlucky_b,nd=80,sea=5,nh=4):
    cnt=Counter();n=0;uw=Counter();un=Counter();dw=0;dn=0;hum_win=0;hum_top3=0
    for _ in range(nd):
        tk=set();hum=draft(nh,"fornuftig",rng,tk)
        teams,nai=league_arrays(hum,ai,nh)
        codes=sorted(ai,key=lambda c:xi_strength(ai[c]))[nh:]
        init=np.array([(np.array([x[1]*x[2] for x in t])).mean() for t in teams])
        order=np.argsort(-init);ri=np.empty(len(teams),int);ri[order]=np.arange(1,len(teams)+1)
        top=[i for i in range(nai) if ri[i]<=10];low=[i for i in range(nai) if ri[i]>10]
        dh=int(rng.choice(low));un_i=int(rng.choice(top))
        bonus=np.zeros(len(teams));bonus[dh]=dark_b;bonus[un_i]-=unlucky_b
        pts_list,_,_=sim_league(teams,sea,5,3,0.8,bonus=bonus)
        for p in pts_list:
            w=int(np.argmax(p));n+=1
            cnt["Spillerhold" if w>=nai else codes[w]]+=1
            un[codes[un_i]]+=1
            if w==un_i: uw[codes[un_i]]+=1
    return cnt,n,uw,un
c,n,uw,un=run(6,6)
print("Titler pr. 100 spil med mørk hest +6 og uheld -6 på ét tilfældigt AI-hold i top 10:")
print(" | ".join(f"{NAMES.get(k,k)} {100*v/n:.0f}" for k,v in c.most_common(10)))
c0,n0,uw0,un0=run(6,0)
print("Samme uden uheld:")
print(" | ".join(f"{NAMES.get(k,k)} {100*v/n0:.0f}" for k,v in c0.most_common(10)))
print("Når det rammer netop dette hold: andel titler (med uheld) mod uden uheld (alle andre spil):")
for code in ("MCI","ARS","LIV","MUN","CHE"):
    a=100*uw[code]/max(un[code],1);print(f"{NAMES[code]}: {a:.0f}% (n={un[code]})")
