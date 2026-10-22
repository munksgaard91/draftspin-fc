# PL Draft

Privat online draftspil til iPhone. **New Season** (solo mod 19 AI-klubber) og **Multiplayer** (2-10 venner, lobbyen åbner med kode, og antallet fastlægges, når admin trykker Start): snak-draft med klubhjul, sæson på 38 runder mod venner og AI-klubber, Hall of Fame.

- `index.html`: selve appen (en enkelt fil), åbnes via GitHub Pages
- `data/`: spillerdata Premier League 2026/27 (Football Manager 26 som base, EA FC som kontrol, Fantasy Premier League til statistik)
- `supabase/migrations/`: databasens opbygning
- `scripts/`: lokale scripts til at bygge og uploade data

Projektet er kun til privat brug blandt venner og er ikke tilknyttet nogen klub, liga eller spiludgiver.

## Tests

Kør alle automatiske tests med `./tests/run.sh` (kræver `deno`). De tjekker, at kampmotoren stadig er identisk med den udgivne, at programmet og formationerne er korrekte, at kamphændelser stemmer med resultatet, at tallene er realistiske, at `index.html` kan parses, at filer og ikoner findes, og at migrationerne er i orden. Ændres motoren med vilje, opdateres fingeraftrykket i `tests/engine_test.ts` og i `engine/SPEC.md`.

## Beslutninger og arbejdsnoter (2026-10-21)
**Hall of Fame** (Rasmus): 100 % neutral, ingen markering af egne rekorder. Spillerrekorder viser spillerens ansigt i stedet for medalje/tal (ingen pokal-overlay); holdrekorder har stadig medaljer. Ingen emojis i rekordtitler (kun Champions har pokalbilledet). Ingen tekst under holdnavnet på Longest winning streak, Most points in a season og Best goal difference. Filter: Respins og Players (All / 1 / 2 / 3 / 4 / 5+), standard er All (migration 059). Mesterholdets opstilling vises med spillerbilleder. Gemt til senere: ewig tabel (efter users), detaljer ved tryk, del-kort.
**Motor 1.11**: AI-klubber får optimal opstilling (ungarsk metode). Faste regler for nye spillere (kortrisiko, boost, alternative positioner, trøjenumre, dubletter) står i `engine/SPEC.md`.
**Spillere** (migration 058-061): Florentino Luis var en dublet og er fjernet; Meghoma fjernet (spiller i Portsmouth); Orozco #58, Monga #12, Mouzakitis #36, Vaz #47 (bekræftet af Rasmus). Billeder mangler stadig til Mouzakitis, Vaz, Orozco, Monga og 9 ældre spillere (atlas v2 venter).
**Test-noter**: skjult testspil = tryk 5 gange på logoet, vælg Quick game. Testspil springer afspilningen over og viser sæsonafslutningen ca. 20 sekunder efter start (flag `dsfc-testgid` i localStorage; ægte spil afspilles som normalt). Flere genveje (kun testspil): `Draft only` i testvinduet går direkte til draften (antal allerede valgte spillere sættes med `localStorage dsfc-testpicks`, 0-10); `localStorage dsfc-testpos` (1-20) flytter dit hold til den plads på sæsonafslutnings-sliden, så mester, Europa, midten og nedrykning kan ses straks. Slettes testbrugeren bagefter, så ryd browserens lager og genindlæs, ellers fås 401-fejl og sæsonen starter aldrig. Ryd ikke localStorage midt i en session (giver "permission denied for function create_game"); genindlæs siden først. Slet egne testspil, HoF-rækker og anonyme testbrugere bagefter. Rasmus' egen konto har et spil kaldet "Test" (id 523de12e…): rør det ikke. Appen opdaterer sig ikke selv, mens den er åben; luk og åbn den igen og tjek versionen øverst til højre.

## Backup plan: manager i draften (2026-10-22, ikke bygget)
Idé: draft en manager som valg nr. 12; managerens FM-rating (CA) giver et %-boost til alle 11 spillere, fx `(CA − 120)/70 × 3 %` (0 % under 120, 3 % ved 190). AI-klubberne får deres egen manager. Simuler effekten (tabel og titelchance) før tallene låses; hvem der er cheftræner skal matches på navn (staff-tabellen har ingen rolle).
