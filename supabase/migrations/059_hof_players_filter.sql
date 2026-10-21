-- 059: Hall of Fame kan filtreres på antal spillere i spillet (p_pmin/p_pmax); uden filter vises alt (som før).
-- Antal spillere findes i hof_teams.players (samme spil); rekorder uden kendt antal vises kun under "Alle".
drop function if exists public.hof_players_top(integer);
drop function if exists public.hof_teams_top(integer);

create or replace function public.hof_players_top(p_resp integer default null, p_pmin integer default null, p_pmax integer default null)
 returns setof hof_players language sql stable set search_path to 'public', 'pg_temp' as $function$
  with b as (select * from hof_players hp where league = 'PL' and (p_resp is null or respins = p_resp)
      and (p_pmin is null and p_pmax is null or (select max(t.players) from hof_teams t where t.game_id = hp.game_id) between coalesce(p_pmin, 0) and coalesce(p_pmax, 1000))),
  sel as (
    select id from (select id, row_number() over (order by goals desc, created_at) rn from (select distinct on (player_id) * from b where goals > 0 order by player_id, goals desc) x) y where rn <= 5
    union select id from (select id, row_number() over (order by assists desc, created_at) rn from (select distinct on (player_id) * from b where assists > 0 order by player_id, assists desc) x) y where rn <= 5
    union select id from (select id, row_number() over (order by clean_sheets desc, created_at) rn from (select distinct on (player_id) * from b where clean_sheets > 0 order by player_id, clean_sheets desc) x) y where rn <= 5
    union select id from (select id, row_number() over (order by reds desc, created_at) rn from (select distinct on (player_id) * from b where reds > 0 order by player_id, reds desc) x) y where rn <= 5
    union select id from (select id, row_number() over (order by yellows desc, created_at) rn from (select distinct on (player_id) * from b where yellows > 0 order by player_id, yellows desc) x) y where rn <= 5
    union select id from (select id, row_number() over (order by best_match_goals desc, created_at) rn from (select distinct on (player_id) * from b where best_match_goals > 1 order by player_id, best_match_goals desc) x) y where rn <= 5
  )
  select * from hof_players where id in (select id from sel)
$function$;

create or replace function public.hof_teams_top(p_resp integer default null, p_pmin integer default null, p_pmax integer default null)
 returns setof hof_teams language sql stable set search_path to 'public', 'pg_temp' as $function$
  with b as (select * from hof_teams where league = 'PL' and (p_resp is null or respins = p_resp)
      and (p_pmin is null and p_pmax is null or players between coalesce(p_pmin, 0) and coalesce(p_pmax, 1000))),
  sel as (
    select id from b where champion
    union select id from (select id from b order by points desc limit 5) a
    union select id from (select id from b order by gf desc limit 5) a
    union select id from (select id from b order by (gf - ga) desc limit 5) a
    union select id from (select id from b order by ga asc limit 5) a
    union select id from (select id from b where win_streak > 0 order by win_streak desc limit 5) a
    union select id from (select id from b where big_win_margin > 0 order by big_win_margin desc limit 5) a
  )
  select * from hof_teams where id in (select id from sel)
$function$;

revoke execute on function public.hof_players_top(integer, integer, integer), public.hof_teams_top(integer, integer, integer) from public, anon;
grant execute on function public.hof_players_top(integer, integer, integer), public.hof_teams_top(integer, integer, integer) to authenticated;
