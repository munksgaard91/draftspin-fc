-- Fast search_path for trigger-funktionen (Supabase security advisor)
alter function public._games_done_at() set search_path = public, pg_temp;
