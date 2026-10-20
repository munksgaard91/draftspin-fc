-- Antal respins i spillet gemmes med rekorderne, så Hall of Fame kan sorteres efter det.
alter table public.hof_teams add column if not exists respins integer;
alter table public.hof_players add column if not exists respins integer;
