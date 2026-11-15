-- 077: tidsforbrug pr. færdigt spil (Rasmus 2026-11-15). Gemmes, når et spil bliver 'done',
-- og overlever, at spillet slettes efter 7 dage. Vises ikke nogen steder endnu (kun service-rollen kan læse).
create table if not exists public.game_times (
  game_id uuid primary key,
  pace text not null,
  humans integer not null,          -- menneskehold i spillet (inkl. dem, der forlod det)
  humans_left integer not null,     -- heraf forladt undervejs (AI overtog)
  max_players integer not null,
  timer_seconds integer not null,
  respins integer not null,
  speed_ai numeric not null,
  speed_hh numeric not null,
  created_at timestamptz not null,  -- spillet oprettet (lobby åbner)
  draft_start timestamptz,          -- første valg
  draft_end timestamptz,            -- sidste valg
  done_at timestamptz not null,     -- sæsonen slut
  lobby_s integer,                  -- oprettet -> første valg
  draft_s integer,                  -- første -> sidste valg
  season_s integer,                 -- sidste valg -> slut
  total_s integer not null,         -- oprettet -> slut
  seen_first timestamptz,           -- første menneske så slutskærmen (meldt af telefonen)
  seen_last timestamptz,            -- seneste menneske så slutskærmen
  seen_n integer default 0 not null, -- antal meldinger
  logged_at timestamptz default now() not null
);
alter table public.game_times enable row level security;
revoke all on table public.game_times from public, anon, authenticated;

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
    insert into game_times (game_id, pace, humans, humans_left, max_players, timer_seconds, respins, speed_ai, speed_hh,
      created_at, draft_start, draft_end, done_at, lobby_s, draft_s, season_s, total_s)
    values (new.id, new.pace, nh, nl, new.max_players, new.timer_seconds, new.respins, new.speed_ai, new.speed_hh,
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
revoke all on function public._games_log_time() from public, anon, authenticated;

-- AFTER-trigger, så done_at fra games_done_at (BEFORE) er sat
drop trigger if exists games_log_time on public.games;
create trigger games_log_time after update on public.games for each row execute function public._games_log_time();

-- de færdige spil, der stadig findes
insert into public.game_times (game_id, pace, humans, humans_left, max_players, timer_seconds, respins, speed_ai, speed_hh,
  created_at, draft_start, draft_end, done_at, lobby_s, draft_s, season_s, total_s)
select g.id, g.pace, (select count(*) from game_players p where p.game_id = g.id), (select count(left_at) from game_players p where p.game_id = g.id),
  g.max_players, g.timer_seconds, g.respins, g.speed_ai, g.speed_hh, g.created_at, d.d0, d.d1, g.done_at,
  extract(epoch from d.d0 - g.created_at)::int, extract(epoch from d.d1 - d.d0)::int, extract(epoch from g.done_at - d.d1)::int,
  extract(epoch from g.done_at - g.created_at)::int
from games g
cross join lateral (select min(picked_at) d0, max(picked_at) d1 from draft_picks where game_id = g.id) d
where g.status = 'done' and g.done_at is not null
on conflict (game_id) do nothing;

-- telefonen melder, når slutskærmen vises (Quick afspilles først på telefonen, efter at serveren er færdig).
-- Spilletid set fra spilleren = seen_last - created_at.
create or replace function public.log_game_seen(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from game_players where game_id = p_game and user_id = auth.uid()) then return; end if;
  update game_times set seen_first = least(coalesce(seen_first, now()), now()),
    seen_last = greatest(coalesce(seen_last, now()), now()), seen_n = seen_n + 1
  where game_id = p_game and seen_n < 50;
end $$;
revoke all on function public.log_game_seen(uuid) from public, anon;
grant execute on function public.log_game_seen(uuid) to authenticated;
