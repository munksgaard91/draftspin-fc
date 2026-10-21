-- 061 (Rasmus 2026-10-21): Jayden Meghoma spiller i Portsmouth (ikke en af de 20 klubber) og fjernes; Orozco får nr. 58 og Monga nr. 12.
delete from public.players where id=543 and name='Jayden Meghoma';
update public.players set number=58 where id=544 and name='Cristian Orozco';
update public.players set number=12 where id=545 and name='Jeremy Monga';
