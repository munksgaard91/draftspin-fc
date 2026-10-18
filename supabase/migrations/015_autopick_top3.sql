-- Auto-valg ved tidsudløb: tilfældig blandt de tre bedste spillere (hver med sin bedste plads),
-- så det aldrig kan betale sig at lade uret løbe ud.
create or replace function public._best_pick(p_game uuid, p_user uuid, p_club text) returns table (player_id int, slot int)
language sql volatile set search_path = public as $$
  with cand as (
    select pl.id as pid, s.i::int as sl,
           pl.rating * case when pl.pos = s.pos then 1.0 else coalesce((pl.alts -> s.pos ->> 'factor')::numeric, 0.6) end as score,
           (pl.pos = s.pos) as exact
    from players pl
    join game_players gp on gp.game_id = p_game and gp.user_id = p_user
    cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
    where pl.club = p_club
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
      and slot_ok(pl.pos, pl.alts, s.pos)
  ), best as (
    select distinct on (pid) pid, sl, score from cand order by pid, score desc, exact desc, sl asc
  ), top3 as (
    select pid, sl from best order by score desc, pid asc limit 3
  )
  select pid, sl from top3 order by random() limit 1
$$;
revoke execute on function public._best_pick(uuid, uuid, text) from public, anon, authenticated;
