-- Hold, der er væk i for mange runder, "udgår": sæsonen spilles færdig, men holdet tæller ikke i Highscore.
alter table public.game_players add column missed_rounds int not null default 0;
alter table public.game_players add column last_missed_round int not null default 0;

-- Kaldes kun af serverfunktionen; tæller højst én gang pr. runde pr. spiller.
create function public.bump_missed(p_game uuid, p_round int, p_users uuid[]) returns void
language sql security definer set search_path = public as $$
  update game_players set missed_rounds = missed_rounds + 1, last_missed_round = p_round
  where game_id = p_game and user_id = any(p_users) and last_missed_round < p_round;
$$;
revoke execute on function public.bump_missed(uuid, int, uuid[]) from public, anon, authenticated;
grant execute on function public.bump_missed(uuid, int, uuid[]) to service_role;
