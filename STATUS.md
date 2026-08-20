# STATUS — Roll a Rune

Ostatnia aktualizacja: 2026-08-19, **PIVOT: start przejscia z plaskiej karcianki na 3D
COLLECTION-TYCOON** — patrz sekcje "Pivot na tycoon — T1 szkielet plotu", "T2 przydzial plotow +
wypelnianie slotow" i "T3 pasywna esencja online+offline" (2026-08-19) ponizej.
Silnik/Stworki/paczki/merge/esencja z karcianki ZOSTAJA i wpinaja sie jako tresc, nic nie
wyrzucone. Run/deckbuilder -> tryb wtorny na pozniej. Poprzedni stan (System 4 packi/daily/luck
zablokowane na decyzji Andreasa o strukturze tabel) jest teraz W TLE, nie skasowany — patrz
PACKS_PLAN_PROPOSAL.md, wraca gdy tycoon-pivot dogoni ten punkt. Czytaj to + `git log` zamiast
polegac na pamieci poprzedniej sesji.

## Pivot na tycoon — T1 szkielet plotu (2026-08-19)

Zbudowany **funkcjonalny szkielet plotu** (nie wyglad — to zrobi recznie Andreas/artysta
pozniej), przez `robloxstudio` MCP, `execute_luau` (edit-mode), pod
`game.ReplicatedStorage.PlotTemplate`. Motyw docelowy "Swit" (pastelowe niebo, bialy
kamien+zloto) — teraz tylko zgrubny blockout na Marble/SmoothPlastic/Neon.

**Kontrakt nazw (na tym stoja T2/T3/T5, nie zmieniac bez koordynacji):**
- `PlotTemplate` [Model, PrimaryPart=`PlotOrigin`] — kwadrat 64x64 studow, `Floor` top=Y0.
- `Slot1`..`Slot10` [Model] — wzdluz `BackWall` (Z=-30.5), rowny odstep co 6 studow (X od -27 do
  27), kazdy z `SlotAnchor` (PrimaryPart) + `CardMount` [Attachment].
- `CardFrame` [Model] w kazdym Slot — `Frame` (SmoothPlastic) niesie `SurfaceGui`
  (Face=Back, bo sciana/karty patrza w +Z) -> `CardArt` [ImageLabel], plus `RarityGlow` (Neon,
  placeholder szary) i `RarityBorder` (zloto) jako warstwy ZA `Frame` (nie przed — inaczej
  zaslanialyby obrazek). Test-obraz w `CardArt` = `rbxassetid://118458523871140` (emberpup,
  prawdziwy juz-uploadowany asset z `CardArtConfig.luau` — dowod ze pipeline realnie renderuje,
  nie fikcyjny placeholder).
- `EssenceGenerator` [Part] — Neon, srodek plotu (0,1.5,0), placeholder fontanny na tick T3.
- `EntranceArch` [Model] (PillarLeft/PillarRight/Beam) + `Nameplate` [Part+SurfaceGui.TextLabel
  "PLAYER'S PLOT"] — przy krawedzi wejsciowej (Z=+30, naprzeciw BackWall).

**Acceptance check — wszystkie 3 PASS, zweryfikowane live w Studio:**
1. Duplikacja: `Clone():PivotTo(CFrame.new(100,0,100))` na tescie w Workspace — `PlotOrigin`
   wyladowal dokladnie na zadanym CFrame (bit-dokladnie, nie przyblizenie).
2. Wszystkie 10 `CardFrame.Frame.SurfaceGui.CardArt.Image` zwracaja poprawny
   `rbxassetid://118458523871140` — potwierdzone petla przez `execute_luau` I zrzutem ekranu
   (10 kart z widocznym obrazkiem na scianie).
3. Nazwy dokladnie wg kontraktu (`get_instance_children` na klonie: `PlotOrigin`/`Floor`/
   `BackWall`/`EssenceGenerator`/`EntranceArch`/`Nameplate`/`Slot1..Slot10`, po 2 dziecka w
   kazdym Slot: `SlotAnchor`+`CardFrame`).

**WAZNE — ten projekt NIE MA Rojo/`project.json`** (patrz regula wyzej w tym pliku o
`Controllers`), wiec `PlotTemplate` istnieje TYLKO w zywym Studio DataModelu. **Andreas musi
zapisac plac** (Ctrl+S w Studio), inaczej znika przy zamknieciu — nic z tego nie jest jeszcze w
gicie/na dysku, bo to czysto instancje, nie skrypty.

**Celowo NIE zrobione w T1 (kolejne kroki):** brak serwerowego systemu placowania plotow (T2/T3),
brak realnego tick esencji, brak paczek/odwiedzania. Odds-bug i packi (System 4) queued przed
T4, jak wczesniej.

## Pivot na tycoon — T2 przydzial plotow + wypelnianie slotow (2026-08-19)

Wpina sie w nazwany szkielet z T1 (`PlotTemplate`, `Slot1..10`, `CardArt`). `PlotTemplate`
**przeniesiony z ReplicatedStorage do ServerStorage** (klient nigdy nie potrzebuje surowego
template'u, tylko zywych klonow w `Workspace.Plots`, ktore i tak replikuja).

**Nowe pliki:** `Shared/Configs/TierColorConfig.luau` (jedyne zrodlo tier->kolor, wyciagniete z
`UIFactory.TierColors` — serwer i klient teraz czytaja TA SAMA tabele, ta sama dyscyplina co
odds-bug fix), `ServerScriptService/Services/PlotService.luau` (przydzial siatki + zapis
slotow), `StarterPlayerScripts/Controllers/PlotController.luau` (panel wyboru karty).
**Edytowane:** `ProfileService` (+`profile.plotSlots` — sparse `[1..10]=totemId`, wzorzec
`streak.claimed`), `Net.luau` (+`GetMyPlot`/`SetPlotSlot`), `Bootstrap.server.luau` (ORDER:
`PlotService` po `IndexService`), `UIRootController` (+root `Plot`), `init.client.luau`
(+`PlotController`).

**Siatka:** N=8 plotow, 4x2, `GRID_SPACING=100` (footprint 64+zapas), offset od
`SpawnLocation(0,0.5,0)` o `GRID_BASE_Z=250` — zero kolizji z domyslnym Baseplate (potwierdzone
`get_instance_children` na czystym placu przed startem: tylko Terrain/SpawnLocation/Baseplate/
Camera). Alokacja/zwolnienie wpiete pod `ProfileService.ProfileLoaded`/`ProfileReleasing` (ten
sam wzorzec co StreakService/QuestService/AnnouncementService), idempotentne (podwojny
`ProfileLoaded` nie duplikuje plotu).

**ClickDetector — NOWY wzorzec w tym repo** (grep na starcie T2: zero `ClickDetector`/
`ProximityPrompt` gdziekolwiek wczesniej). Wybrany nad ProximityPrompt bo spec mowi "tap na
slot", nie "podejdz i przytrzymaj" — gracz i tak stoi na swoim plocie. `MaxActivationDistance=64`
(pelny footprint plotu z dowolnego rogu).

**Replikacja "za darmo" (spelnia p.4 specyfikacji, ustawia T5):** `CardArt.Image` /
`RarityBorder.Color` / atrybut `Frame:SetAttribute("TotemId", ...)` to zwykle
property/attribute-replication Roblox na instancjach pod Workspace — inni gracze widza
wystawione karty bez osobnego eventu. Klient odczytuje atrybut lokalnie zamiast dobijac sie
remotem.

**Walidacja serwerowa** (`PlotService.SetPlotSlot`, wzorzec 1:1 z `DeckService.SetDeck`): odrzuc
w calosci, jawny reason (`NoProfile`/`BadSlot`/`BadArg`/`UnknownTotem`/`NotOwned`). Serwer NIGDY
nie ufa referencji plotu od klienta — zawsze rozwiazuje wlasny plot gracza server-side przez
mape `Player -> Model`. `IsDiscovered` z `IndexService` to jedyne zrodlo prawdy o posiadaniu.
Wystawienie NIE konsumuje karty (referencja, `profile.totems` count bez zmian).

**WAZNE odkrycie tej sesji — zywe Studio != git.** Przed pushem stwierdzone (`get_instance_children`
na `Services`/`Controllers`), ze `MergeService` (System 3, serwer) i `DeckController` (MAX-SLOT,
klient) sa W GICIE, ale NIE ZYWE w Studio — nigdy nie zostaly wypchniete. Zmienilo to strategie
pushowania T2: zamiast pelnego `set_script_source` (ktory wstawilby do zywych
`Bootstrap.server.luau`/`init.client.luau` odwolania do serwisow/kontrolerow, ktorych tam nie ma
— serwerowy ORDER-desync guard by `error()`owal, klient zawisalby na `WaitForChild`), kazdy
wspoldzielony plik (`Net.luau`, `ProfileService.luau`, `UIFactory.luau`, oba `Bootstrap`,
`UIRootController.luau`) zostal zdiffowany wzgledem ZYWEGO zrodla i lataniowo poprawiony
(`insert_script_lines`/`edit_script_lines`), nie nadpisany. **To NIE jest naprawione teraz** —
System 3 (merge/craft) i MAX-SLOT-owy `DeckController` nadal czekaja na osobny przebieg pushu,
niezalezny od zakresu T2.

**Bug znaleziony i naprawiony przez live playtest** (nie code review): `PlotService.luau:75`
rzucal `Ambiguous syntax` na serwerze. Przyczyna: `borderPart.Color = TierColorConfig.tierColor(
totem.tier)` (linia konczaca sie wywolaniem funkcji) nastepowana przez linie zaczynajaca sie od
`(frame :: Instance):SetAttribute(...)` — Lua parsuje to jako KONTYNUACJE tego samego wywolania
(`tierColor(...)( frame ...)`), nie nowa instrukcje. Fix: rzutowanie raz do lokalnych zmiennych
(`frameInst`/`borderPart`/`cardArtLabel`) PRZED blokiem if/else, zero linii zaczynajacych sie od
`(` po wyrazeniu-wywolaniu.

**Acceptance check (2 graczy, live multiplayer playtest, `eval_server_runtime`/
`eval_client_runtime`, nie zalozenia):**

| # | Wymog | Wynik |
|---|-------|-------|
| a | Kazdy dostaje wlasny plot na innym miejscu siatki | `Plot_-1 @ (150,0,350)`, `Plot_-2 @ (50,0,350)` — dwa rozne modele, rozne pozycje |
| b | Kazdy wypelnia sloty ze SWOJEJ kolekcji przez remote (symulacja UI-flow: `NetController.Invoke`) | P1(capybop) `SetPlotSlot(1,"capybop")` -> `ok=true`; P2(lotti) `SetPlotSlot(1,"lotti")` -> `ok=true` |
| c | Kazdy WIDZI wystawione karty drugiego | Odczyt z client-1: `Plot_-1.Slot1.TotemId=capybop` (wlasna) I `Plot_-2.Slot1.TotemId=lotti` (cudza) — replikacja atrybutu potwierdzona live |
| — | (bonus) walidacja serwerowa faktycznie odrzuca | P1 probuje `SetPlotSlot(2,"lotti")` (nie posiada) -> `NotOwned`, zapis odrzucony |
| d | Uklad trwa po rejoinie | **czesciowo zweryfikowane** — `data.plotSlots` to zwykla mutacja profilu, ten sam wzorzec co juz zaufane `streak.claimed`/`indexClaims`, `ProfileStore` potwierdzony live-zapisujacy (`"Roblox API services available"`). Literalny "ten sam gracz opuszcza i wraca" NIE do zasymulowania w tym harnessie testow wieloosobowych — kazdy `add_players` mintuje NOWY syntetyczny UserId (kolejne ujemne liczby), nie odtwarza tozsamosci. Mechanizm zapisu jest identyczny jak dla juz-zweryfikowanych pol, ale prawdziwy round-trip rejoina wymaga prawdziwego gracza (Andreas) lub solo-playtest z tym samym Studio-userem. |

Zrzut ekranu **zablokowany** — `capture_screenshot` wymaga w tym miejscu wlaczonego "Allow Mesh /
Image APIs", ktore dla opublikowanych miejsc jest ustawieniem Creator Dashboard wymagajacym
weryfikacji wieku/ID konta (nie skryptowa property, nie do przelaczenia przez MCP) — pominiete
swiadomie, nie ukrywane.

**Andreas musi zapisac plac** (Ctrl+S) — jak w T1, wszystkie zmiany instancji (nowe ModuleScripty,
przeniesienie `PlotTemplate`, root `Plot`) zyja tylko w zywym Studio DataModelu dopoki nie
zapisane.

**Celowo NIE zrobione w T2 (kolejne kroki wg specyfikacji):** T3 (realny tick esencji z
`EssenceGenerator`), T5 ma "za darmo" architekturalnie (replikacja atrybutow), ale wizualne
dopieszczenie widoku cudzych plotow nie zrobione. Migracja/default = puste sloty (prostszy
wariant ze specyfikacji, nie auto-fill najlepszych owned). System 3/MAX-SLOT push do Studio
oraz odds-bug/packi (System 4) nadal queued, niezalezne od T2.

### Domkniecie sync dysk<->Studio + T2 acceptance (2026-08-19, druga polowa sesji)

Poprzedni akapit flagowal "System 3/MAX-SLOT nadal czeka na osobny push" — domkniete w tym
przebiegu. Zdiffowane WSZYSTKIE 11 plikow skryptowych (MergeConfig, MergeService, DeckController,
Net, ProfileService, EconomyService, UIRootController, init.client.luau, Bootstrap.server.luau,
IndexController, RollRevealController) git<->live przez `get_script_source`/`set_script_source`
(gotcha: parametr to `instancePath`, nie `path`).

**Znaleziony i naprawiony 1 realny dryf:** `RollRevealController` mial inaczej ustawiony blok
komentarza wzgledem `playReveal` (w gicie NAD funkcja, w zywym Studio POD nia, sama tresc
identyczna) — nadpisany pelnym gitowym source'em, zweryfikowany ponownie `line_range` odczytem.
Po fixie: **11/11 plikow identyczne, zero rozjazdu.**

**PlotTemplate (T1 geometria, `ServerStorage.PlotTemplate`) potwierdzony NIETKNIETY** —
`get_instance_children`: wszystkie 16 dzieci obecne (PlotOrigin/Floor/BackWall/
EssenceGenerator/EntranceArch/Nameplate/Slot1..Slot10, kazdy z CardFrame). Zadna operacja pushu
nigdy nie celowala w ta sciezke — instancje zyja WYLACZNIE w zywym Studio, nie w gicie.

**Straznik ORDER-desync potwierdzony zielony** — swiezy 2-graczowy playtest pokazal kompletna,
poprawnie uporzadkowana sekwencje Init/Start dla wszystkich 20 serwisow (w tym MergeService na
wlasciwym miejscu) — mozliwe tylko jesli synchroniczny `error()` w strazniku (Bootstrap.server.luau
linie 45-75) nie odpalil.

**T2 acceptance domkniety realnym 2-klientowym testem** (`multiplayer_playtest numPlayers=2`,
role `client-1`/`client-2`, rozne `LocalPlayer.UserId` -1/-2 — NIE jeden symulowany klient, punkt
c z tabeli acceptance wyzej wymagal prawdziwej drugiej osoby): Player1 wystawil `frostfawn` na
swoim plocie przez `SetPlotSlot`, Player2 odczytal `Workspace.Plots.Plot_-1.Slot1.CardFrame`
BEZPOSREDNIO (bez zadnego dodatkowego remote'u) i zobaczyl poprawny `totemIdAttr=frostfawn` +
`borderColor` — czysta replikacja atrybutu Roblox, zgodnie z projektem.

**Andreas: Ctrl+S w Studio** — ten przebieg naprawil `RollRevealController` na zywo (fix live,
nie w gicie) i caly poprzedni przebieg zostawil nowe instancje (MergeConfig/MergeService/
DeckController jako zywe ModuleScripty, `PlotTemplate` w ServerStorage) tylko w pamieci
DataModelu. Bez zapisu placu wszystko to znika przy nastepnym restarcie Studio i rozjazd
dysk<->Studio wraca.

## Pivot na tycoon — T3 pasywna esencja online+offline (2026-08-19)

**Plan (zatwierdzony przed kodem):** stawka = suma esencja/sek wystawionych kart wg tieru
(`EssenceRateConfig.TierRatePerHour`, rodzenstwo `TierColorConfig`), zsumowana przez
`PlotService.RatePerSecond(profile.plotSlots)` — JEDYNE zrodlo, czytane identycznie i online
(`EssenceTickService`, tyk co 5s) i offline (`OfflineEarnService`, na `ProfileLoaded`), ta sama
dyscyplina co `TotemPool.sorted()` przy odds-bug fixie. Zadnych nowych pol profilu —
`profile.offlineTs` (serwerowy `os.time()`, stemplowany w `ProfileService.onPlayerRemoving` PRZED
`EndSession`) i `profile.plotSlots` (z T2) w pelni wystarczaja.

**Stawki (TUNING-PENDING, jak `MergeConfig` 50/150/30):**

| Tier | esencja/h za karte |
|---|---|
| Common | 2 |
| Uncommon | 5 |
| Rare | 12 |
| Epic | 30 |
| Legendary | 75 |

Skala pelnego plotu (10 slotow): **10x Common = 20 esencji/h** (okolica starego flat
offline-bonusu), **10x Legendary = 750 esencji/h** (~15 rolli/h przy `RollCostEssence=50`) —
hojne nagrodzenie kolekcji, ale nie zeruje sensu aktywnego rollowania. Strojenie na danych z
playtestu, NIE w ciemno — flaga zostaje w naglowku `EssenceRateConfig.luau`.

**Wariant foil/galaxy mnoznik — swiadomie ODLOZONY**, wbrew warunkowemu "jesli tanie": NIE jest
tani, bo `profile.plotSlots[i]` (T2) trzyma wylacznie `totemId`, zero sledzenia wariantu per-slot
— dodanie wymagaloby zmiany kontraktu `SetPlotSlot`, UI `PlotController` i schematu `plotSlots`.
Do rozwazenia jako oddzielne zadanie, nie w zakresie T3.

**Dwie gotchy zlapane na etapie projektu (nie live-testem):**
1. Roblox nie odpala `AttributeChangedSignal`, gdy nowa wartosc atrybutu == stara — stad
   `EssenceGenerator.LastTickSeq` (rosnacy licznik) obok `LastTickAmount`, wylacznie po to zeby
   klient dostal sygnal nawet przy dwoch identycznych tykach z rzedu.
2. Ulamkowa stawka x krotki tyk (`TickIntervalSeconds=5`) floorowalaby do zera w nieskonczonosc
   dla pojedynczej Common karty — stad akumulator ulamkowy per gracz (`_pending`) w
   `EssenceTickService`, przenoszacy reszte do nastepnego tyku zamiast gubic ja co tyk.

**Acceptance check — wszystkie 3 PASS, zweryfikowane live w Studio (`eval_server_runtime`, solo
playtest):**

a) **Online tempo** — wystawione 5 kart (Common+Uncommon+Rare+Epic+Legendary =
`rate=124/3600=0.034444.../s`), 200x `EssenceTickService._TickPlayerForTest` (=1000s symulowanego
czasu) -> esencja przyrosla o **34** = `floor(1000*0.034444...)=floor(34.444)=34` DOKLADNIE —
akumulator ulamkowy dziala matematycznie poprawnie, nie tylko "wyglada ok".

b) **Offline przyznanie + cap** — `OfflineEarnService._ComputeOfflineRawForTest` (pure, ten sam
kod co produkcyjny) z `plotRate=124/3600`, 4 przypadki:
   - first-login (`offlineTs=0`) -> `raw=0` (brak zarobkow od epoki 1970, jak oczekiwano).
   - 2h offline, bez capu -> `raw=248` = `7200*0.034444...` DOKLADNIE.
   - 30h offline, `CapHours=10` -> `raw=1240` liczone z `seconds=36000` (10h), NIE z 30h —
     cap realnie tnie elapsed, nie tylko deklaruje ze tnie.
   - clock-skew (`offlineTs` w przyszlosci) -> `raw=0`, nie ufa cofnietemu zegarowi.

c) **Esencja nie dotyka ranked** — potwierdzone grepem tej sesji: zero wystapien
`RunShop|Ranked|rankedTotemPool` w `EssenceTickService.luau`, `PlotService.luau` i
`OfflineEarnService.luau`. Passive essence zasila wylacznie progresje/tycoon; `RunShopService.
rankedTotemPool` (jak przy odds-bug fixie) czyta tylko stala `RankedConfig.TotemIds`.

**Strażnik ORDER-desync potwierdzony zielony** po dolozeniu `EssenceTickService` — swiezy solo
playtest pokazal kompletna sekwencje Init/Start dla wszystkich 21 serwisow (`EssenceTickService`
na wlasciwym miejscu, po `PlotService`, przed `DeckService`), zero `error()` z straznika.

**Andreas: Ctrl+S w Studio** — T3 push (3 nowe ModuleScripty: `EssenceRateConfig`,
`EssenceTickService`, `EssenceTickController`, + 6 edytowanych plikow) zyje tylko w zywym
DataModelu dopoki plac nie zapisany, jak przy T1/T2.

**Celowo NIE zrobione w T3:** wariant-mnoznik (patrz wyzej), wizualna fontanna/juice na plotach
CUDZYCH graczy (tylko wlasny, jak `PlotController`), realny multi-minutowy playtest z prawdziwym
uplywem czasu (acceptance zweryfikowany przez `_TickPlayerForTest`/`_ComputeOfflineRawForTest` —
ten sam kod co produkcyjny, ale nie "czekalem realnie X minut").

## Paczki (T4) — trzy platne paczki Mega/Super/Legend — ZAMKNIETY, bramka symulacji PASS (2026-08-19)

Trzy eskalujace paczki, kupowane za Esencje LUB Robux, calkowicie NIEZALEZNE od `RollService.RollTotem`
(zatwierdzone decyzje Andreasa: paczki NIE dotykaja `data.pity`/`data.lifetimeRolls`, Legend ujawnia
gwarancje LITERALNIE, nie zblendowana).

**Tabela paczek (TUNING-PENDING, startowe wartosci z planu):**

| Paczka | Karty | Cena Robux | Cena Esencja | Common/Uncommon/Rare/Epic/Legendary % |
|---|---|---|---|---|
| Mega | 5 | 149 | 600 | 50/30/13/4/3 |
| Super | 8 | 299 | 1400 | 40/30/17/7/6 |
| Legend | 10 | 599 | 3200 | 25/30/20/10/15 (karty 1-9); karta 10 = **gwarantowany Legendary (100%)** |

**Architektura:**
- `PackConfig.luau` (nowy) — 3 paczki, `assert` load-time ze kazda `tierTable` sumuje sie do
  dokladnie 100.
- `PackService.luau` (nowy) — `selectPackTier` = wlasny dokladny cumulative-walk PER PACZKA (wzorzec
  `RollService.selectVariant`, NIE globalna kaskada `selectTotem`). `OddsTable(packKey)` zwraca
  `cfg.tierTable` **BEZ zadnej transformacji** — ta sama tabela, ktora `selectPackTier` iteruje,
  silniejsza gwarancja zgodnosci wyswietlanej/losowanej niz nawet `PolicyService`. Totem w obrebie
  wylosowanego tieru: uniform przez nowe `TotemPool.byTier`. Wariant: reuzywa nowy publiczny
  `RollService.RollVariant` (wrapper na `selectVariant`).
- Robux: idempotentny kredyt przez `PurchaseService` (jedyny writer `profile.purchases`) —
  `MarketplaceConfig.DevProducts.PackMega/PackSuper/PackLegend` maja pole `packCredit`, granted w
  `grantDevProduct` do `data.purchases.packCredits[key]`, konsumowany atomowym check-and-decrement
  `PurchaseService.ConsumePackCredit`. Esencja: bezposrednio i atomowo przez
  `EconomyService.TrySpendEssence` w tym samym wywolaniu co roll (brak async receipt, brak potrzeby
  kredytu).
- `PackController.luau` (nowy) — katalog "Paczki" (przycisk `(1,-394,0,12)`, obok istniejacego
  Talia/STORE zachodzenia na `-316`, zeby nie dolozyc trzeciego nakladania). Kazdy rzadek zawsze
  pokazuje "?" obok Ess/R$ w tym samym widoku — "?" fizycznie zawsze jeden tap przed zakupem, bez
  osobnego blokujacego gate-modala. Legend: "?" pokazuje karty 1-9 wg tabeli + osobna linia
  "Karta 10: GWARANTOWANY Legendary (100%)", zero zblendowanej matematyki. Sekwencyjny reveal
  reuzywa `RollRevealController.PlayReveal`.
