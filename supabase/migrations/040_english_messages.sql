-- Engelske beskeder i databasefunktionerne (fejlbeskeder og besked på telefonen). Funktionernes tekster erstattes direkte i deres definitioner.
do $do$
declare
  r record; def text; newdef text; pr record; n int := 0;
  pairs text[][] := array[]::text[][];
begin
  for r in
    select p.oid, p.proname from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname = 'public' and p.prokind = 'f'
  loop
    def := pg_get_functiondef(r.oid);
    newdef := def;
    for pr in select * from (values
    ('Forkortelsen skal være 2 til 3 bogstaver eller tal', 'The abbreviation must be 2 to 3 letters or numbers'),
    ('Kun admin kan ændre indstillinger i lobbyen', 'Only the admin can change settings in the lobby'),
    ('Kun admin kan lukke et spil, der er i gang', 'Only the admin can close a game in progress'),
    ('Ingen anden klub har en brugbar spiller', 'No other club has a usable player'),
    ('Kun admin kan fjerne spillere i lobbyen', 'Only the admin can remove players in the lobby'),
    ('Spilleren kan ikke spille på den plads', 'That player can''t play in that spot'),
    ('Spilleren er ikke fra den trukne klub', 'That player isn''t from the drawn club'),
    ('Kun Premier League 2026/2027 er åben', 'Only the Premier League 2026/2027 is open'),
    ('Lobbyen er ikke fuld endnu (% af %)', 'The lobby isn''t full yet (% of %)'),
    ('Ingen klub har en brugbar spiller', 'No club has a usable player'),
    ('Navne må ikke indeholde < eller >', 'Names can''t contain < or >'),
    ('Dit navn skal være 2 til 16 tegn', 'Your name must be 2 to 16 characters'),
    ('Holdnavn skal være 2 til 22 tegn', 'Team name must be 2 to 22 characters'),
    ('Kun admin kan starte en ny sæson', 'Only the admin can start a new season'),
    ('Admin kan ikke fjerne sig selv', 'The admin can''t remove themselves'),
    ('Du kan ikke forlade spillet nu', 'You can''t leave the game now'),
    ('Du har allerede 5 aktive spil', 'You already have 5 active games'),
    ('Spilleren er allerede valgt', 'That player has already been picked'),
    ('Spillet er allerede startet', 'The game has already started'),
    ('Sæsonen er ikke slut endnu', 'The season isn''t over yet'),
    ('Vælg to forskellige farver', 'Choose two different colours'),
    ('Du har brugt dine respins', 'You''ve used your respins'),
    ('Respins skal være 0 til 3', 'Respins must be 0 to 3'),
    ('Spillet er ikke i lobbyen', 'The game isn''t in the lobby'),
    ('Du er ikke med i spillet', 'You''re not in the game'),
    ('Gør holdet færdigt først', 'Finish your team first'),
    ('Det er din tur i draften', 'It''s your turn in the draft'),
    ('Ugyldigt antal spillere', 'Invalid number of players'),
    ('Sæsonen er ikke i gang', 'The season isn''t in progress'),
    ('Ingen brugbar spiller', 'No usable player'),
    ('Runden er ikke i gang', 'The round isn''t in progress'),
    ('Kun admin kan starte', 'Only the admin can start'),
    ('Alle skal være klar', 'Everyone has to be ready'),
    ('Det er ikke din tur', 'It''s not your turn'),
    ('Ugyldigt abonnement', 'Invalid subscription'),
    ('Draften kører ikke', 'The draft isn''t running'),
    ('Lobbyen er udløbet', 'The lobby has expired'),
    ('Pladsen er optaget', 'That spot is taken'),
    ('Sæsonen kører ikke', 'The season isn''t running'),
    ('Ugyldig tidsgrænse', 'Invalid time limit'),
    ('Ukendt våbenskjold', 'Unknown crest'),
    ('Koden findes ikke', 'The code doesn''t exist'),
    ('Spin hjulet først', 'Spin the wheel first'),
    ('Ugyldig farvekode', 'Invalid colour code'),
    ('Allerede startet', 'Already started'),
    ('Spillet er fuldt', 'The game is full'),
    ('Ukendt formation', 'Unknown formation'),
    ('Ukendt spiltempo', 'Unknown pace'),
    ('Ikke logget ind', 'Not signed in'),
    ('Ugyldig plads', 'Invalid spot'),
    ('Ugyldig runde', 'Invalid round')
    ) as t(old, new) loop
      newdef := replace(newdef, '''' || pr.old || '''', '''' || replace(pr.new, '''', '''''') || '''');
    end loop;
    if newdef <> def then
      execute newdef;
      n := n + 1;
      raise notice 'oversat: %', r.proname;
    end if;
  end loop;
  raise notice 'funktioner opdateret: %', n;
end
$do$;
