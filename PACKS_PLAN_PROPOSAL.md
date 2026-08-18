# PACKS_PLAN_PROPOSAL — System 4: Paczki + Daily + Luck (2026-08-18)

**TO JEST PLAN, NIE KOD.** Zero implementacji w tej sesji — Andreas ocenia po powrocie, potem STOP
na compliance-review przed budową (Paid Random Items za Robux = wymaga jego zgody na liczby PRZED
kodem, nie po).

## 0. Ustalenie fundamentalne: paczka = opakowanie na RollService, nie nowy silnik losowania

Paczka NIE dostaje własnego RNG. Reużywa dokładnie te same prymitywy co dzisiejszy roll
(RollService.luau): wybór konkretnego Stworka w obrębie tieru (uniform) + `selectVariant`
(RollService.luau:78-91, dokładny ważony walk, Void strukturalnie nieobecny w drabinie —
VariantConfig.luau:24-26). Jedyna nowa rzecz to **własna, DOKŁADNA tabela szans na TIER** per
paczka (PackConfig, nowy plik, wzorzec 1:1 z VariantConfig.luau) — z celowym powodem, patrz §4a.

## 1. Baseline: dzisiejszy darmowy roll (bez zmian, punkt odniesienia)

Zweryfikowane w kodzie (RollService.luau:44-73 + RarityConfig.luau:18-24), 25 Stworków w
rosterze (Common 10 / Uncommon 5 / Rare 4 / Epic 4 / Legendary 2), luck=1, policzone jako
sekwencyjna kaskada PO TOTEMIE (nie po tierze — patrz krytyczne znalezisko §4a):

| Tier | Realna szansa (dziś) | Koszt |
|---|---|---|
| Legendary | 2.2% | |
| Epic | 12.4% | 50 essence/roll |
| Rare | 25.1% | (GameConfig.RollCostEssence) |
| Uncommon | 29.4% | |
| Common | 30.9% | |

## 2. PACZKI (3 nazwane, Robux + wariant Esencja)

**Decyzja projektowa do zatwierdzenia:** ta sama tabela szans dla Robux i Esencji w obrębie
jednego tieru paczki — Robux kupuje SZYBKOŚĆ i WIĘKSZY pakiet (3-5 kart, natychmiast), Esencja
kupuje TĘ SAMĄ jakość szans za czas/farmienie (mniej kart/paczkę). Żadna paczka nie daje LEPSZYCH
szans za realne pieniądze niż da się dojść grindem — tylko szybciej. Uważam to za czystszą i
bezpieczniejszą historię compliance (jedna tabela do ujawnienia per tier, nie dwie) — ALTERNATYWA
(gorsza tabela w wersji Esencja) jest możliwa, ale to Twoja decyzja, nie moja.

| Paczka | Robux (karty/cena) | Esencja (karty/cena) | Legendary | Epic | Rare | Uncommon | Common |
|---|---|---|---|---|---|---|---|
| **Mega** | 3 kart / 79 R$ | 2 kart / 180 essence | 3% | 17% | 30% | 30% | 20% |
| **Super** | 5 kart / 149 R$ | 3 kart / 450 essence | 5% | 25% | 35% | 25% | 10% |
| **Legend** | 5 kart / 299 R$ | 3 kart / 1200 essence | 14%* | 44% | 30% | 10% | 2% |

*Legend: tabela powyżej dotyczy kart 1..N-1. **Ostatnia karta w KAŻDEJ paczce Legend jest
wymuszonym Legendary (100%, losowy z 2 istniejących + normalny roll wariantu)** — to jest
gwarancja minimum z Twojego ustalenia ("Legend min 1 Legendary"), realny fallback identyczny w
duchu do dzisiejszego pity (RollService.luau:44-59), tylko wymuszony zamiast progowy. Reveal dla
tej karty dostaje istniejący Legendary pacing (RollRevealController.luau:32, spin 4.5s/hold 2.5s)
— darmowe, już zbudowane.

**Cel Legend osobno licencjonowany za Esencję?** — 1200 essence to 24× koszt pojedynczego rolla,
ogromny sink, ale gwarantuje Legendary tam gdzie darmowy roll ma tylko 2.2% szans. Rekomenduję
ZOSTAWIĆ dostępne (nagroda za długi grind, nie podcina Robux — kto płaci, dostaje to natychmiast,
kto nie płaci, dostaje to po miesiącach grindu). Jeśli wolisz Legend Robux-only — to jedna linijka
do usunięcia w PackConfig, zaznacz przy review.

