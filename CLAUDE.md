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
- `supabase/migrations/`: databasens historik, nummereret 001-078 (027 mangler med vilje). Nye migrationer får næste nummer; en test kræver stigende, unikke numre. Nogle ældre ændringer blev kørt direkte i databasen (fx 051, 054, 055, 057), og databasens egen migrationsliste (`supabase_migrations.schema_migrations`) passer ikke med repoet, så stol ikke på den.
- `supabase/schema/public.sql`: øjebliksbillede af den levende database (tabeller, funktioner, policies, rettigheder, realtime, cron). Det er sandheden om databasen. Genereres med `./scripts/schema_snapshot.sh` (kun læsning); kør det efter hver migration og commit det sammen med migrationen.
- `data/` og `scripts/`: spillerdata og lokale hjælpescripts.

## Versionsnummer

`<meta name="app-version" content="0.8.6.0 (beta)">` i `index.html` (vises øverst til højre på startskærmen). Format 0.MINOR.PATCH.MICRO (beta). Hæv ved meningsfulde batches, i samme commit som ændringen. Sæt aldrig 1.0 uden at spørge Rasmus: den er reserveret til, når cups, brugere og statistik er på plads.
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
- Skærme: `DEMO_SCREENS` i `index.html` (start, lobby, lobby-rules, lobby-instant, draft, kickoff, live, others, squad, goal, penalty, penalty-corner, penalty-ai, fulltime, table, stats, end-champion, end-top, end-mid, end-down, hof, hof-empty, profile, profile-stats, profile-goals, profile-assists, profile-cs, profile-picked). Nye skærme tilføjes dér, når de kommer (Rasmus 2026-11-05).
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

- Profilstatistik er bygget (v0.8.5.0, se "Profilstatistik" nedenfor). Managers-fanen (andre brugeres statistik) er ikke besluttet.
- Mere realistiske klubemblemer; pokaler/cup; ⚽/❌ i Match facts; nyt logo/navn; manager i draften; karakterer pr. spiller pr. kamp; redesign af målanimationen; færre emojis.
- To-spiller-straffeflowet (`penWatch`) er ikke testet med to rigtige enheder; Rasmus 2026-11-15: det er droppet som krav før 1.0.

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
- Continue game (v0.7.2, migration 073): `my_game()` giver det nyeste ufærdige spil (lobby/draft/season, `left_at` null); knappen står KUN på forsiden og KUN for brugere med Google, aldrig for gæster eller på login-skærmen (`CONT`, `contHtml`, `contGo`). Kun ét spil gemmes: New Season/Multiplayer/Join med et igangværende spil viser en bekræftelse (`contGuard`) og kasserer det gamle spil med `discard_game` EFTER det nye er oprettet. `_discard_game`: ingen andre mennesker tilbage → spillet slettes; lobby → rækken slettes; draft/sæson → `left_at` sættes (AI overtager, `missed_rounds` 99 så holdet ikke kommer i Hall of Fame), og admin går videre. `is_member` er falsk for spillere med `left_at`. Home midt i et spil gemmer spillet (kan fortsættes).
- Brugere med Google skal have profil for at oprette/deltage (`_need_profile`). Gæstenavne må ikke være en brugers managernavn eller "Deleted user" (`_check_guest_name`). Navneskift opdaterer også `owner` i Hall of Fame.
- Bots er gæster, så `scripts/bots.py` forventer 0 Hall of Fame-rækker.
- Managers-fanen (andre brugeres statistik) er ikke besluttet. Profilstatistik er bygget i v0.8.5.0.

