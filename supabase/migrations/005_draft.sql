-- Draft: snake-rækkefølge, spin (kun klubber med en brugbar spiller), valg, tidsgrænse og automatisk valg.

create function public.formation_slots(f text) returns text[]
language sql immutable set search_path = public as $$
  select case f
    when '4-3-3'     then array['LW','ST','RW','CM','DM','CM','LB','CB','CB','RB','GK']
    when '4-4-2'     then array['ST','ST','LW','CM','CM','RW','LB','CB','CB','RB','GK']
    when '4-2-3-1'   then array['ST','LW','AM','RW','DM','DM','LB','CB','CB','RB','GK']
    when '4-1-4-1'   then array['ST','LW','CM','CM','RW','DM','LB','CB','CB','RB','GK']
    when '4-1-2-1-2' then array['ST','ST','AM','CM','CM','DM','LB','CB','CB','RB','GK']
    when '3-5-2'     then array['ST','ST','LW','CM','DM','CM','RW','CB','CB','CB','GK']
    when '3-4-3'     then array['LW','ST','RW','CM','CM','LB','CB','CB','CB','RB','GK']
    when '5-3-2'     then array['ST','ST','CM','DM','CM','LB','CB','CB','CB','RB','GK']
    when '5-4-1'     then array['ST','LW','CM','CM','RW','LB','CB','CB','CB','RB','GK']
  end
$$;

-- Kan en spiller med position p_pos (og alternativer p_alts) stå på pladsen p_slot?
create function public.slot_ok(p_pos text, p_alts jsonb, p_slot text) returns boolean
language sql immutable set search_path = public as $$
  select p_pos = p_slot or coalesce((p_alts -> p_slot ->> 'fit')::int, 0) >= 5
$$;

-- Hvem er på tur? Snake: rækkefølgen vender hver runde.
create function public.turn_user(g public.games) returns uuid
language sql immutable set search_path = public as $$
  select g.draft_order[
    1 + case when (g.current_pick / array_length(g.draft_order, 1)) % 2 = 1
             then array_length(g.draft_order, 1) - 1 - (g.current_pick % array_length(g.draft_order, 1))
             else g.current_pick % array_length(g.draft_order, 1) end ]
$$;

-- Klubber med mindst én ledig spiller, der kan bruges på en af brugerens åbne pladser.
create function public._clubs_for(p_game uuid, p_user uuid) returns setof text
language sql stable set search_path = public as $$
  select distinct pl.club
  from players pl
  join game_players gp on gp.game_id = p_game and gp.user_id = p_user
  cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
  where not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
    and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
    and slot_ok(pl.pos, pl.alts, s.pos)
$$;

-- Bedste valg til automatisk pick: højeste rating efter positionsstraf.
create function public._best_pick(p_game uuid, p_user uuid, p_club text) returns table (player_id int, slot int)
language sql stable set search_path = public as $$
  select pl.id, s.i::int
  from players pl
  join game_players gp on gp.game_id = p_game and gp.user_id = p_user
  cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
  where pl.club = p_club
    and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
    and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
    and slot_ok(pl.pos, pl.alts, s.pos)
  order by pl.rating * case when pl.pos = s.pos then 1.0 else coalesce((pl.alts -> s.pos ->> 'factor')::numeric, 0.6) end desc
  limit 1
$$;

create function public._spin(g public.games) returns text
language plpgsql security definer set search_path = public as $$
declare c text;
begin
  select club into c from _clubs_for(g.id, turn_user(g)) club order by random() limit 1;
  if c is null then raise exception 'Ingen klub har en brugbar spiller'; end if;
  update games set current_club = c,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => timer_seconds + 4) end
  where id = g.id;
  return c;
end $$;

create function public._do_pick(g public.games, p_user uuid, p_player int, p_slot int) returns void
language plpgsql security definer set search_path = public as $$
declare pl players; f text; n int; slotpos text;
begin
  select * into pl from players where id = p_player;
  if not found or pl.club is distinct from g.current_club then raise exception 'Spilleren er ikke fra den trukne klub'; end if;
  select formation into f from game_players where game_id = g.id and user_id = p_user;
  slotpos := (formation_slots(f))[p_slot];
  if slotpos is null then raise exception 'Ugyldig plads'; end if;
  if not slot_ok(pl.pos, pl.alts, slotpos) then raise exception 'Spilleren kan ikke spille på den plads'; end if;
  if exists (select 1 from draft_picks where game_id = g.id and player_id = p_player) then raise exception 'Spilleren er allerede valgt'; end if;
  if exists (select 1 from draft_picks where game_id = g.id and user_id = p_user and slot = p_slot) then raise exception 'Pladsen er optaget'; end if;
  insert into draft_picks (game_id, pick_number, user_id, player_id, slot) values (g.id, g.current_pick, p_user, p_player, p_slot);
  n := array_length(g.draft_order, 1);
  if g.current_pick + 1 >= n * 11 then
    update games set current_pick = current_pick + 1, current_club = null, turn_deadline = null, status = 'season' where id = g.id;
  else
    update games set current_pick = current_pick + 1, current_club = null,
      turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => timer_seconds) end
    where id = g.id;
  end if;
end $$;

create function public.spin(p_game uuid) returns text
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'draft' then raise exception 'Draften kører ikke'; end if;
  if turn_user(g) is distinct from auth.uid() then raise exception 'Det er ikke din tur'; end if;
  if g.current_club is not null then return g.current_club; end if;
  return _spin(g);
end $$;

create function public.pick_player(p_game uuid, p_player int, p_slot int) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'draft' then raise exception 'Draften kører ikke'; end if;
  if turn_user(g) is distinct from auth.uid() then raise exception 'Det er ikke din tur'; end if;
  if g.current_club is null then raise exception 'Spin hjulet først'; end if;
  perform _do_pick(g, auth.uid(), p_player, p_slot);
end $$;

-- Kan kaldes af alle i spillet, når fristen er gået. Spinner om nødvendigt og vælger bedste spiller.
create function public.claim_timeout(p_game uuid) returns boolean
language plpgsql security definer set search_path = public as $$
declare g games; u uuid; bp record;
begin
  if not is_member(p_game) then raise exception 'Du er ikke med i spillet'; end if;
  select * into g from games where id = p_game for update;
  if g.status <> 'draft' or g.turn_deadline is null or now() < g.turn_deadline then return false; end if;
  u := turn_user(g);
  if g.current_club is null then
    perform _spin(g);
    select * into g from games where id = p_game;
  end if;
  select * into bp from _best_pick(p_game, u, g.current_club);
  if bp.player_id is null then raise exception 'Ingen brugbar spiller'; end if;
  perform _do_pick(g, u, bp.player_id, bp.slot);
  return true;
end $$;

-- start_game sætter også fristen for første tur (plads til visning af rækkefølgen).
create or replace function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g games; ord uuid[];
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  if exists (select 1 from game_players where game_id = p_game and not ready) then raise exception 'Alle skal være klar'; end if;
  select array_agg(user_id order by random()) into ord from game_players where game_id = p_game;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = p_game and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => timer_seconds + 8) end
  where id = p_game;
end $$;

revoke execute on function public.formation_slots, public.slot_ok, public.turn_user, public._clubs_for, public._best_pick,
  public._spin, public._do_pick, public.spin, public.pick_player, public.claim_timeout, public.start_game from public, anon;
grant execute on function public.spin, public.pick_player, public.claim_timeout, public.start_game, public.turn_user, public.formation_slots, public.slot_ok to authenticated;
revoke execute on function public._clubs_for, public._best_pick, public._spin, public._do_pick from authenticated;
