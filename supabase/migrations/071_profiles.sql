-- 071: brugere med Google-login (2026-11-08).
-- profiles: én række pr. bruger, der er logget ind (gæster = anonyme brugere har ingen profil).
--   manager_name: unikt (uden forskel på store/små bogstaver), vises for alle.
--   full_name: kun internt. Brugeren kan se sin egen; andre spillere kan aldrig læse den (kun via profiles_public uden kolonnen).
--   name_changed_at: sidste navneskift. Det første navnevalg tæller ikke; derefter maks. 1 skift pr. 30 dage.

create table if not exists public.profiles (
  user_id uuid primary key,
  manager_name text not null,
  full_name text not null,
  color text not null,
  avatar_ver integer,
  name_changed_at timestamptz,
  created_at timestamptz not null default now()
);
create unique index if not exists profiles_manager_name_key on public.profiles (lower(manager_name));
alter table public.profiles enable row level security;
drop policy if exists profiles_own on public.profiles;
create policy profiles_own on public.profiles for select to authenticated using (user_id = auth.uid());
revoke all on public.profiles from public, anon, authenticated;
grant select on public.profiles to authenticated;

-- offentlig visning uden fulde navn (kører som ejeren, så alle kan se managernavn, farve og billede)
create or replace view public.profiles_public as
  select user_id, manager_name, color, avatar_ver from public.profiles;
revoke all on public.profiles_public from public, anon, authenticated;
grant select on public.profiles_public to authenticated;

-- hjælpere
create or replace function public._is_guest() returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select is_anonymous from auth.users where id = auth.uid()), true)
$$;
revoke all on function public._is_guest() from public, anon, authenticated;

create or replace function public._clean_name(p text) returns text language sql immutable as $$
  select regexp_replace(trim(coalesce(p, '')), '\s+', ' ', 'g')
$$;

create or replace function public._check_manager_name(p text) returns text language plpgsql stable security definer set search_path = public, pg_temp as $$
declare n text := _clean_name(p);
begin
  if length(n) not between 2 and 16 then raise exception 'Your manager name must be 2 to 16 characters'; end if;
  if n ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  if exists (select 1 from profiles where lower(manager_name) = lower(n) and user_id <> auth.uid()) then raise exception 'That manager name is taken'; end if;
  return n;
end $$;
revoke all on function public._check_manager_name(text) from public, anon, authenticated;

-- første login: opret profil
create or replace function public.create_profile(p_manager text, p_full text) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare n text; f text := _clean_name(p_full);
  pal text[] := array['#2f6bd9','#c0392b','#2fa39a','#b8913a','#8e44ad','#d35400','#16a085','#c2185b','#3949ab','#00897b','#6d4c41','#e67e22'];
begin
  if auth.uid() is null or _is_guest() then raise exception 'Sign in with Google first'; end if;
  if exists (select 1 from profiles where user_id = auth.uid()) then raise exception 'You already have a profile'; end if;
  n := _check_manager_name(p_manager);
  if length(f) not between 2 and 60 then raise exception 'Please enter your full name'; end if;
  if f ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  insert into profiles (user_id, manager_name, full_name, color) values (auth.uid(), n, f, pal[1 + floor(random() * array_length(pal, 1))::int]);
end $$;

-- skift managernavn: maks. 1 gang pr. 30 dage (det første valg tæller ikke)
create or replace function public.set_manager_name(p_name text) returns timestamptz language plpgsql security definer set search_path = public, pg_temp as $$
declare n text; last timestamptz; cur text;
begin
  select name_changed_at, manager_name into last, cur from profiles where user_id = auth.uid() for update;
  if not found then raise exception 'You don''t have a profile'; end if;
  n := _check_manager_name(p_name);
  if n = cur then return last; end if;
  if last is not null and last > now() - interval '30 days' then
    raise exception 'You can change your name again on %', to_char(last + interval '30 days', 'FMDD Mon YYYY');
  end if;
  update profiles set manager_name = n, name_changed_at = now() where user_id = auth.uid();
  update game_players gp set display_name = n from games g where g.id = gp.game_id and gp.user_id = auth.uid() and g.status <> 'closed';
  return now();
