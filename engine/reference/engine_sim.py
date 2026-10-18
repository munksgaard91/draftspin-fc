import json,random,os,sys
import numpy as np
P=json.load(open(os.path.expanduser("~/Desktop/draftspin-fc/data/players_pl_2026-27.json")))
FORMS={'4-3-3':['LW','ST','RW','CM','DM','CM','LB','CB','CB','RB','GK'],'4-4-2':['ST','ST','LW','CM','CM','RW','LB','CB','CB','RB','GK'],'4-2-3-1':['ST','LW','AM','RW','DM','DM','LB','CB','CB','RB','GK'],'4-1-4-1':['ST','LW','CM','CM','RW','DM','LB','CB','CB','RB','GK'],'4-1-2-1-2':['ST','ST','AM','CM','CM','DM','LB','CB','CB','RB','GK'],'3-5-2':['ST','ST','LW','CM','DM','CM','RW','CB','CB','CB','GK'],'3-4-3':['LW','ST','RW','CM','CM','LB','CB','CB','CB','RB','GK'],'5-3-2':['ST','ST','CM','DM','CM','LB','CB','CB','CB','RB','GK'],'5-4-1':['ST','LW','CM','CM','RW','LB','CB','CB','CB','RB','GK']}
WOFF={'ST':.24,'LW':.16,'RW':.16,'AM':.16,'CM':.10,'DM':.04,'LB':.04,'RB':.04,'CB':.02,'GK':0.0}
WDEF={'GK':.28,'CB':.16,'LB':.10,'RB':.10,'DM':.10,'CM':.05,'AM':.01,'LW':.01,'RW':.01,'ST':.01}
def fac(p,slot):
    if p['position']==slot: return 1.0
    a=p.get('alts') or {}
    return a[slot]['factor'] if slot in a else None
clubs={}
for p in P: clubs.setdefault(p['club'],[]).append(p)
def best_xi(pl,form):
    slots=FORMS[form];used=set();xi=[None]*11
    for i in sorted(range(11),key=lambda i:(slots[i]!='GK',slots[i])):
        c=[(p['rating']*fac(p,slots[i]),k) for k,p in enumerate(pl) if k not in used and fac(p,slots[i]) is not None]
        if not c: return None
        v,k=max(c);used.add(k);xi[i]=(slots[i],pl[k]['rating'],fac(pl[k],slots[i]),pl[k].get('consistency') or 12)
    return xi
def xi_strength(xi): return sum(r*f for _,r,f,_ in xi)/11
def best_club_xi(pl):
    b=None
    for f in FORMS:
        x=best_xi(pl,f)
        if x and (b is None or xi_strength(x)>xi_strength(b)): b=x
    return b
def to_arrays(xi):
    pos=[x[0] for x in xi]
    return (np.array([x[1] for x in xi],float),np.array([x[2] for x in xi],float),np.array([6-0.25*(x[3]-1) for x in xi],float),np.array([WOFF[p] for p in pos]),np.array([WDEF[p] for p in pos]))
def draft(nh,mode,rng,taken_out):
    forms=[rng.choice(list(FORMS)) for _ in range(nh)];squad=[[None]*11 for _ in range(nh)];taken=set()
    for rnd in range(11):
        o=list(range(nh)) if rnd%2==0 else list(range(nh))[::-1]
        for u in o:
            open_=[i for i in range(11) if squad[u][i] is None];slots=FORMS[forms[u]]
            cl=[c for c,pl in clubs.items() if any(p['name'] not in taken and fac(p,slots[i]) is not None for p in pl for i in open_)]
            c=rng.choice(cl)
            cand=[(p['rating']*fac(p,slots[i]),p,i) for p in clubs[c] if p['name'] not in taken for i in open_ if fac(p,slots[i]) is not None]
            cand.sort(key=lambda x:-x[0])
            v,p,i=cand[0] if mode=="best" else rng.choice(cand[:3])
            squad[u][i]=(slots[i],p['rating'],fac(p,slots[i]),p.get('consistency') or 12);taken.add(p['name'])
    taken_out.update(taken)
    return squad
def league_arrays(humans,ai,nh):
    # 16/..: fjern de nh svageste AI
    order=sorted(ai,key=lambda c:xi_strength(ai[c]))[nh:]
    teams=[ai[c] for c in order]+humans
    return teams,len(order)
def simulate(teams,k,muH,muA,rng,seasons=1,shared_sd=1.5,pen_rate=0.29,pen_conv=0.80,pen_inh=False):
    N=len(teams);A=[to_arrays(t) for t in teams]
    R=np.stack([a[0] for a in A]);F=np.stack([a[1] for a in A]);S=np.stack([a[2] for a in A]);WO=np.stack([a[3] for a in A]);WD=np.stack([a[4] for a in A])
    hh,aa=np.where(~np.eye(N,dtype=bool));M=len(hh)
    pts_all=[];gf=gt=0;H=D=Aw=0;tot=0
    for _ in range(seasons):
        def side(t):
            eps=rng.normal(0,1,(M,11))*S[t]
            Rm=(R[t]+eps)*F[t]+rng.normal(0,shared_sd,(M,1))
            off=(WO[t]*Rm).sum(1)/WO[t].sum(1);de=(WD[t]*Rm).sum(1)/WD[t].sum(1)
            return off,de
        offH,defH=side(hh);offA,defA=side(aa)
        lH=muH*np.exp((offH-defA)/k);lA=muA*np.exp((offA-defH)/k)
        gH=rng.poisson(lH);gA=rng.poisson(lA)
        npen=rng.poisson(pen_rate,M);forH=rng.random(M)<lH/(lH+lA)
        sc=rng.binomial(npen,pen_conv)
        gH=gH+np.where(forH,sc,0);gA=gA+np.where(~forH,sc,0)
        pts=np.zeros(N)
        w=gH>gA;d=gH==gA;l=gH<gA
        np.add.at(pts,hh,3*w+1*d);np.add.at(pts,aa,3*l+1*d)
        gdiff=np.zeros(N);np.add.at(gdiff,hh,gH-gA);np.add.at(gdiff,aa,gA-gH)
        pts_all.append((pts,gdiff));tot+=(gH+gA).sum();H+=w.sum();D+=d.sum();Aw+=l.sum()
    n=seasons*M
    return pts_all,{'goals':tot/n,'H':H/n,'D':D/n,'A':Aw/n}
