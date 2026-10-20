-- 3.0.1: rettelser fra Fables audit af 3.0.0.

-- F5: kolonnen blev tilføjet uden om migrationerne; dokumenteres her.
alter table public.hof_players add column if not exists yellows int not null default 0;

-- F16: smidte spillere kan ikke joine igen.
create table if not exists public.game_bans (
  game_id uuid not null references public.games(id) on delete cascade,
  user_id uuid not null,
  primary key (game_id, user_id)
);
alter table public.game_bans enable row level security;
revoke all on public.game_bans from anon, authenticated;

create or replace function public.join_game(p_code text) returns uuid
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare uid uuid := auth.uid(); g games;
begin
  if uid is null then raise exception 'Not signed in'; end if;
  select * into g from games where code = upper(trim(p_code)) for update;
  if not found then raise exception 'The code doesn''t exist'; end if;
  if exists (select 1 from game_players where game_id = g.id and user_id = uid) then
    update game_players set last_seen_at = now() where game_id = g.id and user_id = uid;
    if g.admin_id = uid then update games set admin_last_seen = now() where id = g.id; end if;
    return g.id;
  end if;
  if g.status <> 'lobby' or g.setup then raise exception 'The game has already started'; end if;
  if exists (select 1 from game_bans where game_id = g.id and user_id = uid) then raise exception 'You were removed from this game'; end if;
  if g.created_at < now() - interval '6 hours' then raise exception 'The lobby has expired'; end if;
  if (select count(*) from game_players where game_id = g.id) >= g.max_players then raise exception 'The game is full'; end if;
  insert into game_players (game_id, user_id) values (g.id, uid);
  return g.id;
end $$;

-- F23: falder en multiplayer-opsætning under 2 spillere, gå tilbage til lobbyen i stedet for at starte en solo-draft.
create or replace function public.kick_player(p_game uuid, p_user uuid) returns void
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; n int;
begin
  select * into g from games where id = p_game and admin_id = auth.uid() and status = 'lobby' for update;
  if not found then raise exception 'Only the admin can remove players in the lobby'; end if;
  if p_user = auth.uid() then raise exception 'The admin can''t remove themselves'; end if;
  delete from game_players where game_id = p_game and user_id = p_user;
  insert into game_bans (game_id, user_id) values (p_game, p_user) on conflict do nothing;
  if g.setup then
    select count(*) into n from game_players where game_id = p_game;
    if g.max_players > 1 and n < 2 then
      update games set setup = false, max_players = 10 where id = p_game;
      update game_players set ready = false where game_id = p_game;
    else
      update games set max_players = greatest(1, n) where id = p_game;
      perform _maybe_begin(p_game);
    end if;
  end if;
end $$;

create or replace function public.leave_game(p_game uuid) returns void
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; n int;
begin
  select * into g from games where id = p_game and status = 'lobby' and admin_id <> auth.uid() for update;
  if not found then raise exception 'You can''t leave the game now'; end if;
  delete from game_players where game_id = p_game and user_id = auth.uid();
  if g.setup then
    select count(*) into n from game_players where game_id = p_game;
    if g.max_players > 1 and n < 2 then
      update games set setup = false, max_players = 10 where id = p_game;
      update game_players set ready = false where game_id = p_game;
    else
      update games set max_players = greatest(1, n) where id = p_game;
      perform _maybe_begin(p_game);
    end if;
  end if;
end $$;

-- F7: "New season" arver også respins. F18: første frist får plads til rækkefølge-animationen (+ n sekunder).
create or replace function public.new_season(p_game uuid)
returns uuid language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
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
  insert into games (code, admin_id, league, season, mode, max_players, timer_seconds, show_ratings, pace, season_no, respins)
  values (c, g.admin_id, g.league, g.season, g.mode, g.max_players, g.timer_seconds, g.show_ratings, g.pace, g.season_no + 1, g.respins)
  returning id into ng;
  insert into game_players (game_id, user_id, team_name, color1, color2, crest, crest_tag, formation, display_name, ready)
  select ng, user_id, team_name, color1, color2, crest, crest_tag, formation, display_name, true from game_players where game_id = p_game;
  select array_agg(user_id order by random()) into ord from game_players where game_id = ng;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = ng and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8 + coalesce(array_length(ord, 1), 1)) end
  where id = ng;
  update games set next_game_id = ng where id = p_game;
  return ng;
