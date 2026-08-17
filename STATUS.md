# STATUS — Roll a Rune

Ostatnia aktualizacja: 2026-08-17, koniec sesji Faza 2b (serwer, przed UI).
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

### Uwaga: nierozwiazane

- `cardsw/` (raw art PNG od Meshy, 15 Stworkow + `_originals`/`_not_mvp`) jest UNTRACKED w gicie,
  celowo pominiete w tym commicie (nie dotyczy Fazy 2b/serwera). Do decyzji: gitignore czy commit
  w osobnym PR-a-la-art.

## Otwarte zadania (kolejnosc do zrobienia)

1. **Starter + owned shop pool** — pula totemow dostepnych w sklepie na start rundy + logika
   "posiadane" (nie ustalone jeszcze w tej sesji, do zaprojektowania od zera).
2. **TODO harness D1** — (nazwa robocza z poprzedniej rozmowy, tresc nie doprecyzowana w tej
   sesji — sprawdz najblizszy kontekst/notatki zanim zaczniesz, zeby nie zgadywac zakresu).
3. **RollRevealController** (klient) — UI ujawnienia wyniku rolla (tier/wariant/animacja).
4. **IndexController** (klient) — UI kolekcji/indeksu, czytajace `GetIndexState`, wywolujace
   `ClaimIndexLuck`.
5. **HUD entry** dla Roll + Index — wpiecie przyciskow/wejscia do istniejacego HUD-a.
6. **Zrzut portretowy** (portrait screenshot) — zadanie osobno wspomniane przez uzytkownika,
   zapewne do materialow promo/store, szczegoly nie sprecyzowane.
7. *(niepotwierdzone)* — uzytkownik mowil o "7 otwartych zadaniach", ale w tej sesji padlo
   jednoznacznie tylko 6 pozycji powyzej. NIE zgaduj tresci siodmego — dopytaj uzytkownika na
   starcie nastepnej sesji zamiast wymyslac nazwe.

## Stan git

- Branch `main`, w pelni zsynchronizowany z `origin/main` (push potwierdzony, `2050e29..a4a6317`).
- `git status` czysty poza `cardsw/` (untracked, patrz wyzej — swiadomie zostawione).
