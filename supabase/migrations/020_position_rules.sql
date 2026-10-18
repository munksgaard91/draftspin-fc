-- Nye positionsregler (Rasmus 2026-10-18): naturlige pladser uden straf, få pladser med fast straf, resten ikke tilladt.
-- Spillerens position -> plads:  natural (2) / straf (1) / ikke tilladt (0)
--   GK: kun GK. CB: kun CB. LB: LB, RB(straf). RB: RB, LB(straf). DM: DM, CM(straf). CM: CM, DM(straf), AM(straf).
--   AM: AM, CM(straf). LW: LW og LM, ST(straf). RW: RW og RM, ST(straf). ST: ST, LW(straf), RW(straf).
-- Straffen (faktor 0,90 på ratingen i motoren) vises aldrig i appen; kun farverne grøn/gul/grå ved valg af plads.
create or replace function public.slot_fit(p_pos text, p_slot text) returns int
language sql immutable set search_path = public as $$
  select case
    when p_pos = p_slot then 2
    when p_pos = 'LW' and p_slot = 'LM' then 2
    when p_pos = 'RW' and p_slot = 'RM' then 2
    when (p_pos, p_slot) in (('LB','RB'),('RB','LB'),('DM','CM'),('CM','DM'),('CM','AM'),('AM','CM'),('LW','ST'),('RW','ST'),('ST','LW'),('ST','RW')) then 1
    else 0 end
$$;

-- slot_ok bevarer sin signatur, men bruger nu kun reglerne (alts-data bruges ikke mere)
create or replace function public.slot_ok(p_pos text, p_alts jsonb, p_slot text) returns boolean
language sql immutable set search_path = public as $$
  select public.slot_fit(p_pos, p_slot) > 0
$$;

create or replace function public.formation_slots(f text) returns text[]
language sql immutable set search_path = public as $$
  select case f
    when '4-3-3' then array['LW','ST','RW','CM','DM','CM','LB','CB','CB','RB','GK']
    when '4-4-2' then array['ST','ST','LM','CM','CM','RM','LB','CB','CB','RB','GK']
    when '4-2-3-1' then array['ST','LW','AM','RW','DM','DM','LB','CB','CB','RB','GK']
    when '4-1-4-1' then array['ST','LM','CM','CM','RM','DM','LB','CB','CB','RB','GK']
    when '4-1-2-1-2' then array['ST','ST','AM','CM','CM','DM','LB','CB','CB','RB','GK']
    when '3-5-2' then array['ST','ST','LM','CM','DM','CM','RM','CB','CB','CB','GK']
    when '3-4-3' then array['LW','ST','RW','CM','CM','LB','CB','CB','CB','RB','GK']
    when '5-3-2' then array['ST','ST','CM','DM','CM','LB','CB','CB','CB','RB','GK']
    when '5-4-1' then array['ST','LM','CM','CM','RM','LB','CB','CB','CB','RB','GK']
    when '4-5-1' then array['ST','LM','CM','DM','CM','RM','LB','CB','CB','RB','GK']
    when '4-4-1-1' then array['ST','AM','LM','CM','CM','RM','LB','CB','CB','RB','GK']
    when '4-3-1-2' then array['ST','ST','AM','CM','DM','CM','LB','CB','CB','RB','GK']
    when '4-2-2-2' then array['ST','ST','AM','AM','DM','DM','LB','CB','CB','RB','GK']
    when '3-4-2-1' then array['ST','AM','AM','CM','CM','LB','CB','CB','CB','RB','GK']
    when '4-3-2-1' then array['ST','AM','AM','CM','DM','CM','LB','CB','CB','RB','GK']
  end
$$;

-- Auto-valg: tilfældig blandt de tre bedste (rating x straf 0,90 for gul plads), hver spiller med sin bedste plads
create or replace function public._best_pick(p_game uuid, p_user uuid, p_club text) returns table (player_id int, slot int)
language sql volatile set search_path = public as $$
  with cand as (
    select pl.id as pid, s.i::int as sl,
           pl.rating * case when slot_fit(pl.pos, s.pos) = 2 then 1.0 else 0.90 end as score,
           (slot_fit(pl.pos, s.pos) = 2) as exact
    from players pl
    join game_players gp on gp.game_id = p_game and gp.user_id = p_user
    cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
    where pl.club = p_club
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
      and slot_fit(pl.pos, s.pos) > 0
  ), best as (
    select distinct on (pid) pid, sl, score from cand order by pid, score desc, exact desc, sl asc
  ), top3 as (
    select pid, sl from best order by score desc, pid asc limit 3
  )
  select pid, sl from top3 order by random() limit 1
$$;
revoke execute on function public._best_pick(uuid, uuid, text) from public, anon, authenticated;
revoke execute on function public.slot_fit(text, text) from public, anon;
grant execute on function public.slot_fit(text, text) to authenticated;

create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text, p_display text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1','4-5-1','4-4-1-1','4-3-1-2','4-2-2-2','3-4-2-1','4-3-2-1') then raise exception 'Ukendt formation'; end if;
  if p_crest not between 1 and 10 then raise exception 'Ukendt våbenskjold'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Ugyldig farvekode'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Vælg to forskellige farver'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Holdnavn skal være 2 til 22 tegn'; end if;
  if p_display is not null and length(trim(p_display)) not between 2 and 16 then raise exception 'Dit navn skal være 2 til 16 tegn'; end if;
  if p_name ~ '[<>]' or coalesce(p_display, '') ~ '[<>]' then raise exception 'Navne må ikke indeholde < eller >'; end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, ready = false,
    display_name = case when p_display is null then display_name else trim(p_display) end
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
