# ⚡ ROLL A RUNE — ARCHITEKTURA v1 (dokument dla CC)

> Czytaj razem z RUNE_RNG_GDD.md. GDD = CO budujemy. Ten dokument = JAK.
> Wzorce przeniesione z Frameworka WAR RNG — nie wymyślaj nowych tam, gdzie stary działa.

---

## 0. ŻELAZNE ZASADY (z lekcji WAR RNG — obowiązują bez wyjątków)

1. **Server-authoritative WSZYSTKO co dotyczy wyniku i ekonomii.** Klient wysyła TYLKO intencje (indeksy zagranych Run, id kupowanego itemu). Klient NIGDY nie wysyła wyniku, ilości waluty, wylosowanego Totemu. Serwer liczy, waliduje, zapisuje.
2. **`Random.new()` wyłącznie na serwerze.** Nigdy `math.random`, nigdy RNG na kliencie do niczego, co ma konsekwencje.
3. **Zero magic numbers w kodzie.** Każda stała (progi, ceny, szanse, mnożniki) żyje w configach w `Shared/Configs/`. Balans zmienia się bez dotykania logiki.
4. **StatProfile = jedyne źródło statów gracza.** Luck, mnożniki Esencji, dodatkowe zagrania — wszystko czytane WYŁĄCZNIE ze StatProfile (bazy + delty skilli + bonusy indeksu + gamepassy). Żaden serwis nie liczy własnych bonusów.
5. **ProfileStore z session-locking** — kick gracza jeśli profile==nil. Migracje przez Reconcile.
6. **Serwisy: lifecycle Init→Start** przez ServiceRegistry, `get()` jako service-locator wołany leniwie w Start (nigdy w Init).
7. **Klient: bootstrap = init.client ORDER + pcall per kontroler** (klient NIE używa ServiceRegistry — wzorzec z RNG). Prewarm w tle partiami.
8. **Kod w git, assety UI w Studio.** default.project.json mapuje TYLKO partial nodes z kodem (jak w RNG — żadnych $path na całe serwisy/StarterGui). Kanał = MCP, walidacja driftu = validate_modules.py.
9. **PurchaseService rollback-safe** — ProcessReceipt z idempotency (istniejący wzorzec Frameworka).
10. **Determinizm runów:** cały run rozstrzyga się z jednego seeda (patrz §5). Seed Dnia musi dawać identyczny run każdemu graczowi.
11. **DWA ŚWIATY RNG — nigdy się nie mieszają.** RunRNG = seeded, deterministyczny (talia, sklep runowy, procy Totemów w runie — WSZYSTKO ze strumieni SeedUtil). MetaRNG = nieseedowany, per-gracz (roll Stworków, warianty — RollService). Jeśli JAKIKOLWIEK nieseedowany RNG (math.random, os.time, os.clock, timing zdarzeń) wycieknie do runu, determinizm pęka i leaderboard per-seed staje się bezwartościowy. Konkretnie: proc losowy Totemu (np. Jesterling 50%) MUSI iść ze strumienia SeedUtil "totemProc", nigdy z osobnego Random. Test w Fazie 1: dwa runy z tym samym seedem i tą samą sekwencją decyzji = identyczny wynik co do punktu.
12. **DWA TRYBY RUNU — bonusy kolekcji vs wyrównanie (rozstrzyga sprzeczność determinizm↔kolekcja).** RunSessionService przyjmuje `mode`: `"free"` lub `"ranked"`. W **ranked** (Seed Dnia): startowa pula Totemów jest NEUTRALNA i identyczna dla wszystkich (z RankedConfig, nie z profilu gracza), bonusy kolekcji/gamepassów wpływające na wynik są WYŁĄCZONE → dwóch graczy z tym samym seedem i decyzjami = identyczny wynik (leaderboard = czysty skill). W **free**: pula Totemów z kolekcji gracza + wszystkie bonusy p2w aktywne → wynik zależy od kolekcji (zamierzone, trafia tylko na "Najwyższy Wynik w Ogóle", NIE na wyrównany leaderboard). ScoreEngine dostaje flagę `ranked` i ignoruje źródła bonusów oznaczone `collectionScoped=true`. To jest decyzja o tożsamości gry — patrz GDD §2.5b.

---

## 1. STRUKTURA REPO / DRZEWA GRY

