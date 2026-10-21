-- Spin tog ca. 1 sekund (positionstjek ~6.000 gange pr. spin). Opslagstabel player_fit(spiller, position) bygges fra slot_ok
-- og genopbygges automatisk, hvis spillerdata ændres.
create table if not exists public.player_fit (
  player_id int not null references public.players(id) on delete cascade,
  slot text not null,
  primary key (slot, player_id)
);
alter table public.player_fit enable row level security;
revoke all on public.player_fit from anon, authenticated;

create or replace function public.refresh_player_fit() returns void
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
begin
  delete from player_fit;
  insert into player_fit (player_id, slot)
  select pl.id, s.slot from players pl
  cross join unnest(array['GK','LB','CB','RB','LWB','RWB','DM','CM','AM','LM','RM','LW','RW','ST']) s(slot)
  where slot_ok(pl.pos, pl.alts, s.slot);
end $$;
revoke all on function public.refresh_player_fit() from public, anon, authenticated;

create or replace function public._players_changed() returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
begin perform refresh_player_fit(); return null; end $$;
drop trigger if exists players_fit_refresh on public.players;
create trigger players_fit_refresh after insert or update or delete on public.players
for each statement execute function public._players_changed();

select public.refresh_player_fit();

create or replace function public._clubs_for(p_game uuid, p_user uuid) returns setof text
language sql stable set search_path to 'public' as $$
  select distinct pl.club
  from players pl
  join player_fit pf on pf.player_id = pl.id
  join (
    select distinct s.pos
    from game_players gp
    cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
    where gp.game_id = p_game and gp.user_id = p_user
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
  ) fs on fs.pos = pf.slot
  where not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
$$;
