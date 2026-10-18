-- Oprydning og bagstopper, kører hvert minut via pg_cron.
-- 1) Lukker lobbyer, hvor alle har været væk i 10 minutter.
-- 2) Sletter lukkede spil efter 7 dage og lobbyer ældre end et døgn.
-- 3) Auto-vælger i drafter, hvor fristen er overskredet med 90 sekunder (alle har lukket appen).

create extension if not exists pg_cron;

create function public._cron_tick() returns void
language plpgsql security definer set search_path = public as $$
declare g games; u uuid; bp record;
begin
  update games set status = 'closed'
  where status = 'lobby'
    and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '10 minutes');

  delete from games
  where (status = 'closed' and created_at < now() - interval '7 days')
     or (status = 'lobby' and created_at < now() - interval '1 day');

  for g in
    select * from games
    where status = 'draft' and turn_deadline is not null and turn_deadline < now() - interval '90 seconds'
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

revoke execute on function public._cron_tick from public, anon, authenticated;

select cron.schedule('draftspin-tick', '* * * * *', 'select public._cron_tick()');
