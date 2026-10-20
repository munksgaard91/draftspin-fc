-- 10 spillere x 11 valg = 110 valg (0-109); før var grænsen 65 (6 spillere)
alter table public.draft_picks drop constraint if exists draft_picks_pick_chk;
alter table public.draft_picks add constraint draft_picks_pick_chk check (pick_number >= 0 and pick_number <= 109);
