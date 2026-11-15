-- 079: holdnavn maks. 20 tegn på serveren, som i appen (Rasmus 2026-11-15)
CREATE OR REPLACE FUNCTION public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest integer, p_formation text, p_display text DEFAULT NULL::text, p_tag text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare tg text := nullif(upper(trim(coalesce(p_tag, ''))), ''); mn text; gn text;
begin
  perform 1 from games where id = p_game and status = 'lobby' for update;
  if not found then raise exception 'The game isn''t in the lobby'; end if;
  if p_formation not in ('4-3-3','4-3-3 (D)','4-3-3 (O)','4-4-2','4-2-3-1','4-1-4-1','4-1-2-1-2','3-4-3','5-3-2','5-3-2 (D)','5-3-2 (O)','5-3-1-1','4-2-1-3','4-1-3-2','4-3-3 (F)','4-5-1 (F)','4-2-4','3-5-2 (F)','5-4-1','4-5-1','4-4-1-1','4-3-1-2','4-2-2-2','3-4-2-1','4-3-2-1','3-4-1-2','3-1-4-2','4-4-2 (D)','3-4-2-1 (D)','4-2-3-1 (W)') then raise exception 'Unknown formation'; end if;
  if p_crest not between 1 and 12 then raise exception 'Unknown crest'; end if;
  if p_c1 !~ '^#[0-9a-fA-F]{6}$' or p_c2 !~ '^#[0-9a-fA-F]{6}$' then raise exception 'Invalid colour code'; end if;
  if lower(p_c1) = lower(p_c2) then raise exception 'Choose two different colours'; end if;
  if length(trim(p_name)) not between 2 and 20 then raise exception 'Team name must be 2 to 20 characters'; end if;
  if tg is not null and tg !~ '^[A-ZÆØÅ0-9]{2,3}$' then raise exception 'The abbreviation must be 2 to 3 letters or numbers'; end if;
  if p_name ~ '[<>]' then raise exception 'Names can''t contain < or >'; end if;
  select manager_name into mn from profiles where user_id = auth.uid();
  if mn is null and p_display is not null then gn := _check_guest_name(p_display); end if;
  update game_players set team_name = trim(p_name), color1 = lower(p_c1), color2 = lower(p_c2), crest = p_crest, formation = p_formation, crest_tag = tg, ready = false,
    display_name = coalesce(mn, gn, display_name)
  where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'You''re not in the game'; end if;
end $function$
;
revoke all on function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest integer, p_formation text, p_display text, p_tag text) from public, anon, authenticated; grant execute on function public.update_team(p_game uuid, p_name text, p_c1 text, p_c2 text, p_crest integer, p_formation text, p_display text, p_tag text) to authenticated;
