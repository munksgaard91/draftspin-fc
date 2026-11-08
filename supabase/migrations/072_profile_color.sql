-- 072: brugeren kan selv vælge baggrundsfarven bag sine initialer (2026-11-08).
-- Kun farver fra den faste palet (samme som create_profile vælger tilfældigt fra).
create or replace function public.set_profile_color(p_color text) returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare pal text[] := array['#2f6bd9','#c0392b','#2fa39a','#b8913a','#8e44ad','#d35400','#16a085','#c2185b','#3949ab','#00897b','#6d4c41','#e67e22'];
begin
  if not (lower(p_color) = any(pal)) then raise exception 'Unknown colour'; end if;
  update profiles set color = lower(p_color) where user_id = auth.uid();
  if not found then raise exception 'You don''t have a profile'; end if;
end $$;
revoke all on function public.set_profile_color(text) from public, anon, authenticated;
grant execute on function public.set_profile_color(text) to authenticated;