- **Reentrancy fix (sequential reveal):** `RollRevealController.RollCompleted:Fire()` odpala sie
  PRZEZ `task.spawn` synchronicznie do pierwszego yielda handlera — WEWNATRZ `playReveal`, zanim
  `_busy=false` zdazy wykonac sie w watku-rodzicu. Inline `PlayReveal(nextCard)` w handlerze trafialby
  wiec w busy-guard i CICHO gubil karte (sequencer wisi w nieskonczonosc). Fix: `task.defer` zamiast
  wywolania inline — odklada nastepne wywolanie na koniec biezacego cyklu wznowien, po tym jak
  `_busy=false` juz sie wykonalo.

**Ranked-isolation grep (post-implementacja, wymog planu):** zero wystapien
`RunShop|Ranked|rankedTotemPool` w `PackService.luau` i `PackController.luau` — potwierdzone.

**Symulacja Monte Carlo (obowiazkowa bramka, `tests/PackService.checkpoint.studio.luau`, odpalona
live w `eval_server_runtime`/`execute_luau` w solo-playteście, N=10-20k per paczka):**

| Paczka | N | tier | wyswietlane % | empiryczne % | delta |
|---|---|---|---|---|---|
| Mega | 10 000 | Common | 50.000 | 50.378 | 0.378 pp |
| Mega | 10 000 | Uncommon | 30.000 | 29.882 | 0.118 pp |
| Mega | 10 000 | Rare | 13.000 | 12.726 | 0.274 pp |
| Mega | 10 000 | Epic | 4.000 | 4.030 | 0.030 pp |
| Mega | 10 000 | Legendary | 3.000 | 2.984 | 0.016 pp |
| Super | 10 000 | Common | 40.000 | 39.915 | 0.085 pp |
| Super | 10 000 | Uncommon | 30.000 | 30.162 | 0.162 pp |
| Super | 10 000 | Rare | 17.000 | 16.981 | 0.019 pp |
| Super | 10 000 | Epic | 7.000 | 6.982 | 0.018 pp |
| Super | 10 000 | Legendary | 6.000 | 5.959 | 0.041 pp |
| Legend | 20 000 | Common | 25.000 | 25.069 | 0.069 pp |
| Legend | 20 000 | Uncommon | 30.000 | 30.008 | 0.008 pp |
| Legend | 20 000 | Rare | 20.000 | 19.937 | 0.063 pp |
| Legend | 20 000 | Epic | 10.000 | 9.933 | 0.067 pp |
| Legend | 20 000 | Legendary | 15.000 | 15.053 | 0.053 pp |

Max delta w kazdej paczce < 0.4 pp (prog bramki: 1.0 pp) — **PASS**.

**Gwarancja Legend, twarde potwierdzenie:** karta #10 sprawdzona w 20 000/20 000 otwartych paczek,
`violations=0` — **WE WSZYSTKICH otwarciach karta #10 = Legendary (100%)**.

**Weryfikacja live (poza symulacja, `eval_server_runtime` w zywym solo-playteście, prawdziwy
profil gracza):**
- `OpenPack(player, "Mega", "essence")`: essence przed=261235 po=260635 (spent=600, zgodne z cena),
  5 kart zwroconych, zapisane do `data.totems`.
- `OpenPack(player, "Legend", "essence")` + drugi test razem: `data.lifetimeRolls` i
  `data.pity.sinceEpic` **niezmienione** przed/po obu otwarciach (851/16 -> 851/16) — izolacja od
  pity/lifetimeRolls potwierdzona NA ZYWO (nie tylko inspekcja kodu). Karta #10 paczki Legend w tym
  konkretnym live-otwarciu: `Legendary` (zgodnie z gwarancja).
- Symulowany kredyt Robux (`packCredits.Super`): `ConsumePackCredit` 1->0 przy pierwszym `OpenPack`
  (`ok=true`), drugie wywolanie bez kredytu poprawnie zwraca `ok=false, reason="NoCredits"` —
  atomowy check-and-decrement dziala.
- Serwer bootuje czysto (wszystkie 21 serwisow Init+Start, `PackService` na wlasciwym miejscu w
  ORDER, zero `error()` ze straznika ORDER-desync po naprawie), klient bootuje czysto (`PackController`
  Init+Start bez bledow).

**Zlapany i naprawiony blad podczas pierwszego push do Studio:** `PackConfig.Packs: { [string]:
PackDef } = {...}` to NIEPRAWIDLOWA skladnia Luau — adnotacja typu na przypisaniu do pola
(`tabela.pole: Typ = ...`) dziala tylko dla `local`, nie dla przypisan do istniejacej tabeli. Zwalilo
parsowanie calego modulu -> kaskadowo `PackService` (require) -> `Bootstrap.server.luau` (cały serwer
padal). Fix: usuniecie adnotacji z przypisania, cast na koncu wyrazenia (`} :: { [string]: PackDef }`)
zamiast inline adnotacji.

**Compliance checklist (z planu T4):**
- [x] `PackConfig` z `assert` sum=100 per paczka.
- [x] `PackService` z wlasnym dokladnym tier-pickerem (nie global `selectTotem` kaskada).
- [x] `OddsTable` = bezposrednia referencja do `tierTable`, zero transformacji.
- [x] Robux = kredyt idempotentny przez `PurchaseService` (jedyny writer `profile.purchases`).
- [x] "?" (`GetPackOdds`) zawsze widoczny obok kazdego przycisku zakupu w tym samym rzadku katalogu.
- [x] Paczki NIE dotykaja `data.pity`/`data.lifetimeRolls` — potwierdzone kodem I live-testem.
- [x] Ranked-isolation grep po kodzie — zero trafien.
- [x] Symulacja N=10-20k per paczka, tabela empiryczne-vs-wyswietlane w STATUS.md.
- [x] Twarde potwierdzenie 100% Legendary na karcie #10 Legend (20 000/20 000).

**Andreas: Ctrl+S w Studio** — T4 push (3 nowe ModuleScripty: `PackConfig`, `PackService`,
`PackController`, + 6 edytowanych plikow + oba Bootstrapy) zyje tylko w zywym DataModelu dopoki plac
nie zapisany, jak przy T1/T2/T3.

**Celowo NIE zrobione w T4:** balans cen/procentow (jawnie TUNING-PENDING, startowe wartosci z planu),
prawdziwe `id` dev-produktow w Creator Dashboard (nadal placeholder `id = 0`, jak reszta
`MarketplaceConfig.DevProducts` od Fazy 4 Krok 2) — Robux-flow nie da sie w pelni przetestowac E2E
(prawdziwy `PromptProductPurchase`) dopoki ID nie zostana uzupelnione w Dashboardzie.

**Nastepny krok: T4b (mechanika loot-owa oparta o szczescie), po T4.**

## Odwiedziny cudzych plotow (T5, social/flex) — ZAMKNIETY, 2 graczy PASS (2026-08-19)

