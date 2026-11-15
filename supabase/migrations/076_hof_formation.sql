-- 076 (Rasmus 2026-11-15): profilstatistik (v0.9) viser brugerens formationer. Hall of Fame gemte kun formationen for mesterholdet;
-- fra nu skriver serveren (engine/index.ts, finalizeSeason) formationen for alle hold. Her udfyldes ældre rækker, hvor spillet stadig findes.
update public.hof_teams t set formation = st.formation
from public.season_teams st
where st.game_id = t.game_id and st.team_key = t.team_key and t.formation is null and st.formation is not null;
