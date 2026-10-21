-- Multiplayer: fast kampfart for hele spillet (Human v AI og Human v Human), 0,5x til 3x. Sat af admin i lobbyen.
alter table public.games add column if not exists speed_ai numeric not null default 1 check (speed_ai in (0.5, 1, 2, 3));
alter table public.games add column if not exists speed_hh numeric not null default 1 check (speed_hh in (0.5, 1, 2, 3));
-- set_match_speed(p_game, p_ai, p_hh): kun admin, kun i lobbyen. new_season kopierer begge hastigheder. (Se migrationen i databasen.)
