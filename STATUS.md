# STATUS — Roll a Rune

Ostatnia aktualizacja: 2026-08-18, fix compliance odds-bug (PolicyService vs RollService rozjazd)
— patrz sekcja "Odds-bug fix (compliance, 2026-08-18)" ponizej. Blokowal System 4 (packi), teraz
odblokowany, ALE packi wciaz czekaja na decyzje Andreasa o strukturze tabel (patrz
PACKS_PLAN_PROPOSAL.md) — NIE zaczynac kodu paczek bez tego. Poprzedni wpis: System 3 (Merge/
Craft) zbudowany i zamkniety. Czytaj to + `git log` zamiast polegac na pamieci poprzedniej sesji.

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