```
D:\RobloxProjects\rune\
├── default.project.json          # partial nodes: RS.Framework, RS.Shared, SSS.Services, SSS.init, SPS.Controllers, SPS.init
├── src/
│   ├── ReplicatedStorage/
│   │   ├── Framework/            # KOPIA z WAR RNG: Signal, Net, TableUtil, Promise-lite
│   │   └── Shared/
│   │       ├── Configs/          # GameConfig, RuneConfig, SpellConfig, TotemConfig, VariantConfig, ShopConfig, MonetizationConfig, QuestConfig
│   │       ├── HandEvaluator.luau
│   │       ├── ScoreEngine.luau
│   │       ├── TotemEngine.luau
│   │       ├── RunTypes.luau     # typy Luau (RunState, PlayResult, TotemDef...)
│   │       └── SeedUtil.luau
│   ├── ServerScriptService/
│   │   ├── init.server.luau      # bootstrap ServiceRegistry (Z PCALL — lekcja z audytu RNG!)
│   │   └── Services/             # patrz §2
│   └── StarterPlayerScripts/
│       ├── init.client.luau      # ORDER + pcall per kontroler
│       └── Controllers/          # patrz §3
├── tests/                        # testy czystych modułów (HandEvaluator/ScoreEngine/TotemEngine) — odpalane bez Studio
└── tools/                        # validate_modules.py + luau skopiowane z rng/tools
```

**W Studio (poza gitem):** `ReplicatedStorage.UITemplates` — szablony kart, paneli, popupów budowane ręcznie/MCP w Studio; kontrolery je klonują. StarterGui zostaje prawie puste (jeden ScreenGui-root per kontroler tworzony z kodu). Lekcja z RNG: zmiany w Studio-owned wymagają ekstrakcji Studio→dysk po sesji tam, gdzie to kod — szablony UI to NIE kod, zostają w placu.

---

## 2. SERWISY (ServerScriptService/Services)

Kolejność w tabeli ≈ kolejność zależności. „Czyta" = przez ServiceRegistry.get() w Start.