**Luck ×paczka (skalowanie, ten sam mechanizm co warianty):** każdy bucket poza Common
(fallback) mnożony przez aktywny `stats.luck` gracza, algorytm 1:1 z `RollService.selectVariant`
(RollService.luau:78-91: `cumulative += min(pct*luck,100)`, Common wchłania resztę) — suma zawsze
DOKŁADNIE 100% dla KAŻDEJ wartości luck, zero nowej matematyki do zwalidowania, tylko port
istniejącego, już-poprawnego wzorca z tieru na paczki. Legend ma świadomie zostawione 2% w Common,
żeby luck miał gdzie "gryźć" nawet w top-paczce (marketing: "luck podbija KAŻDĄ paczkę").

## 3. DAILY PACZKA (darmowa, raz/dzień)

- 1 karta/dzień, cadence identyczny ze streakiem: `SeedService.DailyKey(os.time())`
  (StreakService.luau:46-47 wzorzec), stan `data.dailyPack = {lastClaimedKey, claimedToday}` —
  nowe pole PROFILE_TEMPLATE, Reconcile() backfilluje jak `lifetimeMerges`.
- Tabela: **dokładnie baseline z §1** (literalnie wywołanie tych samych funkcji co
  `RollService.RollTotem`, tylko essence=0 zamiast 50). Zero nowej tabeli do utrzymania, zero
  ryzyka że daily podkrada wartość paczkom płatnym (to ten sam poziom co pojedynczy dzisiejszy
  roll, tylko raz dziennie za darmo — spójne z "darmowy roll zostaje mocny").
- Reveal: reużycie `RollRevealController.PlayReveal` (już publiczne od merge, RollRevealController.luau:135) — zero nowego UI-flow.

## 4. LUCK — potiony czasowe, TYLKO Robux (Twoja decyzja, potwierdzona)

- Aktualizacja istniejącego stuba `MarketplaceConfig.DevProducts.PotionLuckX2`
  (MarketplaceConfig.luau:32, dziś: mult=2, durationSec=900/15min — NIE pasuje do 30/60min z
  briefu) → rozbić na dwa produkty zamiast nadpisywać:
  | Produkt | Czas trwania | Mnożnik luck | Cena Robux |
  |---|---|---|---|
  | Luck Potion 30 | 1800s (30 min) | ×1.5 | 49 R$ |
  | Luck Potion 60 | 3600s (60 min) | ×2.0 | 89 R$ |
  (dłuższy = lepsza stawka/minutę, ten sam kształt co EssencePack Small→Huge, MarketplaceConfig.luau:28-31)
- Mnoży `stats.luck` DOKŁADNIE jak `GamePasses.LuckX2` (StatProfileService.luau:86-87, `mult`
  gałąź) — stackuje się z permanentnym luckiem z Indeksu (IndexConfig.luau:7-11) i z gamepassem
  LuckX2, bo to ten sam pipeline.
- **BRAKUJĄCY KONSUMENT (odkryte podczas researchu, nie zbudowane nigdzie):**
  `PurchaseService.grantDevProduct` już DZIŚ zapisuje `profile.purchases.tempBuffs[stat] =
  {mult, expiresAt}` (PurchaseService.luau:46-52) — ale `StatProfileService.Recompute` NIGDY tego
  nie czyta (czyta tylko `GamePasses`, StatProfileService.luau:82-93). To jest realna, nie-trywialna
  praca do zrobienia w Kroku implementacji (czytanie + wygasanie tempBuffs w Recompute), nie
  "podłączenie istniejącej rzeczy" — flaguję żeby nie było niespodzianki przy wycenie budowy.
