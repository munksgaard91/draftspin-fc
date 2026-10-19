-- To naturlige positioner: spillere med 19/20 på to positioner i FM er naturlige på begge (alts.<pos>.nat = true).
create or replace function public.pfit(p_pos text, p_alts jsonb, p_slot text) returns integer
language sql immutable set search_path = public as $$
  select greatest(public.slot_fit(p_pos, p_slot), case when coalesce(p_alts -> p_slot ->> 'nat', 'false') = 'true' then 2 else 0 end)
$$;
create or replace function public.slot_ok(p_pos text, p_alts jsonb, p_slot text) returns boolean
language sql immutable set search_path = public as $$
  select public.pfit(p_pos, p_alts, p_slot) > 0
$$;
create or replace function public._best_pick(p_game uuid, p_user uuid, p_club text)
returns table(player_id integer, slot integer)
language sql set search_path = public as $$
  with cand as (
    select pl.id as pid, s.i::int as sl,
           pl.rating * case when pfit(pl.pos, pl.alts, s.pos) = 2 then 1.0 else 0.90 end as score,
           (pfit(pl.pos, pl.alts, s.pos) = 2) as exact
    from players pl
    join game_players gp on gp.game_id = p_game and gp.user_id = p_user
    cross join lateral unnest(formation_slots(gp.formation)) with ordinality s(pos, i)
    where pl.club = p_club
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.user_id = p_user and dp.slot = s.i)
      and not exists (select 1 from draft_picks dp where dp.game_id = p_game and dp.player_id = pl.id)
      and pfit(pl.pos, pl.alts, s.pos) > 0
  ), best as (
    select distinct on (pid) pid, sl, score from cand order by pid, score desc, exact desc, sl asc
  ), top3 as (
    select pid, sl from best order by score desc, pid asc limit 3
  )
  select pid, sl from top3 order by random() limit 1
$$;
update public.players set pos = 'CM' where fm_uid = 28106490;
update public.players p set alts = jsonb_build_object(v.pos2, jsonb_build_object('fit', v.fit, 'factor', 1, 'nat', true))
from (values (29156498,'CM',19),(91151080,'AM',19),(67246383,'CM',19),(19297054,'DM',19),(28106490,'DM',19),(91207265,'CM',20),(19371030,'CM',20),(29127829,'CM',20),(95079151,'AM',20),(72044912,'CM',20),(29162663,'AM',19),(37055838,'LW',20),(2000186138,'CM',20),(2000218543,'ST',20),(71110355,'DM',19),(27088228,'DM',19),(2000032706,'DM',20),(2000124286,'CM',20),(2000250905,'RW',19),(2000273844,'AM',19),(37060598,'LB',20),(93142400,'DM',19),(37071126,'CM',19),(2000315331,'RW',19),(2000033284,'CM',20),(29179656,'LW',20),(19371428,'AM',20),(28120041,'RW',20),(28005566,'CM',20),(2000105653,'CB',20),(2000274374,'LW',19),(86078359,'CM',19),(2000263998,'AM',19),(29086052,'CM',20),(2000339859,'DM',19),(20032912,'LW',19),(28127067,'LB',19),(37050680,'CM',20),(76038469,'CM',20),(67295649,'AM',20),(29085957,'CM',20),(2000053514,'CM',20),(37060951,'DM',19),(28067795,'AM',20),(2000184617,'AM',20),(29218023,'CM',20),(2000288696,'CM',20),(28111078,'LB',19),(28024848,'DM',20),(28126240,'AM',20),(53100298,'CM',20),(28084928,'CM',20),(2000276593,'AM',20),(45109093,'DM',20),(18107443,'CM',20),(222292,'RW',19),(2000170102,'DM',19),(29071195,'CM',19),(29180838,'DM',19),(79033991,'LW',20),(28127065,'RW',19),(83169814,'CM',19),(28122209,'LW',19),(62124086,'CM',20),(14110845,'DM',20),(28084880,'AM',20),(75045574,'AM',20),(45101597,'ST',20),(29175037,'DM',20),(28094948,'AM',19),(98040210,'LW',20),(45104230,'CM',20),(14157129,'DM',19),(43161628,'LW',20),(37071196,'CM',20),(2000108362,'DM',19),(28127221,'CM',20),(49056278,'LW',19),(18106073,'ST',19),(24060472,'CB',20),(83187314,'CM',20),(2000101281,'CM',20),(2000221402,'RW',19),(28108493,'LW',20),(2000166559,'CM',20),(2000123580,'DM',19),(29193653,'AM',20),(48042695,'CM',19),(14076836,'CM',19),(29175208,'CM',20),(16147659,'CM',20),(29136228,'CM',19),(28090340,'LB',19),(52064664,'DM',19),(2000045003,'DM',20),(98003635,'CM',20),(67288501,'CM',19),(2000169229,'AM',19),(43298473,'CM',20),(2000011970,'RW',19),(43295811,'AM',20),(28049744,'LB',19)) v(uid, pos2, fit) where p.fm_uid = v.uid;
