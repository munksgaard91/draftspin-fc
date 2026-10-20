-- Rekordtekster i Hall of Fame på engelsk: "mod X" bliver til "vs X"
update public.hof_teams set big_win_text = 'vs ' || substr(big_win_text, 5) where big_win_text like 'mod %';
update public.hof_players set best_match_text = 'vs ' || substr(best_match_text, 5) where best_match_text like 'mod %';
