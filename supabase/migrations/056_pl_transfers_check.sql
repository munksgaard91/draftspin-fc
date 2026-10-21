-- Afstemning mod Premier Leagues officielle sommertransfers 2026/27 (2026-10-21): Luc De Fougerolles (udlånt, ingen referencer) fjernet;
-- 6 spillere tilføjet med CA/PA og egenskaber fra Database.fm. Trøjenumre er pladsholdere (ikke officielle), boost 0, alts kun naturlige positioner eller fit>=14,
-- yellow_w/red_w/card_risk er tilnærmet med en lineær model fit på de eksisterende spillere. Billeder: silhuet, til næste atlas-version.
delete from public.players where name = 'Luc De Fougerolles' and club = 'FUL';

insert into public.players (club,number,name,pos,age,rating,rating_base,boost,pa,alts,consistency,important_matches,pen_taking,yellow_w,red_w,card_risk,fpl_goals,fpl_assists,fpl_yellow,fpl_red,fpl_minutes,fpl_cs,fm_uid,face_id) values
('IPS',30,'Florentino Luis','DM',27,140,140,0,145,'{"CM": {"fit": 19, "factor": 1, "nat": true}}'::jsonb,18,14,10,1.4,1.15,60,0,0,0,0,0,0,83169226,83169817),
('HUL',30,'Christos Mouzakitis','DM',19,125,125,0,160,'{"CM": {"fit": 19, "factor": 1, "nat": true}}'::jsonb,12,13,12,1.19,1.12,60,0,0,0,0,0,0,2000273793,2000273835),
('HUL',31,'Robinio Vaz','ST',19,114,114,0,145,'{"LW": {"fit": 15, "factor": 0.9}}'::jsonb,12,12,10,0.77,0.76,37,0,0,0,0,0,0,2000290799,2000290881),
('BRE',30,'Jayden Meghoma','LB',20,105,105,0,153,'{"CB": {"fit": 14, "factor": 0.88}}'::jsonb,8,9,8,0.97,0.75,34,0,0,0,0,0,0,2000190479,2000190480),
('MUN',40,'Cristian Orozco','DM',18,88,88,0,126,'{"CM": {"fit": 20, "factor": 1, "nat": true}}'::jsonb,8,5,4,1.24,0.89,43,0,0,0,0,0,0,2000254793,2000254841),
('MCI',30,'Jeremy Monga','LW',17,123,123,0,167,'{"AM": {"fit": 15, "factor": 0.9}, "LM": {"fit": 14, "factor": 0.88}}'::jsonb,10,5,7,0.84,0.88,43,0,0,0,0,0,0,2000474063,2000474101);
