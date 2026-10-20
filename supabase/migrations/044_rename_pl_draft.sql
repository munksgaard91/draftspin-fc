-- Spillet hedder nu PL Draft: push-notifikationens titel.
create or replace function public._notify_turn() returns trigger
language plpgsql security definer set search_path to 'public', 'pg_temp' as $$
declare u uuid; sec text;
begin
  if new.status <> 'draft' or coalesce(array_length(new.draft_order, 1), 0) < 2 then return new; end if;
  if old.status = 'draft' and old.current_pick is not distinct from new.current_pick then return new; end if;
  u := turn_user(new);
  if u is null or not exists (select 1 from push_subs where user_id = u) then return new; end if;
  select value into sec from push_config where key = 'secret';
  if sec is null then return new; end if;
  perform net.http_post(
    url := 'https://apagcfedizgjnnuefzfo.supabase.co/functions/v1/push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', sec),
    body := jsonb_build_object('user_id', u, 'title', 'PL Draft', 'body', 'It''s your turn in the draft', 'tag', 'turn-' || new.id),
    timeout_milliseconds := 10000
  );
  return new;
exception when others then
  return new;
end $$;
