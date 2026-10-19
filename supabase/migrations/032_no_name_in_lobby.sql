-- Navn vælges nu sammen med hold og formation efter spilstart, så open_setup kræver ikke længere navne.
create or replace function public.open_setup(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games; n int;
begin
  select * into g from games where id = p_game for update;
  if not found or g.admin_id <> auth.uid() then raise exception 'Kun admin kan starte'; end if;
  if g.status <> 'lobby' then raise exception 'Allerede startet'; end if;
  if g.setup then return; end if;
  select count(*) into n from game_players where game_id = p_game;
  if n < g.max_players then raise exception 'Lobbyen er ikke fuld endnu (% af %)', n, g.max_players; end if;
  update game_players set ready = false where game_id = p_game;
  update games set setup = true where id = p_game;
end $$;
