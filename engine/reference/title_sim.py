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
def sim_league(teams,seasons,season_sd,form_sd,rho,match_sd=1.5):
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
def titles_ai_only(seasons,ss,fs):
    codes=sorted(ai);teams=[ai[c] for c in codes]
    pts_list,init,_=sim_league(teams,seasons,ss,fs,0.8)
    cnt=Counter(codes[int(np.argmax(p))] for p in pts_list)
    return cnt,seasons
def titles_humans(nd,sea,ss,fs,shift,nh=4):
    cnt=Counter();tot=0
    for _ in range(nd):
        tk=set();hum=draft(nh,"fornuftig",rng,tk)
        ai2={}
        for c,pl in clubs.items():
            pool=[p for p in pl if p['name'] not in tk]
            x=best_club_xi(pool) or ai[c]
            ai2[c]=[(p,r+shift,f,cn) for p,r,f,cn in x]
        order=sorted(ai2,key=lambda c:xi_strength(ai2[c]))[nh:]
        teams=[ai2[c] for c in order]+hum;n_ai=len(order)
        pts_list,init,_=sim_league(teams,sea,ss,fs,0.8)
        for p in pts_list:
            w=int(np.argmax(p));tot+=1
            cnt["Et spillerhold"if w>=n_ai else order[w]]+=1
    return cnt,tot
def show(title,cnt,tot):
    print("\n"+title)
    items=cnt.most_common()
    print(" | ".join(f"{(NAMES.get(k,k))} {100*v/tot:.0f}" for k,v in items))
c,t=titles_ai_only(2000,0,0);show("A) Ren liga uden spillere (20 AI-klubber), ingen ekstra held. Titler pr. 100 sæsoner:",c,t)
c,t=titles_ai_only(2000,5,3);show("B) Samme, MED sæsonheld (sd 5, form 3):",c,t)
c,t=titles_humans(80,5,0,0,0);show("C) 4 spillere + 16 AI, Svær (AI uændret), draftede spillere fjernet fra AI, ingen ekstra held:",c,t)
c,t=titles_humans(80,5,5,3,0);show("D) Som C, MED sæsonheld:",c,t)
c,t=titles_humans(80,5,5,3,-10);show("E) 4 spillere, Normal (AI -10), MED sæsonheld:",c,t)
# hvad er 1 ratingpoint værd i point?
codes=sorted(ai);teams=[ai[c] for c in codes]
base,_,_=sim_league(teams,300,0,0,0.8)
mid=codes.index("BRE");teams2=[ai[c] if c!="BRE" else [(p,r+5,f,cn) for p,r,f,cn in ai[c]] for c in codes]
up,_,_=sim_league(teams2,300,0,0,0.8)
print("\nBrentford (middelhold): gns. point uden og med +5 ratingpoint:",round(np.mean([p[mid] for p in base]),1),round(np.mean([p[mid] for p in up]),1))
