# STATUS — Roll a Rune

Ostatnia aktualizacja: 2026-08-17, koniec sesji Faza 2b (serwer + UI, w pelni zamkniete).
Czytaj to + `git log` zamiast polegac na pamieci poprzedniej sesji.

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

## Stan git

- Branch `main`, w pelni zsynchronizowany z `origin/main` do commitu `384903b` (tryb ranked).
- Biezacy batch LeaderboardService (`LeaderboardConfig.luau` nowy, `LeaderboardService.luau`
  nowy, `Net.luau`, `Bootstrap.server.luau`, ten plik) zmieniony lokalnie + wypchniety do
  zywego Studio, **jeszcze niescommitowany** — kolejny krok w tej sesji.
- `git status` czysty poza tym batchem. `cardsw/` w `.gitignore`, nie pojawia sie juz jako
  untracked.
