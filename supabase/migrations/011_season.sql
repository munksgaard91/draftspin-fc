-- Sæson: hold, opstillinger, kampe, hændelser og hemmeligt held. Kampmotoren kører i en serverfunktion (edge function "engine").

alter table public.game_players add column ready_round int not null default 0;

create table public.season_teams (
  game_id uuid not null references public.games(id) on delete cascade,
  team_key text not null,
  kind text not null check (kind in ('human', 'ai')),
  user_id uuid,
  club text,
  name text not null,
  color1 text,
  color2 text,
  crest int,
  formation text not null,
  primary key (game_id, team_key)
);

create table public.season_lineups (
  game_id uuid not null references public.games(id) on delete cascade,
  team_key text not null,
  slot int not null check (slot between 1 and 11),
  player_id int not null references public.players(id),
  primary key (game_id, team_key, slot)
);

create table public.matches (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games(id) on delete cascade,
  round int not null check (round between 1 and 38),
  home_key text not null,
  away_key text not null,
  home_goals int,
  away_goals int,
  played boolean not null default false,
  unique (game_id, round, home_key)
);
create index on public.matches (game_id, round);

create table public.match_events (
  id bigint generated always as identity primary key,
  game_id uuid not null references public.games(id) on delete cascade,
  match_id bigint not null references public.matches(id) on delete cascade,
  minute int not null,
  type text not null check (type in ('goal', 'yellow', 'red', 'second_yellow', 'pen_miss', 'clean_sheet')),
  team text not null check (team in ('h', 'a')),
  player_id int references public.players(id),
  assist_id int references public.players(id),
  pen boolean not null default false,
  detail text
);
create index on public.match_events (game_id, match_id);

-- Hemmeligt held og seed. Ingen politikker og ingen rettigheder til klienter: kun serveren (service role) kan læse og skrive.
create table public.season_secret (
  game_id uuid primary key references public.games(id) on delete cascade,
  seed text not null,
  luck jsonb not null,
  dark text,
  unlucky text,
  created_at timestamptz not null default now()
);

alter table public.season_teams enable row level security;
alter table public.season_lineups enable row level security;
alter table public.matches enable row level security;
alter table public.match_events enable row level security;
alter table public.season_secret enable row level security;

create policy season_teams_read on public.season_teams for select to authenticated using (public.is_member(game_id));
create policy season_lineups_read on public.season_lineups for select to authenticated using (public.is_member(game_id));
create policy matches_read on public.matches for select to authenticated using (public.is_member(game_id));
create policy match_events_read on public.match_events for select to authenticated using (public.is_member(game_id));

grant select on public.season_teams, public.season_lineups, public.matches, public.match_events to authenticated;
grant all on public.season_teams, public.season_lineups, public.matches, public.match_events, public.season_secret to service_role;
grant all on all sequences in schema public to service_role;
grant select, update on public.games to service_role;
grant select, update on public.game_players to service_role;
grant select on public.players, public.draft_picks to service_role;
revoke all on public.season_secret from anon, authenticated;

alter publication supabase_realtime add table public.matches, public.match_events;

-- En spiller trykker "Næste kamp" for den runde, der er i gang. Når alle har trykket, kalder appen serverfunktionen, som spiller næste runde.
create function public.ready_round(p_game uuid, p_round int) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game;
  if not found or g.status <> 'season' or p_round <> g.current_round then raise exception 'Runden er ikke i gang'; end if;
  update game_players set ready_round = p_round, last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
revoke execute on function public.ready_round from public, anon;
grant execute on function public.ready_round to authenticated;
