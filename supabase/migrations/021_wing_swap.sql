-- LW kan stå på RW og omvendt, med straf (Rasmus 2026-10-18).
create or replace function public.slot_fit(p_pos text, p_slot text) returns int
language sql immutable set search_path = public as $$
  select case
    when p_pos = p_slot then 2
    when p_pos = 'LW' and p_slot = 'LM' then 2
    when p_pos = 'RW' and p_slot = 'RM' then 2
    when (p_pos, p_slot) in (('LB','RB'),('RB','LB'),('DM','CM'),('CM','DM'),('CM','AM'),('AM','CM'),('LW','ST'),('RW','ST'),('ST','LW'),('ST','RW'),('LW','RW'),('RW','LW')) then 1
    else 0 end
$$;
