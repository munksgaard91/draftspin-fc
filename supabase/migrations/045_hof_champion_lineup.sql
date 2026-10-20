-- Mesterholdets opstilling gemmes i Hall of Fame: formation + 11 spillere (navn, kortnavn) i slot-rækkefølge.
alter table public.hof_teams add column if not exists formation text, add column if not exists lineup jsonb;
