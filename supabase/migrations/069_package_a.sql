-- Pakke A (2026-11-05): serverrettelser.
-- 1) update_team: migration 065 rullede 038 (search_path med pg_temp) og 040 (engelske fejlbeskeder) tilbage. Genskabt med begge.
CREATE OR REPLACE FUNCTION public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest integer, p_formation text, p_display text DEFAULT NULL::text, p_tag text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare tg text := nullif(upper(trim(coalesce(p_tag, ''))), '');
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'The game isn''t in the lobby'; end if;
  if p_formation not in ('4-3-3','4-3-3 (D)','4-3-3 (O)','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-4-3','5-3-2','5-3-2 (D)','5-3-2 (O)','5-3-1-1','4-2-1-3','4-1-3-2','4-3-3 (F)','4-5-1 (F)','4-2-4','3-5-2 (F)','5-4-1','4-5-1','4-4-1-1','4-3-1-2','4-2-2-2','3-4-2-1','4-3-2-1','3-4-1-2','3-1-4-2','4-4-2 (D)','3-4-2-1 (D)','4-2-3-1 (W)') then raise exception 'Unknown formation'; end if;
  if p_crest not between 1 and 12 then raise exception 'Unknown crest'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Invalid colour code'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Choose two different colours'; end if;
  if length(trim(p_name)) not between 2 and 22 then raise exception 'Team name must be 2 to 22 characters'; end if;
  if tg is not null and tg !~ '^[A-ZÆØÅ0-9]{2,3}$' then raise exception 'The abbreviation must be 2 to 3 letters or numbers'; end if;
  if p_display is not null and length(trim(p_display)) not between 2 and 16 then raise exception 'Your name must be 2 to 16 characters'; end if;
  if p_name ~ '[<>]' or coalesce(p_display, '') ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, crest_tag = tg, ready = false,
    display_name = case when p_display is null then display_name else trim(p_display) end
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'You''re not in the game'; end if;
end $function$;

-- 2) Ventende straffe gemmes uden udfald (type 'pen_pending'), så udfaldet ikke kan ses, før straffen er taget (motor 1.15).
alter table public.match_events drop constraint match_events_type_check;
alter table public.match_events add constraint match_events_type_check
  check (type = any (array['goal','yellow','red','second_yellow','pen_miss','clean_sheet','pen_pending']));

-- 3) Spillerdata fastfryses ved sæsonstart (kun serveren kan læse season_secret), så senere datarettelser ikke ændrer igangværende sæsoner.
alter table public.season_secret add column if not exists players jsonb;

-- 4) Kampens score og clean sheets tælles op i én transaktion med lås på kampen (to straffe i samme kamp kan afgøres samtidig).
create or replace function public.recount_match(p_match bigint, p_gk_h integer, p_gk_a integer)
returns table (home_goals integer, away_goals integer)
language plpgsql security definer set search_path = public, pg_temp as $$
declare g uuid; hg integer; ag integer;
begin
  select m.game_id into g from matches m where m.id = p_match for update;
  if not found then raise exception 'Unknown match'; end if;
  select count(*) filter (where e.type = 'goal' and e.team = 'h'), count(*) filter (where e.type = 'goal' and e.team = 'a')
    into hg, ag from match_events e where e.match_id = p_match;
  update matches m set home_goals = hg, away_goals = ag where m.id = p_match;
  delete from match_events e where e.match_id = p_match and e.type = 'clean_sheet';
  if ag = 0 and p_gk_h is not null then
    insert into match_events (game_id, match_id, minute, type, team, player_id, pen) values (g, p_match, 90, 'clean_sheet', 'h', p_gk_h, false);
  end if;
  if hg = 0 and p_gk_a is not null then
    insert into match_events (game_id, match_id, minute, type, team, player_id, pen) values (g, p_match, 90, 'clean_sheet', 'a', p_gk_a, false);
  end if;
  return query select hg, ag;
end $$;
revoke all on function public.recount_match(bigint, integer, integer) from public, anon, authenticated;
grant execute on function public.recount_match(bigint, integer, integer) to service_role;
