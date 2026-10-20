import json
d=json.load(open('/Users/munksgaard/Desktop/draftspin-fc/data/players_pl_2026-27.json'))
VALID={'GK','RB','CB','LB','LWB','RWB','DM','CM','AM','LM','RM','LW','RW','ST'}
out=[]
for i,p in enumerate(d):
    pos=p.get('position') if p.get('position') in VALID else p.get('guess_pos')
    if pos not in VALID: continue
    out.append({'id':i+1,'club':p['club'],'name':p['name'],'pos':pos,'alts':p.get('alts') or {},'rating':p['rating'],'consistency':p.get('consistency'),'pen_taking':p.get('pen_taking'),'yellow_w':p.get('yellow_w'),'red_w':p.get('red_w')})
json.dump(out,open('players.json','w'))
print(len(out))
