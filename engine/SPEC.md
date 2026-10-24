# Kampmotor, udkast 0.2 (kalibreret)

Baseret på udkast 0.1, Argons review (2026-10-18) og en Python-referencemotor (`engine/reference/`) kørt på `data/players_pl_2026-27.json`.

## Kalibrerede parametre
- Kampdagsform: `R_i = (rating_i + N(0, σ_i²)) · f_i` med `σ_i = 6 − 0,25 · (consistency − 1)`, plus et fælles holdudsving `N(0, 1,5²)` til alle 11 spillere.
- Holdstyrke: OFF og DEF er vægtede gennemsnit (vægte i udkast 0.1) over de besatte pladser.
- Forventede mål: `λ_H = μ_H · exp((OFF_H − DEF_A) / k)`, `λ_A = μ_A · exp((OFF_A − DEF_H) / k)` med **k = 40, μ_H = 1,37, μ_A = 1,05**.
- Straffe: 0,29 pr. kamp, tildelt holdet proportionalt med λ, scoring 0,80 (justeres efter `pen_taking`). v1.10: én fast skytte pr. hold (højest `pen_taking` blandt dem på banen; ved lighed den udpegede straffeskytte `pen_rank` for den stærkeste klub), og aldrig to straffe i samme minut i en kamp.
- Resultat med 4 spillere og 16 AI-klubber: cirka 2,78 mål pr. kamp, hjemmesejre 46 %, uafgjort 23 %, udesejre 31 %, mester cirka 85 point, sidstepladsen cirka 30 point, standardafvigelse på point cirka 14,7.
- Ratingforskel Δ mellem to hold og hjemmesejr: 0 giver 44 %, 10 giver 59 %, 20 giver 74 %, 30 giver 85 %.

## Balance
Uden justering vinder det bedste spillerhold ligaen i 1 til 8 % af tilfældene, fordi de bedste AI-klubber (Arsenal 168,9, Manchester City 168,5, Liverpool 165,0) er stærkere end næsten alle draftede hold. Løsning: draftede spillere fjernes fra AI-klubberne, og admin vælger en AI-sværhedsgrad (AI-spillernes rating forskydes). Se `engine/reference/run_bal2.py`.

| Sværhedsgrad | AI-skift | 1 spiller, god draft vinder | 4 spillere, bedste hold vinder |
|---|---|---|---|
| Svær | 0 | 2 til 7 % | 8 til 29 % |
| Normal | −10 | 17 til 31 % | 56 til 76 % |
| Let | −15 | 38 til 55 % | 78 til 89 % |
(De to tal er "fornuftig" (blandt de 3 bedste) og "grådig" (altid bedste) drafting.)

## Ikke afprøvet endnu
Røde kort, minutter, scorer og assist, kort, straffeskytter og tidslinje (kun resultater er kalibreret). Formationsneutralitet er neutral pr. konstruktion, når alle pladser har samme rating, men skal testes med rigtige trupper.

## Held og tilfældighed (afprøvet 2026-10-18)
Pointen med spillet er også at slå vennerne, ikke kun ligaen. Målet er derfor, at et bedre draft vinder oftere, men ikke altid (reference: `engine/reference/luck_sim2.py`).

Skjult sæsonheld (et fast tillæg til alle spillere på et hold hele sæsonen, trukket ved sæsonstart) og en skjult formsvingning pr. runde (autokorreleret):

| Spillere | Held | Bedste draft vinder gruppen | Dårligste draft vinder gruppen | Bedre slår dårligere (parvist) |
|---|---|---|---|---|
| 2 | ingen ekstra | 79 % | 21 % | 79 % |
| 2 | sæsonheld sd 5 + form sd 3 | 63 % | 37 % | 62 % |
| 4 | ingen ekstra | 52 % | 5 % | 72 % |
| 4 | sæsonheld sd 3 + form sd 2 | 46 % | 9 % | 68 % |
| 4 | sæsonheld sd 5 + form sd 3 | 44 % | 12 % | 65 % |
| 4 | sæsonheld sd 7 + form sd 4 | 39 % | 12 % | 62 % |

