-- Tillægstid i 2. halvleg (1-9 minutter, i snit 4), bestemt af motoren pr. kamp. Gamle kampe har null og vises som 4.
alter table public.matches add column if not exists added_time smallint check (added_time between 1 and 9);
