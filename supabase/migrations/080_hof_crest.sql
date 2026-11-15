-- 080: holdets emblem gemmes på Hall of Fame-rækken (nyt Hall of Fame, Rasmus 2026-11-15)
alter table public.hof_teams add column if not exists color1 text;
alter table public.hof_teams add column if not exists color2 text;
alter table public.hof_teams add column if not exists crest integer;
alter table public.hof_teams add column if not exists crest_tag text;

-- spil der stadig findes
update public.hof_teams t set color1 = st.color1, color2 = st.color2, crest = st.crest
from public.season_teams st
where st.game_id = t.game_id and st.team_key = t.team_key and t.crest is null;
update public.hof_teams t set crest_tag = gp.crest_tag
from public.game_players gp
where gp.game_id = t.game_id and gp.user_id = t.user_id and t.crest_tag is null and gp.crest_tag is not null;