Leicester-agtige sæsoner (mesteren var plads 8 eller dårligere på papiret): 0 % uden ekstra held, 0,2 til 1,2 % med sæsonheld 3 til 5. 

## Beslutninger om held og sværhedsgrad (Rasmus, 2026-10-18)
- Skjult sæsonheld (sd 5) og skjult formsvingning (sd 3, rho 0,8) indføres.
- Heldet trækkes tilfældigt for hvert hold, hver sæson og hvert spil, af serveren ved sæsonstart. Det gemmes kun i en privat tabel, som klienter ikke kan læse. Det afsløres ALDRIG, hverken undervejs eller ved sæsonslut. Ingen priser, ingen visning.
- Der indføres ingen sværhedsgrad. AI-klubberne beholder deres rigtige styrke (ingen nedskalering).
- Hurtigt spil og hele sæsonen giver samme resultater ved samme seed (seedet er hemmeligt på serveren).

## Mørk hest (forslag, 2026-10-18)
Ved hvert spil udpeger serveren hemmeligt ét AI-hold uden for top 10 (efter styrke) og giver det et ekstra sæsonheld oveni det almindelige. Spillerhold får aldrig bonussen (retfærdigt mellem vennerne). Aldrig afsløret. Resultater (`engine/reference/dark_sim.py`): bonus +10 giver 3 % titler og 26 % top 4; +12 giver 5 % og 37 %; +15 giver 9 % og 52 %.

Beslutning (Rasmus, 2026-10-18): mørk hest-bonus er **+6**.

## Uheld (Rasmus, 2026-10-18)
Ved hvert spil udpeger serveren hemmeligt ét AI-hold i top 10 (efter styrke) og giver det **−6** sæsonheld. Kun AI-hold, aldrig spillerhold, aldrig afsløret, tilfældigt hver gang. Effekt (`engine/reference/unlucky_sim.py`): rammes City, falder deres titelchance fra cirka 42 % til cirka 20 %, Arsenal fra 25 % til cirka 5 %. Samlet over mange spil ændrer det kun lidt (City 44, Arsenal 24, Liverpool 22 pr. 100 spil), fordi det oftest rammer et hold uden for top 3.


## v1.8 (2026-10-20): realistiske målscorere og kort
Problem: topscoreren fik i snit 55 mål pr. sæson (rigtig PL: ca. 26, max 36), 22 hattricks pr. sæson (rigtig: ca. 10). Målt med `engine/reference/realism_sim.ts` (150 sæsoner, kun AI-hold og med en "smart" drafter).
Ændringer: scorervægt `exp((R-140)/80)` (var /25); fladere positionsvægte (ST 1, LW/RW 0,85, AM 0,75, LM/RM 0,65, CM 0,45 osv.); en spiller der har scoret i kampen får chancen ganget med 0,7 pr. mål; K 40->46; holdets forventede mål dæmpes over 2,4 (hældning 0,6); gule-kort-vægte i potens 0,5 (YW_REF 11,1) så ligasnittet (3,99 gule/kamp, 0,13 røde/kamp fra football-data.co.uk) står fast, men enkeltspillere ikke får 17 gule.
Resultat: topscorer gns 26 (p90 31, sjældent over 40), hattricks ca. 6, mål/kamp 2,8, mester ca. 85 point, mest scorende hold ca. 86 mål, gule/kamp 3,99, bedste spiller 15 gule. Titelfordeling stort set uændret (City 47 -> 41 %).
Tjek af den udgivne motor: `action: "hash"` i edge function returnerer fingeraftryk + simulationshash; sammenlign med `deno run --allow-read /tmp/.../fp.ts` (se commit).

## v1.11 (2026-10-21): optimal opstilling til AI-klubber
bestXI bruger nu ungarsk metode (optimal tildeling) i stedet for at fylde plads for plads. Før fik 7 af 20 klubber ikke deres bedste hold (Chelsea op til 1,75 point lavere styrke). Hold fra spillere er upåvirket. Fingeraftryk 57ad7cfb…7976, simulation uændret.

