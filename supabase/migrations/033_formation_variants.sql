-- 4-3-3 findes i to udgaver: (D) med en DM og (O) med en AM. Den gamle nøgle '4-3-3' virker stadig i igangværende spil.
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
    when '3-4-1-2' then array['ST','ST','AM','CM','CM','LB','CB','CB','CB','RB','GK']
  end
$$;

drop function if exists public.update_team(uuid, text, text, text, int, text, text, text);
create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text, p_display text default null, p_tag text default null)
returns void language plpgsql security definer set search_path = public as $$
declare tg text := nullif(upper(trim(coalesce(p_tag, ''))), '');
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-3-3 (D)','4-3-3 (O)','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1','4-5-1','4-4-1-1','4-3-1-2','4-2-2-2','3-4-2-1','4-3-2-1','3-4-1-2') then raise exception 'Ukendt formation'; end if;
  if p_crest not between 1 and 12 then raise exception 'Ukendt våbenskjold'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Ugyldig farvekode'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Vælg to forskellige farver'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Holdnavn skal være 2 til 22 tegn'; end if;
  if tg is not null and tg !~ '^[A-ZÆØÅ0-9]{2,3}$' then raise exception 'Forkortelsen skal være 2 til 3 bogstaver eller tal'; end if;
  if p_display is not null and length(trim(p_display)) not between 2 and 16 then raise exception 'Dit navn skal være 2 til 16 tegn'; end if;
  if p_name ~ '[<>]' or coalesce(p_display, '') ~ '[<>]' then raise exception 'Navne må ikke indeholde < eller >'; end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, crest_tag = tg, ready = false,
    display_name = case when p_display is null then display_name else trim(p_display) end
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
revoke all on function public.update_team(uuid, text, text, text, int, text, text, text) from public, anon;
grant execute on function public.update_team(uuid, text, text, text, int, text, text, text) to authenticated;
