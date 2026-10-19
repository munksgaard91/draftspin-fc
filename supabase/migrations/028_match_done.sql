-- Hver spiller melder, når hendes kamp er set færdig, så andres resultater først vises, når alle er færdige.
alter table public.game_players add column if not exists done_round int not null default 0;

create or replace function public.match_done(p_game uuid, p_round int) returns void
language plpgsql security definer set search_path = public as $$
declare g games;
begin
  select * into g from games where id = p_game;
  if not found or g.status <> 'season' then raise exception 'Sæsonen kører ikke'; end if;
  if p_round < 1 or p_round > g.current_round then raise exception 'Ugyldig runde'; end if;
  update game_players set done_round = greatest(done_round, p_round), last_seen_at = now() where game_id = p_game and user_id = auth.uid();
  if not found then raise exception 'Du er ikke med i spillet'; end if;
end $$;
revoke all on function public.match_done(uuid, int) from public, anon;
grant execute on function public.match_done(uuid, int) to authenticated;