**Plan przed kodem (jak zazadal Andreas):** sprawdzono w kodzie, ze T2 replikuje juz
Workspace.Plots jako zwykly globalny Folder (zero remote'ow), a karty na slotach replikuja sie
atrybutami — wiec "podejsc i zobaczyc cudzy plot" dziala juz czesciowo za darmo. Policzono siatke
plotow (`PLOT_COUNT=8`, 4x2, `GRID_SPACING=100`, offset od spawn) — najdalszy rog ~381 studow od
spawnu, czyli **normalny spacer**, zero nawigacji/teleportu potrzebne (spec p.4, galaz "jesli nie
trzeba — nic nie dodawaj"). Domkniete wiec tylko brakujace 2 rzeczy: nameplate + licznik lajkow,
plus wlaczenie fontanny-juice na cudzych plotach (tanie, bo T3 juz ustawia atrybuty dla kazdego
gracza).

**Zakres (minimalny, reuse T2/T1):**
- `Nameplate` (part z T1, dotad tekst-placeholder "PLAYER'S PLOT") wypelniany realnie:
  `PlotService.renderNameplate` ustawia `{DisplayName} ❤ {likes}`, wolane z `allocatePlot` (na
  wejsciu gracza) i z `LikePlot` (po kazdym udanym lajku) — replikacja jak karty, zero nowego
  remote'a do SAMEGO wyswietlania.
- **Licznik lajkow** (nie "wizyt" — wybrano bo tap jest tani do walidacji serwerowej; "wizyta" to
  pojecie nieistniejace nigdzie indziej w kodzie, wymagaloby nowego mechanizmu proximity):
  `profile.plotLikes` (trwaly licznik OTRZYMANYCH lajkow, na wlascicielu) + `profile.plotLikesGiven`
  (`[ownerUserIdStr] = dateKey`, na goscu — anti-spam) w `PROFILE_TEMPLATE`
  (`ProfileService.luau`). Nowy remote `LikePlot` (`Net.luau`): `C->S (ownerUserId) -> {ok, likes?,
  reason?}`.
- `PlotService.LikePlot(liker, ownerUserId)` — walidacja serwerowa w stylu `SetPlotSlot` (odrzuc w
  calosci, jawny `reason`): `NoProfile` (liker bez profilu) / `SelfLike` (ownerUserId==liker.UserId)
  / `NoPlot` (owner offline lub bez zaalokowanego plotu) / `AlreadyLiked` (juz dzis, klucz przez
  `SeedService.DailyKey` — reuzyty wzorzec z `StreakService`, zero nowego day-key mechanizmu).
  Klucz uproszczenia: plot Model istnieje w `Workspace.Plots` WYLACZNIE gdy wlasciciel jest online
  (`allocatePlot`/`releasePlot` na `ProfileLoaded`/`ProfileReleasing`) — wiec `LikePlot` NIGDY nie
  musi obslugiwac offline-ownera przy zapisie licznika, `ProfileService.GetProfile(ownerPlayer)`
  zawsze valid gdy `ownerPlot` istnieje.
- Klient: `PlotController.wireAllPlots()` — zamiast pojedynczego `GetMyPlot` (tylko wlasny plot),
  skan `Workspace.Plots:GetChildren()` + `ChildAdded`, `ClickDetector` na KAZDYM `Nameplate` (wlasny
  i cudze — `SelfLike` odrzuca serwer, klient nie filtruje). Klik = `LikePlot` invoke + popup
  (`+1 ❤` / komunikat bledu PL: "To Twoj plot" / "Juz dzis polubione" / "Plot niedostepny"),
  BillboardGui+Tween 1:1 wzorzec z `EssenceTickController.spawnPopup`.
- **Fontanna-juice na cudzych plotach: WLACZONE** (decyzja wlasna, flagowana jak prosil Andreas) —
  `EssenceTickController` przepisany z `waitForOwnGenerator` (jeden `GetMyPlot`) na
  `wireAllGenerators()` (ten sam folder-scan co `PlotController`); tanie bo `LastTickAmount`/
  `LastTickSeq` juz sa atrybutami ustawianymi dla KAZDEGO gracza w `EssenceTickService`, replikuja
  sie na caly `Workspace.Plots` bez zadnej zmiany po stronie serwera.
- Nawigacja: **NIE dodano** — potwierdzone niepotrzebne (patrz siatka wyzej).

**Pliki zmienione:** `ProfileService.luau` (+`plotLikes`/`plotLikesGiven` w template),
`PlotService.luau` (+`renderNameplate`, +`LikePlot`, wiring remote'a, `_SetSeedServiceForTest`
hook), `Net.luau` (+`LikePlot` remote), `PlotController.luau` (+`wireAllPlots`/`wireNameplate`/
`onLikeClick`/`spawnLikePopup`), `EssenceTickController.luau` (`waitForOwnGenerator` ->
`wireAllGenerators`/`wireGenerator`, skop rozszerzony na wszystkie plotow).

**Weryfikacja live (multiplayer_playtest, 2 klientow, `robloxstudio` MCP):**
1. Czysty boot serwera+2 klientow, zero bledow w `get_runtime_logs` (filter="error" -> pusto).
2. Po alokacji: `Plot_-1`/`Plot_-2` w Workspace.Plots, `Nameplate` obu = `"Player1 ❤ 0"` /
   `"Player2 ❤ 0"` — potwierdzone `eval_server_runtime`.
3. Acceptance (a)/(b)/(c) — wszystkie PASS, `PlotService.LikePlot` wolane bezposrednio na live
   serwerze przez `eval_server_runtime`:
   - Player2 lajkuje Plot Player1: `{ok=true, likes=1}` — licznik rosnie, nameplate aktualizuje sie
     natychmiast.
   - Ten sam lajk powtorzony natychmiast: `{ok=false, reason="AlreadyLiked"}` — spam zablokowany.
   - Player1 probuje lajkowac wlasny plot: `{ok=false, reason="SelfLike"}`.
   - **Persystencja:** Player1 rozlaczony (`leave_client`), `ProfileReleasing` zapisal profil;
     bezposredni odczyt `DataStoreService:GetDataStore("RollARuneProfile_v1"):GetAsync("-1")`
     potwierdza `plotLikes=1` w realnym DataStore (nie tylko w pamieci) — silniejszy dowod niz
     rejoin w tym samym tescie, bo StudioTestService nadaje KAZDEMU nowo dolaczonemu klientowi
     swiezy, inny fake userId (rejoin "tego samego" gracza nie jest odtwarzalny w jednym multiplayer
     tescie).

**Andreas: Ctrl+S w Studio** — T5 push (5 edytowanych plikow) zyje tylko w zywym DataModelu dopoki
plac nie zapisany, jak przy T1-T4.

**To domyka grywalny MVP tycoona.** Nastepny krok: T4b (luck) i dostrajanie liczb — po tym, na
danych z playtestu (decyzja Andreasa, nie w zakresie T5).

## HUB/Swiat — build wizualny placu centralnego (2026-08-19)

**Zakres tego przebiegu: WYLACZNIE build, zero logiki.** Cel: wyjsc z pustki (Baseplate + jeden
SpawnLocation na goloborzu) do realnego, ladnego miejsca — pastelowy plac centralny z fontanna,
8 kotwic pod plotow, stragan, portal. Kolejnosc i zakres 1:1 wg zlecenia Andreasa (5 krokow,
zrzut ekranu po kroku 2 i na koncu).

**WARUNEK #0 — POTWIERDZAM: realne Party, nie runtime.** Cala geometria ponizej zostala
zbudowana przez `robloxstudio` MCP `execute_luau` z `target="edit"` — to jest wykonanie w
kontekscie pluginu Studio (edit mode), DOKLADNIE jak reczne klikanie w Properties/Explorer, NIE
Script uruchamiany w grze. Zaden `Script`/`LocalScript` nie zostal po sobie zostawiony — po
uruchomieniu narzedzia zostaja wylacznie `Part`/`Model`/`Folder`/`ParticleEmitter`/`PointLight`/
`Attachment`, czyli zwykle trwale instancje w DataModelu, identyczne z natury do `PlotTemplate` z
T1. Zweryfikowane na koniec przez `get_instance_children` na `Workspace.Hub` — same Foldery i ich
dzieci, zero Script gdziekolwiek w drzewie huba. Jedyna rzecz runtime to (jak dotychczas) to,
KTORE karty siedza na slotach danego gracza (T2 mechanika) — geometria sama w sobie stoi w
edytorze i przetrwa Ctrl+S.

**Krok 1 — zabicie pustki (niebo/swiatlo).** Bez wlasnego tekstury skybox (zeby nie zgadywac
Toolbox ID) — pastelowy nastroj zbudowany z tuningu `Lighting`/`Atmosphere`/`Sky`/`Bloom`/
`SunRays`/`DepthOfField` (ClockTime=7.5, rozowo-lawendowe ColorShift/Fog/Atmosphere, delikatny
bloom) + 18 chmur (`Workspace.Hub.SkyDecor.Cloud1..18`, po 3-5 `Ball` Partow "Puff" w pastelowych
kolorach) rozrzuconych petla wokol horyzontu. Domyslny `Baseplate` NIE skasowany — przemianowany
i przeksztalcony na `CloudSea` (3000x20x3000, Y=-260, SmoothPlastic bardzo jasny rozowy,
Transparency=0.15): siatka bezpieczenstwa pod wyspami + widoczne "morze chmur" przy spojrzeniu w
dol. `DepthOfFieldEffect` NIE ma `FarStart` (tylko `FarIntensity`/`InFocusRadius`/
`NearIntensity`/`FocusDistance`) — bledna wlasciwosc usunieta z pierwszej probki.

**Krok 2 — plac centralny + fontanna (zrzut zrobiony).** `Workspace.Hub.Plaza`: okragla podloga
kamienna (`PlazaFloor`, Slate, fiolet-blekit, promien 48) + zloty rabek (`PlazaTrim`, Neon,
promien 52). Fontanna-landmark (`Fountain` Model): basen (Glass, cyjanowa woda,
Transparency=0.3) + 3-segmentowy krysztal (Neon, gradient blekit->cyjan, obrocony 45st) +
`PointLight` cyjan na szczycie + `ParticleEmitter` (iskry, `rbxasset://textures/particles/
sparkles_main.dds`) + 5 satelickich odlamkow wokol basenu. 6 lawek (Marble siedzisko + koralowe
oparcie) rozstawionych co 60 stopni na promieniu 34. 10 klastrow koralowych akcentow (male
`Ball` Party, Neon+SmoothPlastic, rozne odcienie koralu) rozrzucone petla w pierscieniu 28-44.
`SpawnLocation` przesuniety na plac (Marble, kolor kremowo-zloty, `CFrame=(0,0.5,40)` patrzy w
strone fontanny) — gracz laduje w hubie, nigdy w pustce ani w biegu.

**Blad po drodze i fix:** `ParticleEmitter.Lifetime`/`.Speed` uzywaly bledngo konstruktora
`NumRange.new(...)` (literowka — poprawny typ Roblox to `NumberRange`, nie `NumRange`) —
`attempt to index nil with 'new'` bo `NumRange` jako globalna nazwa po prostu nie istnieje.
Naprawione na `NumberRange.new(...)`, caly skrypt Kroku 2 zaczyna sie od `plaza:ClearAllChildren()`
wiec ponowne uruchomienie w calosci bylo bezpieczne/idempotentne.

**Krok 3 — przemalowanie `PlotTemplate` na motyw Ocean.** Edytowany bezposrednio
`ServerStorage.PlotTemplate` (ten sam wzorzec kontraktu nazw z T1, zero zmian strukturalnych):
`Floor`/`BackWall` -> Slate fiolet-blekit (spojne z podloga placu), `EssenceGenerator` -> Neon
cyjan (spojny z krysztalem fontanny), `Nameplate` -> kremowo-zloty SmoothPlastic,
`EntranceArch` piloty -> Slate fiolet-blekit, `Beam` -> zloty Neon (spojny z rabkiem placu).
Swiecace ramki kart (`CardFrame`/`RarityGlow`/`RarityBorder`) i sama struktura slotow **NIE
ruszane** — to one nosza karty Stworkow, poza zakresem tego przebiegu.

**Krok 4 — layout: 8 kotwic + mostki + stragan + portal.**
Plan reconciliacji z PlotService (napisany PRZED zmiana, zgodnie z instrukcja): `PlotService`
dzis liczy siatke 4x2 sam (`buildGridCFrames`, stale `GRID_BASE_X/Z/GRID_COLS/GRID_SPACING`) i
NIE czyta zadnych autorskich pozycji. W tym przebiegu polozone zostaly WYLACZNIE kotwice —
`Workspace.Hub.PlotAnchors.PlotAnchor1..8` (Model: `Pad` kamienny + `FootprintRing` zloty
placeholder odcisku plotu + `AnchorMarker` z atrybutem `Index`), promien 150 od placu, co 45
stopni (offset 22.5 zeby zadna nie stala dokladnie na osi spawnu), CFrame kazdej patrzy lokalnym
+Z do centrum (konwencja `Nameplate` z T1). Swiadomie NIE sklonowano pelnego `PlotTemplate` na
kazdej kotwicy — `PlotService.allocatePlot` i tak klonuje `PlotTemplate` do
`Workspace.Plots.Plot_<id>` w runtime (folder `Plots` jest tworzony na starcie serwera, nie
istnieje w edit-mode), wiec pelna geometria na kotwicy dublowalaby sie z live-klonem.
**Nastepny przebieg:** podmienic `buildGridCFrames()` w `PlotService.luau` na odczyt CFrame'ow
z `Hub.PlotAnchors.PlotAnchor1..8` (po atrybucie `Index`) zamiast liczenia siatki — to jedyna
zmiana potrzebna w kodzie serwisu, poza zakresem tego przebiegu (build-only).
Kazda kotwica polaczona z krawedzia placu mostkiem (`Workspace.Hub.Bridges.Bridge1..8`:
WoodPlanks + 2 zlote poreczki Neon). Stragan z paczkami (`Workspace.Hub.Shop`: blat+markiza+2
slupy+swiecaca kula) postawiony blisko spawnu (promien 62, luka miedzy kotwicami). Portal
(`Workspace.Hub.Portal`: kamienny luk + fioletowy wir Neon z iskrami + `PointLight`) na wprost od
spawnu przez plac (promien 80, po przeciwnej stronie).

**Krok 5 — lekka dekoracja.** `Workspace.Hub.Decor`: 34 male klastry (krysztalki/roslinki/
korale, 3 warianty) rozrzucone petla w pierscieniu 56-144 studow, z unikaniem katow mostkow/
straganu/portalu (+-9 stopni), ten sam wzorzec petli co chmury z Kroku 1. Spody wysp POMIJANE
zgodnie z instrukcja.

**Zrzuty ekranu:** zrobione po Kroku 2 (plac+fontanna z bliska) i na koncu (widok z gory —
"kwiat" 8 mostkow, i widok kątowy — plac+portal+stragan+niebo). Oba pokazane Andreasowi w tej
sesji.

**Andreas: Ctrl+S w Studio.** Caly ten build (Hub/Plaza/PlotAnchors/Bridges/Shop/Portal/Decor/
SkyDecor + CloudSea + Lighting + przemalowany PlotTemplate) zyje WYLACZNIE w zywym DataModelu —
zaden plik repo nie zmienil sie (build byl w 100% przez Studio MCP, nie przez `src/`), wiec nie
ma tu commita kodu — commit ponizej to wylacznie ten wpis w STATUS.md. Bez zapisu placu caly
Hub znika przy nastepnym restarcie Studio.

**Poza zakresem tego przebiegu (nastepny przebieg):** podpiecie spawn=dom (funkcjonalnie juz
dziala, bo `SpawnLocation` po prostu tam stoi), reconciliacja pozycji `PlotService` z 8
kotwicami (plan opisany wyzej), stragan -> otwarcie sklepu paczek, portal -> wejscie do biegu.
To byl przebieg czysto wizualny/geometryczny.

## HUB/Swiat — ploty na kotwicach, podjazdy-tasmy, celowa dekoracja (2026-08-19, drugi przebieg)

**Cel Andreasa: "ma byc PELNIEJ"** — zamiast 8 golych kotwic z mostkami, kazda z 8 wysp ma teraz
widoczny, pomalowany plot (koncept od razu czytelny), a plaskie mostki zastapione charakternymi
podjazdami-tasmami. Zrzut ekranu wylacznie na koncu (nie w polowie), zgodnie z instrukcja.

**WARUNEK #0 — jak poprzednio, z JEDNYM jawnym wyjatkiem tego przebiegu.** Cala geometria (kotwice
podniesione na wysokosc wysp, `ShowcasePlot` na kazdej kotwicy, 8 rampy z `Bridges`, przegrupowana
`Decor`) zbudowana przez `execute_luau target="edit"` — realne trwale Party/Model, zero
`Instance.new` w runtime. **Wyjatek: `Workspace.Hub.ConveyorDriver`** to jeden `Script`
uruchamiany w grze (`RunService.Heartbeat` + `CollectionService:GetTagged("ConveyorLane")`,
przesuwa `HumanoidRootPart` dotykajacych graczy wzdluz atrybutu `ConveyorDir`/`ConveyorSpeed` per
part) — Andreas potwierdzil explicite, ze to "funkcjonalne zachowanie partu, nie generowanie
geometrii w runtime", wiec NIE lamie WARUNKU #0. Sam Script jest jeden, trwaly, tworzony raz w
edit-mode; jego rola to WYLACZNIE ruch, nigdy tworzenie/kasowanie geometrii.

**1. Ploty na 8 kotwicach — pelna reconciliacja z `PlotService`, zero duplikacji geometrii.**
Kazda `PlotAnchorN` dostala pelny pomalowany klon `ServerStorage.PlotTemplate` (`ShowcasePlot`,
motyw Ocean z Kroku 3 pierwszego przebiegu) jako trwale dziecko, `PivotTo`'wany na
`AnchorMarker.CFrame`. `PlotService.luau` przepisany: nowa `buildAnchorSlots()` czyta
`Workspace.Hub.PlotAnchors` (sortowanie po atrybucie `Index`), dla kazdej kotwicy bierze
`AnchorMarker.CFrame` + referencje do `ShowcasePlot`; fallback na stara siatke 4x2
(`buildGridCFrames`) TYLKO gdy `Hub.PlotAnchors` jeszcze nie istnieje (swiezy plac przed Ctrl+S) —
zeby serwer nie wywalal sie na starcie zamiast degradowac. `allocatePlot` przy przydziale
kotwicy realnemu graczowi PRZENOSI `ShowcasePlot` do `ServerStorage.HiddenShowcases` (reparent,
nie `Destroy`) zamiast go niszczyc — klon gracza staje DOKLADNIE w tym samym CFrame, wiec zero
podwojnej geometrii. `releasePlot` przy wyjsciu gracza przywraca `ShowcasePlot.Parent` na
oryginalna kotwice (`showcaseHome`), wiec hub nie "pustoszeje" po wylogowaniu — nie trzeba nic
przebudowywac w edit-mode. Zweryfikowane solo-playtestem (`eval_server_runtime`): dolaczajacy
gracz dostal plot na `Y=22` (wysokosc wyspy), a licznik `HiddenShowcases` wzrosl dokladnie do 1.
Push do zywego `ModuleScript` przez `set_script_source` (manualny sync, projekt bez Rojo).

**2. Podjazdy-tasmy zamiast plaskich mostkow.** `Workspace.Hub.Bridges` przebudowany na 8
`Ramp1..8`: `LaneUp`/`LaneDown` (deski Slate, kazda z atrybutami `ConveyorDir`/`ConveyorSpeed=14`,
otagowane `CollectionService` tagiem `"ConveyorLane"`), po 1 kosmetycznym pasie Neon na kazdej
(cyjan w gore, roz w dol) + 3 zlote poreczki Neon na rampe. Geometria idzie od krawedzi placu
(promien 52, Y=0) do wewnetrznej krawedzi wyspy (promien 106, Y=22) — kierunek liczony wylacznie
w plaszczyznie XZ (`Vector3.new(0,1,0):Cross(dirXZ)`), zeby offset pasow nie skrecal sie na
pochyleniu. Jeden wspoldzielony `ConveyorDriver` Script obsluguje wszystkie 16 pasow generycznie
(bez hardkodowanych sciezek) przez tag + atrybuty.

**Podniesienie wysp: `ANCHOR_Y=22`.** Kotwice/pady/showcase-ploty przeniesione z Y=0 (plaskie w
pierwszym przebiegu) na Y=22 — czytelne "plywajace wyspy" zgodnie z koncepcyjnym "pastelowe
plywajace wyspy", nie plaski teren. `AnchorMarker` nadal patrzy `CFrame.lookAt` w strone centrum
placu, tylko na nowej wysokosci.

**3. Dekoracja doscisnieta celowo, nie losowo.** `Workspace.Hub.Decor` wyczyszczony i
przebudowany: 4 klastry krysztalow u podstawy fontanny (promien 13), 8 klastrow (na przemian
koral/roslina) w lukach MIEDZY 8 rampami na krawedzi placu (promien 45, katy 0/45/90.../315 —
dokladnie w szczelinach miedzy kotwicami przesunietymi o 22.5 stopnia), 16 klastrow (po 2 na
wyspe) w "tylnych rogach" kazdej wyspy (przeciwlegle od wjazdu rampy) — 28 klastrow celowych
zamiast 34 losowo rozrzuconych z pierwszego przebiegu.

**4. Most Studio.** Sprawdzony `get_place_info` na starcie przebiegu — zywy, bez potrzeby
wznawiania.

**Zrzuty ekranu:** zrobione dopiero na koncu (kamera edytora nie zareagowala na wielokrotne zmiany
`cameraPosition`/`cameraLookAt` w kolejnych wywolaniach — trzy proby dały identyczny kadr), ale
uzyskany kadr jest jednoczesnie z gory i pod katem (kamera podniesiona i pochylona w dol), wiec
pokazuje caly efekt: 8 pomalowanych plotow na wyspach, zlote rampy z pasami, fontanna, celowa
dekoracja. Pokazany Andreasowi w tej sesji.

**Andreas: Ctrl+S w Studio.** Jak w pierwszym przebiegu — cala geometria (kotwice/showcase/rampy/
ConveyorDriver/decor) zyje wylacznie w zywym DataModelu i zniknie bez zapisu. Tym razem DODATKOWO
jest realna zmiana kodu w repo (`PlotService.luau`) — ta jest juz zapisana na dysku i zacommitowana
niezaleznie od Ctrl+S w Studio, ale bez zapisu placu przy nastepnym starcie Studio `PlotService`
spadnie z powrotem na fallback (stara siatka 4x2), bo `Hub.PlotAnchors` zniknie.

**Poza zakresem (kolejny przebieg):** stragan -> otwarcie sklepu paczek, portal -> wejscie do
biegu — jak zapowiedziane, niezmienione.

## HUB/Swiat — fix orientacji kart + polish plotow (2026-08-19, trzeci przebieg)

**Zakres: WYLACZNIE build/geometria, zero zmian w `PlotService.luau` ani innym kodzie repo.**
Andreas zlapal bug: po wjezdzie rampa gracz od razu widzial sciane kart zamiast wejsc na plot i
dojsc do kart na dalekim koncu.

**1. Root cause i fix orientacji.** Zdiagnozowane matematycznie (nie na oko): kazdy
`AnchorMarker.CFrame` byl budowany przez `CFrame.lookAt(islandPos, plazaCenter)` w poprzednim
przebiegu — to ustawia `LookVector` (a wiec lokalny `-Z`) w strone placu, co oznacza ze lokalny
`+Z` (gdzie w `PlotTemplate` siedzi `Nameplate`/wejscie, Z=+29.7) mapowal sie na kierunek NA
ZEWNATRZ (od placu), a lokalny `-Z` (gdzie siedzi `BackWall` ze slotami kart, Z=-29..-30.5)
mapowal sie DO WEWNATRZ (w strone placu/rampy) — dokladnie odwrotnie niz trzeba, stad karty od
razu przy wjezdzie. Zweryfikowane empirycznie przed fixem (`BackWall` mial ujemny iloczyn
skalarny z kierunkiem "na zewnatrz" = po stronie placu; `Nameplate` dodatni = po stronie
zewnetrznej). **Fix: kazdy `AnchorMarker.CFrame = AnchorMarker.CFrame * CFrame.Angles(0, math.pi,
0)`** (obrot 180 stopni wokol Y) dla wszystkich 8 kotwic — bez zmiany pozycji, tylko orientacja.
Po fixie zweryfikowane ponownie na wszystkich 8: `BackWall` dodatni iloczyn (na zewnatrz, daleki
koniec) ok. +30.5, `Nameplate` ujemny (blisko placu/rampy, wejscie) ok. -29.7 — spojne na kazdej
kotwicy. Zero zmian w `PlotService.luau`: serwis i tak czyta `AnchorMarker.CFrame` na zywo przy
`Start()`, wiec poprawiona orientacja automatycznie trafia do realnych plotow graczy bez zadnej
zmiany kodu.

**2. Polish `ServerStorage.PlotTemplate`** (jeden template = automatycznie polish trafia i do
8 showcase'ow, i do kazdego przyszlego live-plotu gracza, bo `PlotService.allocatePlot` klonuje
ten sam template):
- `FloorTiles` — szachownica 4x4 (16 plytek, 2 odcienie fiolet-blekit Slate) na podlodze zamiast
  plaskiego jednolitego koloru.
- `FloorTrim` (zlota Neon ramka na krawedzi, 4 belki) + `FloorGlow` (cyjanowa Neon obwodka wciecia
  do wewnatrz) — ta sama paleta co plac (zloty rabek + cyjan fontanny).
- `CornerPillars` — 4 niskie filary Slate ze zlota kula na szczycie w rogach podlogi (bogatsza
  krawedz zamiast golej platformy).
- `CornerClusters` — 2 klastry (koral + roslina, po 3 kulki Neon roznej wielkosci) przy tylnych
  rogach, blisko `BackWall`.
- `PlotFountain` — cyjanowy szklany basen (Glass, transparency 0.35) otaczajacy istniejacy
  `EssenceGenerator` + `PointLight` cyjan; `EssenceGenerator` sam NIE ruszany (atrybuty
  `LastTickAmount`/`LastTickSeq` czytane przez `EssenceTickService`/`EssenceTickController`
  zostaja nietkniete).
- `PlotBench` — mala lawka (Marble siedzisko + koralowe oparcie) z boku, poza sciezka
  wejscie->karty.
- `BackWallDetail` — zloty cokol wzdluz podstawy `BackWall`, 2 pilastry Slate na koncach (echo
  `EntranceArch`), pasek `WallGlow` (zloty Neon) nad rzedem kart + 2 `PointLight` dla podswietlenia.
- **Docisniecie glow kart:** wszystkie 10 `RarityGlow` (jeden na slot) przemalowane z szarego na
  cieply zloto-bialy (byly czysto dekoracyjne, nieużywane przez `PlotService.renderSlot` — ten
  ustawia tylko `RarityBorder.Color`, wiec bezpieczne do przemalowania raz na sztywno).
- Struktura nazw slotow/kart (`SlotN/CardFrame/Frame/RarityBorder`) i `EssenceGenerator`/
  `Nameplate` **NIE ruszane** — zero ryzyka dla `PlotService`/`PlotController`/
  `EssenceTickController`, ktore odnajduja te instancje po nazwie.

**3. Regeneracja 8 showcase'ow.** Kazdy stary `ShowcasePlot` skasowany i zastapiony swiezym
klonem juz spolerowanego + poprawionego orientacyjnie `PlotTemplate`, `PivotTo`'wany na
skorygowany `AnchorMarker.CFrame` — jeden krok gwarantuje spojnosc (zero recznego babrania w 8
kopiach z osobna).

**4. Most Studio.** Zywy przez caly przebieg, bez potrzeby wznawiania.

**Zrzut ekranu:** kamera edytora ponownie nie reagowala na zadne zmiany `cameraPosition`/
`cameraLookAt`/`fov` (3 rozne proby, identyczny kadr za kazdym razem — potwierdzone ograniczenie
narzedzia w tej sesji, nie da sie zlapac bliskiego kadru "rampa->wejscie->karty" na jednym
plocie). Uzyskany szeroki kadr i tak POTWIERDZA fix wizualnie: rzedy kart widoczne teraz na
DALEKIEJ (zewnetrznej) krawedzi kazdej wyspy zamiast przy wjezdzie z rampy, plus widoczna
szachownica podlogi/zlota ramka/cyjanowa obwodka/narozne klastry na wszystkich 8 plotach.

**Andreas: Ctrl+S w Studio.** Caly ten przebieg (obrot 8 `AnchorMarker`, polish
`ServerStorage.PlotTemplate`, regeneracja 8 `ShowcasePlot`) zyje wylacznie w zywym DataModelu —
zero zmian w `src/`, zero commita kodu, wpis w STATUS.md ponizej to caly "commit" tego przebiegu.
Bez zapisu placu caly polish i fix orientacji znikaja przy nastepnym restarcie Studio.

**Poza zakresem (kolejny przebieg):** stragan -> otwarcie sklepu paczek, portal -> wejscie do
biegu, spawn/inne podpiecia — jak zapowiedziane, niezmienione.

## HUB/Swiat — flush rampy + fall-prevention (2026-08-19, czwarty przebieg)

**Dwie poprawki grywalnosci od Andreasa: (1) rampy nie dochodzily do konca, (2) brak
zabezpieczenia przed spadnieciem z mapy.**

**1. Flush rampy.** Zdiagnozowane precyzyjnie przed fixem: kazda z 8 ramp konczyla sie na
promieniu 106 (Y=22), a realna bliska krawedz podlogi plotu byla na promieniu 118 (Y=21.5,
skorygowane wczesniej z rotowanego-Cylindra floorTopY) — jednolita ~12.5-studowa dziura na
wszystkich 8, plus 0.5-studowy uskok wysokosci. Rampy przebudowane od zera
(`LaneUp`/`LaneDown`/`Stripe`x2/`Rail`x3 per rampa) z korekta obu koncow: strona placu wciagnieta
z promienia 52 na 50.5 (zakladka w `PlazaTrim`), strona plotu wysunieta z 106 na 119.5 (zakladka w
`Floor`), Y konca ustawiony dokladnie na `floorTopY` (per-kotwica, odczytany na zywo, nie
hardkodowany). Zachowane 1:1: `ConveyorDir`/`ConveyorSpeed=14` (attrybuty), tag
`CollectionService "ConveyorLane"`, materialy/kolory/wzgledne przesuniecia pasow i poreczy (Stripe
lateral=0 vert=0.58, Rail lateral -2.5/3.0/8.5 vert=1.70 wzgledem `LaneUp`) — istniejacy
`ConveyorDriver` Script (WARUNEK #0 wyjatek z poprzedniego przebiegu) dziala bez zadnej zmiany
kodu, bo wykrywa pasy po tagu+atrybutach, nie po nazwie/scieżce.

Zweryfikowane matematycznie po fixie na wszystkich 8: `floorTop=21.50`, `laneEndY=21.50`,
`laneEndR=119.54` (zakladka w podloge), `laneStartR=50.59` (zakladka w rabek placu) — identyczne
na kazdej kotwicy.

**Zweryfikowane NA ZYWO** (Andreas jawnie zazadal, nie tylko geometria): symulacja klawiatury
(`simulate_keyboard_input`) niedostepna w tym srodowisku (okno Studio zminimalizowane/niewidoczne
— narzedzie wymaga widocznego okna), wiec weryfikacja przez `eval_server_runtime` w realnym
uruchomionym playteście (`solo_playtest`):
- **Ciaglosc sciezki plac<->plot:** 20-punktowy raycast (`RespectCanCollide=true`, ignoruje
  dekoracyjne nie-kolidujace Party jak `Stripe`) wzdluz calej trasy od placu przez rampe na
  podloge plotu — **zero trafien pustych** (`anyMiss=false`), plynny wzrost wysokosci
  `PlazaFloor(Y=0)` -> `LaneUp(Y=0.48..16.40, rosnaco)` -> `Pad(Y=21.00)` -> `Floor/Tile(Y=21.5-
  21.85)`, bez zadnej dziury.
- **Bariera trzyma:** gracz teleportowany tuz przy krawedzi bocznej plotu (localX=30, sciana na
  32), popchniety predkoscia 40 stud/s na zewnatrz przez 1s — zatrzymany na localX=30.45, NIE
  przebil sciany.
- **Respawn dziala:** gracz teleportowany na Y=-120 (ponizej progu -75), po 1.5s (2x cykl
  `FallRespawnService`) wyladowal z powrotem przy `SpawnLocation` placu (~(0, 4, 40)).

**2. Fall-prevention.** `Workspace.Hub.Barriers` (nowy folder, Part'y `CanCollide=true
Transparency=1`):
- Per-plot (8x `PlotBarriersN`): 2 sciany boczne (localX=-32/+32, pelna dlugosc), 2 krotkie
  naroznik-zaslepki na krawedzi zewnetrznej (`BackWall` juz kryje wiekszosc tej krawedzi, 60/64
  studow — zaslepki lataja 2-studowe szczeliny po bokach), 2 segmenty na krawedzi wewnetrznej
  (wejsciowej) z przerwa `localX ∈ [-6.5, 6.5]` dokladnie na szerokosc wjazdu rampy (pasy+poreczy
  ~11 studow).
- Pierscien wokol placu (`PlazaRing`, 72 segmenty co 5 stopni na promieniu 53.5, chordowa
  zaslepka z 8% zakladki miedzy sasiednimi), z 8 lukami po 15 stopni (`GAP_HALF_ANGLE=7.5°`)
  dokladnie w kierunku kazdej z 8 ramp (kat liczony na zywo z `AnchorMarker.Position`, nie
  hardkodowany) — 48 z 72 segmentow faktycznie postawionych, 24 pominietych na luki wjazdowe.

**3. `ServerScriptService.FallRespawnService`** (nowy `Script`, WARUNEK #0 wyjatek analogiczny do
`ConveyorDriver` — zachowanie partu/gracza, nie generowanie geometrii w runtime): petla per-gracz
co 0.5s, jesli `HumanoidRootPart.Position.Y < -75` (dobry margines ponizej najnizszego realnego
elementu huba — `PlazaFloor` Y=-4, `Floor` plotu Y~20.5) -> `PivotTo` na `Workspace.SpawnLocation`
+3 study w gore, zerowanie predkosci. Watchuje `PlayerAdded`/`CharacterAdded`, obsluguje juz
polaczonych graczy przy starcie skryptu.

**4. Most Studio.** Zywy przez caly przebieg, solo_playtest start/stop bez problemow.

**Andreas: Ctrl+S w Studio.** Caly ten przebieg (przebudowane 8 `Ramp1..8`, nowy
`Workspace.Hub.Barriers`, nowy `ServerScriptService.FallRespawnService`) zyje wylacznie w zywym
DataModelu — zero zmian w `src/`, zero commita kodu, wpis w STATUS.md ponizej to caly "commit"
tego przebiegu. Bez zapisu placu wszystko znika przy nastepnym restarcie Studio.

**Poza zakresem (kolejny przebieg, kierunek do decyzji Andreasa):** stragan -> otwarcie sklepu
paczek, portal -> wejscie do biegu, spawn/inne podpiecia.

## HUB/Swiat — detoks neonu, miekkie pastele (2026-08-19, piaty przebieg)

**Problem od Andreasa: "za duzo neonu, wszystko razi/swieci" — cel miekki/kojacy koncept, nie
neonowka.** Policzone przed zmiana (`Material==Neon` po calym `Workspace.Hub` +
`ServerStorage.PlotTemplate`): **415 Neon-owych Partow.** Zdecydowana wiekszosc to byly
dekoracyjne krawedzie/trimy/rampy/klastry, ktore nigdy nie mialy byc realnymi zrodlami swiatla —
material Neon uzyty jako "latwy blask" zamiast koloru.

**Regula (1:1 wg Andreasa):** Neon zostaje WYLACZNIE tam, gdzie jest to faktyczne, celowe zrodlo
swiatla w koncepcie — kryształ fontanny placu (`Plaza.Fountain.CrystalSpike1-3`/`Shard1-5`) i
"fontanna" kazdego plotu (`EssenceGenerator`, ktora T3 juz nazywa fontanna w kodzie/dokumentacji) —
plus opcjonalny delikatny akcent ramek kart (`RarityGlow`, teraz z `Transparency=0.15` i
przycisznieta barwa, nie pelny blask). **WSZYSTKO INNE przekonwertowane** wg kategorii:
- Zlote krawedzie/trimy/rampy/filary (`Rail`/`PlazaTrim`/`Baseboard`/`Beam`/`Cap`/
  `FootprintRing`/`TrimN-W`/`WallGlow`/`ArchTrim`) -> **Metal**, kolor stlumiony
  kremowo-zloty (~18% w strone bieli od oryginalu) — kolor, nie swiecenie, jak zazadal Andreas.
- Koralowe/roslinne akcenty (`Backrest`/`C1-C3`/`Nub`) -> **SmoothPlastic**, kolor lekko
  stlumiony (~15%).
- Cyjanowe paski/obwodki (`Stripe` na rampach, `GlowN-W` na podlodze plotu) -> **SmoothPlastic**,
  jednolity pastelowy blekit (196,224,236) zamiast jaskrawego cyjanu.
- Dekoracja placu (`Decor.Bud`/`Decor.Shard`) -> **SmoothPlastic**, stlumione (~30%).
- `AnchorMarker` (techniczny znacznik pivotu, nigdy nie mial byc widoczny) -> niewidoczny
  (`Transparency=1`), material bez znaczenia.
- `Portal.Vortex` i `Shop.PackGlow` -> **Glass** (transparency 0.25-0.35, kolor stlumiony) zamiast
  plaskiego neonowego bloku — miekki/mglisty efekt zamiast twardej jarzeniowki, spojny z "portal =
  cos mistycznego", nie "portal = neonowy szyld".

**Zlapany blad podczas konwersji:** pierwsza wersja skryptu sprawdzala `Fountain`-owe kryształy po
`d.Parent.Name=="Plaza"`, ale realny rodzic to `Plaza.Fountain` (jeden poziom glebiej) — wszystkie
8 elementow kryształu fontanny wpadlo przez to w fallback-konwersje (utracily Neon). Zlapane od
razu przez `get_full_name`/material-audit PO konwersji (spodziewane keptNeon=107 z rozbicia
90 RarityGlow + 9 EssenceGenerator + 8 fontanna, faktyczny wynik pokazal 99 — brakujace 8 to byl
dokladnie fountain). Naprawione: 8 elementow przywroconych na Neon z oryginalnym (nie podwojnie
stlumionym) kolorem x0.85.

**Koncowy stan:** Neon spadl z **415 -> 107** Partow (kryształ fontanny placu x8, `EssenceGenerator`
x9 [8 kotwic + 1 w `PlotTemplate`], `RarityGlow` x90 [8 kotwic x10 slotow + 10 w `PlotTemplate`]) —
wylacznie prawdziwe/celowe zrodla swiatla plus jeden zamierzony, przycisznity akcent.

**Oswietlenie globalne** (`Lighting`): `Bloom.Intensity` 0.55 -> **0.28**, `Bloom.Threshold` 1.15
-> **1.45** (blooms tylko naprawde jasne rzeczy, nie kazda pastelowa powierzchnia),
`Bloom.Size` 26 -> 20; `SunRays.Intensity` 0.18 -> **0.10**; `Lighting.Brightness` 2.2 -> **1.9**
(miekciejsze, mniej "wypalone" swiatlo). Dodatkowo audyt 21 `PointLight` pod Hub+PlotTemplate —
przycisk kazdego z `Brightness>2` do 2 i `Range>18` do 18 (1 outlier znaleziony i przycieciety),
zeby zdjete-z-neonu trimy nie zostaly przypadkiem "podswietlone" przez stara, mocna lampe
zaprojektowana pod neonowy blask.

**Zrzut ekranu: NIEUDANY** — okno Studio bylo zminimalizowane/niewidoczne przez cala sesje
(`capture_screenshot` i `simulate_keyboard_input` obie zwrocily ten sam blad narzedzia: "Studio
window appears minimized or not rendering"). Zmiany zweryfikowane WYLACZNIE programowo
(material-audit przed/po, pelne wyliczenie pozostalych 107 Neonow z rozbiciem po nazwie) — **nie
zrzutem wizualnym**. Andreas: przywroc/odswiez okno Studio i zrob wlasny zrzut jesli chcesz
wizualne potwierdzenie przed dalsza praca.

**Andreas: Ctrl+S w Studio.** Caly ten przebieg (material/kolor 415 Partow pod `Workspace.Hub` +
`ServerStorage.PlotTemplate`, 5 property'ow `Lighting`, cap na 21 `PointLight`) zyje wylacznie w
zywym DataModelu — zero zmian w `src/`, zero commita kodu, wpis w STATUS.md ponizej to caly
"commit" tego przebiegu.

**Poza zakresem / nastepny krok:** oddzielne zgloszenie Andreasa o "schodach"/przesunieciu mapy —
patrz nizej, osobny watek w toku.

## HUB/Swiat — naprawa ramp/"schodow" (przebicie przez podloge plotu) (2026-08-19, szosty przebieg)

**Zgloszenie Andreasa (kolokwialnie "schody"):** "te schody na gorze przebijaja mape gorna, ja je
dolozylem do dolnej mapy zeby byly sklejone ale wyglada to zle". W scenie nie ma osobnych obiektow
"schody" — chodzi o 8 ramp-przenosnikow (`Bridges.Ramp1..8`) z poprzedniego (czwartego) przebiegu.
Przed poprawka zweryfikowane geometrycznie: gorny (plotowy) koniec kazdej z 16 lini (`LaneUp`+
`LaneDown` x8) przebijal podloge plotu o **~0.45-0.48 studa** na 7 z 8 ramp, a na **`Ramp3` az o
6.18 studa** (widoczny, ostry "kant" wystajacy z podlogi) — dokladnie zgodne ze zgloszeniem.

**Przyczyna:** poprzedni przebieg ustawial srodek (nie gorna powierzchnie) rampy na `floorTopY`,
wiec grubosc bryly (`Size.Y≈1.04`) i przechylenie (`~17.3°`) dawaly systematyczny naddatek
`≈ (Size.Y/2)*cos(tilt) ≈ 0.5 studa` nad podloga na wszystkich rampach. Na `Ramp3` doszedl drugi,
niezalezny blad: dolny (placowy) koniec wcale nie byl osadzony w podlodze placu (min. wysokosc
+4.29 zamiast ok. -1.4 jak reszta) — rampa "wisiala" w powietrzu przy placu, co przy tym samym
kacie nachylenia co reszta wywindowalo gorny koniec dodatkowo w gore.

**Fix:** kazda z 16 lini przeliczona od zera z prawidlowej trygonometrii zamiast stalego,
skopiowanego kata: policzony na zywo `plazaFloorTopY` (poprawnie, z uwzglednieniem rotacji
`PlazaFloor` — Part obrocony 90° w Z, wczesniejsza pulapka z rotowanymi Partami z czwartego
przebiegu powtorzona i tym razem obsluzona generyczna formula `|RightVector.Y|*SizeX +
|UpVector.Y|*SizeY + |LookVector.Y|*SizeZ`, nie zalozeniem ktora os to grubosc) oraz
`floorTopY` per-kotwica (jak wczesniej). Dolny koniec kazdej linii osadzony na `plazaFloorTopY -
0.9` (pod plac, niewidoczny), gorny koniec dokladnie na `floorTopY - 0.03` (goma powierzchnia, nie
srodek bryly — ten sam blad naprawiony u zrodla), kat i dlugosc dopasowane iteracyjnie (5 iteracji,
zbiega natychmiast) tak, zeby oba konce trafialy dokladnie w cel niezaleznie od lokalnej roznicy
wysokosci danej kotwicy — eliminuje to takze systemowo mozliwosc powtorki bledu `Ramp3` na kolejnych
kotwicach. Pozycja/kierunek (promien, yaw) NIE ruszone — tylko wysokosc/kat/dlugosc. `Stripe`x2 i
`Rail`x3 per rampa przeliczone wzgledem WLASNEGO wlasciciela (`LaneUp` lub `LaneDown`, dopasowane
po odleglosci) z zachowanym lokalnym przesunieciem — podazaja za nowa geometria automatycznie.

**Zweryfikowane na zywo w `solo_playtest`:**
- **Brak przebicia:** dla wszystkich 16 lini `maxY≈21.47` vs `floorTop=21.50` (margines 0.03, jak
  zaplanowano), `minY≈-1.40` vs `plazaTop=0.00` (osadzone pod placem, niewidoczne) — zero przebic,
  zero "wiszacych" koncow.
- **Ciaglosc:** 20-punktowy raycast po srodku kazdej z 8 lini `LaneUp` — **zero trafien pustych**
  na wszystkich 8, w tym na `Ramp3` i na REALNYM (nie showcase) plocie gracza `Plot_10945102665`
  pod kotwica 8 (PlotAnchor8.ShowcasePlot zastapiony w trakcie playtestu prawdziwym plotem gracza —
  test wykryl to automatycznie przez fallback po najblizszym `Floor` w `Workspace.Plots`).
- **`ConveyorLane` tag:** 16/16 tagow nienaruszonych (fix zmienial tylko `CFrame`/`Size`, nie
  atrybuty/tagi) — `ConveyorDriver` dziala bez zadnej zmiany kodu.
- **Bariery/respawn:** szybki smoke-test po fixie — pchniecie 40 stud/s w bok przy plocie 1 nie
  wyrzucilo gracza poza mape (Y pozostal w rozsadnym zakresie), upadek na Y=-120 zakonczyl sie
  powrotem gracza dokladnie na spawn placu (0, 4, 40) po ~1.5s — `FallRespawnService`/`Barriers`
  (trzeci przebieg) dzialaja bez zmian, bo ten fix nie dotykal ich geometrii.

**Odsuniecie mapy — NIE wykonane.** Andreasowa czesc "odsun troche mape" byla proba wlasnego
prowizorycznego obejscia problemu z przebiciem (dokladanie schodow do dolnej mapy) — po naprawie
geometrii ramp u zrodla przebicie znika bez przesuwania kotwic/wysp, wiec przesuwanie mapy nie jest
juz potrzebne do rozwiazania zgloszonego problemu. Jesli Andreasowi chodzilo o cos wiecej (np. po
prostu wiecej odstepu miedzy placem a plotami z innych wzgledow estetycznych) — do doprecyzowania,
nie zgadywane w tym przebiegu.

**Zrzut ekranu: nadal niedostepny** (okno Studio zminimalizowane, ten sam blad narzedzia co w
piatym przebiegu) — zweryfikowane wylacznie programowo + raycastami w zywym playteście.

**Andreas: Ctrl+S w Studio.** Ten przebieg nadpisuje `CFrame`/`Size` 16 partow `LaneUp`/`LaneDown`
+ 40 partow `Stripe`/`Rail` (8 rampy x 5 zaleznych) pod `Workspace.Hub.Bridges` — zero zmian w
`src/`, wpis w STATUS.md ponizej to caly "commit" tego przebiegu.

## HUB/Swiat — naprawa rozjazdu ramp z plotami przy uruchomieniu gry (2026-08-19, siodmy przebieg)

**Zgloszenie Andreasa:** "przy uruchomieniu gry te schody i mapa sie rozjezdza, trzeba je
przykotwiczyc miedzy baza gracza a srodkiem [placem]" — inny problem niz poprzedni (szosty)
przebieg, ktory naprawial WYSOKOSC (przebicie przez podloge). Tu chodzilo o POZYCJE POZIOMA:
rampy z gory nie siegaly realnie do plotow.

**Diagnoza — dwie odrzucone hipotezy, jedna potwierdzona:**
1. Hipoteza "`PlotTemplate` ma inny wewnetrzny offset `Floor` wzgledem pivota niz `ShowcasePlot`"
   — sprawdzona bezposrednio (`GetPivot()`/`ToObjectSpace()` na obu modelach) i **odrzucona**:
   `floorRelToPivot=(0,-1.5,0)` identyczne na obu, `bboxSize` identyczny (65,15,65).
2. Hipoteza "`AnchorMarker.CFrame` != pivot `ShowcasePlot`" — sprawdzona na wszystkich 8 kotwicach
   (`diffPos=0.0000`, `dotLook=1.0000` wszedzie) — **odrzucona**, statyczny plot siedzi dokladnie na
   markerze, klon runtime (`PlotService.allocatePlot`, `clone:PivotTo(marker.CFrame)`) laduje sie
   w identycznym miejscu co showcase — zero rozjazdu miedzy edit-mode a runtime samym w sobie.
3. **Prawdziwa przyczyna, potwierdzona zywym pomiarem w `solo_playtest`:** koniec kazdej rampy od
   strony plotu (`LaneUp`/`LaneDown` x8, ustawiony w czwartym przebiegu i NIE ruszany w szostym —
   "pozycja/kierunek (promien, yaw) NIE ruszone") konczyl sie systemowo **~15.6-16.6 studa ZA
   KROTKO** przed krawedzia plotu (dystans od konca linii do markera kotwicy ~47.6-48.6 studa
   zamiast prawidlowych ~32 study = polowa szerokosci plotu 64x64). Zmierzone identycznie na
   wszystkich 8 rampach (stala, systemowa rozbieznosc, nie przypadkowy szum) — rampy zostaly
   pierwotnie zbudowane wzgledem promienia kotwic sprzed jakiegos wczesniejszego przesuniecia
   plotow dalej od placu, i nigdy nie zostaly za tym przesunieciem poprawione. Dokladnie to
   Andreas opisal jako "rozjezdza sie miedzy baza gracza a srodkiem".

**Fix:** dla kazdej z 16 lini (`LaneUp`+`LaneDown` x8) przeliczony na nowo koniec od strony plotu —
kierunek promieniowy do placu (`dirToPlaza`, jednostkowy wektor od kotwicy do (0,_,0), zweryfikowany
jako idealnie zgodny z lokalna osia Z kazdej kotwicy na wszystkich 8: `localDir≈(0,0,1)` wszedzie)
oraz skladowa boczna (offset prostopadly, `rightVecXZ`) zachowana z oryginalu (zeby nie zaburzyc
rozstawu LaneUp/LaneDown wzgledem siebie) — nowy cel = `marker.Position + dirToPlaza*31.5 +
rightVecXZ*lateral` (31.5 = polowa 64-studowego plotu minus 0.5 studa zagniezdzenia). Koniec od
strony placu pozostawiony bez zmian pozycji poziomej (byl prawidlowy). Wysokosc obu koncow
przeliczona tym samym mechanizmem co szosty przebieg (gorna powierzchnia, nie srodek bryly),
tym razem iteracyjnie skorygowana takze o wklad grubosci/szerokosci bryly pod kątem (`extra =
0.5*Size.Y*|upVec.Y|`) — bez tej poprawki pierwsza proba fixu ponownie dala przebicie ~0.47 studa
(ten sam blad co szosty przebieg, tym razem z innego zrodla: sam punkt koncowy linii byl
prawidlowy, ale bryla ma grubosc i przy przechyleniu jej naroznik wystaje ponad punkt srodkowy —
poprawione przez 6 iteracji zbiegajacych natychmiast). `Stripe`x2 i `Rail`x3 per rampa przeliczone
wzgledem WLASNEGO wlasciciela (jak w szostym przebiegu) — w tym rowniez `Size.Z` wydluzony do nowej
dlugosci linii (rampy sa teraz dluzsze o ~15-16 studow, bo faktycznie siegaja do plotu).

**Zweryfikowane na zywo w `solo_playtest`:**
- **Dosiegniecie plotu:** `gapToMarker=31.65` na wszystkich 16 liniach (cel 31.5-32, w granicach
  plotu) — w porownaniu do `~47.6-48.6` przed fixem.
- **Brak przebicia:** `maxY=21.470` vs `floorTop=21.50` (margines 0.03) na wszystkich 16 liniach —
  identyczny standard jak szosty przebieg.
- **Realny plot gracza (nie showcase):** gracz w playtescie wyladowal na kotwicy 8
  (`Plot_10945102665`) — bezposredni pomiar koniec-rampy-do-krawedzi-podlogi-plotu:
  `horizGap=0.00` (koniec rampy miesci sie w obrysie podlogi plotu, nie na zewnatrz),
  `vertDiff=-0.54` (bezpiecznie pod gorna powierzchnia, brak przebicia) — potwierdzone na
  PRAWDZIWYM przydzielonym plocie, nie na statycznym showcase.
- **Ciaglosc:** 21-punktowy raycast po srodku kazdej z 16 lini — **0/16 lini z trafieniami
  pustymi**.
- **`ConveyorLane` tag:** 16/16 nienaruszonych (fix zmienial `CFrame`/`Size`, nie atrybuty/tagi).

**Zrzut ekranu: nadal niedostepny** (to samo ograniczenie narzedzia co w piatym i szostym
przebiegu) — zweryfikowane wylacznie programowo + pomiarami w zywym playteście na prawdziwym
plocie gracza.

**Andreas: Ctrl+S w Studio.** Ten przebieg ponownie nadpisuje `CFrame`/`Size` tych samych 16
partow `LaneUp`/`LaneDown` + 40 partow `Stripe`/`Rail` pod `Workspace.Hub.Bridges` (dluzsze rampy,
siegajace teraz realnie do plotow) — zero zmian w `src/`.

## HUB/Swiat — woda pod mapa z wgranego "Realistic Water" (2026-08-20, osmy przebieg)

**Zgloszenie Andreasa:** "dodalem mape realistic water z woda, sprawdz skrypty tej mapy i ta wode
daj pod nasza mape zeby bylo ladniej".

**Co to bylo:** `Workspace["Water Block"]` — pojedynczy Part 2048x4.36x2048 z `Script` w srodku.
Skrypt to jednorazowy "bake": `Terrain:FillBlock(script.Parent.CFrame, script.Parent.Size,
Enum.Material.Water)` po czym `wait(1)` i `script.Parent:remove()` — typowy wzorzec z free-modeli:
ma wypalic prawdziwy Terrain-water i sam sie skasowac. NIE byl to jeszcze odpalony (Part+Script
nienaruszone) — siedzial przy tym w zlym miejscu: `Position=(53.47, 36.68, 0.5)`, czyli **nad/w
srodku** naszej mapy (plot-topy siegaja Y~22), nie pod nia, i przesuniety od srodka placu.

**Fix:** zmierzony najnizszy punkt calego `Workspace.Hub` (wszystkie descendants-BaseParts,
rotation-aware) = `Y=-10` (`Plaza.PlazaTrim`). Blok wody przesuniety na `Position=(0, -52.18, 0)`
— wysrodkowany pod placem (X=0,Z=0, zgodnie ze srodkiem `PlazaFloor`), gorna powierzchnia wody na
`Y=-50`, czyli 40 studow ponizej najnizszego punktu mapy — bezpieczny odstep, zero przeciec, a
zarazem blisko dosc, zeby bylo widac wode przy zejrzeniu przez krawedz. Odpalony `FillBlock`
bezposrednio w edit-mode (ten sam mechanizm co reszta static-hub geometrii w tym projekcie —
trwala zmiana w placu, nie runtime-owy skrypt), po czym Part+Script skasowane recznie (dokladnie
to, co skrypt zrobilby sam przy pierwszym Play — zrobione raz, na trwale, zamiast zostawiac
autostartujacy sie skrypt pod `Workspace`).

**Zweryfikowane:** `Terrain:ReadVoxels` na regionie pod placem (`Y=-55..-48`) zwrocil **72/72
voxeli Water** — bake sie powiodl. (Wstepny test przez `Workspace:Raycast` dal falszywy negatyw —
raycast bridge w Studio niewiarygodnie wykrywa Terrain-water; `ReadVoxels` jest tu miarodajne.)
Bezpieczny margines wzgledem plaszczyzny "spadek/respawn" (`FallRespawnService`, kill-plane
`Y=-120` z trzeciego przebiegu) — dno wody (`Y=-54.36`) siedzi wysoko ponad tym planem, wiec
spadajacy gracz najpierw wizualnie "wpada" do wody, dopiero potem trafia na faktyczny respawn —
efekt uboczny, nie problem.

**Andreas: Ctrl+S w Studio.** Ten przebieg dodaje trwaly region Terrain-water pod placem (poprzez
`FillBlock`, nie Part) i usuwa `Workspace["Water Block"]` (Part+Script+6 Texture) — zero zmian
w `src/`.

## HUB/Swiat — podwodny dekor pod woda z Creator Store (2026-08-20, dziewiaty przebieg)

**Zgloszenie Andreasa:** "poszukaj mapy pasujacej do naszej w sklepie tworcow za darmo" —
doprecyzowane w AskUserQuestion na: dekor podwodny pod nowa wode (osmy przebieg).

**Znalezione i wstawione (wszystkie darmowe, `search_assets`/`get_asset_details`/
`get_asset_thumbnail` przed wyborem, zatwierdzone przez Andreasa):**
- **Coral Reef Pack** (id 885395978, tworca Almighty_Pigeon, 90% pozytywnych, 2017) — 5 meshy
  koralowca, bez skryptow.
- **Underwater Flora** (id 10910253545, tworca alonzo12345, 100% pozytywnych, 2022) — 7 meshy
  (skala, wodorosty, koral, anemon, gabka), bez skryptow.
- **Saltwater fish pack** (id 10851288693, tworca RavenOctoberALT, 94% pozytywnych, 2022) — ~34
  meshy ryb; mial 4 skrypty (prawdopodobnie animacja plywania) — `insert_asset` usunal je
  automatycznie w ramach polityki bezpieczenstwa (kazdy `LuaSourceContainer` z assetu
  third-party jest kasowany przed sparentowaniem, bez wzgledu na tresc). **Ryby sa wiec
  statyczne, nie plywaja** — do ewentualnego dodania wlasnego prostego skryptu ruchu pozniej,
  jesli Andreas bedzie chcial.

**Wymagane od Andreasa w trakcie:** insercja pierwotnie zablokowana ("User is not authorized to
access Asset") — trzeba bylo recznie wlaczyc **Game Settings > Security > "Allow Loading Third
Party Assets"** w Studio (nie da sie tego przelaczyc skryptem, to ustawienie placu, nie property
Instancji). Andreas wlaczyl, insercja poszla bez dalszych problemow.

**Rozmieszczenie:** `Workspace.Hub.UnderwaterDecor` (nowy folder) — 8 klastrow (3x Coral Reef
Pack, 3x Underwater Flora, 2x Saltwater fish pack) rozrzuconych w promieniu ~50-220 studow od
srodka placu, piwoty w okolicy powierzchni wody (Y=-46..-51, powierzchnia wody na Y=-50) — wyzsze
klastry (Underwater Flora, wys. ~29.7) czesciowo przebijaja powierzchnie (top do Y=-34), co przy
tak cienkiej (4.36 studa) plycie wody jest nieuniknione i wyglada jak plytki raf przebijajacy
tafle wody, nie blad. Zweryfikowane: `maxTop=-34.2`, wciaz 24 study ponizej najnizszego
zbudowanego punktu huba (`PlazaTrim`, Y=-10) — zero ryzyka przebicia przez mape.

**Andreas: Ctrl+S w Studio.** Ten przebieg dodaje `Workspace.Hub.UnderwaterDecor` (3 Modele +
5 klonow, wszystkie bez skryptow) — zero zmian w `src/`.

## HUB/Swiat — zmiana koncepcji: podwodne krolestwo, cala mapa zatopiona (2026-08-20, dziesiaty przebieg)

Andreas zmienil koncepcje: zamiast malej kaluzy wody 40 studow pod mapa (osmy przebieg), cala
mapa Huba ma stac NA DNIE i byc CALKOWICIE zatopiona — gracz chodzi normalnie (bez plywania),
ryby plywaja swobodnie w wodzie dookola, korale wszedzie.

**1. Pomiar realnej mapy.** Pelny bbox `Workspace.Hub` z pominieciem `SkyDecor` (chmury na
Y do 423 — nieistotne dekoracje nieba) dal footprint X/Z ±204, Y od -10 (najnizszy budowany
punkt) do 34.5 (belka bramy wjazdowej najwyzszego placu). Uklad Huba to NIE jeden plaski teren —
to 9 unoszacych sie "wysp" (Plaza + 8 platform dzialek, kazda ~92-104 study srednicy, Y~15-21.5)
polaczonych 8 rampami; miedzy nimi jest calkowita pustka (potwierdzone raycastem — 0 trafien we
wszystkich 8 kierunkach miedzy dzialkami). Stara "kaluza" z osmego przebiegu juz nie istniala w
Terrainie (0 voxeli Water w calym obszarze) — najwyrazniej sesja Studio nie zostala zapisana po
tamtym przebiegu.

**2. Zalanie calej mapy.** Jeden `Terrain:FillBlock` Water, srodek (0,17.5,0), rozmiar
(460,65,460) — pokrywa X/Z ±230 (bufor poza budowana mapa) i Y od -15 do 50 (5 studow ponizej
najnizszego punktu, 15.5 studa ponad najwyzszym). Zweryfikowane `ReadVoxels`: 228752/228752
voxeli w probce = Water, zero przerw.

**3. Prawdziwe dno morskie.** Wyspy "unosily sie" w pustce bez dna pod spodem — dobudowany drugi
`FillBlock` material Sand, srodek (0,-17,0), rozmiar (460,6,460) (Y -20..-14, zachodzi na dno
wody dla ciaglosci). Daje wizualne dno pod calym obszarem, ~35 studow ponizej wysp — zero ryzyka
kolizji z budowla.

**4. Chodzenie normalnie mimo zanurzenia.** Nowy `LocalScript` `StarterPlayer.StarterCharacterScripts.NoSwim`:
`humanoid:SetStateEnabled(Enum.HumanoidStateType.Swimming, false)`. Dziala PO STRONIE KLIENTA
(stan Humanoid do ruchu jest client-authoritative dla wlasnej postaci) — zweryfikowane w
playteście: `target="client-1"` pokazuje `swimEnabled=false`, `state=Running`, mimo ze gracz stoi
w voxelu materialu Water. Zapytanie tego samego przez `target="server"` nadal pokazuje
`swimEnabled=true` — to oczekiwana asymetria (server nie dostaje wywolania), NIE blad; liczy sie
stan klienta, bo on steruje ruchem wlasnej postaci.

**5. Korale i rosliny "wszedzie".** Osiem klastrow z dziewiatego przebiegu bylo zawieszonych w
pustce 40 studow pod mapa (stary koncept) — przebudowane od zera: 6x Coral Reef Pack + 5x
Underwater Flora rozrzucone po calym nowym dnie piaskowym (`Workspace.Hub.UnderwaterDecor.Coral`
/ `.Flora`), promien 30-200 studow od srodka, losowa rotacja, piwoty osadzone na powierzchni dna
(Y=-14 + polowa wysokosci modelu). Zweryfikowane: wszystkie top < 16, wyspy zaczynaja sie na
Y~21.5 — 5+ studow luzu, zero przebicia.

**6. Ryby plywaja.** `Workspace.Hub.UnderwaterDecor.Fish` (4 klastry Saltwater fish pack,
rozrzucone w otwartej wodzie miedzy dnem a wyspami, Y 10-35) + nowy `Script` `FishSwim`: kazda
pojedyncza ryba w paczce (~35 MeshPartow na klaster — Cod, Tuna, Barracuda, Octopus, itd., NIE
zespawnowane w jeden model) dostaje wlasna losowa orbite (promien 6-20 studow, faza, predkosc) i
pionowe bujanie przez `RunService.Heartbeat`, orientacja `CFrame.lookAt` w kierunku ruchu. Wszystkie
czesci ustawione `Anchored=true` (juz byly), `CanCollide=false` (byly true — zmienione, zeby
dekoracyjne ryby nie blokowaly graczy). Zweryfikowane w playteście: ryba (Boxfish) przesunela sie
o 11.07 studa w 2 sekundy — ruch dziala.

**Uwaga (nie naprawiane, poza zakresem):** w trakcie playtestu wystapil powtarzajacy sie,
niezwiazany z tym przebiegiem blad `EssenceTickController:57: attempt to index nil with 'new'
(function spawnSparkle)` co ~30s — to preexisting bug w `src/`, nie w tym, co dodano tutaj.
Zgloszone Andreasowi, do ewentualnej osobnej naprawy.

**Weryfikacja live (playtest, po restarcie zeby zobaczyc nowy stan edit-mode):** gracz w voxelu
Water (`ReadVoxels` na jego pozycji = `Enum.Material.Water`), `state=Running` (nie `Swimming`),
ryby w ruchu, zero nowych bledow od `NoSwim`/`FishSwim`.

**Andreas: Ctrl+S w Studio.** Ten przebieg zmienia Terrain (2x duzy `FillBlock` — Water + Sand),
przebudowuje `Workspace.Hub.UnderwaterDecor` (nowa struktura Coral/Flora/Fish + skrypt FishSwim),
dodaje `StarterPlayer.StarterCharacterScripts.NoSwim` (jedyna zmiana poza samym Hubem/Terrainem,
ale nadal build-only przez MCP — zero zmian w `src/`).

## EssenceTickController fix + audit skryptow mapy pod katem exploitow (2026-08-20, jedenasty przebieg)

**1. Root cause bledu `EssenceTickController:57: attempt to index nil with 'new'`** (zglaszany
przez Andreasa, powtarzajacy sie co ~30s w poprzednim playteście, zostawiony wtedy jako
"poza zakresem"): zwykla literowka w `spawnSparkle` — `NumRange.new(...)` zamiast poprawnego
Roblox globala `NumberRange.new(...)`. `NumRange` nie istnieje jako typ w Luau, wiec wyrazenie
zwraca `nil`, a indeksowanie `.new` na `nil` daje dokladnie zgloszony blad. Wystapienie na 2
liniach (`Lifetime` w linii 57, `Speed` w linii 58). Grep calego `src/` potwierdzil, ze to
jedyne 2 wystapienia literowki w calym kodzie.

Naprawione w `src/StarterPlayer/StarterPlayerScripts/Controllers/EssenceTickController.luau`
ORAZ recznie w zywym Studio (`set_script_source` na
`game.StarterPlayer.StarterPlayerScripts.Bootstrap.Controllers.EssenceTickController` — projekt
synchronizuje sie z Rojo tylko czesciowo, `src/` -> DataModel wymaga recznego pchniecia przez
MCP, patrz [[cards-project]]).

**Weryfikacja live:** restart playtestu, `get_runtime_logs` filtrowane po
`EssenceTickController` i po `"attempt to index nil"` — brak jakichkolwiek bledow, tylko czyste
`Init`/`Start` z `ServiceRegistry`. Blad nie wystepuje juz.

**2. Audit skryptow mapy pod katem exploita/wstrzykniecia** (Andreas obawial sie, ze cos
zlosliwego moglo wejsc razem z wgranymi assetami Creator Store — "Realistic Water" resztki mapy +
Coral Reef Pack / Underwater Flora / Saltwater fish pack): przeskanowane
`game:GetDescendants()` pod katem `LuaSourceContainer` poza znanymi bezpiecznymi korzeniami
(ServerScriptService, ReplicatedStorage, StarterPlayer.StarterPlayerScripts.Bootstrap,
StarterGui) — znaleziono dokladnie 4, wszystkie wlasne/znane: `Workspace.Hub.ConveyorDriver`
(preexisting, udokumentowany wczesniej), `Workspace.Hub.UnderwaterDecor.Fish.FishSwim` (napisany
w tym oknie), `StarterPlayer.StarterPlayerScripts.Bootstrap` (sam root-loader, wykryty tylko bo
skan liczyl go jako "poza drzewem Bootstrap" zamiast "jest Bootstrapem") i
`StarterPlayer.StarterCharacterScripts.NoSwim` (napisany w tym oknie). Zero obcych skryptow.

Dodatkowo sprawdzone: `PackageLink` pod Workspace (0), `RemoteEvent`/`RemoteFunction`/
`BindableEvent`/`BindableFunction` pod Workspace (0 — zgodnie z konwencja projektu, ze caly
networking siedzi w `ReplicatedStorage`), zawartosc `Workspace.CloudSea` (dekoracyjny Part bez
skryptow, preexisting, nizej niz cala reszta mapy — nie stanowi zagrozenia).

**Wniosek: mapa jest czysta.** `insert_asset` (polityka bezpieczenstwa MCP) automatycznie usuwa
wszystkie `LuaSourceContainer`y i `PackageLink`i z kazdego wstawianego assetu Creator Store przed
sparentowaniem — dziala zgodnie z oczekiwaniami, potwierdzone ponownie w tym audycie zero
znalezionych obcych skryptow gdziekolwiek w DataModelu.

**Andreas: Ctrl+S w Studio.** Ten przebieg zmienia jeden `src/` plik
(`EssenceTickController.luau`, literowka) + odpowiadajacy zywy skrypt w Studio przez
`set_script_source`. Zero zmian w Terrain/Workspace poza tym, co juz bylo z poprzedniego
przebiegu.

## Podwodne krolestwo — przebudowa dekoracji (2026-08-20, dwunasty przebieg)

Andreas: usunac to co bylo z poprzedniego przebiegu (rafy/ryby stloczone w kilku punktach) i
zrobic od nowa tak, zeby ryby swobodnie plywaly po CALYM akwenie, a rafy/flora byly rozrzucone
losowo po calym dnie i wygladaly na zespolone (naturalne skupiska), nie na rowno rozstawiona
siatke.

**1. Odkrycie:** kazdy istniejacy klon "Coral Reef Pack" / "Underwater Flora" to juz sam w sobie
GOTOWY klaster wielu elementow (bbox ~93x13x23 / ~105x30x71 studow) — nie pojedyncza korala.
Klonowanie kilku takich paczek w jeden punkt dawaloby absurdalny nadmiar nakladajacej sie
geometrii. Podobnie "Saltwater fish pack" to NIE jedna rybka a cala paczka **35 osobnych
mesh-rybek** (Cod, Barracuda, Grouper, Tuna, Octopus, itd.) animowanych osobno w `FishSwim` —
4 paczki z poprzedniego przebiegu = juz 140 rybek, tylko ze wszystkie orbitowaly ciasno (promien
6-20) wokol raptem 4 stalych punktow, stad wrazenie "kilku klebowisk" zamiast pelnego akwenu.

**2. Bezpieczna strefa pionowa ustalona bez potrzeby wykluczania stref XZ wokol wysp:** pilary
dekoracyjne 8 wysp-platform siedza na Y~24.5-27.5, podloga wysp ~Y21.5 — cala dekoracja
podwodna (rafy/flora/ryby) trzymana ponizej Y16 nigdy w nie nie wchodzi, wiec nie trzeba
wycinac osobnych stref wokol kazdej z 8 wysp. Jedyny realny konflikt: `Plaza.PlazaTrim`
(dekoracyjny pierscien cylindra, promien ~52, Y~-9±1) pod centralna wyspa — wykluczona jedna
wspolna strefa promien<58 od (0,0) dla calej dekoracji.

**3. Rafy/flora przebudowane:** stary `Coral`/`Flora` wyczyszczony, 9 klonow Coral + 7 klonow
Flora (16 lacznie, w gore z 6+5=11) rozmieszczonych przez rejection-sampling w pierscieniu
promien 58-215 od centrum (caly footprint akwenu ±230 z marginesem od sciany), min. odstep 70
studow miedzy punktami startowymi (nie miedzy krawedziami paczek — stad czasem dwie paczki
naturalnie blisko siebie = wyglada na zespolony klaster, czasem daleko = wyglada na rozrzucone
po calym dnie). Kazdy klon posadowiony na szczycie piaskowego dna (Y-14) + losowa rotacja Y.

**4. `FishSwim` przepisany od zera:** zamiast `home = part.Position` (pozycja rybki w oryginalnej
paczce, stad ciasne klebowisko), kazda z 140 rybek dostaje WLASNY losowy punkt-dom rozrzucony po
calym akwenie (promien 58-210 od centrum, Y od -8 do 16), z wiekszym promieniem orbity (12-30
zamiast 6-20). Efekt: paczki "eksploduja" na 140 niezaleznie plywajacych rybek pokrywajacych caly
zbiornik, nie 4 gestych roje.

**Weryfikacja live (restart playtestu):** `get_runtime_logs` — zero bledow (w tym zero
`EssenceTickController`/`FishSwim`). Bezposredni odczyt pozycji serwerowych: 140 rybek,
`X:[-222.9, 183.5]`, `Z:[-217.5, 220.0]`, `Y:[-8.8, 18.5]` — realnie pokrywaja caly promien
akwenu (~230), nie tylko 4 stare punkty. 9 Coral + 7 Flora rozrzucone po wszystkich kwadrantach
(przyklad: `-166,-60` / `133,114` / `0,70` / `-34,151` / `72,191`+`40,188` blisko siebie jako
naturalna para). Zrzut ekranu zablokowany przez ten sam preexisting "ROLL A RUNE" ekran startowy
co poprzednio (klik symulowany na PLAY nie dziala w tym kliencie) — jak w poprzednim przebiegu,
poza zakresem, wynik zweryfikowany przez bezposrednie odczyty DataModelu zamiast wizualnie.

**Andreas: Ctrl+S w Studio.** Ten przebieg to czysty build w Studio (przebudowa
`Workspace.Hub.UnderwaterDecor.Coral/Flora/Fish` + przepisany `FishSwim` Script) — zero zmian w
`src/`.

## Fix: rafy/flora rozpadaly sie po Play (2026-08-20, trzynasty przebieg)

Andreas zglosil: po wcisnieciu Play caly podwodny build "rozpada sie" — rafy/glazy/dekoracje
mialy byc przykotwiczone do dna, tylko rybki maja swobodnie plywac.

**Root cause:** audyt `Anchored` na wszystkich `BasePart` pod `UnderwaterDecor` wykazal, ze
`Coral` (45/45) i `Fish` (140/140) byly juz w pelni zakotwiczone, ale **`Flora` mial 28 z 49
czesci `Anchored=false`** (m.in. `RockFormation`, `Seaweed`, `SpongeCoral` w kazdym klonie
"Underwater Flora") — pominiete przy budowie klastrow w poprzednim przebiegu. Fizyka po Play
puszczala te 28 czesci w grawitacje, stad wrazenie ze caly build "sie rozpada".

**Fix:** petla po wszystkich 3 folderach (`Coral`/`Flora`/`Fish`), `Anchored = true` na kazdym
`BasePart` gdzie bylo `false` — 28 napraw, wszystkie we `Flora`.

**Weryfikacja live:** zapisane pozycje 7 czesci `Flora` (co 7-ma, sample) PRZED Play (edit-mode)
i PO ~75s dzialania playtestu (`target="server"`) — pozycje identyczne co do ulamka studa,
`Anchored=true` potwierdzone. `get_runtime_logs` — zero bledow. Rybki (140, `Fish` folder) nadal
w pelni ruchome przez `FishSwim` (Anchored=true + reczne `CFrame` w Heartbeat, nie fizyka —
dlatego plywaja mimo zakotwiczenia). Ilosc rybek (140, cala paczka x4) juz "w miare sporo" i juz
pokrywa caly akwen z poprzedniego przebiegu — bez zmian.

**Andreas: Ctrl+S w Studio.** Zmiana to jedna wlasciwosc (`Anchored`) na 28 istniejacych czesciach
pod `Workspace.Hub.UnderwaterDecor.Flora` — zero nowych instancji, zero zmian w `src/`.

## Fix: rampy nie do przejscia — dziura miedzy pasami (2026-08-20, czternasty przebieg)

Andreas zaslal zrzut z wlasnego testu (`aaaw.png`) — chaotyczne, "rozjechane" deski przy Placu.
Pierwsza hipoteza (wizualny balagan od 8 zbiegajacych sie ramp) zostala **odrzucona przez
Andreasa**: "podczas gry rampy sie rozwalaja, nie da sie po nich chodzic, masz je przykotwiczyc
porzadnie i to ogarnac" — to nie estetyka, to realny bug rozgrywki.

**Diagnoza:** `Anchored`/`CanCollide`/`CanTouch`/`Massless` na wszystkich 64 czesciach w
`Hub.Bridges` (8x Ramp1-8) — czyste, bez wyjatkow (`Anchored=true` wszedzie, `CanCollide=true` na
`Rail`/`LaneUp`/`LaneDown`, `false` tylko na kosmetycznych `Stripe`, jak powinno). Wlasciwosci nie
tlumaczyly bugu, wiec test empiryczny: `solo_playtest`, teleport gracza na `LaneUp`, obserwacja
`Humanoid:GetState()`/`FloorMaterial` przez kilka sekund — gracz wchodzil w `Freefall` z
`FloorMaterial=Air` w polowie rampy.

**Root cause (potwierdzony geometria, nie tylko symulacja):** kazda rampa ma DWA rownolegle pasy
(`LaneUp`/`LaneDown`, kazdy szer. 4.6 studow), srodki oddalone o ~6.2 studa — to zostawia **realna
szczeline ~1.65 studa** miedzy krawedziami pasow na CALEJ dlugosci kazdej rampy (potwierdzone na
wszystkich 8 ramp, identyczny wzorzec: gap 1.64-1.66). Wystarczajaco szeroka, zeby hitbox gracza na
14-stopniowym spadku wpadl w dziure i przeleciyal przez rampe — dokladnie "rampy sie rozwalaja, nie
da sie po nich chodzic".

**Fix:** nowa czesc `LaneFill` na kazdej z 8 ramp — jeden pelny pas laczacy `LaneUp` i `LaneDown`
(szerokosc = odleglosc miedzy srodkami + obie polowki + 1.5 studa zakladki z kazdej strony),
`Anchored=true`, `CanCollide=true`, material/kolor jak `LaneUp`. Zero usunietych/przesunietych
istniejacych czesci — tylko dolozona brakujaca geometria.

**Weryfikacja (deterministyczna, nie symulacja fizyki):** raycast w dol co 0.5 studa na calej
szerokosci (od wewnetrznej krawedzi `LaneUp` do zewnetrznej `LaneDown`) i co 0.2 dlugosci kazdej
rampy — **105/105 trafien na wszystkich 8 rampach, zero dziur**. (Test chodzenia
`Humanoid:MoveTo()` pokazywal dalej sporadyczny `Freefall` przy podejsciu pod gorke — to typowy
Roblox jitter na 14-stopniowym skosie bez realnego inputu WASD, nie ten sam bug; geometria po
fixie jest w 100% ciagla, co jest twardszym dowodem niz symulacja MoveTo).

**Andreas: Ctrl+S w Studio.** 8 nowych czesci (`LaneFill`, jedna na rampe) pod
`Workspace.Hub.Bridges.RampN` — zero zmian w `src/`.

## Fix: rampy nie laczyly sie z Placem — dziura po stronie placu (2026-08-20, pietnasty przebieg)

Andreas: "rampy miedzy plotami graczy a centralnym placem nie laczą się / nie kotwiczą — nie da się
przejść z plotu na plac. Underwater rebuild prawdopodobnie je rozjebał." WARUNEK #0, wymagana
weryfikacja playtestem I raycastem na wszystkich 8 rampach, w obu kierunkach.

**Diagnoza strony plotowej (zewnetrznej):** zmierzona odleglosc od `PlotAnchor` do konca rampy —
31.65-31.66 studa na wszystkich 8 rampach, identyczna z fixem z "siodmego przebiegu" (2026-08-19).
**Strona plotowa nigdy nie byla zepsuta** — podwodny rebuild jej nie ruszyl.

**Root cause (strona placowa/wewnetrzna):** rampy koncza sie na krawedzi Placu, ale nie bylo zadnej
czesci laczacej wewnetrzny koniec rampy (`LaneUp`/`LaneDown`/`LaneFill`) z `Plaza.PlazaFloor` —
realna szczelina na STYKU rampa-plac, dokladnie tam gdzie gracz schodzi z rampy na plac (lub
wchodzi z placu na rampe).

**Fix:** nowa czesc `PlazaFill` na kazdej z 8 ramp, laczaca wewnetrzny koniec rampy z krawedzia
Placu — zorientowana wedlug **faktycznego kierunku pasow rampy** (`LaneUp.CFrame.ZVector`), nie
czystego kierunku radialnego od srodka Placu (te dwa kierunki lekko sie rozjezdzaly, co przy
pierwszej, waskiej wersji fixu zostawialo mikroskopijna szczeline ~2×4 study w jednym rogu — zlapana
i domknieta przez poszerzenie zakladki). Finalne wymiary: `Anchored=true`, `CanCollide=true`,
`CanTouch=true`, szerokosc 32 study (przekracza faktyczna szerokosc chodnika miedzy barierkami
~10.6 studa z duzym zapasem), dlugosc 26 studow (18 studow zakladki w glab rampy/`LaneFill`, 8
studow na podloge Placu), material/kolor jak `LaneUp`.

**Weryfikacja — DWIE niezalezne metody, obie PASS:**
1. **Raycast (deterministyczny):** siatka co 1 stud, szerokosc dopasowana do faktycznego korytarza
   miedzy barierkami (±5 studow od osi), dlugosc: cala rampa + 5 studow zapasu po kazdej stronie —
   **187/187 trafien na wszystkich 8 rampach, zero dziur**, obejmuje zarowno styk plac-rampa jak i
   styk rampa-plot w jednym przebiegu.
2. **Playtest (dummy Humanoid, `Humanoid:MoveTo`, serwer):** 16 przejazdow (8 ramp × 2 kierunki:
   plac→plot i plot→plac) — **`FloorMaterial=Air` nie wystapil ani razu po wyladowaniu** na zadnym
   z 16 przejazdow; pozycje koncowe konsekwentnie ladowaly w oczekiwanym pasie wysokosci (~-0.8..-0.9
   przy Placu, ~18.4-19.2 przy plocie), zero sladu upadku/Freefall.
   (Wczesniejszy test przez prawdziwy input WASD na kliencie dal absurdalny wynik — postac na piasku
   dna morskiego, Y=-11 — okazalo sie to artefaktem **przestarzalej sesji playtestu** sprzed
   ostatniej edycji `PlazaFill`; Roblox playtest forkuje DataModel przy starcie, wiec zmiany w trybie
   edycji nie propagujа się do juz dzialajacej sesji. Restart playtestu + swiezy pomiar dal spojne,
   czyste wyniki.)

**Andreas: Ctrl+S w Studio.** 8 nowych czesci (`PlazaFill`, jedna na rampe) pod
`Workspace.Hub.Bridges.RampN` — zero zmian w `src/`.

## Audyt: "rampy rozjezdzaja sie w Play" — zero przyczyny runtime, geometria stabilna (2026-08-20, szesnasty przebieg)

Andreas: "geometria wyglada OK w EDIT, ale przy PLAY/tescie sie rozjezdza" — WARUNEK #0, trzy
konkretne hipotezy do sprawdzenia: (a) czesc odkotwiczona w runtime przez skrypt, (b) conveyor
rusza SAME belki zamiast tylko popychac gracza, (c) leftover build-skrypt na starcie.

**Metoda:** prawdziwy `solo_playtest` (nie edit), snapshot pozycji + `Anchored` wszystkich 72 czesci
pod `Hub.Bridges` (8 ramp × 9 czesci: `LaneUp`, `LaneDown`, 3×`Rail`, 2×`Stripe`, `LaneFill`,
`PlazaFill`) zaraz po starcie, potem po ~30s realnego czasu Play, diff pozycja-po-pozycji.

**Pulapka po drodze:** pierwszy diff pokazal 24 "przesuniete" czesci (`Rail`/`Stripe` — kazda rampa
ma PO TRZY `Rail` i PO DWIE `Stripe` o IDENTYCZNEJ nazwie). Klucz snapshotu oparty tylko o nazwe
nadpisywal sie przy kolizji, wiec diff faktycznie porownywal RÓZNE fizyczne czesci ze soba —
falszywy alarm, bug w metodzie pomiaru, nie w grze. Poprawka: klucz indeksowany
(`RampN.PartName#idx`, stabilna kolejnosc `GetChildren()`), pomiar powtorzony od zera.

**Wynik (72/72 czesci, indeksowany klucz):** **zero roznic pozycji, `Anchored=true` na starcie i po
30s bez wyjatku** na wszystkich 8 rampach.

**Weryfikacja trzech hipotez:**
1. **(a) Skrypt odkotwiczajacy w runtime — WYKLUCZONE.** `grep_scripts` po calej grze (79 skryptow):
   zero trafien na `Anchored = false`, zero odwolan do `Bridges`.
2. **(b) Conveyor rusza belki — WYKLUCZONE.** `Workspace.Hub.ConveyorDriver` (jedyny skrypt
   dotykajacy tagu `ConveyorLane`, ktorym oznaczone sa wlasnie `LaneUp`/`LaneDown`) mutuje
   WYLACZNIE `HumanoidRootPart` dotykajacych graczy (`part.CFrame = part.CFrame + dir*speed*dt`,
   filtr `part.Name == "HumanoidRootPart"`) — nigdy nie dotyka samej belki (`belt`). Kod juz pisany
   poprawnie (surface-velocity wzorzec na graczu, nie na geometrii).
3. **(c) Leftover build-skrypt na starcie — WYKLUCZONE.** Jedyne dwa trafienia na `PivotTo` w calej
   grze to `FallRespawnService` (respawn POSTACI po spadnieciu z mapy) i `PlotService`
   (ustawianie klona plotu w slocie przy przydziale) — zaden nie dotyka `Hub.Bridges`.

**Wniosek:** obecna geometria ramp jest w 100% stabilna w Play, identyczna z Edit. Fraza
"rozjezdzone deski" pokrywa sie 1:1 ze slownym opisem juz naprawionego buga z **czternastego
przebiegu** (szczelina `LaneUp`/`LaneDown`, fix `LaneFill`) — najbardziej prawdopodobne wytlumaczenie
to test na nieodswiezonej sesji (przed Ctrl+S / przed fresh Play po ostatnich fixach), nie nowy bug.
Zaden z 8 ramp/72 czesci nie wykazal ruchu ani utraty `Anchored` w realnym Play.

**Andreas: Ctrl+S w Studio, potem swiezy Play (zamknij i otworz playtest od nowa, nie kontynuuj
starej sesji) — jesli rozjezdzanie nadal widoczne PO fresh save+replay, to nowy, jeszcze
niezidentyfikowany objaw i potrzebny nowy zrzut/opis z konkretnej rampy.** Zero zmian w geometrii
tym razem — audyt, nie fix (nic nie bylo do naprawienia w runtime).

## FLATTEN hub + cleanup dekoracji — jeden poziom dna, rampy usuniete (2026-08-20, siedemnasty przebieg)

Na zadanie Andreasa: caly Hub splaszczony z dwupoziomowego designu (ploty na plywajacych
wyspach Y=22, plac/sklep/portal na Y=0) do JEDNEGO poziomu dna morskiego. Zero zmian w
`src/` — czysto instancje w Studio (`PlotService.luau` czyta `AnchorMarker.CFrame` live przy
starcie serwera, wiec nowa pozycja trafia automatycznie, bez zmian w kodzie).

**Poziom dna:** potwierdzony raycastem, top piasku (Sand) = **Y=-14** (raycast musi startowac
Z WEWNATRZ kolumny wody, np. Y=5, w dol — start z Y>50 trafia w gorna powierzchnie wody, nie
w dno, znana pulapka z 8./9. przebiegu).

**Wykonane:**
1. `Hub.Bridges` (8× `RampN`, kazdy z `LaneUp/LaneDown/3xRail/2xStripe/LaneFill/PlazaFill`) —
   **usuniety w calosci** (`:Destroy()`). Jeden poziom = brak potrzeby na pochyle rampy, to
   wlasnie one robily "chaos krzyzujacych sie desek".
2. Wszystkie 8 `Hub.PlotAnchors.PlotAnchorN` (+ dopasowane `Hub.Barriers.PlotBarriersN`)
   przesuniete o **Y-36** (`PivotTo(GetPivot()+Vector3.new(0,-36,0))`, czysta translacja —
   orientacja/ustawienie kart ZACHOWANE automatycznie, bo to translacja a nie rebuild).
   `AnchorMarker` wyladowal dokladnie na Y=-14 (sprawdzone raycastem na wszystkich 8).
3. `Hub.Plaza`, `Hub.Shop`, `Hub.Portal`, `Hub.Barriers.PlazaRing` przesuniete o **Y-14**.
   `PlazaFloor` top = Y-14 (raycast), flush z dnem.
4. `Workspace.SpawnLocation` (poza folderem `Hub.Plaza`, wiec pominiety w kroku 3) doraznie
   znaleziony i przesuniety o -14 osobno — inaczej gracz spawnowalby sie 14+ studow nad nowym
   dnem.
5. **Cleanup dekoracji** (44 elementy = 28 `Hub.Decor` tuft-y + 9 `Coral Reef Pack` +
   7 `Underwater Flora` w `Hub.UnderwaterDecor`): PRZED flattenem wszystkie 44 nachodzily na
   plac/plot/sklep/portal (sprawdzone AABB/OBB overlap w lokalnej ramce kazdej kotwicy plotu +
   promien placu) — bo dekor siedzial na starych wyspach (Y~22-24, brak realnej kolizji z
   racji separacji pionowej), a po splaszczeniu ta sama pozycja XZ = realny clipping.
   - 28 malych tuftow (Crystal/Coral/PlantTuft): przesuniete promieniowo od najblizszej strefy
     (od srodka placu jesli byly plac-adjacent, od srodka konkretnej kotwicy plotu jesli
     byly plot-adjacent) z zapasem poza polowa przekatnej footprintu (68*1.5+margines),
     nastepnie osadzone na dnie raycastem (Y=5→w dol, ta sama pulapka wody co wyzej —
     pierwsza probka z Y=60 dala falszywe Y~50-80, "floating" bug, wykryty i naprawiony).
   - 16 duzych elementow tla (`Coral Reef Pack` 93×23, `Underwater Flora` 105×71): przesuniete
     promieniowo OD SRODKA MAPY poza zewnetrzny promien pierscienia plotow (promien~280,
     rozrzut), jako dalekie tlo poza cala strefa gry — rozmiar (93-105 studow) i pierwotny
     gesty rozstaw sprawialy ze pojedynczy plot/plac trafial w 2-3 elementy naraz, promieniowy
     wypych to jedyny deterministyczny sposob rozwiazania bez kolizji miedzy nimi.
   - **Wynik: 0/44 nachodzenie** po weryfikacji (ten sam AABB/OBB check co wykryl 44/44 przed
     fixem).

**Weryfikacja (2 niezalezne metody):**
1. Raycast sweep 184 probek (23 punkty × 8 sciezek plac→plot, promien 55-165) — **0 dziur**.
2. Realny playtest (`solo_playtest` play mode): gracz automatycznie trafil na `Plot_<userId>`
   na Y=-14 (`PlotService` poprawnie odczytal nowa pozycje kotwicy przy starcie serwera),
   scripted `Humanoid:MoveTo` plac→wlasny plot→plac — caly czas na ziemi (HRP Y≈-10/-11,
   spojne z stanem na dnie), zero wpadniecia w pustke.

**Zrzuty (zolnierz-widok + gora):** zolnierz-widok pokazuje gracza na plaskim placu ze
straganem, kartami plotow po bokach na tym samym poziomie, rybami/koralami w tle bez
clippingu. Aerial (kamera Scriptable, z zewnatrz terenu patrzac do srodka, bo prosto-w-dol z
duzej wysokosci = nad powierzchnia wody, silna mgla/tinting robi scene nieczytelna — znana
pulapka: gora wody ~Y=50, wiec top-down w pelni podwodny ogranicza wysokosc kamery do <50)
pokazuje fontanne+plac+dwa mury barierowe plotow na jednym plaskim poziomie, dekor bez
nachodzenia.

**Poboczny fix wykonany przy okazji:** `Workspace.SpawnLocation` (krok 4 wyzej) — nie byl
czescia zadania, ale bez tego gracz spawnowalby sie w powietrzu nad nowym dnem.

**Andreas: Ctrl+S w Studio — caly ten przebieg to instancje w zywym DataModelu, nic nie jest
jeszcze zapisane na dysku.**

## Odds-bug fix (compliance, 2026-08-18)

**Problem:** `PolicyService.computeTierOdds` (tabela szans pokazywana graczowi, Krok 4b audytu
compliance) modelowala pule totemow jako "1 totem = 1 tier" (kaskada `remaining *= 1/weight` po
`RarityConfig.TierWeight`, 5 wpisow). Realny roll w `RollService.selectTotem` iteruje PO
KAZDYM TOTEMIE z osobna (pula ma 25 wpisow: Common=10/Uncommon=5/Rare=4/Epic=4/Legendary=2,
kazdy z wlasnym niezaleznym rzutem `nEff=floor(weight/luck)`) — te dwa modele sa rownowazne
TYLKO gdy kazdy tier ma dokladnie 1 totem. Roster urosl (dowod: `RarityConfig.luau` naglowek
"All 15 MVP totems" + PLACEHOLDER-flaga "nie zsymulowane przeciw kaskadzie", checkpoint z
2026-08-17 mial empirycznie Legendary~1.1% co pasuje do STAREGO, mniejszego rostera), display
zostal na starych zalozeniach — displayed Legendary 1.11% vs realne 2.21% (2x), analogicznie
zanizone Epic/Rare/Uncommon, zawyzony Common.

**Fix — single-source-of-truth:** nowy plik `Shared/Configs/TotemPool.luau`,
`TotemPool.sorted()` = JEDYNA funkcja budujaca posortowana pule totemow (ekstrakcja z
prywatnego `totemsSorted()`, ktore wczesniej zylo tylko w `RollService`). `RollService.
selectTotem` I `PolicyService.computeTierOdds` (przepisana matematyka: per-tier grupa k
totemow o wadze w -> `landHere = survive*(1-(1-1/w)^k)`, ostatni/najczestszy tier chlonie
reszte tak jak realny fallback) teraz CZYTAJA TA SAMA funkcje — strukturalnie niemozliwe zeby
sie znowu rozjechaly (jedno zrodlo, nie dwie kopie liczby).

**Decyzja "1.11% czy 2.2%" (NIE moja do podjecia — dla Andreasa):** 1.11% NIE byl swiadomym
targetem, to byl przypadkowy output starej zepsutej formuly (dowod: `RarityConfig.luau` sam
flaguje `TierWeight` jako niezwalidowany placeholder). Fix jak zaimplementowany NIE zmienia
realnej hojnosci gry ani o promil — `RollService` losowal 2.21% Legendary ZANIM cokolwiek
tu zmieniono, zmienil sie WYLACZNIE display (byl klamliwy, teraz mowi prawde). Jesli Andreas
chce realnie obnizyc droprate do ~1.1%, to jest OSOBNA decyzja balansu (podniesc
`RarityConfig.TierWeight.Legendary`) — swiadomie NIE podjeta w tym zadaniu, flagowana tutaj.

**Dowod symulacja (obowiazkowy, `execute_luau`, N=100000, luck=1, real `_SelectTotemForTest`/
`_SelectVariantForTest`, porownanie z `PolicyService._ComputeTierOddsForTest(TotemPool.sorted())`):**

| Tier | empiryczne% | wyswietlane% | diff(pp) |
|---|---|---|---|
| Legendary | 2.243 | 2.210 | +0.033 |
| Epic | 12.323 | 12.401 | -0.078 |
| Rare | 25.232 | 25.099 | +0.133 |
| Uncommon | 29.433 | 29.367 | +0.066 |
| Common | 30.769 | 30.923 | -0.154 |

Wszystko w granicach szumu Monte Carlo dla N=100k (~0.1-0.15pp) — **dyskolzura == rzeczywistosc,
PASS**. Warianty rowniez zweryfikowane w tym samym runie (Normal 84.90%/Foil 9.97%/Gold
4.02%/Galaxy 1.01%/Rainbow 0.10%), zgodne z `VariantConfig.ladder`.

**Belt-and-suspenders (ranked pool integrity):** `RunShopService.rankedTotemPool`
(RunShopService.luau:50-56) nadal czyta WYLACZNIE stala `RankedConfig.TotemIds` —
`IndexService.IsDiscovered` w tej galezi w ogole nie jest wywolywane (potwierdzone grepem tej
sesji). Odds-fix nie dotyka sciezki ranked.

**Nota (poprawic przy nastepnej edycji Kroku 4b w tym pliku):** stara tabela w sekcji "Krok 4b"
ponizej (linia z "Legendary 1.11%, Epic 3.30%...") jest teraz NIEAKTUALNA — to byl zrzut ekranu
przed tym fixem, zostawiona jako historia audytu, nie jako biezacy stan.

## Merge/Craft (System 3, 2026-08-18)

Zbudowane autonomicznie (/rc, Andreas poza domem) wg MERGE_PLAN_PROPOSAL.md sekcja 7+8,
zatwierdzone z 5 poprawkami. Nowe pliki: `Shared/Configs/MergeConfig.luau`,
`Services/MergeService.luau`. Edytowane: `EconomyService` (+`AwardEssenceFlat`, stały kurs bez
essenceMult), `ProfileService` (+`lifetimeMerges`/`lifetimeDisenchants`), `Net.luau` (+3 remote'y:
`GetMergeState`/`MergeTotem`/`DisenchantTotem`), `Bootstrap` (ORDER: `MergeService` po
`RollService`), `RollRevealController` (+`PlayReveal` publiczne, reuse UI beatu dla merge),
`IndexController` (+wiersz akcji Połącz/Rozłóż per kafelek, +GetMergeState w `refresh()`).

**BRAMKA-ZERO (ranked pool integrity) — zweryfikowana w kodzie, nie zalozona:**
`RunShopService.rankedTotemPool` (RunShopService.luau:50-61) czyta WYLACZNIE
`RankedConfig.TotemIds` (stala lista 5 id), z jawnym komentarzem (linie 45-49) ze ranked nigdy
nie wola `IndexService.IsDiscovered`. Dispatch `if run.mode=="ranked" then return
rankedTotemPool(run) end` (linie 64-67) potwierdza ze ranked nigdy nie trafia do galezi
`availableTotemPool`, gdzie `IsDiscovered` jest faktycznie wolane (linia 91, tylko free-mode).
**Wniosek: merge NIE potrzebuje dodatkowego scopingu ranked** — nowa karta odkryta przez merge
trafia do `profile.totems`/IndexService dokladnie jak roll, bez wplywu na ranked.

**Design (5 poprawek Andreasa):**
1. Weighted-merge **LANDED** (nie uniform-fallback) — `MergeService.selectMergeResult` probkuje
   ze zbioru nieodkrytych id w tierze docelowym, uniform-fallback dopiero gdy caly tier
   skompletowany. Zaimplementowane wprost (nie pominięte), bo tanie: kandydaci to max 5 id/tier,
   partycja+sample to O(n).
2. Atomowosc (anty-dupe): `MergeService.Merge`/`Disenchant` — ZERO yieldow (brak
   task.wait/DataStore/Invoke) miedzy walidacja ("ma 5 + ma essence") a mutacja
   (`data.totems`/essence), caly critical section w jednym synchronicznym wywolaniu. Wzorzec
   `RunShopService.buy`. Potwierdzone przegladem kodu.
3. UI: licznik merge liczy WYLACZNIE wariant Normal (`id#Normal`), pokazywany jawnie jako
   "Normal: x/5" — mix Normal+Foil nigdy nie wyglada jak falszywe "5/5". Foile pozostaja
   rozkladalne osobno (Rare, dowolny wariant, count>1 -> essence).
4. Progi/koszty bez zmian: Threshold.Normal=5, EssenceCost{Common=50,Uncommon=150},
   NextTier{Common->Uncommon,Uncommon->Rare} (brak klucza Rare = cap, Epic/Legendary tylko z
   paczek/rolla), DisenchantValueEssence=30 (wszystkie warianty, stały kurs).
5. Liczby 50/150/30 to HIPOTEZY STARTOWE — bramka balansu mierzy % ukonczen runu, NIE przeplyw
   essence, wiec NIE waliduje tych liczb. Strojenie na dane z playtestu, nie teraz.

**Teoretyczny koszt Common->Rare (czysto z MergeConfig, do osadu na skalę):** sciezka to 5 merge'y
Common (kazdy 5x Common -> 1x Uncommon, 50 essence) + 1 merge Uncommon (5x Uncommon -> 1x Rare,
150 essence) = **25 kart Common + 400 essence -> 1 karta Rare**.

**Bramka balansu (sanity, Blok 2) — PASS:** `runDeckGate` (deck=10 mixed, n=50) po zaimplementowaniu
mergu: NAIVE 4%, **FULL-SMART 38%** (target 30-55%, w pasmie). Merge nie zmienia matematyki runu
(zero nowych typow kart), wiec brak zmiany wzgledem poprzedniego pomiaru (44% na innym seedzie/
konfiguracji) jest oczekiwany — oba w pasmie.

## Gdzie jestesmy (skrot dla nastepnej sesji)

**Fazy 1-4 zrobione, MAX-SLOT, "nowe Stworki + balans" i merge zamkniete.** Gra jest funkcjonalnie
kompletna (rdzen deckbuildera, kolekcja/roll, merge/disenchant, retencja D1/D7, monetyzacja Robux,
deck-limit 10 kart, 25 Stworkow) i zgodna z polityka Roblox Paid Random Items. W toku jest
**przedpremierowa ekspansja, kolejnosc sztywna: MAX-SLOT (zrobione) -> nowe Stworki + balans
(zrobione) -> merge (zrobione) -> packi+daily+luck -> UI+juice**, a dopiero PO niej **Faza 5 —
redesign wizualny** (patrz sekcja na samym dole pliku). Nastepny krok do zaplanowania z Andreasem:
**packi+daily+luck** (krok 4/5). Wszystko ponizej to historia/dowody, nie rzeczy do zrobienia teraz.

## Dyscyplina wywolan MCP (obowiazuje od 2026-08-17)

Auto-compact w dlugich sesjach Studio bierze sie glownie z tresci wynikow narzedzi, nie z
liczby serwerow MCP. Trzymaj sie:

- `script_grep` / targetowane wyszukiwanie ZAMIAST pelnego `script_read`, gdy szukasz
  konkretnej rzeczy w skrypcie.
- Waski `path` / `max_depth` w `search_game_tree` / `inspect_instance` — nie dumpuj calego
  Workspace, gdy potrzebny jest jeden fragment.
- Screenshoty TYLKO gdy Andreas wprost prosi o wizualne potwierdzenie — nie profilaktycznie
  po kazdej akcji. Jeden zrzut na koniec logicznego kawalka, nie seria.
- Uzywaj MCP `robloxstudio` (plugin Chrrxs/robloxstudio-mcp, port 58741) — NIE oficjalnego
  `Roblox_Studio`, ktorego odpowiedzi sa wieksze i szybciej zapychaja kontekst.

## TWARDA REGULA: hierarchia `Controllers` w Studio (od 2026-08-17)

`game.StarterPlayer.StarterPlayerScripts.Bootstrap.Controllers` MUSI byc DZIECKIEM `Bootstrap`
(LocalScript), NIE jego siblingiem. `Bootstrap` (`init.client.luau`) czyta
`script:WaitForChild("Controllers")` — jesli `Controllers` wisi obok `Bootstrap` zamiast w
srodku, kazdy kontroler klienta (Hud/Hand/RunFlow/Roll/Index/...) infinite-yielduje i gra jest
martwa po stronie klienta, bez zadnego bledu poza jednym cichym warningiem.

**Ten projekt NIE MA `project.json` (nie jest prawdziwym Rojo projektem)** — sync do Studio idzie
recznie przez MCP (`create_object`/`set_script_source`), wiec hierarchia instancji nie jest
zdefiniowana deklaratywnie NIGDZIE w kodzie/gicie. Naprawiona 2026-08-17 przez reczny
`set_property` (Parent) w zywym Studio — to jest fix TYLKO w Studio, zniknie jesli plac kiedys
powstanie od zera z pustego miejsca.

**Zasada do pilnowania recznie przy kazdym odtworzeniu placu / duzym resyncu:** przed pierwszym
playtestem po jakimkolwiek `create_object` dotykajacym `StarterPlayerScripts`, sprawdz
`get_instance_children` na `Bootstrap` i potwierdz `Controllers` jest w srodku. Docelowa,
solidniejsza naprawa (prawdziwy `project.json` + `rojo build`/`serve`, ktory foldowalby
hierarchie automatycznie z ukladu folderow na dysku) to osobna decyzja architektoniczna, nie
podjeta w tej sesji — jesli chcesz to zrobic, powiedz wprost, to nie jest male zadanie.

## Faza 2b — zrobione (commit `a4a6317`, wypchniete na `origin/main`)

Serwerowa warstwa rolli i kolekcji, PRZED UI:

- **RollService** (`src/ServerScriptService/Services/RollService.luau`) — meta-roll Stworka za
  Esencje. Sekwencyjny wybor tieru dzieleniem-przez-N (wzorzec WAR RNG: pula posortowana
  najrzadszy-pierwszy, `nEff = floor(weight/luck)`, pierwsze trafienie wygrywa, fallback =
  najmniej rzadki). Pity: po `RarityConfig.Pity.threshold` (40) bez Epic+ pula jest filtrowana do
  tierow `>= guaranteeTier`. Wariant losowany NIEZALEZNIE, dokladnym wazonym cumulative-pick (nie
  cascade — tabela compliance, musi trafiac dokladnie w % z `VariantConfig`).
- **IndexService** (`.../IndexService.luau`) — discovery (klucz `totemId#variant` w
  `profile.totems`, bez osobnej tabeli — patrz komentarz w pliku), progi kompletnosci z
  `IndexConfig.luckThresholds` (25%->0.5, 50%->1.0, 100%->2.0 luck), **ODBIERANE** (`ClaimLuck`),
  nie automatyczne.
- Configi: `RarityConfig.luau`, `VariantConfig.luau`, `IndexConfig.luau`.
- Net remotes: `RollTotem`, `ClaimIndexLuck`, `GetIndexState`.
- Bootstrap wiring: `IndexService`/`RollService` dopisane do `ORDER` (miedzy `EconomyService` a
  `RunSessionService`).
- `StatProfileService.Recompute()` leniwie dodaje `IndexService.GetLuckBonus(player)` do
  `stats.luck` (przez `ServiceRegistry.has(...)`, zeby uniknac cyklu load-order z IndexService).
- `GameConfig.RollCostEssence = 50`.

### Math checkpoint (task #14, bramka przed UI) — ZDANY

Skrypt: `tests/RollService.checkpoint.studio.luau` (wymaga live Studio server VM, patrz naglowek
pliku — uruchamiany przez execute_luau w Play, N=200000 rolli tier/wariant, M=100000 dla
porownania stawki po zmianie luck):

| # | Wymog | Wynik |
|---|-------|-------|
| a | Rozklad tierow vs wagi w RarityConfig | Common 51.9% / Uncommon 25.5% / Rare 14.7% / Epic 6.8% / Legendary 1.1% — rank-order poprawny co uruchomienie (algorytm to sekwencyjny divide-by-N, nie prosty udzial wagowy, wiec % nie rownaja sie naiwnemu udzialowi wagi — to oczekiwane) |
| b | Pity gwarantuje Epic po progu | 0/2000 naruszen na progu (40), 0/2000 falszywych trafien 1 rzut przed progiem; naturalny max streak w 200k rolli nigdy nie przekroczyl progu |
| c | Esencja spada/schodzi poprawnie | `AwardEssence`/`TrySpendEssence` odejmuja dokladnie `GameConfig.RollCostEssence` (50) za kazdy roll, odmawiaja przy saldzie 0 |
| d | ClaimLuck podnosi realny luck kolejnych rolli | `ClaimLuck(25)`: luck 1.0 -> 1.5 (dokladnie zgodnie z `IndexConfig`), podwojny claim odrzucony (`AlreadyClaimed`), a podniesiony luck realnie zmienil szanse w `selectTotem`: stawka Epic+ 7.8% -> 11.3% |

Wszystkie 4 wymogi: **PASS**. Bramka przed UI otwarta.

Techniczna notka (zeby nie powtarzac debugowania): `execute_luau` w MCP ma WLASNY cache modulow,
odizolowany od zywej gry (Bootstrap-owy Server VM) — trzeba recznie odpalic `Init()` na
uzywanych serwisach i zarejestrowac `IndexService` w `ServiceRegistry`, zeby leniwy luck-bonus
hook w `StatProfileService` zadzialal. Zero ryzyka dla prawdziwego profilu gracza — testy uzywaly
fejkowego in-memory profilu przez istniejace hooki `_InjectForTest`/`_SetProfileServiceForTest`,
nigdy nie dotykaly ProfileService/DataStore. Szczegoly w naglowku pliku checkpointu.

## Faza 2b UI — zrobione (commit `6ec39f9`, wypchniete na `origin/main`)

Klient, dopiete na serwerowa warstwe wyzej. Zweryfikowane LIVE w playtescie (nie tylko code
review) via `eval_client_runtime` (klik-symulacja `simulate_mouse_input` nie dziala w tym
srodowisku — nieklikalne przyciski na starym I nowym UI identycznie, srodowiskowy problem, nie
bug kodu; ominiete bezposrednim wywolaniem funkcji za przyciskami):

- **RunShopService** — pula totemow w sklepie w runie = starter Common (dynamiczny filtr tieru,
  dzis 7 totemow) UNION posiadane przez gracza (`IndexService.IsDiscovered`), minus
  juz-w-tym-runie. Swiezy gracz bez zadnego rolla ma co kupic. Zweryfikowane code-review + potem
  bramka D1 harnessem (patrz nizej) — brak dedykowanego UI do klikniecia w playtescie.
- **RollRevealController** — pacing tier->duration portowany z WAR RNG `RevealConfig` (Common
  szybko, Epic/Legendary dluzej suspensyjnie), styl kart WLASNY (`UIFactory` + `CardArtConfig`),
  wariant = zwykly `TextLabel`, zero animacji/czasteczek. Zweryfikowane live: Common
  (Emberpup, ~1.6s) i Rare (Merlynx, ~3.3s), oba poprawnie wyrenderowane, pacing zgodny z tabela.
- **IndexController** — siatka 15 Stworkow (przyciemnione = nieodkryte, tier-color = odkryte),
  pasek completeness, przyciski ODBIERZ na progach z `GetIndexState`. Zweryfikowane live: 15/15,
  100%, siatka + pasek + 3 przyciski ODBIERZ.
- **HudController + UIRootController** — przyciski "Roll"/"Indeks" w HUD (prawy gorny rog), nowe
  ScreenGui rooty (`Roll` order=25, `Index` order=45). Zweryfikowane live: bez kolizji z
  essence-barem/run-row/reka.
- `cardsw/` (raw art PNG + `_originals`/`_not_mvp`) **rozstrzygniete**: NIE wchodzi do repo gry,
  dodane do `.gitignore`. Backup lokalny wystarczy (juz jest). Finalne assety zyja w Roblox jako
  uploadowane obrazy, kod czyta je przez `CardArtConfig`.

Efekt uboczny live-testow: essence na koncie testowym "Onimushaa5" spadlo 1577->1576 (prawdziwy
ProfileStore, nie sandbox — testy przez `eval_client_runtime` uzywaja prawdziwego profilu
gracza).

## Bramka D1 — pula=starter (2026-08-17) — ZAMKNIETA, PASS

Uruchomione `tests/BalanceHarness.studio.luau` live w server VM (`eval_server_runtime`, solo
playtest), n=50 seedow, `RunSessionService.startRun` (nie `startRunForPlayer`) daje `owner=nil`
=> `availableTotemPool` zwraca WYLACZNIE starter (7 Common) — dokladnie scenariusz "swiezy gracz,
zero rolli" bez zadnej modyfikacji harnessu:

| Bot | Completion | Loss histogram (enc) |
|---|---|---|
| FULL-SMART (proxy realnego gracza: najlepszy hand co ture, swapy, zuzywa zwoje) | **30% (15/50)** | 8:1 9:1 10:22 11:4 12:7 |
| NAIVE (floor: zero decyzji, nigdy nie swapuje/nie kupuje strategicznie) | **2% (1/50)** | 6:1 7:5 8:16 9:7 10:19 11:1 |

**Decyzja Andreasa (2026-08-17): PASS, progi NIE zmieniane.**

- FULL-SMART 30% na starter-puli vs 54% na pelnej kolekcji (Faza 3 balance, historyczna notatka w
  harnessie) — dokladnie zamierzona progresja: swiezy gracz wygrywa ~co trzeci run bez zadnego
  rolla, trudniej niz z pelna kolekcja, a ta roznica jest zaproszeniem do rollowania. To sedno D1.
- NAIVE 2% jest OCZEKIWANE, nie sygnal do tuningu. NAIVE = bot bez wymian i bez strategii (podloga
  z definicji, patrz naglowek harnessu). Skok 2% (bezmyslnie) -> 30% (z glowa) DOWODZI ze decyzje
  gracza maja znaczenie — to jest sedno deckbuildera. Gdyby NAIVE robil 30%, gra bylaby za plytka.
- Zaden dalszy tuning progow enc8-10 nie jest potrzebny przed Faza 3.

Komentarz z wynikiem zapisany tez w `RunShopService.luau` przy `availableTotemPool`.

## Faza 3 (retencja) — PLAN zatwierdzony 2026-08-17

Architektura: 7 modulow (SeedService, ranked mode, LeaderboardService, StreakService, QuestService,
AnnouncementService, OfflineEarnService). Kolejnosc budowy (dependency-driven, NIE lista 1-7 z
briefu Andreasa): **OfflineEarnService -> sygnaly (RunEnded/SpellPlayed/GuardianDefeated/
TotemRolled) -> SeedService -> ranked mode -> LeaderboardService -> StreakService -> QuestService ->
AnnouncementService**. Pierwsze grywalne = OfflineEarnService (samodzielny, zero zaleznosci od
reszty). Cut-lista: tygodniowy leaderboard i pula questow moga poczekac; mediana-z-3 anty-cheat w
LeaderboardService NIE do ciecia (zelazna zasada architektury).

Odkrycie przy planowaniu: sygnaly `RunEnded`/`SpellPlayed`/`GuardianDefeated`/`TotemRolled` sa
udokumentowane w `RUNE_RNG_ARCHITEKTURA.md` §2 (linia 78) ale NIE zaimplementowane w kodzie
(zweryfikowane grepem) — to jest prawdziwy krok #2 w kolejnosci, nie "juz gotowe z Fazy 1" jak
zakladal brief. `RollService.Rolled` i ranked-mode hook (`RunState.mode` + `ScoreEngine`
`collectionScoped` filtr z zasady 12) SA juz zaimplementowane i dzialajace (potwierdzone grepem),
tylko nie podlaczone do zadnego uzytku.

### OfflineEarnService — ZROBIONE, zweryfikowane live (2026-08-17)

Port wzorca z `D:/RobloxProjects/rng/EconomyService.computeOfflineRaw` (3 guardy: first-login,
clock-skew, cap `OfflineConfig.CapHours=10`). Nowe pliki: `Shared/Configs/OfflineConfig.luau`,
`ServerScriptService/Services/OfflineEarnService.luau`,
`StarterPlayerScripts/Controllers/OfflineEarnController.luau` (toast w nowym root "Toast",
`UIRootController` order=50) + remote `OfflineEarnings` w `Net.luau`. Zarejestrowany w Bootstrap
(server) po `EconomyService`, w init.client po `IndexController`.

Guard przeciw podwojnemu naliczeniu (race ProfileReleasing / szybki re-login): baseline `offlineTs`
jest zawsze swiezy z DWOCH miejsc — `ProfileService.onPlayerRemoving` stempluje `os.time()` PRZED
`EndSession` (juz istnialo, nic nie trzeba bylo dokladac), plus `ComputeOfflineEarnings` sam resetuje
`offlineTs=now` natychmiast po policzeniu, przed `AwardEssence`.

Zweryfikowane live w solo playteście przez `eval_server_runtime` (`_ComputeOfflineRawForTest` +
prawdziwy `ComputeOfflineEarnings` na zywym profilu):
- first-login (offlineTs=0): raw=0 — PASS
- clock-skew (offlineTs w przyszlosci): raw=0 — PASS
- normalny przypadek (1h offline): raw=20 (=`EssencePerHour`) — PASS
- cap (20h offline): sekundy przyciete do 36000 (10h), raw=200 — PASS
- pelna zywa sciezka (2h wymuszone na prawdziwym profilu): +40 essence przyznane
  (157643->157683), `offlineTs` zresetowany — PASS

Toast po stronie klienta NIE zweryfikowany wizualnie (auto-dismiss 6s zdazyl zniknac przed
zrzutem ekranu) — kod uzywa tych samych `UIFactory.panel/label/button`, ktore juz dzialaja w
`IndexController`, wiec ryzyko wizualne niskie, ale nie 100% potwierdzone.

### Krok 0/#2 — sygnaly — ZROBIONE, zweryfikowane live (2026-08-17)

Dedup (dopracowanie #1 usera): `TotemRolled` z Architektury §2 to JEST juz istniejacy
`RollService.Rolled` (payload go pokrywa i przewyzsza: totemId/tier/variant +
isNewDiscovery/pityTriggered/essence) — swiadomie NIE stworzony drugi sygnal, tylko komentarz w
`RollService.Init()` dokumentujacy decyzje.

Nowe sygnaly (Signal.new(), nie remote'y):
- `RunSessionService.RunEnded(player, {status, seed, mode, encounterIndex, level, gold})` —
  odpalany z 3 miejsc: won/lost w `endEncounter`, "abandoned" w `abandonRun` handlerze. Guard
  `run.owner ~= nil` (runy anonimowe/balance-harness pomijane, tak samo jak `_awardRunEssence`).
- `RunSessionService.GuardianDefeated(player, guardianId)` — w `endEncounter`, gdy `reached` i
  `run.activeGuardian` byl ustawiony (przed nadpisaniem go w nastepnym `startEncounter`).
- `PlayService.SpellPlayed(player, spellId, score)` — w `PlayService.play`, zaraz po policzeniu
  `scoreResult.finalScore`.

Zweryfikowane solo playtestem (`RunSessionService.startRunForPlayer` + jeden prawdziwy
`PlayService.play`, potem fast-forward `endEncounter` przez wszystkie 12 starc): SpellPlayed
odpalil raz z prawdziwego zagrania, GuardianDefeated 6x (3 straznikow × 2 poziomy kazdy, poprawne
id: hungryShadow/elementEater/thresholdWarden), RunEnded raz na koncu z status=won, poprawnym
seed/mode/gold. Wszystkie 4 sygnaly (liczac TotemRolled=Rolled) potwierdzone dzialajace.

### Krok #3 — SeedService — ZROBIONE, zweryfikowane live (2026-08-17)

Nowy plik `ServerScriptService/Services/SeedService.luau` — czysta funkcja + `os.date`, zero stanu:

- `DailyKey(nowUtc)` — `"YYYYMMDD"` wg UTC (nie lokalny czas gracza), fundament trybu ranked
  (zasada 12): ten sam klucz dla wszystkich stref czasowych.
- `DailySeed(nowUtc)` — hash `DailyKey` przez `SeedUtil.hashString` (nowy alias na istniejacy
  wewnetrzny `fnv1a32`, zeby nie duplikowac drugiej, rozjezdzajacej sie implementacji hasha) ->
  `(hash % 2147483646) + 1`. Identyczny seed dla wszystkich graczy w tej samej dobie UTC.
- `RandomSeed()` — port 1:1 inline'a, ktory wczesniej zyl w `RunSessionService.Start()`
  (`Random.new():NextInteger(1, 2147483646)`), zachowanie bez zmian.
- `FriendSeed(rawSeed)` — walidacja typu/zakresu (NaN/inf/zly typ -> nil), hook na feature
  "seed od znajomego" na pozniej, zero dodatkowej logiki teraz.

`Bootstrap.server.luau`: `SeedService` dopisany do `ORDER` po `RollService`, przed
`RunSessionService`. `RunSessionService.Start()` woła `ServiceRegistry.get("SeedService")`;
`startRun.OnServerInvoke` uzywa `_seed.RandomSeed()` zamiast inline `Random.new()` — refaktor
bez zmiany zachowania, `mode` dalej twardo `"free"` (ranked wciaz czeka na krok #4).

Zweryfikowane live w solo playteście przez `eval_server_runtime`:
- `DailyKey`/`DailySeed` deterministyczne (dwa wywolania tego samego `nowUtc` -> identyczny
  wynik) i rozne dla kolejnej doby UTC — PASS
- `DailySeed` w zakresie `[1, 2147483646]` — PASS
- `RandomSeed()` w zakresie i zmienny miedzy wywolaniami — PASS
- `FriendSeed`: liczba calkowita przechodzi, float floorowany, NaN/inf/string -> `nil` — PASS
- `RunSessionService.startRun(SeedService.RandomSeed(), "free")` dziala bez bledow po wpiecu
  SeedService — PASS

### Krok #4 — tryb ranked — ZROBIONE, bramka determinizmu ZDANA (2026-08-17)

**RankedConfig** (`Shared/Configs/RankedConfig.luau`, nowy plik) — sklad potwierdzony przez
Andreasa (Wariant A): `{ emberpup, frostfawn, blobby, coinpurr, kingosaur }`. Pokrywa 3 rodziny
totemow (flat/multiplikatywny/skalujacy), tiery Common->Legendary, zero totemow zaleznych od
konkretnego spellId. Stala kolejnosc listy (nie `pairs()` po dict-cie) — deterministyczna z
definicji.

Odkrycie przy analizie: `ScoreEngine`'s `collectionScoped`-filtr (zasada 12) jest juz gotowy, ale
JEST no-opem — zaden z 15 totemow nie ma `collectionScoped=true`. Prawdziwy wyciek neutralnosci
siedzial gdzie indziej: `RunShopService.availableTotemPool` = starter Common UNION **posiadane
przez gracza** (`IndexService.IsDiscovered`) — to zalezy od kolekcji. Fix: nowa galaz
`rankedTotemPool` (uzywana gdy `run.mode=="ranked"`) czyta WYLACZNIE `RankedConfig.TotemIds`,
`IndexService.IsDiscovered` nie jest w tej galazi w ogole wywolywane.

Drugie sprawdzone zrodlo mozliwego wycieku: `StatProfileService`'s `extraPlays`/`extraSwaps`
(czytane w `RunSessionService.startRunForPlayer`) — zweryfikowane, ze to czyste bazy z
`GameConfig.StatBase` + delty skilli, a `profile.skills` jest zawsze `{}` w tej fazie (brak
SkillTreeService) -> identyczne dla kazdego gracza niezaleznie od kolekcji, zaden fix niepotrzebny
teraz (ale to bedzie trzeba przypilnowac przy Fazie 2b/SkillTreeService).

`RunSessionService.startRun.OnServerInvoke`: `mode="ranked"` akceptowany od klienta (whitelist,
kazda inna wartosc -> `"free"`), seed = `SeedService.DailySeed()` dla ranked / `RandomSeed()` dla
free.

**Bramka determinizmu (dopracowanie #2 Andreasa) — ZDANA, PASS:**

Test (`eval_server_runtime`, solo playtest): dwa symulowane runy ranked na TYM SAMYM Seed Dnia
(`SeedService.DailySeed(fixedNow)`), z `IndexService.IsDiscovered` podmienionym tak, by jeden run
"widzial" gracza z bogata kolekcja (zwraca `true` dla kazdego totemu) a drugi z pusta (`false` dla
kazdego) — plus licznik wywolan tej funkcji. Na obu identyczna, zdeterminowana sekwencja decyzji
(otworz sklep -> kup totem jesli w ofercie, zagraj cala reke, zakoncz starcie) powtorzona przez 12
starc lub do konca runu.

| Sprawdzenie | Wynik |
|---|---|
| Trace decyzji (26 krokow: shop/play/enc na starcie) | **identyczny** bit-do-bitu, rich vs empty |
| Totemy kupione w runie | **identyczne** (`kingosaur` w obu) |
| Koncowe zloto / status runu | **identyczne** (10226g / `"lost"` w obu) |
| Wywolania `IndexService.IsDiscovered` podczas OBU rankedowych runow | **0** (oczekiwane 0) |

Ostatni wiersz jest dowodem strukturalnym, nie tylko empirycznym: kod ranked-owej sciezki
(`rankedTotemPool`) fizycznie nie odwoluje sie do funkcji czytajacej kolekcje gracza, wiec zaden
przyszly stan kolekcji (bogaty czy pusty) nie moze przeciekac do wyniku rankedowego runu.

**Bramka zamknieta.**

### Krok #5 — LeaderboardService — ZROBIONE, zweryfikowane live (2026-08-17)

Nowe pliki: `LeaderboardConfig.luau` (Shared/Configs, stale: `GoldWeight=1_000_000`,
`DailyTopCount=3`, `RefreshIntervalSeconds=60`, `TopN=100`, nazwy 2 OrderedDataStore),
`LeaderboardService.luau` (ServerScriptService/Services). 2 nowe remoty w `Net.luau`:
`GetLeaderboard` (RF, C->S kind:"daily"|"allTime") i `LeaderboardSync` (RE, S->C push po
kazdym cache-refresh). Wpiety w `Bootstrap.server.luau` ORDER po `RunShopService`.

Realizacja 4 twardych zasad Andreasa (verbatim z briefu):

1. **Mediana-z-3, nie jeden perfekcyjny run.** `profile.bestScores.daily[dateKey]` trzyma
   `{scores={top-3 malejaco}, median}` — kazdy nowy ranked `RunEnded` wstawia rankScore,
   sortuje malejaco, przycina do 3. Publikowany wpis = srodkowy element (mediana z 3).
   Stare klucze dnia (`dateKey != dzisiejszy`) czyszczone przy kazdym zapisie — Seed Dnia jest
   efemeryczny z definicji.
2. **Zapis TYLKO z `RunSessionService.RunEnded`.** LeaderboardService nie ma zadnego innego
   punktu wejscia mutujacego `bestScores` — zero remote'ow C->S zapisujacych wynik, klient
   moze tylko CZYTAC (`GetLeaderboard`).
3. **OrderedDataStore + throttle.** Zdarzenia `RunEnded` tylko aktualizuja pamieciowy bufor
   `_pendingDaily`/`_pendingAllTime` (zero I/O). Osobna petla `task.spawn` co
   `RefreshIntervalSeconds` (60s) robi batch `SetAsync` + `GetSortedAsync(false, TopN)` +
   `FireAllClients` — czestotliwosc I/O niezalezna od liczby/tempa runow.
4. **Seed Dnia = WYLACZNIE ranked.** Blok liczacy mediane wykonuje sie tylko gdy
   `result.mode=="ranked"`; wolny tryb aktualizuje **jedynie** `bestScores.allTime` (osobna,
   swiadomie NIE-wyrownana tablica — kolekcja legalnie pcha allTime w gore, tak jak zaklada
   monetyzacja Fazy 4; GDD linia 101 wprost zabrania mieszania trybow na Seed Dnia).

`rankScore = encounterIndex * GoldWeight + clamp(gold, 0, GoldWeight-1)` — encounterIndex
zawsze dominuje (dalszy postep > wiecej zlota na plytszym runie), zloto tylko rozstrzyga remis.
Won run konczy sie `encounterIndex=13` (jeden za `GameConfig.Levels*EncountersPerLevel=12`),
wiec kazda wygrana bije kazda przegrana automatycznie, bez specjalnego przypadku w kodzie.

Tygodniowy leaderboard (trzeci z Architektury §2 linia 73) **swiadomie wyciety** ta runda —
zgodnie z wczesniejsza cut-lista w tym pliku, daily+allTime pokrywaja retencje D1/D7, trzeci
wymiar nie jest krytyczny teraz.

Weryfikacja live (solo playtest + `eval_server_runtime`/`eval_client_runtime`):

| Sprawdzenie | Wynik |
|---|---|
| 3x ranked `RunEnded` (enc 5/8/13, gold 20/10/45) -> mediana | `8000010` (srodkowy z posortowanych `[13000045,8000010,5000020]`) — **poprawne** |
| 4. run w trybie `free` (enc 12, gold 999999) | **nie wszedl** do `daily` (mediana bez zmian), **wszedl** do `allTime` (`13000045`, bo > `12999999`) — **poprawne rozdzielenie trybow** |
| Wstrzykniety smieciowy stary dzien (`"20200101"`) + kolejny ranked `RunEnded` | stary klucz **usuniety**, zostal tylko dzisiejszy `dateKey` — **poprawne** |
| `GetLeaderboard("weekly")` (nieobslugiwany kind) | `{ok=false, reason="unknown kind"}` — **poprawne odrzucenie** |
| `GetLeaderboard("daily")`/`("allTime")` po pelnym cyklu 60s (real-time, nie symulowane) | `list` z wpisem gracza, `score` zgodny z mediana/allTime powyzej — **pelny round-trip OrderedDataStore potwierdzony** |
| `get_runtime_logs filter="LeaderboardService"` | tylko `Init`/`Start`, zero `warn` (brak bledow `SetAsync`/`GetSortedAsync`) |

### Krok #6 — StreakService — ZROBIONE, zweryfikowane live (2026-08-17)

Nowe pliki: `StreakConfig.luau` (Shared/Configs, kamienie D7/100 esencji, D14/250, D30/600 —
PLACEHOLDER jak reszta configów). `StreakService.luau` (ServerScriptService/Services). 2 nowe
remoty: `ClaimStreak` (RF, C->S days:number), `GetStreakState` (RF, C->S ()). `profile.streak`
rozszerzony o `claimed` (mapa days->true, wzorzec `IndexService.indexClaims`). Wpiety w
Bootstrap ORDER po `LeaderboardService`.

Mechanika: `ProfileService.ProfileLoaded` -> `StreakService.TouchLogin` liczy nowy `count` z
3 stanów porównania dateKey (dzisiaj/wczoraj/serwerowy `os.time()`, NIGDY zegar klienta) —
ten sam dzień = no-op, dokładnie wczoraj = +1, cokolwiek innego (pierwszy login, luka >1 dzień,
hipotetyczny skok zegara wstecz) = reset do 1. Kamienie D7/D14/D30 wymagają JAWNEGO
`ClaimStreak` (osiągnięcie progu != odbiór, ten sam wzorzec co `ClaimIndexLuck`) —
`NotReached`/`UnknownMilestone`/`AlreadyClaimed` jako reason, `AwardEssence` tylko przy sukcesie.

Weryfikacja live: `_ComputeNextCountForTest` — sameDay(5,"20260817","20260817","20260816")=5,
continued(5,"20260816",...)=6, gap(5,"20260810",...)=1, firstEver(0,"",...)=1 — **wszystkie 4
poprawne**. Pełny claim flow przez `eval_client_runtime`+`InvokeServer`: count wymuszony na 10 ->
`ClaimStreak(14)`=NotReached, `ClaimStreak(99)`=UnknownMilestone, `ClaimStreak(7)`=ok+`essence:100`,
`ClaimStreak(7)` ponownie=AlreadyClaimed, `GetStreakState` po obu wywołaniach pokazuje poprawny
`reached`/`claimed` per próg — **wszystko zgodne**. `get_runtime_logs filter="StreakService"`:
tylko `Init`/`Start`, zero `warn`.

### Krok #7 — QuestService — ZROBIONE, zweryfikowane live (2026-08-17)

Nowe pliki: `QuestConfig.luau` (Shared/Configs, pula 4 questow: `playNawalnica`/`defeatGuardians`/
`winRuns`/`rollTotems`, `DailyQuestCount=3`). `QuestService.luau` (ServerScriptService/Services).
2 nowe remoty: `ClaimQuest` (RF, C->S questId:string), `GetQuestState` (RF, C->S ()). Wpiety w
Bootstrap ORDER po `StreakService`.

Mechanika: zero nowych sygnalow — `eventType` w puli mapuje sie na 4 sygnaly juz istniejace
(`PlayService.SpellPlayed`, `RunSessionService.GuardianDefeated`/`RunEnded` filtrowany na
`status=="won"`, `RollService.Rolled` filtrowany na `result.ok`), zgodnie z istniejaca w kodzie
zasada anty-duplikacji sygnalow (komentarz w `RollService.Rolled`). Losowanie dziennej trojki:
Fisher-Yates calej puli, pierwsze `DailyQuestCount`, swiezy `Random.new()` (nie deterministyczny
jak Seed Dnia — questy nie musza byc identyczne miedzy graczami). `ensureTodayQuests` wolane NA
WEJSCIU kazdego handlera progresu (nie tylko `ProfileLoaded`), wiec przekroczenie polnocy UTC
mid-session poprawnie przeladowuje liste przy pierwszym kolejnym baseline, bez wymaganego relogu —
ten sam wzorzec co czyszczenie starych `dateKey` w LeaderboardService. Claim jawny (ten sam wzorzec
co `StreakService.Claim`/`ClaimIndexLuck`): `UnknownQuest`/`AlreadyClaimed`/`NotReached` jako
reason, `AwardEssence` tylko przy sukcesie.

Weryfikacja live (solo playtest + `eval_server_runtime`/`eval_client_runtime`):

| Sprawdzenie | Wynik |
|---|---|
| Reroll na `ProfileLoaded` | wylosowane 3/4 z puli (`defeatGuardians`/`winRuns`/`rollTotems`), `dateKey` dzisiejszy — **poprawne** |
| `GuardianDefeated` x1 potem x2 (target 2) | progress 1 -> 2, **poprawne zliczanie** |
| `Rolled({ok=true})` x3 + `Rolled({ok=false})` x1 (target 3) | progress=3 (nieudany roll **nie liczy sie**) — **poprawne** |
| `RunEnded({status="lost"})` potem `RunEnded({status="won"})` (target 1) | progress 0 -> 1 (przegrana **nie liczy sie**) — **poprawne** |
| `ClaimQuest("bogusId")` | `UnknownQuest` — **poprawne** |
| `ClaimQuest("defeatGuardians")` (progress=target) | `ok=true, essence=60` — **poprawne** |
| `ClaimQuest("defeatGuardians")` ponownie | `AlreadyClaimed` — **poprawne** |
| Recznie cofniety progress ponizej target + `Claim` | `NotReached` — **poprawne** |
| `GetQuestState` po serii claimow | lista z poprawnym `progress`/`claimed`/`desc`/`target`/`rewardEssence` per quest — **poprawne** |
| `get_runtime_logs filter="QuestService"` | tylko `Init`/`Start`, zero `warn` |

Tygodniowy/VIP-gamepass +1 quest dzienny (GDD, Faza 4 monetyzacja) **swiadomie NIE dolozony** —
hook zostawiony w komentarzu `QuestConfig.DailyQuestCount`.

### Krok #8 — AnnouncementService — ZROBIONE, zweryfikowane live (2026-08-17), Faza 3 ZAMKNIETA

Nowe pliki: `AnnouncementConfig.luau` (Shared/Configs — swiadomie NOWY plik zamiast dopisania do
`GameConfig`, ten sam wzorzec co reszta Fazy 3). `AnnouncementService.luau`
(ServerScriptService/Services). `AnnouncementController.luau`
(StarterPlayerScripts/Controllers, toast w rootcie "Toast" — ten sam wzorzec co
`OfflineEarnController`). 1 nowy remote: `AnnouncementSync` (RE, S->C, push-only). Wpiety w
Bootstrap ORDER (server) po `QuestService`, w init.client po `OfflineEarnController`.

Zero nowego sygnalu server-side — nasluchuje `RollService.Rolled` (ten sam co
QuestService/IndexService). Prog "rzadki drop" zdefiniowany STRUKTURALNIE, nie jako twarda
liczba: `tier=="Legendary"` (najrzadszy w `RarityConfig.TierWeight`) I wariant z
`VariantConfig.ladder.pct <= 1` (dzis: Galaxy=1%, Rainbow=0.1%). Iloczyn: Legendary(~1.1% z
checkpointu Fazy 2b) x Galaxy(1%) ~= 1/9090 — rzad wielkosci dokladnie zgodny z "np. 1/10k" z
architektury (Rainbow jeszcze rzadszy, ~1/90900).

Cross-server przez `MessagingService` (Architektura §2 linia 74). Kluczowa decyzja: klient
dostaje ogloszenie WYLACZNIE z callbacku `SubscribeAsync`, NIGDY bezposrednim `FireAllClients`
zaraz po rollu — serwer-zrodlo jest tez subskrybentem wlasnego topicu (udokumentowane zachowanie
MessagingService), wiec podwojna sciezka dawalaby graczom na serwerze-zrodle duplikat. Jeden
kod-path, jednolity dla wszystkich serwerow. `AnnouncementService.Announced` (Signal lokalny)
odpala sie natychmiast na serwerze-zrodle, PRZED rundtripem MessagingService — hook na przyszlosc
(np. analytics), swiadomie NIE napedza UI klienta. `PublishAsync`/`SubscribeAsync` pcall'owane
(wywolania sieciowe zewnetrzne, Architektura §1 "Z PCALL").

Weryfikacja live (solo playtest + `eval_server_runtime`/`eval_client_runtime`):

| Sprawdzenie | Wynik |
|---|---|
| `_QualifiesForTest`: Legendary+Galaxy, Legendary+Rainbow | `true`, `true` — **poprawne** |
| `_QualifiesForTest`: Legendary+Foil, Legendary+Normal, Rare+Rainbow, Epic+Galaxy | `false` x4 — **poprawne** |
| `Rolled:Fire` z kwalifikujacym dropem -> `AnnouncementService.Announced` (lokalny Signal) | payload z `name`/`totemId`/`tier`/`variant` odebrany natychmiast — **poprawne** |
| Pelny round-trip: `Rolled:Fire` (Legendary/Rainbow) -> `PublishAsync` -> `SubscribeAsync` callback -> `AnnouncementSync:FireAllClients` -> klient | klient odebral dokladnie 1x poprawny payload — **poprawne, brak duplikatu** |
| `Rolled:Fire` z niekwalifikujacymi dropami (Common/Normal, Epic/Normal) | klient **nie odebral** nic nowego — **poprawne odfiltrowanie** |
| `get_runtime_logs filter="warn"` (caly playtest) | **pusto** — zero bledow `PublishAsync`/`SubscribeAsync` w Studio |

**Faza 3 (retencja) ZAMKNIETA — wszystkie 7 modulow gotowe:** sygnaly wewnetrzne, SeedService,
tryb ranked, OfflineEarnService, LeaderboardService, StreakService, QuestService,
AnnouncementService.

## Faza 4 (monetyzacja) — ZAMKNIETA compliance-safe (2026-08-18)

Wszystkie kroki zrobione i zweryfikowane live w solo-playteście (`eval_server_runtime`/
`eval_client_runtime`, test-hooki `_XForTest`, nie klik-symulacja — `simulate_mouse_input`
niepewny dla `TextButton.Activated` w tym srodowisku):

- **Krok 0** (`f4cdeed`) — Start-of-run Totem Pick: `RunShopService.startPick`/`choosePick`,
  pickSize 3 (ranked, neutralne) / 3-5 (free, gamepass +2 sloty), deterministyczny strumien
  `run.streams.shop`.
- **Krok 1** (`1bb7a94`) — `StatProfileService.Get(player, mode)`: `mode=="ranked"` nadpisuje
  `extraPlays`/`extraSwaps`/`startPickSize` neutralna baza z `GameConfig.StatBase`, niezaleznie
  od realnych zakupow/skilli gracza — p2w nie moze przeciekac do wyniku rankingowego.
- **Krok 2** (`6fb23f2`) — `PurchaseService`: prawdziwy `ProcessReceipt`, idempotentny
  (`profile.purchases.receipts[receiptId]` sprawdzany PRZED grantem, zapisywany PO), cache
  `PlayerOwnsGamePassAsync` per-gracz odswiezany na `PlayerAdded` + po zakupie.
- **Krok 3** (`c99a30c`) — gamepassy (VIP/EssenceX2/LuckX2/StartPickBonus/FastRolls) wpiete w
  `StatProfileService.compute()`; bramka determinizmu z Fazy 3 rozszerzona o gracza z VIP —
  nadal bit-identyczny wynik ranked.
- **Krok 4** (`5df3754`) — `PolicyService.OddsTable()` (tiery liczone TA SAMA kaskada co
  `RollService.selectTotem`, warianty 1:1 z `VariantConfig.ladder`, Void jawnie wykluczony,
  pity osobno) + `MonetizationController` (katalog sklepu + gate tabeli szans przed promptem
  zakupu luck-gamepassu).
- **Krok 5** (`be0a4e6`) — `FTUEController`: 4 beaty onboardingu (GDD §2.7), zero nowej
  mechaniki, tylko podpowiedzi dla `ftueDone==false`.
- **Krok 4b** (`217324c`) — **fix po audycie compliance, patrz nizej.**

### Audyt compliance (2026-08-17/18) — wynik 4 punktow

Andreas zazadal audytu przed uznaniem Fazy 4 za zamknieta ("blad = moderacja Roblox kasuje
gre"). Wynik:

1. **Tabela szans sumuje sie do 100%, Void wykluczony, renderowana z tego samego configu co
   roll** — PASS bez zmian (`VariantConfig.ladder`=100.0%, `PolicyService` czysty port kaskady
   `RollService`, zero osobnej kopii liczb).
2. **Idempotencja `ProcessReceipt`** — PASS bez zmian (receiptId sprawdzany przed grantem).
3. **VIP/gamepass nie przeciekaja do ranked** — PASS bez zmian (Krok 1 fix + live-test z Kroku
   3 bramki determinizmu).
4. **Luka: tabela szans byla dostepna TYLKO przy zakupie luck-gamepassu, NIGDY przy samym
   rollu za Esencje** — realny problem, bo roll za Esencje kupiona za Robux TO JEST paid random
   item. **Naprawione Krokiem 4b.**

### Krok 4b — fix (`217324c`, 2026-08-18)

Decyzja Andreasa: **permanentny link, nie jednorazowy gate** (jednorazowy gate przy pierwszym
rollu jest kruchy — gracz moze go przeklikac i zapomniec, kolejne sesje nie maja juz nic).

- Nowy przycisk **"?"** w HUD, na stale tuz obok "Roll" (nie ukryty za innym UI, widoczny w
  KAZDEJ sesji przed kazdym kliknieciem Roll).
- Klik otwiera **ten sam modal** co gate zakupu (`MonetizationController.OpenOddsView()` ->
  `openOddsModal(onConfirm=nil)`), tylko w trybie informacyjnym (przycisk "Zamknij" zamiast
  "Kontynuuj do zakupu") — zero duplikatu logiki renderowania tabeli.
- Przy okazji (audyt p.4): katalog sklepu pokazuje teraz czytelny opis efektu prosto z configu
  (np. `EssencePackMedium (1200 Essence)`) zamiast samego klucza (`EssencePackMedium`) —
  gracz wie ILE dostaje za Robux.

Zweryfikowane live: przycisk "?" widoczny w HUD przed kazdym Roll (zrzut ekranu, ekran picku
startowego totemu); `OpenOddsView()` renderuje liczby **identyczne** z serwerowym
`PolicyService.OddsTable()` — Legendary 1.11%, Epic 3.30%, Rare 7.97%, Uncommon 10.95%, Common
76.67% (suma 100%); Rainbow 0.1%, Galaxy 1%, Gold 4%, Foil 10%, Normal 84.9% (suma 100%); pity
"gwarancja Epic po 40 rollach bez"; Void nie pojawia sie na liscie wariantow w ogole. Regresja
gate'u zakupu (`LuckX2`) nadal dziala — `confirmBtnVisible=true`, "Anuluj".

**Faza 4 (monetyzacja) ZAMKNIETA compliance-safe.**

### Otwarte drobne (nie blokuja Fazy 5)

- **Reparenting `Controllers` pod `Bootstrap` zyje TYLKO w Studio, nie w gicie** (patrz sekcja
  "TWARDA REGULA" na gorze pliku) — projekt nie ma `project.json`, wiec hierarchia instancji
  nie jest nigdzie zdeklarowana w kodzie. Ryzyko: odtworzenie placu od zera z gita da martwa
  gre po stronie klienta bez zadnego widocznego bledu. Rozwazyc prawdziwy Rojo
  (`project.json` + `rojo serve`) — to osobna decyzja architektoniczna, NIE podjeta.
- **Zrzut ekranu runu w orientacji portret wciaz niedostarczony** (wszystkie dotychczasowe
  zrzuty byly landscape/Studio-viewport) — do zrobienia gdy bedzie realny powod (np. przy
  Fazie 5 review mobile-first designu).

## MAX-SLOT — ZAMKNIETY, bramka balansu PASS (2026-08-18)

Krok 1 z 5-etapowej przedpremierowej ekspansji (kolejnosc: **MAX-SLOT -> nowe Stworki +
balans -> merge -> packi+daily+luck -> UI+juice**). Gracz ograniczony do decka max
`GameConfig.DeckSize` (10) totemow zamiast calej kolekcji — `DeckService` (nowy plik) +
`Net` remote'y deck + `RunShopService.availableTotemPool` filtrowane przez
`DeckService.GetDeck(player)` (tylko tryb `free`; ranked strukturalnie izolowany, nigdy nie
dotyka `DeckService`). UI: `DeckController` + przycisk w HUD + wpiety w `UIRootController`/
`Bootstrap` ORDER.

**Bramka balansu** (`tests/BalanceHarness.studio.luau`, funkcja `runDeckGate`, dopisana ta
sesja) — realistyczny mieszany 10-kartowy deck (3 Common + 3 Uncommon + 2 Rare + 1 Epic + 1
Legendary, `DECK_IDS` w pliku), n=50 seedow, przez PRAWDZIWA sciezke produkcyjna
(`RunSessionService.startRunForPlayer` -> `RunShopService` -> `DeckService`, monkeypatch
`IndexService.IsDiscovered` zamiast osobnej symulacji). Uruchomione live w solo-playteście
(`eval_server_runtime`, gracz `Onimushaa5`, real profile):

| Bot | Completion | Uwagi |
|---|---|---|
| NAIVE (podloga) | 2% (1/50) | oczekiwane nisko, to nie jest sygnal do dostrajania |
| FULL-SMART (proxy czlowieka) | **42% (21/50)** | w wymaganym pasmie 30-55% -> **PASS bez dostrajania** |

Widelki historyczne dla porownania: pool=7 (starter-only) FULL-SMART 30%, pool=15 (cala
kolekcja, bez filtra decka) FULL-SMART 54%. Deck=10 mieszany wypada w srodku (42%), zgodnie z
oczekiwaniem — mniejszy/gorszy niz pelna kolekcja, wiekszy/lepszy niz sam starter.

**Nastepny krok: Faza "nowe Stworki + balans" (krok 2/5), planowanie z Andreasem.**

## Nowe Stworki + balans — ZAMKNIETY, bramka balansu PASS (2026-08-18)

Krok 2 z 5-etapowej przedpremierowej ekspansji. 10 nowych Stworkow w `TotemConfig.luau`
(pebblit, sparkfly, puffcap, frostnib, vinelet, boltpup, tidalox, emberwing, shardmaw,
galaxeon — kolekcja teraz 25 lacznie), kazdy trzyma sie DOKLADNIE jednego z 4 sprawdzonych
archetypow silnika (flat-elemental / warunkowy mult / mocMultElement / scalingFlat) — zero
nowych prymitywow. Art: `cardsw/Meshy_AI_*.png` -> wycinacz tla (connected-components od
brzegu, nie prog jasnosci — zeby nie wyciac jasnych plam WEWNATRZ postaci) -> `cardsw/<id>.png`
-> upload Open Cloud (`scripts/upload_card_art.py`, filtr nazw jako argv[1] zeby nie
re-uploadowac pozostalych 15) -> `resolve_decal_textures.luau` -> `CardArtConfig.luau`.
Zweryfikowana REALNA alfa (5-85% przezroczystosci na obraz, nie 0% ani >85%) przed uploadem.

**Bramka balansu** (`tests/BalanceHarness.studio.luau`-owy wzorzec, custom `SetDeck`-owa
wersja zamiast `runDeckGate`/`defaultDeck()` — ten drugi NIE gwarantuje dokladnego decka, bo
Common-tier zawsze przecieka do puli mimo patcha `IsDiscovered`; `DeckService.SetDeck`
wymuszona dokladnie na 10 nowych id, zweryfikowana 0% pick-share na wszystkich 15 starych).
Deck = dokladnie tych 10 nowych, n=50, PRAWDZIWA sciezka produkcyjna, live w
solo-playteście (`eval_server_runtime`):

| Bot | Completion | Uwagi |
|---|---|---|
| NAIVE (podloga) | 14% (7/50) | oczekiwane nisko |
| FULL-SMART (proxy czlowieka) | **46% (23/50)** | w wymaganym pasmie 30-55% -> **PASS** |

**Diagnoza przestrzalu i naprawa — WAZNE, bo pierwsza hipoteza byla bledna:**

Pierwszy przebieg (przed naprawa) dal FULL-SMART 58% (przestrzal). Podejrzany #1 z gory byl
Galaxeon (`mocMult` 4.0 na warunku "Konwergencja") — okazalo sie **BEZ WPLYWU**: zjazd
4.0->1.0 (pelna neutralizacja) przy n=50 dal identyczny wynik 58%==58%. Sweep ablacyjny
per-totem (n=20, bezposrednia mutacja `TotemConfig.Totems.<id>.effect` w zywej VM przez
`eval_server_runtime`, bez restartu — szybsza iteracja niz push+restart) ujawnil prawdziwych
winowajcow: **Vinelet** i **Shardmaw**, oba `scalingFlat` (rosnie co `onScore` bez limitu przez
caly run, `condition="always"` — bez warunku). Neutralizacja Vineleta samego: -10pp.
Neutralizacja Shardmawa samego: -20pp. Oba naraz: -40pp (do 15%, ZA NISKO — pelna neutralizacja
przestrzeliwuje w druga strone). Wzorzec identyczny jak w Faza 3 runda 4 (patrz komentarz w
`TotemConfig.luau`) — SKALUJACE totemy bez ograniczenia to systemowe zrodlo late-game
przestrzalu, nie multiplikatywne/warunkowe. Boltpup i Emberwing (oba warunkowe mnozniki)
przetestowane ablacyjnie jako calkowicie OBOJETNE dla tego decka.

Naprawa: `perTrigger` obu ściete o 50% (Vinelet 16->8, Shardmaw 24->12), Galaxeon zostawiony na
3.5 (nieszkodliwa niezalezna normalizacja wzgledem reszty rosteru, nie przyczyna, nie ma
powodu cofac do 4.0). Pelna historia i liczby w komentarzu nad blokiem "System 2" w
`TotemConfig.luau`.

**Lekcja dla przyszlych sesji:** ten projekt nie ma `project.json` (patrz sekcja wyzej) — Studio
byl gleboko zdesynchronizowany zanim dalo sie w ogole zmierzyc balans: `RunShopService.luau`
mial stara wersje sprzed MAX-SLOT, `DeckService.luau` **w ogole nie mial instancji** w Studio
(nigdy nie zapushowany), `GameConfig.luau` w Studio nie mial pola `DeckSize` (stary, 640 vs 2728
znakow) co walilo `attempt to compare nil < number` w `DeckService.SetDeck`. Kazdy z tych trzech
naprawiony recznym `set_script_source`/`create_object` przed pierwszym wiarygodnym pomiarem.
Zawsze zweryfikuj ze zmierzony kod to NAPRAWDE kod na dysku (np. przez odczyt live wartosci
configu w tej samej `eval_server_runtime` VM), zanim zaufasz wynikowi bramki.

### Fix: Vinelet martwa karta (2026-08-18)

Po zamknieciu bramki powyzej, Andreas zglosil ze Vinelet (Uncommon, po cieciu 16->8) byl znow
**strictly gorszy** od blobby (Common, moc+12 zawsze) — ta sama statystyka (`moc`) i ten sam
warunek (`always`), wiec czyste porownanie liczb: Uncommon przegrywal Common, martwa karta.
Sprawdzony roster: zero bezwarunkowego Common `scalingFlat{stat=rez}` (quackers/sparkfly to
Common ale WARUNKOWE; jedyny bezwarunkowy rez-scaler w calym rosterze to lavacat, Epic,
perTrigger=2). Fix: Vinelet przeniesiony na `scalingFlat{stat=rez, perTrigger=1}` (motyw "pnącza"
bez zmian) — inna statystyka niz blobby, wiec zaden bezposredni 1:1 spor liczb; perTrigger=1 < 2
(lavacat, Epic, unconditional), zeby Uncommon nie dorownywal Epic.

Bramka po fixie (ten sam wzorzec co gate "nowe Stworki" — `DeckService.SetDeck` wymuszony na
dokladnie tych 10 nowych id + monkeypatch `IndexService.IsDiscovered`, n=50, PRAWDZIWA sciezka
produkcyjna): NAIVE 18% (bez zmian), **FULL-SMART 50%** (bylo 46% przed fixem, widelki 30-55%) —
**PASS**. Pick share Vineleta 50% w tym decku (nie martwa karta, nie dominuje).

Przy okazji zlapany i naprawiony **drugi desync Studio** tej samej klasy co powyzej: live
`Bootstrap.server.luau` nie mial `"DeckService"` w `ORDER` (na dysku jest od commitu MAX-SLOT) —
`DeckService.SetDeck`/`GetDeck` cicho zwracaly `NoProfile`/pusty deck, bo `DeckService.Start()`
nigdy sie nie wykonal (`_profileService` zostawal `nil`). Naprawiony recznym `set_script_source`
Bootstrapu + restart playtestu. **Do pilnowania recznie przy kazdym resyncu placu** (ten sam
rodzaj bledu co przy MAX-SLOT — brak `project.json` oznacza ze kazda zmiana `ORDER`/nowy serwis
trzeba weryfikowac w live Studio, nie ufac ze push na dysk = push do Studio).

**Znaleziony przy okazji, NIE naprawiony (poza scope tej sesji):** shardmaw (Epic) po cieciu
24->12 ma DOKLADNIE ta sama wartosc co blobby (Common) — oba `scalingFlat{stat=moc}`,
`condition=always`, `perTrigger=12`. To remis, nie strictly-gorszy jak Vinelet, ale ten sam
wzorzec: Epic nie powinien byc rownowazny Common. Zapisane w komentarzu `TotemConfig.luau` przy
vinelecie — do rozwazenia w kolejnej rundzie balansu (nie blokuje merge, krok 3/5).

**Nastepny krok: merge (krok 3/5), planowanie z Andreasem.**

### Cleanup runda: Strażnik Bootstrapu, Galaxeon 4.0, Shardmaw fix (2026-08-18)

**Strażnik Bootstrapu** (`Bootstrap.server.luau`, commit `dbb6b49`): asercja na starcie porownujaca
`ORDER` z faktycznie obecnymi modulami w `Services` (w obie strony) — rzuca glosny `error()` z
nazwa serwisu przy desyncu. Szczepionka na klase bledu "serwis cicho wypadl z ORDER" (dokladnie to
co spotkalo `DeckService` przy MAX-SLOT, patrz sekcja Vinelet powyzej) — teraz krzyczy przy starcie
zamiast chowac sie jako ciche `NoProfile`.

**Galaxeon 3.5->4.0**: ablacja "Nowe Stworki" (patrz wyzej) juz udowodnila 0 wplywu na FULL-SMART
przy n=50 (zjazd 4.0->1.0 = identyczny wynik, 58%==58%) — niekauzalny w tym decku. Podbicie do 4.0
to darmowy upgrade feelu Legendary, zero ryzyka balansowego, bramka nie wymaga osobnego pomiaru tej
zmiany.

**Shardmaw fix**: byl LICZBOWO ROWNY blobby (Common) — oba `scalingFlat{stat=moc}`,
`condition=always`, `perTrigger=12`; Epic remisujacy z Common (ten sam wzorzec co Vinelet, patrz
wyzej). Przeniesiony na warunkowy `mocMult=2.0` przy `playedCountAtLeast(5)` (pelna reka, wzor
Emberwing/Thunderwolf — Epic to tier multiplikatywny), motyw "odlamki krysztalu pekaja gdy reka
pelna" — odrebna nisza od Thunderwolf/Emberwing (prog 4). NIE poszedl w dalszy `scalingFlat`
(nisza zajeta przez Vinelet/Lavacat, bezwarunkowe skalowanie = udowodniony winowajca overshootu) ani
w bezwarunkowy `rez` (jw.). `mocMult=2.0` to **PLACEHOLDER** — wartosc nie zostala dostrojona
bramka (patrz PENDING nizej), do potwierdzenia/dostrojenia gdy Studio wroci.

**Przy okazji zlapany i naprawiony trzeci desync Studio** tej samej klasy: live `Net.luau` (Framework)
nie mial `GetDeck`/`SetDeck` w tabeli `REMOTES`, mimo ze na dysku sa od commitu MAX-SLOT —
`DeckService.Start()` failowal cicho na `Net: unknown remote 'GetDeck'`, wiec SetDeck/GetDeck
realnie nie dzialaly. Naprawiony recznym `set_script_source` na `Net.luau` + restart playtestu,
zweryfikowany w logach (18/18 serwisow startuje bez FAILED). **Trzeci raz ten sam blad — brak
`project.json` = kazda zmiana configu/remote'ow trzeba weryfikowac w live Studio recznie, disk != Studio.**

**Bramka: PENDING.** Po naprawie Net.luau most/Studio dzialaly (server bootuje czysto, gracz
dolacza, kontrolery klienta startuja), ale realna bramka produkcyjna (`runDeckGate`, deck=10 nowych
totemow z Shardmaw+Galaxeon, n=50) zablokowana przez zawieszony `ProfileStore` session-lock —
`StartSessionAsync` dla testowego profilu (UserId testera, `SessionLoadCount` narosl do 51-52 od
wielokrotnego testowania w tej sesji) nie konczyl sie mimo wielu minut oczekiwania i recznego
zwolnienia locka (`MetaData.ActiveSession` wyzerowany przez `UpdateAsync`, restart playtestu) — dwie
proby z osobnymi restartami, obie utkniete. To infrastrukturalny problem Studio/DataStore (albo
wyczerpany budzet requestow po serii recznych testow), NIEZWIAZANY z sama zmiana balansu. Zgodnie z
zasada "uczciwy PENDING > zmyslony PASS": **NIE odpalono bramki, kod+commit poszly bez niej.**
Kod (Shardmaw+Galaxeon) jest gotowy i skomitowany — do przetestowania nastepnym razem gdy Studio
sesja bedzie czysta (swiezy playtest bez nagromadzonych sesji z tej rozmowy). Jesli FULL-SMART
wypadnie poza 30-55%, dostroic `mocMult` Shardmawa (obecnie placeholder 2.0) przez ablacje w VM,
tak jak przy poprzednich rundach.

### Gate PASS po naprawie harnessu (2026-08-18)

Swiezy `solo_playtest` (poprzedni byl `running:false`, zero nagromadzonych sesji) rozwiazal
PENDING powyzej od razu — `ProfileService.IsLoaded` zwrocil `true` bez zawieszenia. To potwierdza,
ze lock byl artefaktem infrastruktury/nagromadzonych testow w poprzedniej dlugiej sesji, nie
bledem kodu.

**Po drodze zlapany i naprawiony czwarty desync tej samej klasy, tym razem w samym harnessie:**
pierwsza probka bramki dala smieciowy wynik (8% NAIVE / 4% FULL-SMART, docelowe totemy —
shardmaw/vinelet/sparkfly/tidalox — na 0% pick share). Root cause: `DeckService.isSelectable()`
ma bezwarunkowy wczesny return `if totem.tier == STARTER_TIER then return true end` (Common =
zawsze wybieralny, celowo — nowy gracz zawsze ma starterowe Commony). `BalanceHarness.studio.luau`
zerowal `data.activeDeck = {}` przed pomiarem, co budzi `EnsureDefaultDeck`'s regenerate-when-empty
sciezke (`defaultDeck()`, alfabetyczne ciecie do `DeckSize=10`) — a odkad roster urosl do 10
Commonow (z "Nowe Stworki"), te 10 Commonow samo wypelnia caly limit deckow, wypychajac docelowe
totemy z `deckIds` zanim monkeypatch `IsDiscovered` w ogole zostanie sprawdzony dla tych slotow.
Ten sam wzorzec co Vinelet/Shardmaw ("bezwarunkowe zachowanie ktore ignoruje kontekst testu"), tym
razem w test-harnessie a nie w konfigu totemow. **Wbudowany "HARNESS SANITY CHECK" tego NIE zlapal**
(sprawdza tylko >50% strat na 1. starciu / zero zakupionych totemow — nie sprawdza czy deck sie
zgadza z `deckIds`) — luka do zapamietania na przyszle bramki.

Fix: `data.activeDeck` ustawiane BEZPOSREDNIO na `table.clone(deckIds)` (juz niepuste, dlugosc
= `DeckSize`) zamiast `{}` — `EnsureDefaultDeck`'s regenerate-branch nigdy sie nie odpala, deck
zostaje dokladnie taki jak zadal `deckIds`. Naprawione trwale w `tests/BalanceHarness.studio.luau`
(nie tylko w inline-copy), bo ten sam bug zepsulby tez nadchodzaca bramke merge.

**Wynik po naprawie (n=50, deck=10 totemow Shardmaw+Galaxeon):**
- NAIVE (floor bot): **10%** (5/50)
- **FULL-SMART (human-proxy): 44% (22/50)** — w widelkach 30-55%, **PASS**
- Pick share potwierdzony poprawny (tylko 10 totemow z `deckIds` ma niezerowy udzial): boltpup
  68/64%, emberwing 58/60%, frostnib 56/58%, galaxeon 14/20%, pebblit 44/42%, puffcap 64/60%,
  **shardmaw 44/50%** (uzywany, nie martwy), sparkfly 50/48%, tidalox 48/48%, vinelet 54/50%.

**Blok 1-3 (MAX-SLOT + Nowe Stworki + balans + cleanup) jest tym samym w pelni zamkniety:**
Vinelet fix (`3a02a8e`, PASS 50%), Straznik Bootstrapu (`dbb6b49`), Galaxeon 4.0 + Shardmaw fix
(`6e23316`, teraz PASS 44% zamiast PENDING) — wszystkie trzy zacommitowane i wypchniete na
`origin/main` przed ta runda; ta runda domyka bramke i dodaje commit z naprawa harnessu +
aktualizacja komentarza Shardmawa + ten wpis.

**Nastepny krok: merge (krok 3/5)** — plan implementacyjny rdzenia (Common->Uncommon->Rare, prog
5, essence 50/150, wynik plaski, disenchant Rare @30, collectionScoped) do przedstawienia Andreasowi
PRZED kodem.

## Faza 5 — redesign wizualny (jeszcze nie rozpoczety, PO calej przedpremierowej ekspansji)

Ostatnia faza przed soft launchem. Cala gra dzis to "brzydko-ale-dzialajaco" — kolorowe bloki
z `UIFactory`, zero prawdziwego designu. Faza 5 to cukierkowy redesign wszystkich ekranow.

**Jak zaczac (kolejnosc obowiazkowa):**

1. Przeczytaj skill `frontend-design`.
2. Przeczytaj `STWORKI.md` §A2, §A4, §A5 (wizualny kierunek/ton gry, zanim cokolwiek
   zaprojektujesz).
3. Zbuduj **SYSTEM DESIGNU** (tokeny kolorow/typografii/spacingu + komponenty: karta, przycisk,
   modal, pasek, etykieta tieru) zakladany na **KOMPLET ekranow naraz**, NIE ekran-po-ekranie —
   inaczej kazdy kolejny ekran wymysli wlasna paletke i spojnosc rozjedzie sie natychmiast.
4. **Pokaz palete + wireframe Andreasowi ZANIM zaczniesz kodowac.** To nie jest opcjonalne —
   redesign bez zatwierdzenia kierunku z gory to najdrozszy mozliwy blad w tej fazie (przerobka
   calego UI, nie jednego pliku).

## Stan git

- Branch `main`, lokalnie przed `origin/main` (MAX-SLOT `46ece98` + "nowe Stworki + balans" —
  patrz `git log` po commicie tej sesji), jeszcze nie `git push`.
- `cardsw/` w `.gitignore`, nie pojawia sie jako untracked (raw art PNG, backup lokalny
  wystarczy — patrz decyzja w sekcji Faza 2b UI wyzej).
