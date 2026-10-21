-- Straffeskytter: pen_rank = rækkefølgen på FPL Scouts liste over straffeskytter (opdateret 29. sep 2026), 1 = førstevalg på sin klub.
-- Kun spillere i vores data får en rang (48 stk.); kampmotoren (v1.10) bruger pen_rank som afgørelse ved lighed i pen_taking.
-- Selve opdateringen er kørt direkte i databasen.
alter table public.players add column if not exists pen_rank smallint;
