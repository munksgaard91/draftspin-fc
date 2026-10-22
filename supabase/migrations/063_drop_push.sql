-- Push-beskeder er fjernet helt (Rasmus 2026-10-23): trigger blev droppet i 062, nu fjernes resten.
-- Tabellen push_config indeholdt VAPID-nøglerne og den delte hemmelighed; de slettes med den.
drop function if exists public._notify_turn();
drop function if exists public.save_push_sub(text, text, text);
drop function if exists public.drop_push_sub(text);
drop table if exists public.push_subs;
drop table if exists public.push_config;
