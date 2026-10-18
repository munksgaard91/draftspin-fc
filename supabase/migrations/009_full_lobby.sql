-- Spillet kan kun startes, når lobbyen er fyldt (antal deltagere = valgt antal spillere) og alle er klar.
-- Admin kan stadig sætte antallet ned i lobbyen (update_game_settings), fx hvis en ven melder afbud.

create or replace function public.start_game(p_game uuid)
returns void language plpgsql security definer set search_path = public as $$
declare g games; ord uuid[]; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  select count(*) into n from game_players where game_id = p_game;
  if n < g.max_players then raise exception 'Lobbyen er ikke fuld endnu (% af %)', n, g.max_players; end if;
  if exists (select 1 from game_players where game_id = p_game and (not ready or formation is null)) then raise exception 'Alle skal være klar'; end if;
  select array_agg(user_id order by random()) into ord from game_players where game_id = p_game;
  update game_players gp set draft_pos = x.n from unnest(ord) with ordinality as x(u, n) where gp.game_id = p_game and gp.user_id = x.u;
  update games set status = 'draft', draft_order = ord, current_pick = 0, current_club = null,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => least(timer_seconds, 20) + 8) end
  where id = p_game;
end $$;
