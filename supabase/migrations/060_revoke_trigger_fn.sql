-- 060: trigger-funktionen _players_changed() skal ikke kunne kaldes via API (fund i selv-audit 2026-10-21)
revoke execute on function public._players_changed() from public, anon, authenticated;