end $$;

create or replace function public._begin_draft(p_game uuid)
returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; ord uuid[];
begin
  select * into g from games where id = p_game for update;
  select array_agg(user_id order by random()) into ord from game_players where game_id = p_game;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = p_game and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8 + coalesce(array_length(ord, 1), 1)) end
  where id = p_game;
end $$;

-- F4 + F9: tving kun et valg, når spilleren på tur har været væk (admin: 2 min), eller fristen er overskredet.
create or replace function public.claim_timeout(p_game uuid, p_force boolean default false)
returns boolean language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; u uuid; bp record; away boolean;
begin
  if not is_member(p_game) then raise exception 'You''re not in the game'; end if;
  select * into g from games where id = p_game for update;
  if g.status <> 'draft' then return false; end if;
  u := turn_user(g);
  if not (g.turn_deadline is not null and now() >= g.turn_deadline) then
    away := exists (select 1 from game_players where game_id = p_game and user_id = u and last_seen_at < now() - interval '2 minutes');
    if not (p_force and g.admin_id = auth.uid() and away) then return false; end if;
  end if;
  if g.current_club is null then
    perform _spin(g);
    select * into g from games where id = p_game;
  end if;
  select * into bp from _best_pick(p_game, u, g.current_club);
  if bp.player_id is null then raise exception 'No usable player'; end if;
  perform _do_pick(g, u, bp.player_id, bp.slot);
  return true;
end $$;

-- F1: ingen push til en spiller, der har appen åben (set de sidste 45 s; hjerteslaget er 30 s).
create or replace function public._notify_turn() returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare u uuid; sec text;
begin
  if new.status <> 'draft' or coalesce(array_length(new.draft_order, 1), 0) < 2 then return new; end if;
  if old.status = 'draft' and old.current_pick is not distinct from new.current_pick then return new; end if;
  u := turn_user(new);
  if u is null or not exists (select 1 from push_subs where user_id = u) then return new; end if;
  if exists (select 1 from game_players where game_id = new.id and user_id = u and last_seen_at > now() - interval '45 seconds') then return new; end if;
  select value into sec from push_config where key = 'secret';
  if sec is null then return new; end if;
  perform net.http_post(
    url := 'https://apagcfedizgjnnuefzfo.supabase.co/functions/v1/push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', sec),
    body := jsonb_build_object('user_id', u, 'title', 'PL Draft', 'body', 'It''s your turn in the draft', 'tag', 'turn-' || new.id),
    timeout_milliseconds := 10000
  );
  return new;
exception when others then
  return new;
end $$;

-- F4 + F8: auto-valg når spilleren på tur har været væk i 5 min (også uden timer); færdige spil beholdes 7 dage.
create or replace function public._cron_tick()
returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; u uuid; bp record;
begin
  update games set status = 'closed'
  where (status = 'lobby'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '10 minutes'))
     or (status = 'draft'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '60 minutes'))
     or (status = 'season' and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '14 days'));

  delete from games gm
  where (gm.status = 'closed' and coalesce((select max(gp.last_seen_at) from game_players gp where gp.game_id = gm.id), gm.created_at) < now() - interval '24 hours')
     or (gm.status = 'done' and coalesce(gm.done_at, (select max(gp.last_seen_at) from game_players gp where gp.game_id = gm.id), gm.created_at) < now() - interval '7 days')
     or (gm.status = 'lobby' and gm.created_at < now() - interval '1 day');

  for g in
    select * from games gm
    where gm.status = 'draft'
      and exists (select 1 from game_players gp where gp.game_id = gm.id and gp.last_seen_at > now() - interval '5 minutes')
      and ((gm.turn_deadline is not null and gm.turn_deadline < now() - interval '90 seconds')
           or exists (select 1 from game_players gp where gp.game_id = gm.id and gp.user_id = turn_user(gm) and gp.last_seen_at < now() - interval '5 minutes'))
    for update skip locked
  loop
    u := turn_user(g);
    if g.current_club is null then
      perform _spin(g);
      select * into g from games where id = g.id;
    end if;
    select * into bp from _best_pick(g.id, u, g.current_club);
    if bp.player_id is not null then perform _do_pick(g, u, bp.player_id, bp.slot); end if;
  end loop;
end $$;
