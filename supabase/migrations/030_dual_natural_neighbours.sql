-- To naturlige positioner kun for nabo-pladser (DM-CM, CM-AM, AM-LW/RW/ST, LW-RW, LW/RW-ST, LB-RB, LB/RB-CB). Resten fjernet.
update public.players set alts = '{}'::jsonb where fm_uid in (2000033284,28084928,29175037,83187314,2000101281);
