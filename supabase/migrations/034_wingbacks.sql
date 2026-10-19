-- Wingbacks: LWB og RWB som nye positioner. Spillere med 19/20 i FM på både wingback og back er naturlige på begge (alts.<LWB|RWB>.nat).
alter table public.players drop constraint if exists players_pos_check;
alter table public.players add constraint players_pos_check check (pos in ('GK','RB','CB','LB','LWB','RWB','DM','CM','AM','LW','RW','ST'));

create or replace function public.slot_fit(p_pos text, p_slot text) returns int
language sql immutable set search_path = public as $$
  select case
    when p_pos = p_slot then 2
    when p_pos = 'LW' and p_slot = 'LM' then 2
    when p_pos = 'RW' and p_slot = 'RM' then 2
    when (p_pos, p_slot) in (('LB','RB'),('RB','LB'),('DM','CM'),('CM','DM'),('CM','AM'),('AM','CM'),('LW','ST'),('RW','ST'),('ST','LW'),('ST','RW'),('LW','RW'),('RW','LW'),
      ('LB','LWB'),('RB','RWB'),('LWB','LB'),('RWB','RB'),('LWB','LM'),('LWB','LW'),('RWB','RM'),('RWB','RW')) then 1
    else 0 end
$$;

create or replace function public.formation_slots(f text) returns text[]
language sql immutable set search_path = public as $$
  select case f
    when '4-3-3' then array['LW','ST','RW','CM','DM','CM','LB','CB','CB','RB','GK']
    when '4-3-3 (D)' then array['LW','ST','RW','CM','DM','CM','LB','CB','CB','RB','GK']
    when '4-3-3 (O)' then array['LW','ST','RW','CM','AM','CM','LB','CB','CB','RB','GK']
    when '4-4-2' then array['ST','ST','LM','CM','CM','RM','LB','CB','CB','RB','GK']
    when '4-2-3-1' then array['ST','LW','AM','RW','DM','DM','LB','CB','CB','RB','GK']
    when '4-1-4-1' then array['ST','LM','CM','CM','RM','DM','LB','CB','CB','RB','GK']
    when '4-1-2-1-2' then array['ST','ST','AM','CM','CM','DM','LB','CB','CB','RB','GK']
    when '3-5-2' then array['ST','ST','LWB','CM','DM','CM','RWB','CB','CB','CB','GK']
    when '3-4-3' then array['LW','ST','RW','CM','CM','LWB','CB','CB','CB','RWB','GK']
    when '5-3-2' then array['ST','ST','CM','DM','CM','LWB','CB','CB','CB','RWB','GK']
    when '5-4-1' then array['ST','LM','CM','CM','RM','LWB','CB','CB','CB','RWB','GK']
    when '4-5-1' then array['ST','LM','CM','DM','CM','RM','LB','CB','CB','RB','GK']
    when '4-4-1-1' then array['ST','AM','LM','CM','CM','RM','LB','CB','CB','RB','GK']
    when '4-3-1-2' then array['ST','ST','AM','CM','DM','CM','LB','CB','CB','RB','GK']
    when '4-2-2-2' then array['ST','ST','AM','AM','DM','DM','LB','CB','CB','RB','GK']
    when '3-4-2-1' then array['ST','AM','AM','CM','CM','LWB','CB','CB','CB','RWB','GK']
    when '4-3-2-1' then array['ST','AM','AM','CM','DM','CM','LB','CB','CB','RB','GK']
    when '3-4-1-2' then array['ST','ST','AM','CM','CM','LWB','CB','CB','CB','RWB','GK']
  end
$$;

update public.players p set pos = v.pos from (values (28127067,'RWB'),(93144073,'LWB'),(28127165,'RWB'),(27164405,'LWB')) v(uid, pos) where p.fm_uid = v.uid;
update public.players p set alts = coalesce(p.alts, '{}'::jsonb) || jsonb_build_object(v.pos2, jsonb_build_object('fit', v.fit, 'factor', 1, 'nat', true))
from (values (43425831,'LWB',20),(28121371,'LWB',19),(2000027527,'RWB',19),(29129043,'LWB',19),(2000262551,'LWB',19),(2000006104,'LWB',20),(37060598,'LWB',19),(37060598,'RWB',19),(18110463,'LWB',19),(2000136195,'RWB',20),(28108034,'RWB',19),(49056279,'RWB',20),(29125191,'LWB',20),(28047407,'LWB',20),(28111503,'LWB',20),(67245412,'RWB',19),(29128510,'LWB',20),(28095582,'RWB',19),(37039748,'RWB',19),(18073919,'RWB',20),(29165599,'LWB',19),(29125264,'LWB',19),(29113873,'RWB',19),(29175220,'LWB',19),(2000047224,'RWB',20),(29175561,'LWB',19),(29179790,'RWB',20),(93064996,'LWB',20),(49041156,'LWB',20),(2000011135,'LWB',20),(28113827,'RWB',20),(49047563,'LWB',20),(2000280805,'LWB',19),(2000108690,'LWB',20),(16283628,'RWB',20),(28115790,'RWB',20),(76050664,'RWB',20),(28090340,'LWB',19),(28090340,'RWB',19),(2000188077,'LWB',20),(43426042,'LWB',20),(67268144,'RWB',19),(2000049214,'LWB',19)) v(uid, pos2, fit) where p.fm_uid = v.uid;
