-- DraftSpin FC: grundskema. Alle skrivninger sker via funktioner (security definer); klienter kan kun læse.

create table public.clubs (
  code text primary key,
  name text not null
);

create table public.players (
  id int generated always as identity primary key,
  club text not null references public.clubs(code),
  number int not null,
  name text not null,
  pos text not null check (pos in ('GK','RB','CB','LB','DM','CM','AM','LW','RW','ST')),
  age int,
  rating int not null,
  rating_base int,
  boost numeric(3,1) not null default 0,
  pa int,
  alts jsonb not null default '{}',
  consistency int,
  important_matches int,
  pen_taking int,
  yellow_w numeric,
  red_w numeric,
  card_risk int,
  fpl_goals int, fpl_assists int, fpl_yellow int, fpl_red int, fpl_minutes int, fpl_cs int,
  fm_uid bigint,
  unique (club, number)
);

create table public.games (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  admin_id uuid not null,
  league text not null default 'PL',
  season text not null default '2026/2027',
  mode text not null default 'league',
  max_players int not null default 6 check (max_players between 1 and 6),
  timer_seconds int not null default 0 check (timer_seconds in (0,30,60,90)),
  show_ratings boolean not null default false,
  status text not null default 'lobby' check (status in ('lobby','draft','season','done','closed')),
  draft_order uuid[],
  current_pick int not null default 0,
  current_club text,
  turn_deadline timestamptz,
  current_round int not null default 0,
  admin_last_seen timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.game_players (
  game_id uuid not null references public.games(id) on delete cascade,
  user_id uuid not null,
  team_name text,
  color1 text,
  color2 text,
  crest int,
  formation text,
  ready boolean not null default false,
  auto_ready boolean not null default false,
  draft_pos int,
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (game_id, user_id)
);

create table public.draft_picks (
  game_id uuid not null references public.games(id) on delete cascade,
  pick_number int not null,
  user_id uuid not null,
  player_id int not null references public.players(id),
  slot int not null,
  picked_at timestamptz not null default now(),
  primary key (game_id, pick_number),
  unique (game_id, player_id),
  unique (game_id, user_id, slot)
);

create index on public.game_players (user_id);

create function public.is_member(g uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.game_players where game_id = g and user_id = auth.uid())
$$;

alter table public.clubs enable row level security;
alter table public.players enable row level security;
alter table public.games enable row level security;
alter table public.game_players enable row level security;
alter table public.draft_picks enable row level security;

create policy clubs_read on public.clubs for select to anon, authenticated using (true);
create policy players_read on public.players for select to anon, authenticated using (true);
create policy games_read on public.games for select to authenticated using (public.is_member(id));
create policy game_players_read on public.game_players for select to authenticated using (public.is_member(game_id));
create policy draft_picks_read on public.draft_picks for select to authenticated using (public.is_member(game_id));

-- ingen insert/update/delete-politikker: kun funktioner må skrive

alter publication supabase_realtime add table public.games, public.game_players, public.draft_picks;

insert into public.clubs (code, name) values
 ('ARS','Arsenal'),('AVL','Aston Villa'),('BOU','Bournemouth'),('BRE','Brentford'),('BHA','Brighton'),
 ('CHE','Chelsea'),('COV','Coventry City'),('CRY','Crystal Palace'),('EVE','Everton'),('FUL','Fulham'),
 ('HUL','Hull City'),('IPS','Ipswich Town'),('LEE','Leeds United'),('LIV','Liverpool'),('MCI','Manchester City'),
 ('MUN','Manchester United'),('NEW','Newcastle United'),('NFO','Nottingham Forest'),('SUN','Sunderland'),('TOT','Tottenham Hotspur');