| Serwis | Odpowiada za | Czyta | Uwagi |
|---|---|---|---|
| **ProfileService** | ProfileStore: load/release, Reconcile, kick przy nil, ProfileReleasing signal | — | Port 1:1 z WAR RNG (z lekcją Bug 2B: cleanup przez ProfileReleasing, nie PlayerRemoving) |
| **StatProfileService** | Jedno źródło statów: bazy z GameConfig + delty skilli + bonusy indeksu + gamepassy → `Get(player) -> Stats` + `Recompute(player)` | ProfileService | Stats v1: `luck, essenceMult, extraPlays, extraSwaps, startPickSize, offlineRate, fastRoll(bool)` |
| **EconomyService** | Esencja (persistent) + złoto runowe (per-run, ulotne). `TrySpendEssence`, `AwardEssence` (przez essenceMult), EssenceSync do klienta | ProfileService, StatProfileService | Bliźniak CoinsSync z RNG |
| **RunSessionService** | Cykl życia runu: StartRun(seed?) → stan runu per gracz (poziom, starcie, zagrania/wymiany, talia, ręka, złoto, totemy w runie, ulepszenia zaklęć) → EndRun(win/lose). JEDYNY właściciel RunState | ProfileService, StatProfileService, EconomyService, SeedService | Cały stan runu w pamięci serwera (tabela per player). Run NIE jest zapisywany do profilu (przerwany run = przepada, Esencja z niego już wypłacona zostaje) — v1 świadomie bez resume |
| **PlayService** | Obsługa `PlayRunes(indices)` i `SwapRunes(indices)`: walidacja (czy runy w ręce, czy zostały zagrania) → HandEvaluator → ScoreEngine+TotemEngine → aktualizacja RunState → `ScoreResult` payload z PEŁNYM breakdownem (dla juice klienta) → sprawdzenie progu → advance/lose | RunSessionService | Cienki orkiestrator nad czystymi modułami. Rate-limit na remote |
| **RunShopService** | Sklep W RUNIE: generacja 3 ofert z run-seeda (stream „shop"), `BuyShopItem(slotId)`, re-roll za złoto (rosnący koszt) | RunSessionService, EconomyService | Oferty trzymane server-side; klient dostaje tylko opis. Kupno Totemu = dopisanie do RunState.totems |
| **RollService** | META-roll Totemów za Esencję: rzut rzadkości (dzielenie mianowników floor(N/luck) — wzorzec z RNG), osobny rzut wariantu (Foil...), pity, zapis do profilu, RollResult do klienta | ProfileService, StatProfileService, EconomyService | PORT z WAR RNG (3 osie → tu 2: totem + wariant). invKey = `totemId#variant` |
| **IndexService** | Kolekcja: discovery, progi kompletności, klaimowalny luck (ODBIERZ), bestiariusz Strażników | ProfileService, StatProfileService | PORT z RNG (Etap 2+4). Po claimie → StatProfile.Recompute |
| **SkillTreeService** | Drzewko meta za Esencję (3 gałęzie), `PurchaseSkill(id) -> newRank` | ProfileService, EconomyService, StatProfileService | PORT okrojony z RNG |
| **QuestService** | 3 questy dzienne (reset UTC), progres eventowy (nasłuch sygnałów z PlayService/RunSessionService), claim nagród | ProfileService, EconomyService | Definicje w QuestConfig; progres w profilu `{questId, progress, claimed, dateKey}` |
| **StreakService** | Daily login streak, kamienie D7/14/30, claim | ProfileService, EconomyService | dateKey UTC, guard przeciw skew (wzorzec z offline earn RNG) |
| **OfflineEarnService** | Flat rate Esencji offline, cap 10h, 3 guardy (first-login/skew/cap) + reset offlineTs | ProfileService, EconomyService, StatProfileService | PORT 1:1 z RNG |
| **SeedService** | Generacja seedów: `DailySeed()` deterministyczny z daty UTC (identyczny dla wszystkich), `RandomSeed()`, `FriendSeed` passthrough | — | Czysta funkcja + os.date. ŻADNEGO stanu |
| **LeaderboardService** | OrderedDataStore: leaderboard Seed Dnia (klucz = dateKey), all-time best, tygodniowy. Zapis TYLKO po zweryfikowanym EndRun(win/score) z RunSessionService. Seed Dnia = tryb ranked (neutralna pula, zasada 12). ANTY-SKRYPT: ranking Seed Dnia liczony z MEDIANY 3 najlepszych runów gracza tego dnia (nie z jednego perfekcyjnego przejścia) — zniechęca do kopiowania udostępnionej "idealnej sekwencji". Seed dnia ujawniany dopiero przy starcie runu, nie z wyprzedzeniem | RunSessionService | Throttle zapisów; top100 cache odświeżany co 60s, LeaderboardSync do klientów |
| **AnnouncementService** | Globalne ogłoszenia rzadkich dropów (próg z GameConfig, np. 1/10k) przez MessagingService cross-server + event lokalny | RollService | Wzorzec Sol's RNG |
| **PurchaseService** | ProcessReceipt (dev products) rollback-safe + idempotency, granty gamepassów, MarketplaceService.PlayerOwnsGamePass cache → StatProfile.Recompute | ProfileService, EconomyService, StatProfileService | Wzorzec Framework. Tabele szans: patrz MonetizationController §3 |
| **AntiCheatService** | Rate-limity remotes (centralnie), sanity-checks (score/s, essence/s), log anomalii | — | Lekki w v1; sam scoring jest już server-side więc główny wektor odcięty |

**Sygnały wewnętrzne (Signal, nie remotes):** `RunEnded(player, result)`, `SpellPlayed(player, spellId, score)`, `TotemRolled(player, totemId, rarityN, variant)`, `GuardianDefeated(player, guardianId)` — na nich wiszą QuestService, IndexService (discovery Strażników), LeaderboardService, AnnouncementService. Dzięki temu serwisy nie wołają się nawzajem krzyżowo.

---

## 3. KONTROLERY (StarterPlayerScripts/Controllers) — kolejność ORDER w init.client

| # | Kontroler | Odpowiada za |
|---|---|---|
| 1 | **NetController** | Cache referencji remotes, helpery subscribe |
| 2 | **UIRootController** | Tworzy ScreenGui-rooty (DisplayOrder!), klonuje UITemplates, scaling (UIScale + UIAspectRatioConstraint), portret mobile-first |
| 3 | **HudController** | Pasek Esencji, przyciski otwierające panele (Roll/Indeks/Drzewko/Questy/Sklep R$), licznik streak |
| 4 | **RunFlowController** | Ekrany runu: start (pick 1 z N Totemów), intro poziomu, zapowiedź debuffu Strażnika, WIN/LOSE summary. Steruje widocznością HandController |
| 5 | **HandController** | Ręka 7 Run: render z RunState, tap-select (mobile), przyciski ZAGRAJ/WYMIEŃ, **auto-suggest**: lokalnie woła HandEvaluator (ten sam moduł Shared) i podświetla najlepszy układ — TYLKO podpowiedź wizualna, wynik i tak liczy serwer |
| 6 | **ScoreFxController** | Cały juice z payloadu ScoreResult: popup każdej składowej (Moc runy po runie → bonusy Totemów → mnożnik), licznik kręcący się w górę, screen shake, płomień od ×10 progu, dźwięki eskalujące. WSZYSTKO TweenService + ParticleEmitter na UI |
| 7 | **TotemBarController** | Rządek 5 Totemów w runie, tooltips, highlight przy proc-u (z breakdownu) |
| 8 | **RunShopController** | UI sklepu w runie (3 sloty + re-roll), kupno przez remote |
| 9 | **RollRevealController** | PORT z WAR RNG: reveal "1 na N", kaskada wariantu, skip przy gamepassie Szybkie Rolle |
| 10 | **IndexController** | Panel kolekcji 4 zakładki + ODBIERZ (port z RNG) |
| 11 | **SkillTreeController** | Drzewko (port okrojony) |
| 12 | **QuestController** | Panel questów + streak claim |
| 13 | **LeaderboardController** | Tablice Seed Dnia / all-time / weekly, przycisk "Graj Seed Dnia" |
| 14 | **AnnouncementController** | Toast globalnych dropów w lobby |
| 15 | **MonetizationController** | Sklep R$: gamepassy + dev products + **tabele szans przy każdym płatnym rollu/luck-boostcie** (PolicyService compliance — modal z tabelą PRZED promptem zakupu) |
| 16 | **FTUEController** | Pierwszy run prowadzony: wymuszone kroki, power-spike <3 min, flaga w profilu |
| 17 | **SettingsController** | Auto-suggest ON/OFF, jakość FX, dźwięk |

Zasada z RNG: każdy kontroler owinięty pcall w init.client; kontrolery UI klonują szablony z ReplicatedStorage.UITemplates zamiast budować wszystko z kodu (kompromis: logika w gicie, wygląd w Studio).

---

## 4. CZYSTE MODUŁY (Shared) — serce gry, budowane NAJPIERW, testowalne bez Studio

### HandEvaluator.luau
`evaluate(runes: {Rune}) -> {spellId, baseMoc, baseRezonans, matchedRunes}` — czysta funkcja, zero stanu, zero wywołań Roblox API. Wykrywa najlepsze Zaklęcie z tabeli SpellConfig (priorytet od najwyższego). Używana przez serwer (autorytatywnie) i klienta (auto-suggest).

### ScoreEngine.luau
`score(playedRunes, spell, runState) -> PlayResult` gdzie PlayResult zawiera finalny wynik ORAZ **ordered breakdown**: lista kroków `{source="rune"/"totem"/"spell", id, mocDelta?, rezDelta?, mult?}` — klient odtwarza z tego animację krok po kroku. Determinizm: identyczne wejście → identyczny wynik.

### TotemEngine.luau
`apply(totems, phase, ctx)` — iteracja lewo→prawo, każdy Totem to wpis w TotemConfig: `{rarity, phase="onScore"/"onPlay"/"onShop"/"onRoundStart"/"onFail", condition(ctx)->bool, effect(ctx)->deltas}`. `ctx` zawiera m.in. `playCounter` (dla efektów typu "co trzecie zagranie"), `runesPlayed`, `runesInHand`, `spellId`, `rngStream` (strumień "totemProc" z SeedUtil — patrz zasada 11). Biblioteka warunków i efektów MUSI pokrywać wszystkie klucze użyte w rosterze z RUNE_RNG_STWORKI.md (w tym: extraPlay, procChance, scalingRezPerSpell, onFail-revive). NOWY TOTEM = NOWY WPIS W CONFIGU, zero zmian w silniku — to jest nasza szybkość update'ów.

### SeedUtil.luau
Podział jednego seeda na niezależne strumienie: `streams(seed) -> {deck=Random.new(h(seed,"deck")), shop=Random.new(h(seed,"shop")), ...}` — żeby re-roll sklepu nie zmieniał tasowania talii (inaczej Seed Dnia przestaje być fair).

---

## 5. PRZEPŁYWY DANYCH (kontrakty)

### Zagranie
```
Klient: tap 3 runy → [RF] PlayRunes({2,5,6})
Serwer (PlayService): walidacja stanu → HandEvaluator → ScoreEngine(+TotemEngine)
  → mutacja RunState (zużyte zagranie, dobranie kart, wynik skumulowany)
  → return PlayResult{breakdown, newHand, runProgress}
Klient (ScoreFxController): odtwarza breakdown jako animację → HandController renderuje newHand
```

### Roll Totemu (meta)
```
Klient: [RF] RollTotem() → Serwer (RollService): TrySpendEssence → rzut rzadkości (luck ze StatProfile)
  → rzut wariantu → zapis profilu → return RollResult{totemId, rarityN, variant}
  → Signal TotemRolled → AnnouncementService (jeśli próg) / IndexService (discovery) / QuestService
Klient: RollRevealController odpala reveal z rarityN (revealTier liczony client-side — wzorzec RNG)
```

### Remotes (Net) — komplet v1
RemoteFunctions: `StartRun(mode, seed?)`, `AbandonRun`, `PlayRunes(indices)`, `SwapRunes(indices)`, `BuyShopItem(slot)`, `RerollShop`, `RollTotem`, `PurchaseSkill(id)`, `ClaimIndexLuck(pct)`, `ClaimQuest(id)`, `ClaimStreak`, `GetLeaderboard(kind)`.
RemoteEvents S→C: `EssenceSync`, `RunStateSync` (pełny stan przy starcie/reconnect), `AnnouncementEvent`, `LeaderboardSync`.
Wszystkie RF z rate-limit (AntiCheatService) i pcall po stronie klienta.

---

## 6. SCHEMAT PROFILU (ProfileStore template — Reconcile-safe)

```lua
{
  essence = 0,
  totems = {},            -- ["totemId#variant"] = count
  indexClaims = {},        -- claimed luck thresholds
  guardiansSeen = {},      -- bestiariusz
  skills = {},             -- [skillId] = rank
  lifetimeRolls = 0, spendableNote = nil, pity = { sinceEpic = 0 },
  bestScores = { daily = {}, allTime = 0 },  -- daily: [dateKey] = score (do walidacji anti-resubmit)
  quests = { dateKey = "", list = {} },
  streak = { count = 0, lastDateKey = "" },
  offlineTs = 0,
  ftueDone = false,
  purchases = { receipts = {} },  -- idempotency ProcessReceipt
  settings = { autoSuggest = true, fxQuality = 2 },
}
```
Uwaga: DWA liczniki rolek jeśli wprowadzimy walutę-zakręcenia później (lekcja z RNG: spendable vs lifetime NIE mieszać).

---

## 7. KOLEJNOŚĆ BUDOWY (mapowanie na fazy GDD — każdy krok ma definition of done)

**FAZA 1 — rdzeń (bez Studio, czyste moduły + testy):**
1. Configs: GameConfig, RuneConfig, SpellConfig (7 zaklęć z GDD), TotemConfig (15 wpisów), progi.
2. HandEvaluator + testy (każde zaklęcie: pozytywny, negatywny, priorytet przy nakładaniu).
3. ScoreEngine + TotemEngine + testy (breakdown deterministyczny; totem skalujący; kolejność lewo→prawo zmienia wynik — test na to!).
4. SeedUtil + test determinizmu (2× ten sam seed = identyczna talia i sklep).
5. RunSessionService + PlayService + RunShopService; smoke-test runu przez execute_luau.
DoD: pełny run przechodzalny komendami, wyniki zgodne z ręczną kalkulacją.

**FAZA 2 — profil + meta + juice:**
6. ProfileService, StatProfileService, EconomyService (porty).
7. RollService + RollRevealController (port), IndexService v1.
8. UITemplates w Studio (karta runy, panel ręki, popup, panel sklepu) + HandController + ScoreFxController + RunFlowController.
DoD: run grywalny na telefonie, roll z revealem działa, Esencja persystuje.

**FAZA 3 — retencja:** SeedService + LeaderboardService + Seed Dnia UI, QuestService, StreakService, OfflineEarnService (port), AnnouncementService.
**FAZA 4 — monetyzacja + FTUE:** PurchaseService (port), MonetizationController Z TABELAMI SZANS, gamepassy wpięte w StatProfile, FTUEController, soft launch.

---

## 8. CZEGO NIE ROBIĆ (odpowiedź na znane pokusy)
- NIE budować systemu animacji postaci/awatarów w lobby. Lobby v1 = UI + lista graczy. Żadnego 3D poza domyślnym spawnem.
- NIE liczyć wyniku na kliencie „dla płynności" — breakdown z serwera wystarcza do animacji.
- NIE dodawać tradingu w v1 (anti-scam to osobny projekt).
- NIE wpisywać szans w dwóch miejscach — tabela szans w UI renderuje się Z TEGO SAMEGO configa, z którego losuje RollService.
- NIE robić resume przerwanego runu w v1 (stan runu tylko w RAM serwera — świadoma decyzja).
