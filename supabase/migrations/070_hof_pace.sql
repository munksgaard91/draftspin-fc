-- 070: Hall of Fame kan filtreres på spiltype (Classic/Quick game) (2026-11-05).
-- hof-rækkerne får kolonnen pace (kopieret fra games ved sæsonslut). Gamle rækker udfyldes fra games;
-- rækker fra spil, der allerede er slettet, har ukendt type (null) og vises kun under "All".
alter table public.hof_players add column if not exists pace text;
alter table public.hof_teams add column if not exists pace text;
update public.hof_players h set pace = g.pace from public.games g where g.id = h.game_id and h.pace is null;
update public.hof_teams h set pace = g.pace from public.games g where g.id = h.game_id and h.pace is null;

drop function if exists public.hof_players_top(integer, integer, integer);
drop function if exists public.hof_teams_top(integer, integer, integer);

CREATE OR REPLACE FUNCTION public.hof_players_top(p_resp integer DEFAULT NULL::integer, p_pmin integer DEFAULT NULL::integer, p_pmax integer DEFAULT NULL::integer, p_pace text DEFAULT NULL::text)
 RETURNS SETOF hof_players
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with b as (select * from hof_players hp where league = 'PL' and (p_resp is null or respins = p_resp) and (p_pace is null or pace = p_pace)
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
$function$
;

CREATE OR REPLACE FUNCTION public.hof_teams_top(p_resp integer DEFAULT NULL::integer, p_pmin integer DEFAULT NULL::integer, p_pmax integer DEFAULT NULL::integer, p_pace text DEFAULT NULL::text)
 RETURNS SETOF hof_teams
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  with b as (select * from hof_teams where league = 'PL' and (p_resp is null or respins = p_resp) and (p_pace is null or pace = p_pace)
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
$function$
;

revoke all on function public.hof_players_top(integer, integer, integer, text) from public, anon, authenticated;
grant execute on function public.hof_players_top(integer, integer, integer, text) to authenticated;
revoke all on function public.hof_teams_top(integer, integer, integer, text) from public, anon, authenticated;
grant execute on function public.hof_teams_top(integer, integer, integer, text) to authenticated;
