-- Hurtigere indlæsning: hele spillets tilstand i ét kald i stedet for tre forespørgsler (to af dem efter hinanden).
create or replace function public.game_state(p_game uuid) returns jsonb
language plpgsql stable security definer set search_path to 'public', 'pg_temp' as $$
declare g games;
begin
  if not is_member(p_game) then return null; end if;
  select * into g from games where id = p_game;
  if not found then return null; end if;
  return jsonb_build_object(
    'game', to_jsonb(g),
    'players', coalesce((select jsonb_agg(to_jsonb(gp) order by gp.joined_at) from game_players gp where gp.game_id = p_game), '[]'::jsonb),
    'picks', case when g.status = 'lobby' then '[]'::jsonb
      else coalesce((select jsonb_agg(to_jsonb(d) order by d.pick_number) from draft_picks d where d.game_id = p_game), '[]'::jsonb) end
  );
end $$;
revoke all on function public.game_state(uuid) from public, anon;
grant execute on function public.game_state(uuid) to authenticated;
