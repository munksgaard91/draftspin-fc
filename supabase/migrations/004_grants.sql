-- Nye tabeller er lukkede som standard. Giv kun læseadgang; alle skrivninger sker via funktioner.
grant select on public.clubs, public.players to anon, authenticated;
grant select on public.games, public.game_players, public.draft_picks to authenticated;
