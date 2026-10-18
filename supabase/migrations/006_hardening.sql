-- Audit-rettelser (Argon, 2026-10-18): låsning i lobbyen, validering, kick/leave, admin-tving, kortere frist før spin, constraints.

alter table public.draft_picks
  add constraint draft_picks_slot_chk check (slot between 1 and 11),
  add constraint draft_picks_pick_chk check (pick_number between 0 and 65);
create index on public.players (club);

create or replace function public.create_game(p_league text, p_season text, p_max int, p_timer int, p_show boolean)
returns json language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text; gid uuid; i int;
begin
  if uid is null then raise exception 'Ikke logget ind'; end if;
  if p_league <> 'PL' or p_season <> '2026/2027' then raise exception 'Kun Premier League 2026/2027 er åben'; end if;
  if (select count(*) from games where admin_id = uid
        and (status = 'draft' or (status = 'lobby' and created_at > now() - interval '6 hours'))) >= 5 then
    raise exception 'Du har allerede 5 aktive spil';
  end if;
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

create or replace function public.join_game(p_code text)
returns uuid language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); g games;
begin
  if uid is null then raise exception 'Ikke logget ind'; end if;
  select * into g from games where code = upper(trim(p_code)) for update;
  if not found then raise exception 'Koden findes ikke'; end if;
  if exists (select 1 from game_players where game_id = g.id and user_id = uid) then
    update game_players set last_seen_at = now() where game_id = g.id and user_id = uid;
    if g.admin_id = uid then update games set admin_last_seen = now() where id = g.id; end if;
    return g.id;
  end if;
  if g.status <> 'lobby' then raise exception 'Spillet er allerede startet'; end if;
  if g.created_at < now() - interval '6 hours' then raise exception 'Lobbyen er udløbet'; end if;
  if (select count(*) from game_players where game_id = g.id) >= g.max_players then raise exception 'Spillet er fuldt'; end if;
  insert into game_players (game_id, user_id) values (g.id, uid);
  return g.id;
end $$;

create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1') then raise exception 'Ukendt formation'; end if;
  if p_crest not between 1 and 5 then raise exception 'Ukendt våbenskjold'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Ugyldig farvekode'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Vælg to forskellige farver'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Holdnavn skal være 2 til 22 tegn'; end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, ready = false
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;

create or replace function public.set_ready(p_game uuid, p_ready boolean)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  update game_players set ready = p_ready
  where game_id = p_game and user_id = auth.uid() and (not p_ready or (team_name is not null and formation is not null));
  if not found then raise exception 'Gør holdet færdigt først'; end if;
end $$;

create function public.kick_player(p_game uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' for update;
  if not found then raise exception 'Kun admin kan fjerne spillere i lobbyen'; end if;
  if p_user = auth.uid() then raise exception 'Admin kan ikke fjerne sig selv'; end if;
  delete from game_players where game_id = p_game and user_id = p_user;
end $$;

create function public.leave_game(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' and admin_id <> auth.uid() for update;
  if not found then raise exception 'Du kan ikke forlade spillet nu'; end if;
  delete from game_players where game_id = p_game and user_id = auth.uid();
end $$;

create function public.update_game_settings(p_game uuid, p_max int, p_timer int, p_show boolean) returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' for update;
  if not found then raise exception 'Kun admin kan ændre indstillinger i lobbyen'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if p_max < greatest(1, n) or p_max > 6 then raise exception 'Ugyldigt antal spillere'; end if;
  if p_timer not in (0, 30, 60, 90) then raise exception 'Ugyldig tidsgrænse'; end if;
  update games set max_players = p_max, timer_seconds = p_timer, show_ratings = coalesce(p_show, false) where id = p_game;
end $$;

-- Frist før spin er højst 20 s, så en tur ikke kan blive dobbelt så lang.
create or replace function public._do_pick(g public.games, p_user uuid, p_player int, p_slot int) returns void
language plpgsql security definer set search_path = public as $$
declare pl players; f text; n int; slotpos text;
begin
  select * into pl from players where id = p_player;
  if not found or pl.club is distinct from g.current_club then raise exception 'Spilleren er ikke fra den trukne klub'; end if;
  select formation into f from game_players where game_id = g.id and user_id = p_user;
  slotpos := (formation_slots(f))[p_slot];
  if slotpos is null then raise exception 'Ugyldig plads'; end if;
  if not slot_ok(pl.pos, pl.alts, slotpos) then raise exception 'Spilleren kan ikke spille på den plads'; end if;
  if exists (select 1 from draft_picks where game_id = g.id and player_id = p_player) then raise exception 'Spilleren er allerede valgt'; end if;
  if exists (select 1 from draft_picks where game_id = g.id and user_id = p_user and slot = p_slot) then raise exception 'Pladsen er optaget'; end if;
  insert into draft_picks (game_id, pick_number, user_id, player_id, slot) values (g.id, g.current_pick, p_user, p_player, p_slot);
  n := array_length(g.draft_order, 1);
  if g.current_pick + 1 >= n * 11 then
    update games set current_pick = current_pick + 1, current_club = null, turn_deadline = null, status = 'season' where id = g.id;
  else
    update games set current_pick = current_pick + 1, current_club = null,
      turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20)) end
    where id = g.id;
  end if;
end $$;

create or replace function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g games; ord uuid[];
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  if exists (select 1 from game_players where game_id = p_game and (not ready or formation is null)) then raise exception 'Alle skal være klar'; end if;
  select array_agg(user_id order by random()) into ord from game_players where game_id = p_game;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = p_game and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8) end
  where id = p_game;
end $$;

-- claim_timeout: admin kan tvinge auto-valg, også uden tidsgrænse.
drop function public.claim_timeout(uuid);
create function public.claim_timeout(p_game uuid, p_force boolean default false) returns boolean
language plpgsql security definer set search_path = public as $$
declare g games; u uuid; bp record;
begin
  if not is_member(p_game) then raise exception 'Du er ikke med i spillet'; end if;
  select * into g from games where id = p_game for update;
  if g.status <> 'draft' then return false; end if;
  if not (p_force and g.admin_id = auth.uid()) then
    if g.turn_deadline is null or now() < g.turn_deadline then return false; end if;
  end if;
  u := turn_user(g);
  if g.current_club is null then
    perform _spin(g);
    select * into g from games where id = p_game;
  end if;
  select * into bp from _best_pick(p_game, u, g.current_club);
  if bp.player_id is null then raise exception 'Ingen brugbar spiller'; end if;
  perform _do_pick(g, u, bp.player_id, bp.slot);
  return true;
end $$;

create or replace function public._best_pick(p_game uuid, p_user uuid, p_club text) returns table (player_id int, slot int)
language sql stable set search_path = public as $$
  select pl.id, s.i::int
  from players pl
  join game_players gp on gp.game_id = p_game and gp.user_id = p_user
  cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
  where pl.club = p_club
    and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
    and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
    and slot_ok(pl.pos, pl.alts, s.pos)
  order by pl.rating * case when pl.pos = s.pos then 1.0 else coalesce((pl.alts -> s.pos ->> 'factor')::numeric, 0.6) end desc,
           (pl.pos = s.pos) desc, s.i asc, pl.id asc
  limit 1
$$;

revoke execute on function public.kick_player, public.leave_game, public.update_game_settings, public.claim_timeout from public, anon;
grant execute on function public.kick_player, public.leave_game, public.update_game_settings, public.claim_timeout to authenticated;
revoke execute on function public.turn_user, public.slot_ok, public.formation_slots from authenticated;
