-- 073: "Continue game" + rettelser fra Fable-auditten af brugere (2026-11-14).
-- Kun det nyeste ufærdige spil gemmes pr. spiller. Starter man et nyt, kasseres det gamle:
--   solospil (eller ingen andre mennesker tilbage) slettes; i spil med andre forlader man spillet (left_at),
--   de andre spiller videre, og admin-rollen går videre til en anden spiller.

alter table public.game_players add column if not exists left_at timestamptz;

-- navne: fjern usynlige tegn (zero-width, bløde bindestreger) og samle mellemrum
create or replace function public._clean_name(p text) returns text language sql immutable as $$
  select regexp_replace(trim(regexp_replace(coalesce(p, ''), '[\u200B-\u200F\u2060\uFEFF\u00AD]', '', 'g')), '\s+', ' ', 'g')
$$;

-- managernavn: "Deleted user" er reserveret
create or replace function public._check_manager_name(p text) returns text language plpgsql stable security definer set search_path = public, pg_temp as $$
declare n text := _clean_name(p);
begin
  if length(n) not between 2 and 16 then raise exception 'Your manager name must be 2 to 16 characters'; end if;
  if n ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  if lower(n) = 'deleted user' then raise exception 'That manager name is taken'; end if;
  if exists (select 1 from profiles where lower(manager_name) = lower(n) and user_id <> auth.uid()) then raise exception 'That manager name is taken'; end if;
  return n;
end $$;
revoke all on function public._check_manager_name(text) from public, anon, authenticated;

-- gæstenavne: ikke en brugers managernavn og ikke "Deleted user"
create or replace function public._check_guest_name(p text) returns text language plpgsql stable security definer set search_path = public, pg_temp as $$
declare n text := _clean_name(p);
begin
  if length(n) not between 2 and 16 then raise exception 'Your name must be 2 to 16 characters'; end if;
  if n ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  if lower(n) = 'deleted user' or exists (select 1 from profiles where lower(manager_name) = lower(n)) then
    raise exception 'That name belongs to a signed-in manager. Please pick another';
  end if;
  return n;
end $$;
revoke all on function public._check_guest_name(text) from public, anon, authenticated;

-- en bruger med Google skal have oprettet sin profil, før der kan spilles
create or replace function public._need_profile() returns void language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not _is_guest() and not exists (select 1 from profiles where user_id = auth.uid()) then
    raise exception 'Create your manager profile first';
  end if;
end $$;
revoke all on function public._need_profile() from public, anon, authenticated;

-- første login: samme navn på samme tid giver en pæn fejl i stedet for en rå databasefejl
create or replace function public.create_profile(p_manager text, p_full text) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare n text; f text := _clean_name(p_full);
  pal text[] := array['#2f6bd9','#c0392b','#2fa39a','#b8913a','#8e44ad','#d35400','#16a085','#c2185b','#3949ab','#00897b','#6d4c41','#e67e22'];
begin
  if auth.uid() is null or _is_guest() then raise exception 'Sign in with Google first'; end if;
  if exists (select 1 from profiles where user_id = auth.uid()) then raise exception 'You already have a profile'; end if;
  n := _check_manager_name(p_manager);
  if length(f) not between 2 and 60 then raise exception 'Please enter your full name'; end if;
  if f ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  begin
    insert into profiles (user_id, manager_name, full_name, color) values (auth.uid(), n, f, pal[1 + floor(random() * array_length(pal, 1))::int]);
  exception when unique_violation then raise exception 'That manager name is taken';
  end;
end $$;

-- navneskift slår også igennem i Hall of Fame
create or replace function public.set_manager_name(p_name text) returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare n text; last timestamptz; cur text;
begin
  select name_changed_at, manager_name into last, cur from profiles where user_id = auth.uid() for update;
  if not found then raise exception 'You don''t have a profile'; end if;
  n := _check_manager_name(p_name);
  if n = cur then return last; end if;
  if last is not null and last > now() - interval '30 days' then
    raise exception 'You can change your name again on %', to_char(last + interval '30 days', 'FMDD Mon YYYY');
  end if;
  begin
    update profiles set manager_name = n, name_changed_at = now() where user_id = auth.uid();
  exception when unique_violation then raise exception 'That manager name is taken';
  end;
  update game_players gp set display_name = n from games g where g.id = gp.game_id and gp.user_id = auth.uid() and g.status <> 'closed';
  update hof_teams set owner = n where user_id = auth.uid();
  update hof_players set owner = n where user_id = auth.uid();
  return now();
