-- Flere våbenskjolde: 1 til 10.
create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text, p_display text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1') then raise exception 'Ukendt formation'; end if;
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
