-- Lobby-funktioner. Alle kræver login (anonym eller e-mail) og kører som security definer.

create function public.create_game(p_league text, p_season text, p_max int, p_timer int, p_show boolean)
returns json language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text; gid uuid; i int;
begin
  if uid is null then raise exception 'Ikke logget ind'; end if;
  if p_league <> 'PL' or p_season <> '2026/2027' then raise exception 'Kun Premier League 2026/2027 er åben'; end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from games where code = c);
  end loop;
  insert into games (code, admin_id, league, season, max_players, timer_seconds, show_ratings)
  values (c, uid, p_league, p_season, p_max, p_timer, coalesce(p_show, false))
  returning id into gid;
  insert into game_players (game_id, user_id) values (gid, uid);
  return json_build_object('id', gid, 'code', c);
end $$;

create function public.join_game(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); g games;
begin
  if uid is null then raise exception 'Ikke logget ind'; end if;
  select * into g from games where code = upper(trim(p_code));
  if not found then raise exception 'Koden findes ikke'; end if;
  if exists (select 1 from game_players where game_id = g.id and user_id = uid) then
    update game_players set last_seen_at = now() where game_id = g.id and user_id = uid;
    if g.admin_id = uid then update games set admin_last_seen = now() where id = g.id; end if;
    return g.id;
  end if;
  if g.status <> 'lobby' then raise exception 'Spillet er allerede startet'; end if;
  if (select count(*) from game_players where game_id = g.id) >= g.max_players then raise exception 'Spillet er fuldt'; end if;
  insert into game_players (game_id, user_id) values (g.id, uid);
  return g.id;
end $$;

create function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from games where id = p_game and status = 'lobby') then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1') then raise exception 'Ukendt formation'; end if;
  if p_crest not between 1 and 5 then raise exception 'Ukendt våbenskjold'; end if;
  if p_c1 = p_c2 then raise exception 'Vælg to forskellige farver'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Holdnavn skal være 2 til 22 tegn'; end if;
  update game_players set team_name = trim(p_name), color1 = p_c1, color2 = p_c2, crest = p_crest, formation = p_formation, ready = false
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;

create function public.set_ready(p_game uuid, p_ready boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from games where id = p_game and status = 'lobby') then raise exception 'Spillet er ikke i lobbyen'; end if;
  update game_players set ready = p_ready
  where game_id = p_game and user_id = auth.uid() and (not p_ready or (team_name is not null and formation is not null));
  if not found then raise exception 'Gør holdet færdigt først'; end if;
end $$;

create function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g games; ord uuid[];
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  if exists (select 1 from game_players where game_id = p_game and not ready) then raise exception 'Alle skal være klar'; end if;
  select array_agg(user_id order by random()) into ord from game_players where game_id = p_game;
  update game_players gp set draft_pos = x.n from (select u, row_number() over () as n from unnest(ord) as u) x where gp.game_id = p_game and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null, turn_deadline = null where id = p_game;
end $$;

create function public.touch_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  update game_players set last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  update games set admin_last_seen = now() where id = p_game and admin_id = auth.uid();
end $$;

revoke execute on all functions in schema public from public, anon;
grant execute on function public.create_game, public.join_game, public.update_team, public.set_ready, public.start_game, public.touch_game, public.is_member to authenticated;