end $$;

create or replace function public.set_name(p_game uuid, p_name text)
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare mn text; gn text;
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'The game isn''t in the lobby'; end if;
  select manager_name into mn from profiles where user_id = auth.uid();
  if mn is null then gn := _check_guest_name(p_name); end if;
  update game_players set display_name = coalesce(mn, gn) where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'You''re not in the game'; end if;
end $function$;

create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest integer, p_formation text, p_display text default null::text, p_tag text default null::text)
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare tg text := nullif(upper(trim(coalesce(p_tag, ''))), ''); mn text; gn text;
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'The game isn''t in the lobby'; end if;
  if p_formation not in ('4-3-3','4-3-3 (D)','4-3-3 (O)','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-4-3','5-3-2','5-3-2 (D)','5-3-2 (O)','5-3-1-1','4-2-1-3','4-1-3-2','4-3-3 (F)','4-5-1 (F)','4-2-4','3-5-2 (F)','5-4-1','4-5-1','4-4-1-1','4-3-1-2','4-2-2-2','3-4-2-1','4-3-2-1','3-4-1-2','3-1-4-2','4-4-2 (D)','3-4-2-1 (D)','4-2-3-1 (W)') then raise exception 'Unknown formation'; end if;
  if p_crest not between 1 and 12 then raise exception 'Unknown crest'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Invalid colour code'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Choose two different colours'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Team name must be 2 to 22 characters'; end if;
  if tg is not null and tg !~ '^[A-ZÆØÅ0-9]{2,3}$' then raise exception 'The abbreviation must be 2 to 3 letters or numbers'; end if;
  if p_name ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  select manager_name into mn from profiles where user_id = auth.uid();
  if mn is null and p_display is not null then gn := _check_guest_name(p_display); end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, crest_tag = tg, ready = false,
    display_name = coalesce(mn, gn, display_name)
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'You''re not in the game'; end if;
end $function$;

-- opret/deltag: kræver profil for brugere med Google
create or replace function public.create_game(p_league text, p_season text, p_max integer, p_timer integer, p_show boolean, p_pace text default 'full'::text)
 returns json language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare
  uid uuid := auth.uid();
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text; gid uuid; i int;
begin
  perform _need_profile();
  if p_league <> 'PL' or p_season <> '2026/2027' then raise exception 'Only the Premier League 2026/2027 is open'; end if;
  if p_pace not in ('full', 'quick') then raise exception 'Unknown pace'; end if;
  if (select count(*) from games where admin_id = uid
        and (status = 'draft' or (status = 'lobby' and created_at > now() - interval '6 hours'))) >= 5 then
    raise exception 'You already have 5 active games';
  end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from games where code = c);
  end loop;
  insert into games (code, admin_id, league, season, max_players, timer_seconds, show_ratings, pace)
  values (c, uid, p_league, p_season, p_max, p_timer, coalesce(p_show, false), p_pace)
  returning id into gid;
  insert into game_players (game_id, user_id) values (gid, uid);
  return json_build_object('id', gid, 'code', c);
end $function$;

create or replace function public.join_game(p_code text)
 returns uuid language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare uid uuid := auth.uid(); g games; me game_players;
begin
  perform _need_profile();
  select * into g from games where code = upper(trim(p_code)) for update;
  if not found then raise exception 'The code doesn''t exist'; end if;
  select * into me from game_players where game_id = g.id and user_id = uid;
  if found then
    if me.left_at is not null then raise exception 'You left this game'; end if;
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
end $function$;

-- en spiller, der har forladt spillet, holder ikke spillet i live med hjerteslag
create or replace function public.touch_game(p_game uuid)
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
begin
  update game_players set last_seen_at = now() where game_id = p_game and user_id = auth.uid() and left_at is null;
  update games set admin_last_seen = now() where id = p_game and admin_id = auth.uid();
end $function$;

-- ny sæson: kun spillere, der stadig er med
create or replace function public.new_season(p_game uuid)
 returns uuid language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
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
  insert into games (code, admin_id, league, season, mode, max_players, timer_seconds, show_ratings, pace, season_no, respins, speed_ai, speed_hh)
  values (c, g.admin_id, g.league, g.season, g.mode, g.max_players, g.timer_seconds, g.show_ratings, g.pace, g.season_no + 1, g.respins, g.speed_ai, g.speed_hh)
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
end $function$;

