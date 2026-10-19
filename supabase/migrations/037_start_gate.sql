-- Classic: første kamp starter først, når alle spillere har trykket "Klar" (game_players.start_ready).
alter table public.game_players add column if not exists start_ready boolean not null default false;

create or replace function public.ready_start(p_game uuid) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game;
  if not found or g.status <> 'season' then raise exception 'Sæsonen er ikke i gang'; end if;
  update game_players set start_ready = true, last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
revoke execute on function public.ready_start(uuid) from public, anon;
grant execute on function public.ready_start(uuid) to authenticated;
