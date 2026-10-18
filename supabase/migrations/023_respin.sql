-- Ét respin pr. spiller i draften: ny tilfældig klub, før der er valgt en spiller.
alter table public.game_players add column if not exists respin_used boolean not null default false;

create or replace function public.respin(p_game uuid) returns text
language plpgsql security definer set search_path = public as $$
declare g games; c text;
begin
  select * into g from games where id = p_game for update;
  if not found or g.status <> 'draft' then raise exception 'Draften kører ikke'; end if;
  if turn_user(g) is distinct from auth.uid() then raise exception 'Det er ikke din tur'; end if;
  if g.current_club is null then raise exception 'Spin hjulet først'; end if;
  if exists (select 1 from game_players where game_id = p_game and user_id = auth.uid() and respin_used) then raise exception 'Du har brugt dit respin'; end if;
  select club into c from _clubs_for(p_game, auth.uid()) club where club <> g.current_club order by random() limit 1;
  if c is null then raise exception 'Ingen anden klub har en brugbar spiller'; end if;
  update game_players set respin_used = true, last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  update games set current_club = c,
    turn_deadline = case when timer_seconds > 0 then now() + make_interval(secs => timer_seconds + 4) end
  where id = p_game;
  return c;
end $$;
revoke all on function public.respin(uuid) from public, anon;
grant execute on function public.respin(uuid) to authenticated;