-- draft: står en spiller, der har forladt spillet, for tur, vælger serveren straks for holdet (ingen ventetid for de andre)
create or replace function public._autopick_left(p_game uuid) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare g games; u uuid; bp record; i int := 0;
begin
  if current_setting('dsfc.autopick', true) = '1' then return; end if;
  perform set_config('dsfc.autopick', '1', true);
  -- fejler et automatisk valg, må det aldrig rulle det rigtige valg tilbage, som kaldte os (cron tager det så senere)
  begin
  loop
    i := i + 1;
    exit when i > 120;
    select * into g from games where id = p_game for update;
    exit when not found or g.status <> 'draft';
    u := turn_user(g);
    exit when not exists (select 1 from game_players where game_id = p_game and user_id = u and left_at is not null);
    if g.current_club is null then
      perform _spin(g);
      select * into g from games where id = p_game;
    end if;
    select * into bp from _best_pick(p_game, u, g.current_club);
    exit when bp.player_id is null;
    perform _do_pick(g, u, bp.player_id, bp.slot);
  end loop;
  exception when others then null;
  end;
  perform set_config('dsfc.autopick', '0', true);
end $$;
revoke all on function public._autopick_left(uuid) from public, anon, authenticated;

create or replace function public._do_pick(g games, p_user uuid, p_player integer, p_slot integer)
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare pl players; f text; n int; slotpos text;
begin
  select * into pl from players where id = p_player;
  if not found or pl.club is distinct from g.current_club then raise exception 'That player isn''t from the drawn club'; end if;
  select formation into f from game_players where game_id = g.id and user_id = p_user;
  slotpos := (formation_slots(f))[p_slot];
  if slotpos is null then raise exception 'Invalid spot'; end if;
  if not slot_ok(pl.pos, pl.alts, slotpos) then raise exception 'That player can''t play in that spot'; end if;
  if exists (select 1 from draft_picks where game_id = g.id and player_id = p_player) then raise exception 'That player has already been picked'; end if;
  if exists (select 1 from draft_picks where game_id = g.id and user_id = p_user and slot = p_slot) then raise exception 'That spot is taken'; end if;
  insert into draft_picks (game_id, pick_number, user_id, player_id, slot) values (g.id, g.current_pick, p_user, p_player, p_slot);
  n := array_length(g.draft_order, 1);
  if g.current_pick + 1 >= n * 11 then
    update games set current_pick = current_pick + 1, current_club = null, turn_deadline = null, status = 'season' where id = g.id;
  else
    update games set current_pick = current_pick + 1, current_club = null,
      turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20)) end
    where id = g.id;
    perform _autopick_left(g.id);
  end if;
end $function$;

-- en spiller, der har forladt spillet, kan ikke blive "til stede" igen (fx fra en anden telefon, der stadig viser spillet)
create or replace function public._left_stays_left() returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if old.left_at is not null then
    new.left_at := old.left_at;
    new.last_seen_at := old.last_seen_at;
    new.ready_round := greatest(new.ready_round, old.ready_round);
    new.missed_rounds := greatest(new.missed_rounds, old.missed_rounds);
  end if;
  return new;
end $$;
drop trigger if exists game_players_left_stays on public.game_players;
create trigger game_players_left_stays before update on public.game_players for each row execute function _left_stays_left();

-- "Continue game": et gemt spil lukkes ikke længere efter 10/60 minutter uden nogen til stede.
-- lobby: 6 timer (lobbyer udløber alligevel efter 6 timer), draft: 14 dage som sæsonen.
create or replace function public._cron_tick()
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare g games; u uuid; bp record;
begin
  update games set status = 'closed'
  where (status = 'lobby'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '6 hours'))
     or (status = 'draft'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '14 days'))
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
end $function$;
revoke all on function public._cron_tick() from public, anon, authenticated;

-- kassér ét spil for en spiller (bruges af discard_game og sletning af konto)
create or replace function public._discard_game(p_game uuid, p_uid uuid) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare g games; others int; nxt uuid; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status not in ('lobby', 'draft', 'season') then return; end if;
  select count(*) into others from game_players where game_id = p_game and user_id <> p_uid and left_at is null;
  if others = 0 then
    delete from games where id = p_game;
    return;
  end if;
  if g.status = 'lobby' then
    delete from game_players where game_id = p_game and user_id = p_uid;
    if g.setup then
      select count(*) into n from game_players where game_id = p_game;
      if g.max_players > 1 and n < 2 then
        update games set setup = false, max_players = 10 where id = p_game;
        update game_players set ready = false where game_id = p_game;
      else
        update games set max_players = greatest(1, n) where id = p_game;
      end if;
    end if;
  else
    -- holdet bliver i sæsonen (AI vælger/klarmelder for det), men tæller ikke i Hall of Fame
    update game_players set left_at = now(), last_seen_at = now() - interval '1 day', missed_rounds = greatest(missed_rounds, 99),
      start_ready = true, ready_round = greatest(ready_round, g.current_round)
    where game_id = p_game and user_id = p_uid;
  end if;
  if g.admin_id = p_uid then
    select user_id into nxt from game_players where game_id = p_game and user_id <> p_uid and left_at is null order by last_seen_at desc, joined_at limit 1;
    update games set admin_id = nxt, admin_last_seen = now() where id = p_game;
  end if;
  if g.status = 'lobby' and g.setup then perform _maybe_begin(p_game); end if;
  if g.status = 'draft' then perform _autopick_left(p_game); end if;
