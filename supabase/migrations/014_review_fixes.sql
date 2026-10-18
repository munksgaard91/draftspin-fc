-- Rettelser efter Fables gennemgang (2026-10-18).
-- 1) Hændelser kan ikke dubleres, selv om to serverkørsler spiller samme runde samtidigt.
-- 2) Navne må ikke indeholde < eller > (forsvar i dybden mod XSS; klienten escaper også).
-- 3) Motorversion gemmes sammen med sæsonens hemmelige seed.
-- 4) Admin kan lukke et spil, der hænger.

alter table public.match_events
  add constraint match_events_uniq unique (match_id, minute, type, team, player_id, pen);

alter table public.season_secret add column engine_version text;

create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text, p_display text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1') then raise exception 'Ukendt formation'; end if;
  if p_crest not between 1 and 5 then raise exception 'Ukendt våbenskjold'; end if;
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

create function public.close_game(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update games set status = 'closed' where id = p_game and admin_id = auth.uid() and status in ('lobby', 'draft', 'season');
  if not found then raise exception 'Kun admin kan lukke et spil, der er i gang'; end if;
end $$;
revoke execute on function public.close_game(uuid) from public, anon;
grant execute on function public.close_game(uuid) to authenticated;
