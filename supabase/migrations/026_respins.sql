-- Antal respins pr. spiller (0-3) kan vælges i spilreglerne.
alter table public.games add column if not exists respins int not null default 1;
alter table public.games drop constraint if exists games_respins_chk;
alter table public.games add constraint games_respins_chk check (respins between 0 and 3);
alter table public.game_players add column if not exists respins_used int not null default 0;
update public.game_players set respins_used = 1 where respin_used;
alter table public.game_players drop column if exists respin_used;

create or replace function public.respin(p_game uuid) returns text
language plpgsql security definer set search_path = public as $$
declare g games; c text;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'draft' then raise exception 'Draften kører ikke'; end if;
  if turn_user(g) is distinct from auth.uid() then raise exception 'Det er ikke din tur'; end if;
  if g.current_club is null then raise exception 'Spin hjulet først'; end if;
  if exists (select 1 from game_players where game_id = p_game and user_id = auth.uid() and respins_used >= g.respins) then raise exception 'Du har brugt dine respins'; end if;
  select club into c from _clubs_for(p_game, auth.uid()) club where club <> g.current_club order by random() limit 1;
  if c is null then raise exception 'Ingen anden klub har en brugbar spiller'; end if;
  update game_players set respins_used = respins_used + 1, last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  update games set current_club = c,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => timer_seconds + 4) end
  where id = p_game;
  return c;
end $$;

drop function if exists public.update_game_settings(uuid, int, int, boolean, text);
create or replace function public.update_game_settings(p_game uuid, p_max int, p_timer int, p_show boolean, p_pace text default null, p_respins int default null) returns void
language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' and not setup for update;
  if not found then raise exception 'Kun admin kan ændre indstillinger i lobbyen'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if p_max < greatest(1, n) or p_max > 6 then raise exception 'Ugyldigt antal spillere'; end if;
  if p_timer not in (0, 30, 60, 90) then raise exception 'Ugyldig tidsgrænse'; end if;
  if p_pace is not null and p_pace not in ('full', 'quick') then raise exception 'Ukendt spiltempo'; end if;
  if p_respins is not null and p_respins not between 0 and 3 then raise exception 'Respins skal være 0 til 3'; end if;
  update games set max_players = p_max, timer_seconds = p_timer, show_ratings = coalesce(p_show, false), pace = coalesce(p_pace, pace), respins = coalesce(p_respins, respins) where id = p_game;
end $$;
revoke all on function public.update_game_settings(uuid, int, int, boolean, text, int) from public, anon;
grant execute on function public.update_game_settings(uuid, int, int, boolean, text, int) to authenticated;
