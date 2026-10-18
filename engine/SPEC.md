# Kampmotor, udkast 0.2 (kalibreret)

Baseret på udkast 0.1, Argons review (2026-10-18) og en Python-referencemotor (`engine/reference/`) kørt på `data/players_pl_2026-27.json`.

## Kalibrerede parametre
- Kampdagsform: `R_i = (rating_i + N(0, σ_i²)) · f_i` med `σ_i = 6 − 0,25 · (consistency − 1)`, plus et fælles holdudsving `N(0, 1,5²)` til alle 11 spillere.
- Holdstyrke: OFF og DEF er vægtede gennemsnit (vægte i udkast 0.1) over de besatte pladser.
- Forventede mål: `λ_H = μ_H · exp((OFF_H − DEF_A) / k)`, `λ_A = μ_A · exp((OFF_A − DEF_H) / k)` med **k = 40, μ_H = 1,37, μ_A = 1,05**.
- Straffe: 0,29 pr. kamp, tildelt holdet proportionalt med λ, scoring 0,80 (justeres efter `pen_taking`).
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
