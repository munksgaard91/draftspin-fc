-- Fables audit (2026-10-20): pfit låses ned som de øvrige, pg_temp i search_path på alle definer-funktioner,
-- holdforkortelsen følger med i Ny sæson, og oprydning bruger sidste aktivitet i stedet for oprettelsestidspunktet.
revoke all on function public.pfit(text, jsonb, text) from public, anon;
grant execute on function public.pfit(text, jsonb, text) to authenticated, service_role;

do $$
declare f record;
begin
  for f in select p.oid::regprocedure as sig from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosecdef loop
    execute format('alter function %s set search_path = public, pg_temp', f.sig);
  end loop;
end $$;

create or replace function public.new_season(p_game uuid)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare
  g games; ng uuid; c text; i int; ord uuid[];
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte en ny sæson'; end if;
  if g.status <> 'done' then raise exception 'Sæsonen er ikke slut endnu'; end if;
  if g.next_game_id is not null then return g.next_game_id; end if;
  loop
    c := '';
    for i in 1..6 loop c := c || substr(chars, 1 + floor(random() * length(chars))::int, 1); end loop;
    exit when not exists (select 1 from games where code = c);
  end loop;
  insert into games (code, admin_id, league, season, mode, max_players, timer_seconds, show_ratings, pace, season_no)
  values (c, g.admin_id, g.league, g.season, g.mode, g.max_players, g.timer_seconds, g.show_ratings, g.pace, g.season_no + 1)
  returning id into ng;
  insert into game_players (game_id, user_id, team_name, color1, color2, crest, crest_tag, formation, display_name, ready)
  select ng, user_id, team_name, color1, color2, crest, crest_tag, formation, display_name, true from game_players where game_id = p_game;
  select array_agg(user_id order by random()) into ord from game_players where game_id = ng;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = ng and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8) end
  where id = ng;
  update games set next_game_id = ng where id = p_game;
  return ng;
end $$;

create or replace function public._cron_tick()
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare g games; u uuid; bp record;
begin
  update games set status = 'closed'
  where (status = 'lobby'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '10 minutes'))
     or (status = 'draft'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '60 minutes'))
     or (status = 'season' and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '14 days'));

  -- lukkede spil slettes 7 dage efter sidste aktivitet, færdige spil efter 90 dage (Hall of Fame har ingen FK og overlever)
  delete from games gm
  where (gm.status = 'closed' and coalesce((select max(gp.last_seen_at) from game_players gp where gp.game_id = gm.id), gm.created_at) < now() - interval '7 days')
     or (gm.status = 'done' and coalesce((select max(gp.last_seen_at) from game_players gp where gp.game_id = gm.id), gm.created_at) < now() - interval '90 days')
     or (gm.status = 'lobby' and gm.created_at < now() - interval '1 day');

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
