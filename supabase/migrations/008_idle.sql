-- Inaktivitet. Spillet kører videre på serveren, uanset om en telefon er i baggrunden (opkald, SMS, andre apps).
-- Klienten sender et hjerteslag (touch_game) hvert 30. sekund, mens appen er synlig, og hver handling tæller også som aktivitet.
-- En spiller regnes som "til stede", hvis vedkommende er set inden for de seneste 5 minutter.
--   Lobby: lukkes efter 10 minutter, hvor ingen er til stede (uændret).
--   Draft: lukkes efter 60 minutter uden nogen til stede.
--   Sæson: lukkes efter 14 dage uden nogen til stede.
-- Bagstopper for tidsgrænsen (auto-valg efter 90 sekunder over frist) kører kun, hvis mindst én spiller er til stede.
-- Når ingen er til stede, venter spillet. Så snart en spiller vender tilbage, udløser appen claim_timeout som før.

create or replace function public._cron_tick() returns void
language plpgsql security definer set search_path = public as $$
declare g games; u uuid; bp record;
begin
  update games set status = 'closed'
  where (status = 'lobby'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '10 minutes'))
     or (status = 'draft'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '60 minutes'))
     or (status = 'season' and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '14 days'));

  delete from games
  where (status = 'closed' and created_at < now() - interval '7 days')
     or (status = 'lobby' and created_at < now() - interval '1 day');

  for g in
    select * from games gm
    where gm.status = 'draft' and gm.turn_deadline is not null and gm.turn_deadline < now() - interval '90 seconds'
      and exists (select 1 from game_players gp where gp.game_id = gm.id and gp.last_seen_at > now() - interval '5 minutes')
    for update skip locked
  loop
    u := turn_user(g);
    if g.current_club is null then
      perform _spin(g);
      select * into g from games where id = g.id;
    end if;
    select * into bp from _best_pick(g.id, u, g.current_club);
    if bp.player_id is not null then perform _do_pick(g, u, bp.player_id, bp.slot); end if;
  end loop;
end $$;

-- Handlinger tæller som aktivitet.
create or replace function public.spin(p_game uuid) returns text
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'draft' then raise exception 'Draften kører ikke'; end if;
  if turn_user(g) is distinct from auth.uid() then raise exception 'Det er ikke din tur'; end if;
  update game_players set last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  if g.current_club is not null then return g.current_club; end if;
  return _spin(g);
end $$;

create or replace function public.pick_player(p_game uuid, p_player int, p_slot int) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'draft' then raise exception 'Draften kører ikke'; end if;
  if turn_user(g) is distinct from auth.uid() then raise exception 'Det er ikke din tur'; end if;
  if g.current_club is null then raise exception 'Spin hjulet først'; end if;
  update game_players set last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  perform _do_pick(g, auth.uid(), p_player, p_slot);
end $$;
