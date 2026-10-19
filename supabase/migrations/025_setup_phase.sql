-- Ny rækkefølge: lobby (regler, deltagere) først. Admin åbner derefter holdopsætningen (navn, hold, formation) for alle samtidig.
-- Når alle er klar, starter draften automatisk.
alter table public.games add column if not exists setup boolean not null default false;

create or replace function public._begin_draft(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games; ord uuid[];
begin
  select * into g from games where id = p_game for update;
  select array_agg(user_id order by random()) into ord from game_players where game_id = p_game;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = p_game and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8) end
  where id = p_game;
end $$;
revoke all on function public._begin_draft(uuid) from public, anon, authenticated;

create or replace function public._maybe_begin(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'lobby' or not g.setup then return; end if;
  select count(*) into n from game_players where game_id = p_game;
  if n < 1 or n < g.max_players then return; end if;
  if exists (select 1 from game_players where game_id = p_game and (not ready or formation is null)) then return; end if;
  perform _begin_draft(p_game);
end $$;
revoke all on function public._maybe_begin(uuid) from public, anon, authenticated;

create or replace function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g games; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if n < g.max_players then raise exception 'Lobbyen er ikke fuld endnu (% af %)', n, g.max_players; end if;
  if exists (select 1 from game_players where game_id = p_game and (not ready or formation is null)) then raise exception 'Alle skal være klar'; end if;
  perform _begin_draft(p_game);
end $$;

create or replace function public.set_name(p_game uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if length(trim(p_name)) not between 2 and 16 then raise exception 'Dit navn skal være 2 til 16 tegn'; end if;
  if p_name ~ '[<>]' then raise exception 'Navne må ikke indeholde < eller >'; end if;
  update game_players set display_name = trim(p_name) where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
revoke all on function public.set_name(uuid, text) from public, anon;
grant execute on function public.set_name(uuid, text) to authenticated;

create or replace function public.open_setup(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  if g.setup then return; end if;
  select count(*) into n from game_players where game_id = p_game;
  if n < g.max_players then raise exception 'Lobbyen er ikke fuld endnu (% af %)', n, g.max_players; end if;
  if exists (select 1 from game_players where game_id = p_game and display_name is null) then raise exception 'Alle skal have skrevet deres navn'; end if;
  update game_players set ready = false where game_id = p_game;
  update games set setup = true where id = p_game;
end $$;
revoke all on function public.open_setup(uuid) from public, anon;
grant execute on function public.open_setup(uuid) to authenticated;

create or replace function public.set_ready(p_game uuid, p_ready boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  update game_players set ready = p_ready
  where game_id = p_game and user_id = auth.uid() and (not p_ready or (team_name is not null and formation is not null));
  if not found then raise exception 'Gør holdet færdigt først'; end if;
  if p_ready then perform _maybe_begin(p_game); end if;
end $$;

create or replace function public.join_game(p_code text) returns uuid
language plpgsql security definer set search_path = public as $$
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
  if g.status <> 'lobby' or g.setup then raise exception 'Spillet er allerede startet'; end if;
  if g.created_at < now() - interval '6 hours' then raise exception 'Lobbyen er udløbet'; end if;
  if (select count(*) from game_players where game_id = g.id) >= g.max_players then raise exception 'Spillet er fuldt'; end if;
  insert into game_players (game_id, user_id) values (g.id, uid);
  return g.id;
end $$;

create or replace function public.kick_player(p_game uuid, p_user uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game and admin_id = auth.uid() and status = 'lobby' for update;
  if not found then raise exception 'Kun admin kan fjerne spillere i lobbyen'; end if;
  if p_user = auth.uid() then raise exception 'Admin kan ikke fjerne sig selv'; end if;
  delete from game_players where game_id = p_game and user_id = p_user;
  if g.setup then
    update games set max_players = greatest(1, (select count(*) from game_players where game_id = p_game)) where id = p_game;
    perform _maybe_begin(p_game);
  end if;
end $$;

create or replace function public.leave_game(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game and status = 'lobby' and admin_id <> auth.uid() for update;
  if not found then raise exception 'Du kan ikke forlade spillet nu'; end if;
  delete from game_players where game_id = p_game and user_id = auth.uid();
  if g.setup then
    update games set max_players = greatest(1, (select count(*) from game_players where game_id = p_game)) where id = p_game;
    perform _maybe_begin(p_game);
  end if;
end $$;

create or replace function public.update_game_settings(p_game uuid, p_max int, p_timer int, p_show boolean, p_pace text default null) returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' and not setup for update;
  if not found then raise exception 'Kun admin kan ændre indstillinger i lobbyen'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if p_max < greatest(1, n) or p_max > 6 then raise exception 'Ugyldigt antal spillere'; end if;
  if p_timer not in (0, 30, 60, 90) then raise exception 'Ugyldig tidsgrænse'; end if;
  if p_pace is not null and p_pace not in ('full', 'quick') then raise exception 'Ukendt spiltempo'; end if;
  update games set max_players = p_max, timer_seconds = p_timer, show_ratings = coalesce(p_show, false), pace = coalesce(p_pace, pace) where id = p_game;
end $$;
