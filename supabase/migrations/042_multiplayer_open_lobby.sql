-- Multiplayer: lobbyen åbner med plads til 10, og antallet spillere fastlægges, når admin trykker Start (mindst 2). Solo (1 spiller) er uændret.
alter table public.games drop constraint if exists games_max_players_check;
alter table public.games add constraint games_max_players_check check (max_players >= 1 and max_players <= 10);

create or replace function public.open_setup(p_game uuid)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Only the admin can start'; end if;
  if g.status <> 'lobby' then raise exception 'Already started'; end if;
  if g.setup then return; end if;
  select count(*) into n from game_players where game_id = p_game;
  if g.max_players > 1 then
    -- multiplayer: alle der er kommet ind, spiller med
    if n < 2 then raise exception 'At least 2 players are needed to start'; end if;
    update games set max_players = n where id = p_game;
  end if;
  update game_players set ready = false where game_id = p_game;
  update games set setup = true where id = p_game;
end $$;

create or replace function public.update_game_settings(p_game uuid, p_max integer, p_timer integer, p_show boolean, p_pace text default null::text, p_respins integer default null::integer)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare n int;
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' and not setup for update;
  if not found then raise exception 'Only the admin can change settings in the lobby'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if p_max < greatest(1, n) or p_max > 10 then raise exception 'Invalid number of players'; end if;
  if p_timer not in (0, 30, 60, 90) then raise exception 'Invalid time limit'; end if;
  if p_pace is not null and p_pace not in ('full', 'quick') then raise exception 'Unknown pace'; end if;
  if p_respins is not null and p_respins not between 0 and 3 then raise exception 'Respins must be 0 to 3'; end if;
  update games set max_players = p_max, timer_seconds = p_timer, show_ratings = coalesce(p_show, false), pace = coalesce(p_pace, pace), respins = coalesce(p_respins, respins) where id = p_game;
end $$;
