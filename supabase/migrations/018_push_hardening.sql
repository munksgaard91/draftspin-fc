-- Efter Fables runde 2: pg_net-timeout, endpoint-allowlist og sletning af ældste abonnement kun når det er nødvendigt.
create or replace function public.save_push_sub(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Ikke logget ind'; end if;
  if length(p_endpoint) > 1000 or length(p_p256dh) > 200 or length(p_auth) > 100
     or p_endpoint !~ '^https://([a-z0-9-]+\.)*(push\.apple\.com|googleapis\.com|push\.services\.mozilla\.com|notify\.windows\.com)/' then
    raise exception 'Ugyldigt abonnement';
  end if;
  if not exists (select 1 from push_subs where endpoint = p_endpoint)
     and (select count(*) from push_subs where user_id = auth.uid()) >= 8 then
    delete from push_subs where id in (select id from push_subs where user_id = auth.uid() order by created_at limit 1);
  end if;
  insert into push_subs (user_id, endpoint, p256dh, auth) values (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth;
end $$;

create or replace function public._notify_turn() returns trigger
language plpgsql security definer set search_path = public as $$
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
    body := jsonb_build_object('user_id', u, 'title', 'DraftSpin FC', 'body', 'Det er din tur i draften', 'tag', 'turn-' || new.id),
    timeout_milliseconds := 10000
  );
  return new;
exception when others then
  return new;
end $$;
