-- Spillerbilleder: players.face_id = FM26 unique_id (bruges som filnavn i den offentlige bucket 'faces', <face_id>.webp, 96 px).
-- Mapping club+number -> face_id ligger i data/face_ids.json (9 nye spillere har intet billede og får en silhuet).
-- Selve billederne ligger IKKE i git. Tabelopdateringen og bucketen er kørt direkte i databasen.
alter table public.players add column if not exists face_id bigint;
insert into storage.buckets (id, name, public) values ('faces', 'faces', true) on conflict (id) do nothing;
