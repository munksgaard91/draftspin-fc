-- 058: seks nye spillere: kortrisiko genberegnet, trøjenumre, boost efter fast regel, alternative positioner kun ved fit >= 19 (Florentino Luis var en dublet af Florentino, id 309 -> fjernet id 540)
delete from public.players where id=540 and face_id=83169817;
update public.players set card_risk=62,yellow_w=1.41,red_w=1.07,boost=2.3,rating=127,number=36,alts='{"CM": {"fit": 19, "nat": true, "factor": 1}}'::jsonb where face_id=2000273835;
update public.players set card_risk=42,yellow_w=0.79,red_w=0.76,boost=2.0,rating=116,number=47,alts='{}'::jsonb where face_id=2000290881;
update public.players set card_risk=35,yellow_w=0.98,red_w=0.68,boost=2.4,rating=107,number=30,alts='{}'::jsonb where face_id=2000190480;
update public.players set card_risk=41,yellow_w=1.21,red_w=0.75,boost=2.5,rating=90,number=40,alts='{"CM": {"fit": 20, "nat": true, "factor": 1}}'::jsonb where face_id=2000254841;
update public.players set card_risk=47,yellow_w=0.88,red_w=0.83,boost=2.9,rating=126,number=30,alts='{}'::jsonb where face_id=2000474101;
update public.players set rating=round(rating_base+boost) where rating<>round(rating_base+boost); -- Orozco 91, Yohanna 123 (afrundingsfejl)
