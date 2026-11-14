# PL Draft: arbejdsnoter til Claude

Rasmus' private fodbold-draftspil (iPhone, venner). Dette er en overdragelse: den nye Claude skal kunne køre videre uden at spørge om det grundlæggende. Læs også `README.md` (beslutninger og testgenveje) og `engine/SPEC.md` (motorens regler).

## Sprog og stil

- Rasmus skriver dansk; svar på dansk. Selve appen er på engelsk.
- Hold svarene korte: besvar hans spørgsmål først, rapportér kun det han selv skal gøre og det vi har lært. Ingen lange succesopsummeringer.
- Beslutninger til ham: en simpel nummereret liste, ét konkret ja/nej-spørgsmål pr. punkt, uden baggrund.
- Nævn ikke hver gang, at noget ikke er set på hans telefon.
- Efter synlige UI-ændringer: tag selv et screenshot (390×844) i en lokal kopi og send det, i stedet for at bede ham åbne appen.

## Arkitektur

- `vendor/supabase-2.45.4.min.js`: supabase-js, kopieret fra npm-pakken (integritet tjekket mod npm-registret). Opdateres ved at lægge en ny fil og rette navnet i både `index.html` og `sw.js`.
- `index.html`: hele klienten i én fil. Hostes på GitHub Pages (`munksgaard91/draftspin-fc`, branch `main`). `sw.js` er service worker; hæv `CACHE` (`dsfc-shell-vNN`) ved hver klientændring, ellers ser telefonerne den gamle version.
- Supabase-projekt `apagcfedizgjnnuefzfo` (Postgres, anonym login, RPC'er, edge function `engine`). Kampmotoren kører på serveren: `supabase/functions/engine/engine.js` (ren simulation) og `index.ts` (handlinger, fx afspilning af runder og interaktive straffe).
- `supabase/migrations/`: databasens historik, nummereret 001-073 (027 mangler med vilje). Nye migrationer får næste nummer; en test kræver stigende, unikke numre. Nogle ældre ændringer blev kørt direkte i databasen (fx 051, 054, 055, 057), og databasens egen migrationsliste (`supabase_migrations.schema_migrations`) passer ikke med repoet, så stol ikke på den.
- `supabase/schema/public.sql`: øjebliksbillede af den levende database (tabeller, funktioner, policies, rettigheder, realtime, cron). Det er sandheden om databasen. Genereres med `./scripts/schema_snapshot.sh` (kun læsning); kør det efter hver migration og commit det sammen med migrationen.
- `data/` og `scripts/`: spillerdata og lokale hjælpescripts.

## Versionsnummer

`<meta name="app-version" content="0.7.2.0 (beta)">` i `index.html` (vises øverst til højre på startskærmen). Format 0.MINOR.PATCH.MICRO (beta). Hæv ved meningsfulde batches, i samme commit som ændringen. Sæt aldrig 1.0 uden at spørge Rasmus: den er reserveret til, når cups, brugere og statistik er på plads.
- Changelog: tilføj en post øverst i `CHANGELOG` i `index.html` ved HVER versionsændring, på engelsk og kun med det, spillerne kan mærke. Del op i `new` (New features), `fix` (Bug fixes), `ui` (Design) og `small` (Small changes), og skriv alt i et sprog, alle forstår (intet teknisk). Den vises under "What's new" i hjørnet og som popup én gang efter en opdatering.

## Motoren

- `ENGINE_VERSION` i `engine.js` (nu 1.15). Hver ændring af motoren ændrer fingeraftrykket.
- Ændres motoren med vilje: opdatér fingeraftryk og simulationshash i `tests/engine_test.ts` og i `engine/SPEC.md`, tilføj en kort sektion i `SPEC.md`/README.
- Kør alle tests: `./tests/run.sh` (kræver `deno`). De skal være grønne før commit.
- Deploy af edge function: udgiv både `engine.js` og `index.ts` som fulde filer (Supabase-konnektoren `deploy_edge_function` eller Supabase CLI). Verificér bagefter med `action: "hash"` (kræver en gyldig bruger-token; en anonym tilmelding mod `/auth/v1/signup` med projektets publishable key giver en) og sammenlign med fingeraftrykket fra testene. Repo og udgivet kode skal være identiske.
- Straffespark (v1.15): i menneskekampe (ikke Quick) gemmes straffe som `type = 'pen_pending'` uden udfald og tæller ikke i scoren. Serverhandlingen `pen` afgør dem med spillerens valg (`applyPen`). Springes en straf over, afgør serveren den med et seedet hjørne, når runden skifter (`settleSkipped`). Score og clean sheets tælles op i RPC'en `recount_match`.
- Sæsonafslutning: et normalt spil afsluttes først, når alle har bekræftet runde 38 ("End season", `advance` i runde 38 → `finishSeason`). Hurtigt spil afsluttes, så snart runde 38 er spillet.
- Spillerdata fastfryses ved sæsonstart i `season_secret.players`; sæsoner fra før v1.15 bruger de nuværende data.

## Demotilstand og skærmgalleri (design)

- `index.html?demo=<skærm>` viser en skærm med faste, opdigtede data (4 demo-hold, en hel sæson simuleret med motoren). `?demo=list` viser alle skærme. Supabase erstattes af en falsk klient (`demoClient`), og browserens lager kører kun i hukommelsen, så intet skrives til databasen, og et rigtigt spil på telefonen røres ikke. Mærket "DEMO" vises nederst til venstre.
- Skærme: `DEMO_SCREENS` i `index.html` (start, lobby, draft, kickoff, live, others, squad, goal, penalty, penalty-corner, penalty-ai, fulltime, table, stats, end-champion, end-top, end-mid, end-down, hof, hof-empty). Nye skærme tilføjes dér, når de kommer (Rasmus 2026-11-05).
- Data: `demo/fixtures.json`, genereres med `deno run --allow-read --allow-write scripts/demo_fixtures.ts <players.json> <clubs.json>` (eksportér spillere/klubber med `supabase db query ... --read-only`, se kommentaren i scriptet). Generér igen, når spillerdata eller motoren ændres.
- Skærmgalleri: Claude tager selv billeder i browser-panelet (390×844) af hver `?demo=`-skærm og samler dem med `python3 scripts/gallery_sheet.py <ud.png> "nøgle|titel|billede" ...` til ét billede i `~/Desktop/PL Draft/galleri/`. Send det til Rasmus efter UI-ændringer.
- Animationer står stille, når browser-panelet er skjult; demoen slår derfor indtoning fra og fryser målanimationen midtvejs.

## Test uden at vente

- Skjult testspil: tryk 5× på logoet (`.startlogo`), vælg Quick game (`[data-tm=quick]`) eller Draft only (`[data-tm=draft]`). Mere i README, afsnittet om test-noter.
- Vent aldrig på en hel sæson: sæt `localStorage dsfc-testskipsim`=1 i testspillet; `dsfc-testpos` (1-20) flytter holdet i slutskærmens tabel.
- Lokal server: `python3 -m http.server 8123` i repo-mappen (browser-preview via `.claude/launch.json`).
- Browser-panelet kan ikke registrere service workers på localhost (selv en tom fejler); test `sw.js` på den udgivne side eller i et lille Deno-testmiljø.
- Ryd ikke localStorage og slet ikke testbrugere, mens siden kører (giver 401 / "permission denied for function create_game"); genindlæs først.
- Registrér hvert testspil i `scripts/testids.json`. Slet bagefter dine egne testspil (først `hof_*`, så `games`) og anonyme testbrugere (`is_anonymous`), verificér antal før/efter. Rør aldrig Rasmus' egne spil eller Hall of Fame-rækker; hans konto har et spil kaldet "Test" (id 523de12e…) og et spil f303deb9-5205-4387-8143-7a65208175b8, som må blive.

## Åbne punkter (ikke påbegyndt, start ikke uden besked)

- Brugere/login og statistik pr. bruger (inkl. "Flest nedrykninger"); i dag er alle anonyme.
- Mere realistiske klubemblemer; spillerbilleder (facepacks); pokaler/cup; ⚽/❌ i Match facts; nyt logo/navn; manager i draften; karakterer pr. spiller pr. kamp; redesign af målanimationen; færre emojis.
- To-spiller-straffeflowet (modstander venter via `penWatch`) er ikke testet med to rigtige enheder.

## Adgang

Supabase-projektet ligger på Rasmus' private konto. Adgang sker via Supabase CLI (`brew install supabase/tap/supabase`, Rasmus kører selv `supabase login`); kør kommandoerne fra repo-roden.
- Læse-SQL: `supabase db query "<sql>" --remote=apagcfedizgjnnuefzfo --read-only` (tilføj `--output-format json` for at parse). SQL der skriver kræver `--yes`: spørg Rasmus først.
- Edge functions: `supabase functions deploy engine --remote=apagcfedizgjnnuefzfo`; `supabase functions download` til at sammenligne med repoet.
- `supabase db dump` kræver Docker, som ikke er installeret; brug `scripts/schema_snapshot.sh` i stedet.
- Kontoen har også projektet "Lottes PlexPlan": rør det aldrig.
- GitHub Actions kører `./tests/run.sh` ved hvert push (`.github/workflows/tests.yml`).

Gem aldrig tokens, adgangskoder eller service-nøgler i repoet.

## Hall of Fame-filtre (2026-11-05)
- Tre filtre, alle starter på All: Game mode (`pace`: full/quick), Respins og Players. `hof_players_top`/`hof_teams_top(p_resp, p_pmin, p_pmax, p_pace)` (migration 070). Engine skriver `pace` på hof-rækkerne. Rækker fra slettede spil har `pace` null og vises kun under All.
- RPC'erne kan kun kaldes som `authenticated`, så `--read-only` CLI kan ikke teste dem; test i appen.

## Brugere (v0.7, 2026-11-08)
- Login med Google via Googles egen knap (popup, `signInWithIdToken` med nonce) eller som gæst (anonym Supabase-bruger som før). Client ID står i `G_CLIENT` i index.html (offentligt). Google-opsætningen står som In production uden logo; privatlivspolitikken ligger i `privacy.html`.
- `AUTH.stage`: "login" (første skærm), "setup" (første login: managernavn og fulde navn), "ok". `AUTH.view="profile"` er profilsiden. Gæstevalget huskes i `dsfc-mode`.
- Migration 071: `profiles` (managernavn unikt, fulde navn kun for brugeren selv; andre læser `profiles_public` uden fulde navn), `create_profile`, `set_manager_name` (maks. 1 gang pr. 30 dage, første valg tæller ikke), `set_avatar`, bucket `avatars` (`<uid>.jpg`, kun egen fil, maks. 256 KB). `update_team`/`set_name` bruger altid managernavnet for brugere.
- Engine: kun brugere MED profil gemmes i Hall of Fame (opslag i `profiles`; fejler opslaget, stopper sæsonslut). `owner` = managernavnet. `players` tæller stadig alle menneskehold. `delete_account` kalder `delete_account_data` (migration 073, én transaktion), sletter derefter billedet og brugeren.
- Continue game (v0.7.2, migration 073): `my_game()` giver det nyeste ufærdige spil (lobby/draft/season, `left_at` null); knappen står på start- og login-skærmen (`CONT`, `contHtml`, `contGo`). Kun ét spil gemmes: New Season/Multiplayer/Join med et igangværende spil viser en bekræftelse (`contGuard`) og kasserer det gamle spil med `discard_game` EFTER det nye er oprettet. `_discard_game`: ingen andre mennesker tilbage → spillet slettes; lobby → rækken slettes; draft/sæson → `left_at` sættes (AI overtager, `missed_rounds` 99 så holdet ikke kommer i Hall of Fame), og admin går videre. `is_member` er falsk for spillere med `left_at`. Home midt i et spil gemmer spillet (kan fortsættes).
- Brugere med Google skal have profil for at oprette/deltage (`_need_profile`). Gæstenavne må ikke være en brugers managernavn eller "Deleted user" (`_check_guest_name`). Navneskift opdaterer også `owner` i Hall of Fame.
- Bots er gæster, så `scripts/bots.py` forventer 0 Hall of Fame-rækker.
- Managers-fanen og profilstatistik venter: Rasmus har en anden idé. Spørg, før det bygges.