- Ranked-bezpieczne z tego samego powodu co merge/roll: `luck` nigdy nie był w
  `RANKED_NEUTRAL_FIELDS` (StatProfileService.luau:101-106, komentarz: "luck/essenceMult... nie
  dotykają rankScore ani mechaniki runu") — bo luck działa WYŁĄCZNIE w RollService/paczkach, poza
  runem. Zero nowego scopingu.

## 5. COMPLIANCE

**(a) Ruchoma tabela — ⚠️ KRYTYCZNE ZNALEZISKO, poza scope tej sesji, wymaga Twojej decyzji:**

`PolicyService.computeTierOdds` (PolicyService.luau:25-46), dzisiejsza tabela pokazywana graczowi
w `GetOddsTable`, liczy tak jakby KAŻDY tier miał dokładnie JEDEN Stworka. W rzeczywistości
`RollService.selectTotem` iteruje PO TOTEMIE (10 Common/5 Uncommon/4 Rare/4 Epic/2 Legendary,
każdy z WŁASNYM rzutem) — te dwie matematyki się rozjeżdżają:

| Tier | Pokazywane graczowi (dziś, GetOddsTable) | Realne (RollService, przeliczone) |
|---|---|---|
| Legendary | 1.11% | 2.2% (2×) |
| Epic | 3.30% | 12.4% (3.8×) |
| Rare | 7.97% | 25.1% (3.1×) |
| Uncommon | 10.95% | 29.4% (2.7×) |
| Common | 76.67% | 30.9% (0.4×) |

To jest błąd JUŻ NA PRODUKCJI (dziś, na zwykłym rollu), niezależny od paczek — sama tabela sumuje
się do 100% (matematycznie "ładna"), ale nie zgadza się z tym co faktycznie losuje RollService.
To już DZIŚ jest niezgodne compliance-disclosure. Nie naprawiam teraz (poza zakresem: cleanup miał
4 pozycje, to piąta, świeżo znaleziona) — **rekomendacja: napraw PRZED albo RAZEM z budową paczek**,
bo inaczej wysyłasz DWA złe systemy zamiast jednego.

Dobra wiadomość: **paczki NIE dziedziczą tego buga**, bo świadomie dostają WŁASNĄ, dokładną tabelę
(jak warianty, nie jak dzisiejszy tier-cascade) — patrz §0. Nowy `PolicyService.PackOddsTable(player)`
(nowa funkcja, analogiczna do `OddsTable()`) liczy DYNAMICZNIE z `StatProfileService.Get(player)`
(zawsze non-ranked — paczki nigdy nie wołane z runu), suma=100% z KONSTRUKCJI dla każdego luck.
Nowy remote `GetPackOddsTable`, ten sam wzorzec UX co dzisiejszy "permanentny dostęp do tabeli
szans przy Roll" (Faza 4 Krok #4b, STATUS.md) — pokazany PRZED potwierdzeniem zakupu.

**(b) Determinism-gate (ranked):** paczki i luck-potiony dotykają `profile.totems`/IndexService
DOKŁADNIE jak dzisiejszy roll i merge — collectionScoped za darmo, bo `RunShopService.rankedTotemPool`
czyta wyłącznie stałą `RankedConfig.TotemIds` (RunShopService.luau:50-61,64-67, zweryfikowane
ponownie w tej sesji), a `luck`/paczki nigdy nie są wołane z wnętrza runu. Zero nowego kodu.

**(c) Idempotencja ProcessReceipt:** paczki wchodzą do `MarketplaceConfig.DevProducts` jak
istniejące wpisy — `productKeyFromId` (PurchaseService.luau:27-34) i `data.purchases.receipts`
dedup (linie 66-67, PRZED grantem) już to pokrywają, `grantDevProduct` dostaje nową gałąź
`cfg.packId` obok `essence`/`rerollCredits`/`tempBuff`. Zero nowej idempotencji do wymyślenia.

**(d) Void wykluczony:** karty z paczek reużywają `VariantConfig.ladder` + `RollService.selectVariant`
1:1 — Void jest strukturalnie nieobecny z `ladder` (VariantConfig.luau:24-26), więc paczki
dziedziczą to wykluczenie za darmo, bez nowego kodu.

## 6. Relacja z darmowym rollem (liczbowo)

| | Free roll | Essence Mega (90/karta) | Robux Mega (natychmiast) |
|---|---|---|---|
| Legendary | 2.2% | 3% (+36%) | 3% (+36%) |
| Epic | 12.4% | 17% (+37%) | 17% (+37%) |
| Koszt/kartę | 50 essence | 90 essence (1.8×) | 79 R$, 0 essence |

Paczka Mega to ~1.4× lepsza szansa na Epic+ za 1.8× essence/kartę — odczuwalna premia, nie
przepaść. Free roll zostaje w pełni grywalny (identyczny jak dziś, zero degradacji) — dokładnie
ten sam precedens co przy mergu ("cap chroni monetyzację, reszta może być hojna"). Robux nie kupuje
LEPSZYCH szans niż grind, kupuje CZAS.

## 7. Co NIE jest zbudowane (do zrobienia w kroku implementacji, nie teraz)

- `PackConfig.luau` (nowy, wzorzec MergeConfig.luau) — tabele/rozmiary/ceny z tego dokumentu.
- `PackService.luau` (nowy) — otwieranie paczki (N sekwencyjnych draw + gwarancja), daily claim.
- `StatProfileService.Recompute` — czytanie/wygasanie `profile.purchases.tempBuffs` (dziś tylko
  zapisywane, nigdy czytane — patrz §4).
- `PolicyService.PackOddsTable` + remote `GetPackOddsTable`.
- Fix `PolicyService.computeTierOdds` (§5a) — osobna decyzja priorytetu, ale silnie rekomendowana
  przed/razem z paczkami.
- UI: ekran zakupu paczki (tabela szans przed zakupem — compliance wymóg), licznik aktywnego luck.

**STOP tutaj.** Czekam na Twoją ocenę liczb (ceny/tabele/gwarancje) + decyzję ws. fixa
PolicyService przed jakimkolwiek kodem.
