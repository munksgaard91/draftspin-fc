-- Push-beskeder bruges ikke længere (Rasmus 2026-10-22): stop afsendelsen.
-- Tabeller (push_subs, push_config), RPC'erne og edge-funktionen "push" ligger urørt, så det kan tændes igen ved at oprette triggeren på ny (se 048_audit_3_0_1.sql).
drop trigger if exists games_notify_turn on public.games;
