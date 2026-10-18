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
    out=[]
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
        out.append((prank,pts.max(),pts.min(),np.std(pts),(gH+gA).mean()))
    a=np.array(out)
    return dict(fav=100*(a[:,0]==1).mean(),top3=100*(a[:,0]<=3).mean(),r5=100*(a[:,0]>=5).mean(),r8=100*(a[:,0]>=8).mean(),r12=100*(a[:,0]>=12).mean(),champ=a[:,1].mean(),last=a[:,2].mean(),sd=a[:,3].mean(),goals=a[:,4].mean())
ai={c:best_club_xi(pl) for c,pl in clubs.items()}
tk=set();hum=draft(4,"fornuftig",rng,tk)
teams,nai=league_arrays(hum,ai,4)
print("Mester forhåndsrang (efter styrke på papiret) og fordeling. 400 sæsoner, 20 hold (4 spillere + 16 AI, Svær).")
print("Indstilling | favorit vinder | mester fra top 3 | mester fra plads 5+ | plads 8+ | plads 12+ | mester-point | sidst | mål")
cfg=[("Kun nuværende støj",0,0,0),("Sæsonheld sd 2",2,0,0),("Sæsonheld sd 3",3,0,0),("Sæsonheld sd 4",4,0,0),("Sæsonheld 3 + formsvingning (sd 2, ρ 0,8)",3,2,0.8),("Sæsonheld 4 + formsvingning (sd 2,5, ρ 0,8)",4,2.5,0.8),("Sæsonheld 5 + formsvingning (sd 3, ρ 0,8)",5,3,0.8)]
for name,s,f,rho in cfg:
    r=sim_league(teams,400,s,f,rho)
    print(f"{name} | {r['fav']:.0f}% | {r['top3']:.0f}% | {r['r5']:.0f}% | {r['r8']:.1f}% | {r['r12']:.1f}% | {r['champ']:.0f} | {r['last']:.0f} | {r['goals']:.2f}")
    sys.stdout.flush()
