-- Spiltempo: 'full' = se hele sæsonen (kamp for kamp), 'quick' = hurtigt spil (serveren simulerer hele sæsonen med det samme,
-- og hver spiller ser sine egne resultater til sidst). Cuppen spilles altid kamp for kamp, uanset valget.

alter table public.games add column pace text not null default 'full' check (pace in ('full', 'quick'));

drop function public.create_game(text, text, int, int, boolean);
create function public.create_game(p_league text, p_season text, p_max int, p_timer int, p_show boolean, p_pace text default 'full')
returns json language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  c text; gid uuid; i int;
begin
  if uid is null then raise exception 'Ikke logget ind'; end if;
  if p_league <> 'PL' or p_season <> '2026/2027' then raise exception 'Kun Premier League 2026/2027 er åben'; end if;
  if p_pace not in ('full', 'quick') then raise exception 'Ukendt spiltempo'; end if;
  if (select count(*) from games where admin_id = uid
        and (status = 'draft' or (status = 'lobby' and created_at > now() - interval '6 hours'))) >= 5 then
    raise exception 'Du har allerede 5 aktive spil';
  end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from games where code = c);
  end loop;
  insert into games (code, admin_id, league, season, max_players, timer_seconds, show_ratings, pace)
  values (c, uid, p_league, p_season, p_max, p_timer, coalesce(p_show, false), p_pace)
  returning id into gid;
  insert into game_players (game_id, user_id) values (gid, uid);
  return json_build_object('id', gid, 'code', c);
end $$;

drop function public.update_game_settings(uuid, int, int, boolean);
create function public.update_game_settings(p_game uuid, p_max int, p_timer int, p_show boolean, p_pace text default null)
returns void language plpgsql security definer set search_path = public as $$
declare n int;
begin
  perform 1 from games where id = p_game and admin_id = auth.uid() and status = 'lobby' for update;
  if not found then raise exception 'Kun admin kan ændre indstillinger i lobbyen'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if p_max < greatest(1, n) or p_max > 6 then raise exception 'Ugyldigt antal spillere'; end if;
  if p_timer not in (0, 30, 60, 90) then raise exception 'Ugyldig tidsgrænse'; end if;
  if p_pace is not null and p_pace not in ('full', 'quick') then raise exception 'Ukendt spiltempo'; end if;
  update games set max_players = p_max, timer_seconds = p_timer, show_ratings = coalesce(p_show, false), pace = coalesce(p_pace, pace) where id = p_game;
end $$;

revoke execute on function public.create_game(text, text, int, int, boolean, text), public.update_game_settings(uuid, int, int, boolean, text) from public, anon;
grant execute on function public.create_game(text, text, int, int, boolean, text), public.update_game_settings(uuid, int, int, boolean, text) to authenticated;
