-- Nye spil starter med 0 respins (tidligere 1). Igangværende spil beholder deres værdi.
alter table public.games alter column respins set default 0;