end $$;
revoke all on function public._discard_game(uuid, uuid) from public, anon, authenticated;

-- "Start nyt spil" efter bekræftelse: det spil, man fik vist og bekræftede, kasseres (kaldes EFTER det nye spil er oprettet)
create or replace function public.discard_game(p_game uuid) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from game_players where game_id = p_game and user_id = auth.uid() and left_at is null) then return; end if;
  perform _discard_game(p_game, auth.uid());
end $$;
revoke all on function public.discard_game(uuid) from public, anon, authenticated;
grant execute on function public.discard_game(uuid) to authenticated;

-- "Continue game": det nyeste ufærdige spil, man stadig er med i
create or replace function public.my_game() returns json language sql stable security definer set search_path = public, pg_temp as $$
  select json_build_object('id', g.id, 'code', g.code, 'status', g.status, 'setup', g.setup, 'pace', g.pace, 'round', g.current_round,
           'pick', g.current_pick, 'picks_total', coalesce(array_length(g.draft_order, 1), 0) * 11, 'max', g.max_players,
           'team', gp.team_name, 'humans', (select count(*) from game_players x where x.game_id = g.id and x.left_at is null))
  from games g join game_players gp on gp.game_id = g.id and gp.user_id = auth.uid() and gp.left_at is null
  where g.status in ('lobby', 'draft', 'season')
  order by g.created_at desc limit 1
$$;
revoke all on function public.my_game() from public, anon, authenticated;
grant execute on function public.my_game() to authenticated;

-- sletning af konto: alt i databasen i én transaktion (motoren sletter bagefter billedet og selve brugeren)
create or replace function public.delete_account_data(p_uid uuid) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare r record;
begin
  if (select is_anonymous from auth.users where id = p_uid) is distinct from false then raise exception 'Guests don''t have an account'; end if;
  delete from hof_players where user_id = p_uid;
  delete from hof_teams where user_id = p_uid;
  delete from profiles where user_id = p_uid;
  -- igangværende spil: samme regel som "start nyt spil" (solospil slettes, ellers forlader man spillet, og admin går videre)
  for r in select game_id from game_players where user_id = p_uid order by game_id loop
    perform _discard_game(r.game_id, p_uid);
  end loop;
  -- afsluttede/lukkede spil: solospil slettes, i spil med andre fjernes navnet
  delete from games g where exists (select 1 from game_players gp where gp.game_id = g.id and gp.user_id = p_uid)
    and not exists (select 1 from game_players gp where gp.game_id = g.id and gp.user_id <> p_uid);
  update game_players set display_name = 'Deleted user' where user_id = p_uid;
  -- afsluttede spil med andre: admin går videre, så de andre kan starte en ny sæson
  update games g set admin_id = (select gp.user_id from game_players gp where gp.game_id = g.id and gp.user_id <> p_uid and gp.left_at is null order by gp.last_seen_at desc limit 1)
  where g.admin_id = p_uid and exists (select 1 from game_players gp where gp.game_id = g.id and gp.user_id <> p_uid and gp.left_at is null);
end $$;
revoke all on function public.delete_account_data(uuid) from public, anon, authenticated;
grant execute on function public.delete_account_data(uuid) to service_role;

-- motoren slår profiler op ved sæsonslut (hvem er bruger, hvad hedder de)
grant select on public.profiles to service_role;

-- en spiller, der har forladt spillet, er ikke længere medlem (kan hverken vælge, klarmelde eller læse spillet)
create or replace function public.is_member(g uuid) returns boolean language sql stable security definer set search_path to 'public', 'pg_temp' as $function$
  select exists (select 1 from public.game_players where game_id = g and user_id = auth.uid() and left_at is null)
$function$;