end $$;

-- profilbillede: billedet ligger i bucket avatars som <user_id>.jpg; versionen tvinger telefoner til at hente det nye
create or replace function public.set_avatar(p_has boolean) returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update profiles set avatar_ver = case when p_has then coalesce(avatar_ver, 0) + 1 else null end where user_id = auth.uid();
  if not found then raise exception 'You don''t have a profile'; end if;
end $$;

revoke all on function public.create_profile(text, text) from public, anon, authenticated;
revoke all on function public.set_manager_name(text) from public, anon, authenticated;
revoke all on function public.set_avatar(boolean) from public, anon, authenticated;
grant execute on function public.create_profile(text, text) to authenticated;
grant execute on function public.set_manager_name(text) to authenticated;
grant execute on function public.set_avatar(boolean) to authenticated;

-- i spil bruges managernavnet altid for brugere, der er logget ind (gæster skriver selv et navn)
create or replace function public.set_name(p_game uuid, p_name text)
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare mn text;
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'The game isn''t in the lobby'; end if;
  select manager_name into mn from profiles where user_id = auth.uid();
  if mn is null then
    if length(trim(p_name)) not between 2 and 16 then raise exception 'Your name must be 2 to 16 characters'; end if;
    if p_name ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  end if;
  update game_players set display_name = coalesce(mn, trim(p_name)) where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'You''re not in the game'; end if;
end $function$;

create or replace function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest integer, p_formation text, p_display text default null::text, p_tag text default null::text)
 returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $function$
declare tg text := nullif(upper(trim(coalesce(p_tag, ''))), ''); mn text;
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'The game isn''t in the lobby'; end if;
  if p_formation not in ('4-3-3','4-3-3 (D)','4-3-3 (O)','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-4-3','5-3-2','5-3-2 (D)','5-3-2 (O)','5-3-1-1','4-2-1-3','4-1-3-2','4-3-3 (F)','4-5-1 (F)','4-2-4','3-5-2 (F)','5-4-1','4-5-1','4-4-1-1','4-3-1-2','4-2-2-2','3-4-2-1','4-3-2-1','3-4-1-2','3-1-4-2','4-4-2 (D)','3-4-2-1 (D)','4-2-3-1 (W)') then raise exception 'Unknown formation'; end if;
  if p_crest not between 1 and 12 then raise exception 'Unknown crest'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Invalid colour code'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Choose two different colours'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Team name must be 2 to 22 characters'; end if;
  if tg is not null and tg !~ '^[A-ZÆØÅ0-9]{2,3}$' then raise exception 'The abbreviation must be 2 to 3 letters or numbers'; end if;
  select manager_name into mn from profiles where user_id = auth.uid();
  if mn is null and p_display is not null and length(trim(p_display)) not between 2 and 16 then raise exception 'Your name must be 2 to 16 characters'; end if;
  if p_name ~ '[<>]' or (mn is null and coalesce(p_display, '') ~ '[<>]') then raise exception 'Names can''t contain < or >'; end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, crest_tag = tg, ready = false,
    display_name = coalesce(mn, case when p_display is null then display_name else trim(p_display) end)
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'You''re not in the game'; end if;
end $function$;

-- billeder: offentlig læsning, men kun brugere med profil må skrive, og kun deres egen fil
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 262144, array['image/jpeg'])
on conflict (id) do update set public = true, file_size_limit = 262144, allowed_mime_types = array['image/jpeg'];
drop policy if exists avatars_insert on storage.objects;
drop policy if exists avatars_update on storage.objects;
drop policy if exists avatars_delete on storage.objects;
drop policy if exists avatars_select on storage.objects;
create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg' and exists (select 1 from public.profiles p where p.user_id = auth.uid()));
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg')
  with check (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and name = auth.uid()::text || '.jpg');

-- oprydning af anonyme brugere: uændret (brugere med Google er ikke anonyme og slettes aldrig automatisk)
