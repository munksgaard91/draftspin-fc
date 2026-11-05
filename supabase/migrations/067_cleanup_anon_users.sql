-- Oprydning af døde anonyme brugere (2026-11-05).
-- En anonym bruger slettes, når den ikke har været logget ind i 14 dage og ikke findes i noget spil,
-- nogen opstilling, noget draft-valg, nogen udelukkelse eller Hall of Fame. 14 dage = samme grænse som
-- for et forladt sæsonspil i _cron_tick. Klienten opretter selv en ny anonym bruger ved næste start,
-- hvis dens gamle session er udløbet.
create or replace function public._cleanup_anon_users()
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare n integer;
begin
  delete from auth.users u
  where u.is_anonymous
    and coalesce(u.last_sign_in_at, u.created_at) < now() - interval '14 days'
    and not exists (select 1 from game_players x where x.user_id = u.id)
    and not exists (select 1 from games x where x.admin_id = u.id)
    and not exists (select 1 from draft_picks x where x.user_id = u.id)
    and not exists (select 1 from season_teams x where x.user_id = u.id)
    and not exists (select 1 from game_bans x where x.user_id = u.id)
    and not exists (select 1 from hof_players x where x.user_id = u.id)
    and not exists (select 1 from hof_teams x where x.user_id = u.id);
  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public._cleanup_anon_users() from public, anon, authenticated;

-- Dagligt kl. 04:23 UTC.
select cron.unschedule(jobid) from cron.job where jobname = 'draftspin-anon-cleanup';
select cron.schedule('draftspin-anon-cleanup', '23 4 * * *', $cron$select public._cleanup_anon_users()$cron$);
