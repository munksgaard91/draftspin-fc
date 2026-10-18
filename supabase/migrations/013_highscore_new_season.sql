-- Spillernavn, Highscore (rekorder på tværs af alle færdige sæsoner) og ny sæson med samme gruppe.

alter table public.game_players add column display_name text;
alter table public.games add column season_no int not null default 1;
alter table public.games add column next_game_id uuid;

-- update_team får et valgfrit spillernavn (ejer af holdet)
drop function public.update_team(uuid, text, text, text, int, text);
create function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest int, p_formation text, p_display text default null)
returns void language plpgsql security definer set search_path = public as $$
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'Spillet er ikke i lobbyen'; end if;
  if p_formation not in ('4-3-3','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-5-2','3-4-3','5-3-2','5-4-1') then raise exception 'Ukendt formation'; end if;
  if p_crest not between 1 and 5 then raise exception 'Ukendt våbenskjold'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Ugyldig farvekode'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Vælg to forskellige farver'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Holdnavn skal være 2 til 22 tegn'; end if;
  if p_display is not null and length(trim(p_display)) not between 2 and 16 then raise exception 'Dit navn skal være 2 til 16 tegn'; end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, ready = false,
    display_name = case when p_display is null then display_name else trim(p_display) end
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
revoke execute on function public.update_team(uuid, text, text, text, int, text, text) from public, anon;
grant execute on function public.update_team(uuid, text, text, text, int, text, text) to authenticated;

-- Highscore: et øjebliksbillede pr. færdig sæson. Ingen fremmednøgle til games, så rekorderne består, selv om et gammelt spil ryddes væk.
create table public.hof_teams (
  id bigint generated always as identity primary key,
  game_id uuid not null,
  team_key text not null,
  league text not null default 'PL',
  season text not null,
  season_no int not null default 1,
  user_id uuid,
  team_name text not null,
  owner text,
  players int not null,
  pos int not null,
  points int not null,
  w int not null, d int not null, l int not null,
  gf int not null, ga int not null,
  win_streak int not null default 0,
  big_win_margin int not null default 0,
  big_win_score text,
  big_win_text text,
  champion boolean not null default false,
  created_at timestamptz not null default now(),
  unique (game_id, team_key)
);
create table public.hof_players (
  id bigint generated always as identity primary key,
  game_id uuid not null,
  player_id int not null references public.players(id),
  league text not null default 'PL',
  season text not null,
  season_no int not null default 1,
  user_id uuid,
  team_name text not null,
  owner text,
  goals int not null default 0,
  assists int not null default 0,
  clean_sheets int not null default 0,
  reds int not null default 0,
  best_match_goals int not null default 0,
  best_match_text text,
  created_at timestamptz not null default now(),
  unique (game_id, player_id)
);
alter table public.hof_teams enable row level security;
alter table public.hof_players enable row level security;
create policy hof_teams_read on public.hof_teams for select to authenticated using (true);
create policy hof_players_read on public.hof_players for select to authenticated using (true);
grant select on public.hof_teams, public.hof_players to authenticated;
grant all on public.hof_teams, public.hof_players to service_role;
grant all on all sequences in schema public to service_role;
grant select, update on public.games to service_role;

-- Ny sæson med samme gruppe: admin opretter et nyt spil med de samme hold, og draften starter straks.
create function public.new_season(p_game uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  g games; ng uuid; c text; i int; ord uuid[];
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte en ny sæson'; end if;
  if g.status <> 'done' then raise exception 'Sæsonen er ikke slut endnu'; end if;
  if g.next_game_id is not null then return g.next_game_id; end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from games where code = c);
  end loop;
  insert into games (code, admin_id, league, season, mode, max_players, timer_seconds, show_ratings, pace, season_no)
  values (c, g.admin_id, g.league, g.season, g.mode, g.max_players, g.timer_seconds, g.show_ratings, g.pace, g.season_no + 1)
  returning id into ng;
  insert into game_players (game_id, user_id, team_name, color1, color2, crest, formation, display_name, ready)
  select ng, user_id, team_name, color1, color2, crest, formation, display_name, true from game_players where game_id = p_game;
  select array_agg(user_id order by random()) into ord from game_players where game_id = ng;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = ng and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8) end
  where id = ng;
  update games set next_game_id = ng where id = p_game;
  return ng;
end $$;
revoke execute on function public.new_season(uuid) from public, anon;
grant execute on function public.new_season(uuid) to authenticated;
