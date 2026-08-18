# STATUS — Roll a Rune

Ostatnia aktualizacja: 2026-08-18, koniec sesji MAX-SLOT (krok 1/5 przedpremierowej
ekspansji, bramka balansu PASS). Czytaj to + `git log` zamiast polegac na pamieci poprzedniej
sesji.

## Gdzie jestesmy (skrot dla nastepnej sesji)

**Fazy 1-4 zrobione, MAX-SLOT zamkniety.** Gra jest funkcjonalnie kompletna (rdzen
deckbuildera, kolekcja/roll, retencja D1/D7, monetyzacja Robux, deck-limit 10 kart) i zgodna
z polityka Roblox Paid Random Items. W toku jest **przedpremierowa ekspansja, kolejnosc
sztywna: MAX-SLOT (zrobione) -> nowe Stworki + balans -> merge -> packi+daily+luck ->
UI+juice**, a dopiero PO niej **Faza 5 — redesign wizualny** (patrz sekcja na samym dole
pliku). Nastepny krok do zaplanowania z Andreasem: nowe Stworki + balans. Wszystko ponizej to
historia/dowody, nie rzeczy do zrobienia teraz.

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

- Branch `main`, drzewo robocze czyste, w pelni zsynchronizowany z `origin/main` do commitu
  `217324c` (Faza 4 krok #4b — ostatni commit calej Fazy 4).
- `cardsw/` w `.gitignore`, nie pojawia sie jako untracked (raw art PNG, backup lokalny
  wystarczy — patrz decyzja w sekcji Faza 2b UI wyzej).