## FM27-data og billeder (v0.8.0, 2026-11-14)
- Kilde: Rasmus' FM27-karriere `~/Library/Application Support/Sports Interactive/Football Manager 27/games/` (frisk, in-game 2026-07-13). Læses med `fmsave` 0.12.5 i et venv (`fmsave export <save> players --all -o players.csv`); kopiér savet først. Match på `unique_id` = `face_id` og på den klub spilleren spiller i (`club_uid`), ikke kontraktklubben (lejespillere). Klub-ID'er: ARS 602, AVL 603, BOU 600, BHA 618, BRE 617, CHE 630, COV 639, CRY 642, EVE 649, FUL 654, HUL 665, IPS 667, LEE 671, LIV 676, MCI 679, MUN 680, NEW 688, NFO 692, SUN 722, TOT 728.
- Migration 074: CA/PA fra FM27 for alle (boost uændret), Monga fjernet (udlejet; regel fra Rasmus: kun spillere, der er i klubben lige nu), 8 silhuetter fik FM27-ID, Richarlison tilføjet (TOT #9). Tal før: `data/players_rating_backup_20261114.json`.
- Billeder: sortitoutsi-pakken ligger installeret i FM27 (`graphics/sortitoutsi/faces`, face_<unique_id>.png). Billedarket bygges med `python3 scripts/build_atlas.py <faces-mappe> <ids.json> <ud.webp>` (96 px-celler, 24 pr. række; giver også FACE_ORDER og CSS-størrelsen, der står 5 steder i index.html). Læg op som nyt navn (`atlas-N.webp`) i bucket `faces` med `supabase storage cp ... --experimental`, ret `ATLAS_URL` og ryd det gamle navn i `preloadFaces`. Nu: `atlas-3.webp`, alle 542 spillere har billede.
- Spillere uden for FM: eget billede i `data/faces_extra/face_<id>.png` (250×250, gennemsigtig, beskåret som pakken) og et face_id fra 900000001 og op. Max Dowman = 900000001.
- Migration 075 (efter Fable-audit): age, consistency, important_matches, pen_taking fra FM27; boost regnet om for ALLE efter SPEC-regel 2 (Rasmus: reglen gælder for alle ved hver dataopdatering, de gamle boosts fulgte den ikke); positioner efter FM (Rasmus: "FM bestemmer"; MR/ML bliver RW/LW, da LM/RM ikke er hovedpositioner); Hincapié LB + CB nat (Rasmus' valg), Marmoush ST (LW/RW er allerede svage for ST). Tal før: `data/players_backup_075.json` (fuld tabel).
- Svage ekstrapositioner pr. spiller findes ikke: kun `alts.<pos>.nat` tæller (pfit/fac); svage pladser er faste pr. hovedposition (PENALTY_SLOTS).
- `fm_uid` er upålidelig (blandet FM26/FM27 save-uid); match altid på `face_id` = FM unique_id.
- CLI-eksport giver numeric-kolonner (yellow_w, red_w) som tekst; konvertér til tal før `scripts/demo_fixtures.ts`.

## Afklaret med Rasmus og lært (2026-11-14)
- Arbejdsgang: efter store ændringer i tal skal Fable (Agent med `model: fable`, kun læse) auditere, og Claude skal selv auditere før push. Rapportér fund kort med nummererede ja/nej-beslutninger.
- Versioner: "version 8.0" betyder 0.8.0.0 (formatet 0.MINOR.PATCH.MICRO; 1.0 stadig reserveret). En upushet version kan omdøbes/samles; skriv én samlet changelog-post.
- Trupper: kun spillere, der er i klubben lige nu, er med. Udlejede spillere fjernes; lejespillere IND tæller for klubben, de spiller i.
- Positioner: "FM bestemmer" (FM's naturlige position, MR/ML → RW/LW). Rasmus kan overstyre: Marmoush ST (svag LW/RW følger af ST), Hincapié LB + CB fuld. Svage ekstrapositioner pr. spiller findes ikke; skal noget være "svagt", må det følge af hovedpositionens faste straf-pladser, ellers vælg mellem fuld ekstra eller ingen.
- Boost: reglen gælder for alle ved hver dataopdatering, og alder opdateres samtidig. De gamle boosts (loft 8,0) var ikke regnet efter reglen. Boost afrundes til 1 decimal før rating.
- Dobbelte spillere er bevidst: en draftet spiller spiller også for sin AI-klub. Derfor vises AI-holdenes målscorere ikke, og statistik tæller kun for ejeren. Ret ikke det.
- Spillere, der ikke er i FM (fx Max Dowman): Rasmus sender et billede; beskær det som pakken (håret til overkanten, hovedet ca. 75 % af bredden, 250×250, gennemsigtig).
- Forventet efter FM27: Liverpool vinder ligaen sjældnere (ca. 14 % mod 26 %), fordi deres stjerner faldt i FM27. Det er data, ikke en fejl. Tallene i SPEC (Arsenal 168,9 osv.) og i headeren på `engine/reference/season_titles.ts` er forældede.
- Straffe: klienten må ikke regne serverafgjorte tal af de levende data, når sæsonen bruger fastfrosne. Hjørner pr. skytte sendes nu med den ventende straf (`detail`).
- Deploy-kontrol: `supabase functions download engine --use-api` i en tom mappe i scratchpad (ALDRIG i repoet: den overskriver `supabase/functions/engine`) og `diff` mod repoet. `action: "hash"` kræver en anonym testbruger; auto mode afviste at oprette den 2026-11-14, så byte-diff blev brugt.
- Nyttige CLI-kommandoer: `supabase db query -f <fil> --remote=... --yes` (migration), `supabase storage cp <fil> ss:///faces/<navn> --experimental --content-type image/webp --remote=...`, `supabase functions deploy engine --use-api --remote=... --yes`. Auto mode har bløde stop på skrivende SQL og deploy: spørg Rasmus først.
- Skarpe screenshots uden browser-panelet: `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --force-device-scale-factor=2 --window-size=446,1700 --virtual-time-budget=4000 --screenshot=<fil> <url>` (lokal Chrome). Mockups uden for repoet kan vises via en kopi i `.claude/` (ikke i git) på `localhost:8123/.claude/...`; en server uden for repoet blev afvist af auto mode.
- Browser-preview: `.claude/launch.json` findes lokalt (ikke i git); virker preview_start ikke, så start `python3 -m http.server 8123` i baggrunden og åbn `http://localhost:8123/index.html?demo=...`. Appens variabler er ikke globale i browseren (kan ikke sættes via JS-konsollen); test via demotilstanden.

## Profilstatistik (v0.8.5.0, 2026-11-15)
- Kode: `PST`/`pst*` og `hofLeaders` i index.html. Henter `hof_teams`/`hof_players` med `user_id` + `hof_teams_top`/`hof_players_top` (All) direkte fra klienten (RLS tillader authenticated); ingen ny RPC. Cache 60 s pr. bruger (`PST.uid`).
- Hall of Fame nr. 1 = samme sortering som Hall of Fame-skærmen; ved uafgjort vinder den første række i RPC-rækkefølgen (som på skærmen).
- Clean sheets: motoren giver kun `clean_sheet` til målmanden, så Players > Clean sheets viser kun målmænd. Holdets clean sheets = maks. spiller-clean-sheets pr. sæson (præcis i dag).
- Formation gemmes nu for ALLE hold i `hof_teams` (før kun mesteren); migration 076 fyldte de 3 sæsoner, hvor spillet stadig fandtes. `lineup` er stadig kun for mesteren. Vises med `flabel()`.
- "Most picked" tæller `hof_players`-rækker; motoren skriver kun rækker for spillere med mindst én hændelse (i praksis altid 11 pr. sæson).
- "Back to top" (`totopCheck`): vises automatisk på skærme over ca. 1,7 skærmhøjde (ikke draft/live); på profilen står den over Log out.
- Versioner: Rasmus valgte selv 0.8.5.0 frem for 0.9 for denne batch.

## Spilletid (v0.8.5.1, 2026-11-15)
- Lobbyen viser "about N min" under Classic/Quick game og i regel-linjen (`estMin` i index.html), rundet OP til nærmeste 5 (Rasmus). Regnes ud fra antal deltagere nu, timer og kamphastighed.
- Grundlag (Claude målte 2026-11-15): Classic 37 s pr. runde ved 1x med 2 s reaktion; regnet forsigtigt som 26 s/hastighed + 14 s, +5 s med flere mennesker; runder med en menneske-mod-menneske-kamp (n(n-1) af 38) går i den langsomste hastighed, fordi alle venter; draft 18 s pr. valg på skift; hvert respin +12 s pr. spiller. Rasmus: hellere for lang end for kort tid; Quick afspiller 38 runder à 4,4 s PÅ TELEFONEN efter at serveren er færdig. Testspil (5 tryk på logoet) springer Quick-afspilningen over, så de kan ikke bruges til at måle Quick.
- Migration 077: `game_times` (kun service-rollen kan læse; vises ingen steder) skrives af en trigger, når et spil bliver `done`, og overlever, at spillet slettes efter 7 dage. Telefonen kalder `log_game_seen` ved slutskærmen (`logSeen`), så `seen_last - created_at` er den tid, spillerne faktisk brugte. Serverens `done_at` er misvisende for Quick.
- Rasmus: kør med estimatet, indtil der er rigtige data; opdatér så `estMin` ud fra `game_times` (medianer pr. spiltype og antal spillere).

## Instant (Quick game, 2026-11-15)
- Rasmus: ny afspilning "Instant", kun i Quick game. Viser kun resultatet runde for runde (`INSTANT_MS` = 1,3 s pr. runde, ca. 50 s for en sæson). Kamp-delen (fase A i `liveSimStep`) springes over; Pause/Skip virker som før.
- Gemmes i `games.playback` ('normal'/'instant', migration 078), sættes af admin i lobbyen (`set_playback`, række "Playback" vises kun ved Quick game), kopieres af `new_season`, gemmes i `game_times.playback`.
- Hall of Fame: tæller som Quick (`pace` = quick), intet eget filter (Rasmus).
- Testspil: skjult testboks har "Quick game (Instant)"; Instant-testspil afspilles (springes ikke over som normale testspil).

## Næste skridt (stoppet 2026-11-15)
Mod 1.0 (reserveret til når brugere, statistik og cups er på plads; brugere er færdige i v0.7):

1. **Profilstatistik** (BYGGET i v0.8.5.0, 2026-11-15; specifikationen nedenfor er det godkendte design). Mockup: `~/Desktop/PL Draft/mockups/profil2.html` (`?p=1` Overview, `3` tom Hall of Fame-blok, `2` Goals, `4` Assists, `5` Clean sheets, `6` Most picked) og `mockup-profil2.png`. `profil.html` (v1 med Teams) er forældet.
   - Farvevalg: én linje små dæmpede prikker (14 px, 50 % opacity), valgt farve fuld med ring, label "Colour".
   - "Your stats" med filter All / Classic / Quick (`pace`) og to faner: **Overview** og **Players**. INGEN introtekst. INGEN Teams-sektion (holdnavne er bevidst unikke pr. spil).
   - **Overview**, i rækkefølge:
     - Topfelt med 3 tal på linje (25 px mono, samme højde): Titles (pokal + tal, "Leagues won"), Seasons ("Played to the end"), Avg. finish som HELTAL med ordenstal ("6th", "Your usual place").
     - **Recent form**: præcis 2 rækker × 8 = de 16 seneste sæsoner, NYESTE først, ordenstal (1st, 2nd, 13th). Alle brikker samme neutrale farve, kun 1st i guld. Tekst: "Your last 16 seasons, newest first."
     - **Career finishes** (hele karrieren): én kolonne fra bedst til dårligst med ikon og antal, 0 (nedtonet) hvis ikke opnået: Champions (pl-trophy) 1., Runner-up (sølvmedalje-SVG) 2., Champions League (eu-cl) 3.–4., Europa League (eu-el) 5.–6., Conference League (eu-ecl) 7., Relegated (efl-champ) 18.–20. Samme zoner som `zone()` i tabellen.
     - **Results**: Points per match (tal + "points" til højre, ingen forklaring); Matches med "456 played" til højre, 3 kolonner Won/Drawn/Lost med stor procent (afrundet så summen er 100) og "Won · 219" under, grafen under kolonnerne.
     - **Stats**: Goals scored, Goals conceded (x.x per match), Clean sheets ("Matches without conceding"), Yellow cards (x.x per match), Red cards (0.05 per match, to decimaler). Små kort-ikoner foran kortene.
     - **Your records** (brugerens egne bedste, samme navne som Hall of Fame): Most points in a season, Longest winning streak, Biggest win, Most team goals in a season.
     - **Hall of Fame entries** (guld-design): kun lister hvor brugeren er nr. 1 af alle (filtre på All). Overskrift "You hold N records", rækker med guldmønt "1" eller spillerens ansigt (spillerrekorder), værdi i guld. Uden rekorder står blokken der stadig: "No records yet" + forklaring på hvordan man kommer på listen.
     - Log out, Privacy, Delete account nederst.
   - **Players**: under-filtre Goals / Assists / Clean sheets / Most picked. Ingen forklaringslinje. Nr. 1 stort kort (tal 26 px, plads til 4 cifre), nr. 2–10 i liste (top 10).
     - Goals/Assists/Clean sheets: totaler over alle sæsoner; under navnet "Best season: x goals" (11 px i listen, 12 px på topkortet). Ingen guld i listen. I bunden en guld "Hall of Fame"-blok med selve rekorden (fx Most goals in a season, spiller · hold · sæson) KUN hvis en af brugerens spillere har rekorden for den kategori; ellers ingenting (ingen forklarende tekst).
     - Most picked: tal = "picks" (antal sæsoner draftet); under navnet spillerens NUVÆRENDE klub med lille emblem (`badges/<KODE>.png`). Ingen Hall of Fame-blok. I bunden **Formations**: brugerens formationer, mest brugte først, "9 seasons · avg. 4th" + grøn bjælke relativ til favoritten.
   - Data: kun afsluttede sæsoner med Google-bruger (`hof_teams`/`hof_players` med `user_id`). Kræver sandsynligvis en RPC (fx `my_stats(p_pace)`), da hof-RPC'erne kun kan kaldes som `authenticated`. Hall of Fame nr. 1 skal matche Hall of Fame-skærmens logik (`hof_teams_top`/`hof_players_top` med All). Tilføj demo-skærme (`DEMO_SCREENS`) med opdigtede tal.
2. **Varighed pr. spil**: BYGGET i v0.8.5.1/0.8.6.0 (se "Spilletid"). Opdatér `estMin`, når `game_times` har rigtige data.
3. **Endnu hurtigere spiltype**: BYGGET i v0.8.6.0 som "Instant" under Quick game (se "Instant").
4. **Cups/pokaler**: ikke designet.
5. **Hall of Fame-redesign** (Rasmus 2026-11-15: skal med før 1.0): ikke designet endnu; afklar med Rasmus, hvad der skal ændres.