## v1.12 (2026-10-24): balance, wingbacks, selvmål og tilfældig tillægstid
- **Balance-regel**: angrebs- og forsvarsstyrke (de vægtede gennemsnit i kampen) trækkes begge ned med 0,03 × (skævhed)², hvor skævhed = (angreb − forsvar) / 2. Små udsving er næsten gratis, ekstremer koster. Ved samme samlede rating giver blandede hold flest point (målt: ren forsvar 1,34 / balanceret 1,48 / ren angreb 1,44 point pr. kamp mod ligaen).
- **Holdstyrke** (`xiStrength`) er nu (angreb + forsvar) / 2 − samme straf, med kampens pladsvægte (før: almindeligt gennemsnit). Bruges til AI-klubbernes formationsvalg, rangering og dark horse/uheld.
- **Wingbacks** (LWB/RWB): angrebsvægt 0,07 → 0,10, målvægt 0,4 → 0,5, assistvægt 0,75 → 0,9. Assistvægt for LB/RB 0,6 → 0,4 og CB 0,12 → 0,06 (backs og stoppere stod for ca. 28 % af alle assists, nu ca. 20 %).
- **Selvmål**: ca. 0,046 pr. kamp (`OG_RATE` 0,023 pr. hold). Gemmes som `goal` med `detail = 'og'`: `team` er holdet der får målet, `player_id` er modstanderens spiller. Tæller ikke som mål for spilleren i statistik og Hall of Fame.
- **Tillægstid** i 2. halvleg: 1-9 minutter (1 + Poisson(3), snit 4), returneres som `added` og gemmes i `matches.added_time` (migration 064). Gamle kampe viser 4.
- **Fire nye formationer** (24 til valg): 3-1-4-2, 4-4-2 (D), 3-4-2-1 (D), 4-2-3-1 (W) (migration 065). Bedste mulige hold fra puljen ligger inden for samme bånd som de eksisterende (2,30-2,33 point pr. kamp).
- Fingeraftryk e340b7a8…84e6, simulation edcf370c…fd7f. Rang-profil og målfordeling: se rapporten i chatten 2026-10-24.

## Faste regler for nye spillere i `players` (Rasmus, 2026-10-21)
Bruges når en spiller kommer til (transfer, nyt save), og vi ikke har de oprindelige tal. Eksisterende spillere røres ikke af reglerne.
1. **Kortrisiko** (`card_risk`, `yellow_w`, `red_w`): regnes fra FM-egenskaber (0-20) med `card_risk = clamp(4,2·aggression + 4,6·dirtiness + 2,5·tackling + 0,3·bravery − 0,5·anticipation + positionskonstant, 0, 100)`, positionskonstant cirka −63 til −71 (CB −67, DM −69, ST −69). Passer på eksisterende spillere med gennemsnitlig fejl 4 point (95 % inden for 10); den oprindelige formel er ukendt. `red_w` slås op i kurven card_risk -> red_w fra eksisterende spillere (50 -> 0,83, 100 -> 1,99); `yellow_w` fra en ret linje card_risk -> yellow_w for spillerens position.
2. **Boost** (kun op til 23 år): `boost = faktor × (PA − CA)`, faktor 16-19 år 0,065, 20 år 0,05, 21 år 0,04, 22 år 0,03, 23 år 0,015, 24+ 0. `rating = round(CA + boost)` (afrund halve op, ikke bankers' afrunding).
3. **Alternative positioner**: kun en position med fit 19 eller 20 giver en ekstra plads (`alts.<pos>.nat = true`), og kun én; hvis det er en naboposition vælges den mest logiske. Svagere alternativer lægges ikke ind (motoren bruger alligevel kun `nat` og straf-tabellen).
4. **Trøjenumre**: fra Premier Leagues officielle liste, ellers ESPN-truppen; findes intet, bruges et ledigt nummer (30+). Unikt pr. klub.
5. **Dubletter**: tjek `face_id` og navn+klub før indsættelse (Florentino Luis blev ved en fejl indsat to gange).
