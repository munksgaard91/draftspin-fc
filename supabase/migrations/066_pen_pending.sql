-- v1.14: en straffe i en menneskekamp venter på spillerens valg af skytte og hjørne, til den afgøres eller runden rykker videre.
alter table public.match_events add column if not exists pending boolean not null default false;
