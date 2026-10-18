-- Web push: besked når det er din tur i draften.
-- Nøglerne (VAPID + delt hemmelighed) ligger i push_config og indsættes manuelt, aldrig i repoet.
create extension if not exists pg_net with schema extensions;

create table public.push_subs (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);
create index push_subs_user on public.push_subs (user_id);
create table public.push_config (key text primary key, value text not null);
alter table public.push_subs enable row level security;
alter table public.push_config enable row level security;
grant all on public.push_subs, public.push_config to service_role;
grant all on all sequences in schema public to service_role;

create function public.save_push_sub(p_endpoint text, p_p256dh text, p_auth text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Ikke logget ind'; end if;
  if p_endpoint !~ '^https://' or length(p_endpoint) > 1000 or length(p_p256dh) > 200 or length(p_auth) > 100 then raise exception 'Ugyldigt abonnement'; end if;
  if (select count(*) from push_subs where user_id = auth.uid()) >= 8 then
    delete from push_subs where id in (select id from push_subs where user_id = auth.uid() order by created_at limit 1);
  end if;
  insert into push_subs (user_id, endpoint, p256dh, auth) values (auth.uid(), p_endpoint, p_p256dh, p_auth)
  on conflict (endpoint) do update set user_id = auth.uid(), p256dh = excluded.p256dh, auth = excluded.auth;
end $$;
create function public.drop_push_sub(p_endpoint text) returns void
language sql security definer set search_path = public as $$
  delete from push_subs where endpoint = p_endpoint and user_id = auth.uid();
$$;
revoke execute on function public.save_push_sub, public.drop_push_sub from public, anon;
grant execute on function public.save_push_sub, public.drop_push_sub to authenticated;

-- Trigger: når turen skifter i draften, sendes en besked til den, der er på.
create function public._notify_turn() returns trigger
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
    body := jsonb_build_object('user_id', u, 'title', 'DraftSpin FC', 'body', 'Det er din tur i draften', 'tag', 'turn-' || new.id)
  );
  return new;
exception when others then
  return new;
end $$;
revoke execute on function public._notify_turn from public, anon, authenticated;
create trigger games_notify_turn after update of current_pick, status on public.games
  for each row execute function public._notify_turn();
