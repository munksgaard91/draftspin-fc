-- 078: "Instant" afspilning i Quick game (Rasmus 2026-11-15). Kun visningen på telefonen ændres: Instant viser
-- kun resultaterne runde for runde. Resultaterne er de samme, og Hall of Fame tæller det som Quick (pace).
alter table public.games add column if not exists playback text not null default 'normal';
alter table public.games drop constraint if exists games_playback_check;
alter table public.games add constraint games_playback_check check (playback in ('normal', 'instant'));
alter table public.game_times add column if not exists playback text;

create or replace function public.set_playback(p_game uuid, p_playback text) returns void
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' and not setup for update;
  if not found then raise exception 'Only the admin can change settings in the lobby'; end if;
  if p_playback not in ('normal', 'instant') then raise exception 'Invalid playback'; end if;
  update games set playback = p_playback where id = p_game;
end $$;
revoke all on function public.set_playback(uuid, text) from public, anon, authenticated;
grant execute on function public.set_playback(uuid, text) to authenticated;

-- næste sæson beholder valget
CREATE OR REPLACE FUNCTION public.new_season(p_game uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  g games; ng uuid; c text; i int; ord uuid[];
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Only the admin can start a new season'; end if;
  if g.status <> 'done' then raise exception 'The season isn''t over yet'; end if;
  if g.next_game_id is not null then return g.next_game_id; end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from games where code = c);
  end loop;
  insert into games (code, admin_id, league, season, mode, max_players, timer_seconds, show_ratings, pace, season_no, respins, speed_ai, speed_hh, playback)
  values (c, g.admin_id, g.league, g.season, g.mode, g.max_players, g.timer_seconds, g.show_ratings, g.pace, g.season_no + 1, g.respins, g.speed_ai, g.speed_hh, g.playback)
  returning id into ng;
  insert into game_players (game_id, user_id, team_name, color1, color2, crest, crest_tag, formation, display_name, ready)
  select ng, user_id, team_name, color1, color2, crest, crest_tag, formation, display_name, true from game_players where game_id = p_game and left_at is null;
  select array_agg(user_id order by random()) into ord from game_players where game_id = ng;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = ng and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8 + coalesce(array_length(ord, 1), 1)) end
  where id = ng;
  update games set next_game_id = ng where id = p_game;
  return ng;
end $function$
;

CREATE OR REPLACE FUNCTION public.open_setup(p_game uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
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
end $function$
;

CREATE OR REPLACE FUNCTION public.pfit(p_pos text, p_alts jsonb, p_slot text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public'
AS $function$
  select greatest(public.slot_fit(p_pos, p_slot), case when coalesce(p_alts -> p_slot ->> 'nat', 'false') = 'true' then 2 else 0 end)
$function$
;

-- spilletiden gemmer også afspilningen
create or replace function public._games_log_time() returns trigger
language plpgsql security definer set search_path = public as $$
declare d0 timestamptz; d1 timestamptz; nh int; nl int; fin timestamptz;
begin
  if new.status = 'done' and old.status is distinct from 'done' then
   -- må ALDRIG stoppe sæsonslut: enhver fejl her ignoreres (spillet bliver 'done' uanset)
   begin
    fin := coalesce(new.done_at, now());
    select min(picked_at), max(picked_at) into d0, d1 from draft_picks where game_id = new.id;
    select count(*), count(left_at) into nh, nl from game_players where game_id = new.id;
    insert into game_times (game_id, pace, humans, humans_left, max_players, timer_seconds, respins, speed_ai, speed_hh, playback,
      created_at, draft_start, draft_end, done_at, lobby_s, draft_s, season_s, total_s)
    values (new.id, new.pace, nh, nl, new.max_players, new.timer_seconds, new.respins, new.speed_ai, new.speed_hh, new.playback,
      new.created_at, d0, d1, fin,
      extract(epoch from d0 - new.created_at)::int, extract(epoch from d1 - d0)::int, extract(epoch from fin - d1)::int,
      extract(epoch from fin - new.created_at)::int)
    on conflict (game_id) do nothing;
   exception when others then
    raise warning '_games_log_time: %', sqlerrm;
   end;
  end if;
  return new;
end $$;
