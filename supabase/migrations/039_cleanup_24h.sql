-- Oprydning: færdige og lukkede spil slettes 24 timer efter (rekorderne i hof_* har ingen kobling til spillet og bliver liggende).
alter table public.games add column if not exists done_at timestamptz;
-- eksisterende færdige spil får 24 timer fra nu
update public.games set done_at = now() where status = 'done' and done_at is null;

create or replace function public._games_done_at() returns trigger language plpgsql as $$
begin
  if new.status = 'done' and old.status is distinct from 'done' then new.done_at := now(); end if;
  return new;
end $$;
drop trigger if exists games_done_at on public.games;
create trigger games_done_at before update on public.games for each row execute function public._games_done_at();

create or replace function public._cron_tick()
returns void language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare g games; u uuid; bp record;
begin
  update games set status = 'closed'
  where (status = 'lobby'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '10 minutes'))
     or (status = 'draft'  and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '60 minutes'))
     or (status = 'season' and not exists (select 1 from game_players gp where gp.game_id = games.id and gp.last_seen_at > now() - interval '14 days'));

  delete from games gm
  where (gm.status = 'closed' and coalesce((select max(gp.last_seen_at) from game_players gp where gp.game_id = gm.id), gm.created_at) < now() - interval '24 hours')
     or (gm.status = 'done' and coalesce(gm.done_at, (select max(gp.last_seen_at) from game_players gp where gp.game_id = gm.id), gm.created_at) < now() - interval '24 hours')
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
