# System 3 — Merge/Craft (5→1 upgrade tieru) — PROPOZYCJA, do zatwierdzenia

Status: **PLAN, brak kodu.** Dotyka ekonomii i determinizmu (ranked), więc Andreas
zatwierdza kierunek przed implementacją. Poniżej sześć decyzji do podjęcia + rekomendacje.

## 1. MECHANIKA

| Pytanie | Rekomendacja | Uzasadnienie |
|---|---|---|
| Kurs wymiany | **5 identycznych Stworków (ten sam `id`, tier niżej) → 1 losowy Stworek tieru wyżej** | Prosta reguła, łatwa do zakomunikowania w UI; "5" już wybrane przez Andreasa w briefie |
| Wynik: losowy czy wybrany | **Losowy** (ważony wśród Stworków o tier+1, spośród tych które gracz jeszcze NIE odkrył lub wszystkich — do ustalenia) | Wybór wprost zdewaluowałby rollowanie (dlaczego kręcić, skoro mogę wykuć dokładnie to czego chcę) — kolizja z `RollService`/`PolicyService` (tabela szans, compliance) |
| Koszt dodatkowy poza 5 kartami | **Tak — essence, rosnący z tierem docelowym** (patrz #2) | Sam koszt "5 sztuk" nie skaluje się z tym jak drogi jest tier docelowy — bez essence-costu merge Common→Uncommon i Rare→Epic są "równie tanie" mimo zupełnie różnej wartości wyniku |

## 2. EKONOMIA — kluczowe ryzyko

**Problem wprost z briefu Andreasa:** darmowy merge do Legendary psuje sens kupowania paczek
Mega/Super/Legend. Jeśli 5×Epic → 1×Legendary za darmo, gracz z dużą kolekcją Epic nigdy nie
kupi paczki premium.

Trzy dźwignie, rekomendacja: **wszystkie trzy naraz**, nie jedna:

1. **Cap tieru wyjściowego: merge działa tylko do Rare.** Epic i Legendary NIE są osiągalne
   przez merge — wyłącznie paczki/roll. To najtwardsza i najprostsza gwarancja że premium-tier
   zostaje premium. (Common→Uncommon, Uncommon→Rare; Rare i wyżej: merge zablokowany, UI pokazuje
   dlaczego).
2. **Essence cost rosnący z tierem wejściowym**, np. Common→Uncommon: tanio (symboliczne),
   Uncommon→Rare: drożej — tak żeby merge nigdy nie był "wolniejszym ale darmowym substytutem"
   paczki, tylko sposobem na upłynnienie nadmiarowych duplikatów niskich tierów.
3. **Merge NIE generuje nowej wartości bez straty** — 5 kart znika, essence znika, gracz dostaje
   1 kartę. To musi być gorsze EV niż kupno paczki z tej samej puli essence (do przeliczenia razem
   z `PolicyService`'s tabelą szans, żeby liczby faktycznie się zgadzały, nie "na oko").

**Do potwierdzenia z Andreasem:** czy cap na Rare jest akceptowalny, czy woli inny próg (np. Epic
jako najwyższy osiągalny merge, tylko Legendary wyłącznie z paczek).

## 3. DETERMINIZM — `collectionScoped`, nie może przeciekać do ranked

Istniejący wzorzec w kodzie (`RunShopService.rankedTotemPool`, `StatProfileService`
`RANKED_NEUTRAL_FIELDS`): tryb `ranked` **nigdy** nie czyta kolekcji/statów gracza — dostaje
zawsze `RankedConfig.TotemIds` (stała pula) + zneutralizowane staty, żeby p2w/kolekcja nie dawały
przewagi w rankingu Seed Dnia.

Merge musi trzymać się dokładnie tego samego kontraktu: wynik merge (nowo wykuty Stworek) trafia
do `profile.totems` (kolekcja) i `IndexService` (discovery), identycznie jak roll — **zero nowego
kodu ścieżki ranked**, bo ranked już ignoruje kolekcję całościowo. Jedyna rzecz do pilnowania:
merge nie może w żaden sposób wpływać na `activeDeck`/`DeckService` automatycznie (gracz sam
decyduje czy nowo wykuty Stworek wchodzi do decka) — inaczej merge cicho zmieniałby aktywny deck
bez zgody gracza w trakcie/między runami.

## 4. DANE (profil)

Rozszerzenie `PROFILE_TEMPLATE` (`ProfileService.luau`) o coś w rodzaju:

```lua
-- merge: idempotencja + audyt (opcjonalnie, do decyzji czy w ogóle potrzebne)
mergeHistory = {}, -- lub brak pola, jeśli merge jest czystą transformacją totems-count bez logu
```

**Idempotencja:** merge to atomowa transformacja `profile.totems[id] -= 5` (dla dokładnie
wybranego `id#variant`) `+ profile.totems[newId#variant] += 1`, wykonana w jednej operacji
serwerowej (bez remote round-tripów pomiędzy "policz 5" a "wykuj 1" — identyczny wzorzec co
`RunShopService.buy`, walidacja + mutacja w jednym wywołaniu, żeby podwójne kliknięcie/race nie
mogło spalić kart bez wyniku). Nie potrzeba osobnego logu historii, chyba że Andreas chce
telemetrię do balansu (wtedy: `mergeHistory` append-only, analogicznie do `bestScores.daily`).

## 5. UI TOUCHPOINT

Ekran kolekcji: przy każdym Stworku z `count >= 5` (i tier ≤ cap z #2) — badge/przycisk
**"Połącz" (Merge)**. Klik otwiera potwierdzenie ("5× Puffcap + X essence → 1× losowy Uncommon"),
gracz potwierdza, serwer wykonuje atomowo, klient dostaje wynik + animację reveal (podobną do
`RollRevealController` — nowy Stworek to nowy Stworek, ten sam beat co roll, żeby nie budować
drugiego UI-flow od zera).

## 6. EDGE CASE — warianty/foile

**Kluczowe pytanie do Andreasa, nie ma oczywistej domyślnej odpowiedzi:**

- Kolekcja liczy warianty osobno (`totemId#Normal`, `#Foil`, `#Gold`, `#Galaxy` — widać w danych
  profilu, np. `"blobby#Foil":14`). Czy merge wymaga **5× tego samego wariantu**, czy miesza
  warianty (5× dowolna mieszanka Normal/Foil/Gold tego samego `id`)?
- Rekomendacja: **merge per-wariant, osobno** (5× Normal → Normal wyniku; 5× Foil → Foil wyniku).
  Prostsze reguły, i nie dewaluuje rzadkich wariantów przez "zmieszanie ich w dół" do zwykłego
  Normal wyniku. Konsekwencja: Foile są RZADZIEJ mergowalne (gracz rzadziej ma 5× tego samego
  Foila) — to trzyma wartość foili, co wydaje się pożądane (foile już są rzadkościowym systemem
  osobno od tierów).
- Alternatywa (jeśli Andreas chce prostszy system): merge ignoruje wariant, wynik zawsze `Normal`
  niezależnie co wrzucono — prostsze, ale kasuje wartość Foili wrzuconych do merge'a (gracz traci
  ich "foilowość" bez rekompensaty). Nie rekomendowane bez dodatkowej logiki (np. "5× Foil → 1×
  Foil wyniku" zamiast degradacji do Normal).

---

**Do zatwierdzenia:** #1 (losowy wynik), #2 (cap na Rare + essence-cost + gorszy EV niż paczka),
#6 (merge per-wariant). Reszta (#3-5) to bezpośrednia konsekwencja istniejących wzorców w kodzie,
nie wymaga osobnej decyzji.

---

## 7. LICZBY STARTOWE — hipotezy do bramki (2026-08-18)

Decyzje #1-#5 z tego dokumentu **zatwierdzone przez Andreasa** (patrz jego brief). Poniżej
konkretne liczby, wyprowadzone z realnej ekonomii gry (`RarityConfig`, `VariantConfig`,
`GameConfig`, math checkpoint z `STATUS.md`), nie wymyślone w próżni. **Każda liczba niżej to
HIPOTEZA STARTOWA, nie wartość docelowa** — do zwalidowania własną bramką (n=50+) po
zaimplementowaniu, dokładnie tym samym trybem co Vinelet/Shardmaw/Galaxeon.

### Dane wejściowe (fakty z kodu, nie hipotezy)

| Wielkość | Wartość | Źródło |
|---|---|---|
| Rozkład tierów (zmierzony, N=200k) | Common 51.9% / Uncommon 25.5% / Rare 14.7% / Epic 6.8% / Legendary 1.1% | `STATUS.md` math checkpoint |
| Liczba Stworków w tierze | Common=10, Uncommon=5, Rare=4, Epic=4, Legendary=2 (razem 25) | `TotemConfig.luau` |
| Prawd. konkretnego id w rollu | Common 5.19%, Uncommon 5.10%, Rare 3.68%, Epic 1.70%, Legendary 0.55% | tier% ÷ liczba id w tierze |
| Ladder wariantów | Rainbow 0.1% / Galaxy 1% / Gold 4% / Foil 10% / Normal 84.9% | `VariantConfig.luau` |
| Koszt jednego rolla | 50 essence | `GameConfig.RollCostEssence` |

Cap #2 oznacza, że **jedyne dwa kroki merge to Common→Uncommon i Uncommon→Rare** — Rare nigdy nie
jest wejściem (nie merguje się dalej), więc poniższe liczby dotyczą tylko tych dwóch kroków.

### A. Próg (ile duplikatów wchodzi)

**Common ma mieć niższy próg niż krok kończący się na Rare?** — Nie. Prawdopodobieństwo trafienia
konkretnego id jest niemal identyczne dla obu wejściowych tierów (Common 5.19%, Uncommon 5.10% —
tak wyszło z konstrukcji rosteru: 10 Common przy 51.9% i 5 Uncommon przy 25.5% dają prawie ten sam
% na sztukę). Nie ma matematycznego powodu różnicować progu Common-in vs Uncommon-in.

- **HIPOTEZA: próg Normal = 5** (dla obu kroków, Common→Uncommon i Uncommon→Rare).
  Oczekiwana liczba rolli do 5 duplikatów konkretnego id+Normal: Common ≈113.5 rolla (≈5675
  essence), Uncommon ≈115.5 rolla (≈5773 essence) — rząd wielkości "dziesiątki rolli", osiągalne
  bez farmienia jednego itemu specjalnie.
  *Gate-sygnał:* jeśli >X% aktywnych graczy z ≥2 duplikatami danego tieru nigdy nie dobija do 5 w
  ciągu typowego okna sesji (do zmierzenia telemetrycznie) → obniż próg; jeśli mediana rolli-do-progu
  wychodzi z bramki wyraźnie niżej niż ~113 (np. gracze trafiają próg przez przypadek co chwilę,
  merge czuje się jak nic) → podnieś.

- **Foile: próg 5 jest praktycznie martwy.** Foil (10%) wchodzi jako mnożnik na już-niską
  prawdopodobność konkretnego id: oczekiwana liczba rolli do 5× tego samego Foila ≈963 (Common) /
  ≈980 (Uncommon) — **~48–49 tysięcy essence**, ~8.5× drożej niż próg 5 dla Normal. Próg 5 stałby
  się realny dopiero przy drop-rate Foili rzędu **~19-20%** (żeby zmieścić się w orientacyjnym
  "jeszcze granym" pułapie ~500 rolli) — obecne 10% to około połowa tej wartości, więc próg 5 jest
  ~2× za wysoki względem realnego drop-rate'u.
  - **HIPOTEZA: próg Foil = 2** (nie 5). Oczekiwana liczba rolli do 2× tego samego Foila ≈385
    (Common) / ≈392 (Uncommon) — nadal wymaga sporo gry (to i tak rzadki moment, celowo), ale nie
    jest matematycznie martwe jak próg 5. Niżej niż 2 nie ma sensu (2 to praktyczne minimum, żeby
    "merge" cokolwiek znaczył).
  - Fallback jeśli 2 okaże się w praktyce zbyt rzadkie/niewidoczne w telemetrii: próg 3 (≈578-588
    rolli, ≈29k essence) jako pośredni krok, zanim rozważy się coś poza merge (patrz uwaga na
    końcu o Foilach).
  *Gate-sygnał:* jeśli >Y% graczy z ≥1 duplikatem Foil nigdy nie osiąga progu 2 w ciągu miesiąca
  aktywnej gry → sam merge nie jest dobrym sinkiem dla Foili niezależnie od progu (osobny problem,
  patrz flaga na końcu); jeśli próg 2 okazuje się trafiany "za łatwo" i ludzie farmią go świadomie
  kosztem zwykłego rollowania → podnieś do 3.

### B. Koszt essence per tier (krzywa)

**HIPOTEZA — krzywa geometryczna ×3 na krok:** `koszt(tier_in) = RollCostEssence × 3^n`, gdzie n=0
dla Common-in, n=1 dla Uncommon-in.

| Krok | n | Koszt (essence) | Jako wielokrotność 1 rolla |
|---|---|---|---|
| Common → Uncommon | 0 | **50** | 1× |
| Uncommon → Rare | 1 | **150** | 3× |

×3 to okrągła liczba wybrana dla czytelności hipotezy, nie wyprowadzona z `TierWeight` (stosunek
wag Uncommon/Common to tylko ~2.67×, Rare/Uncommon ~1.5× — jeśli ×3 nie "poczuje się" dobrze w
bramce, naturalna alternatywa to skalowanie kosztu wprost stosunkiem wag zamiast stałego ×3).

*Gate-sygnał (oba kroki):* jeśli gracze z odblokowanym progiem i essence > 2× kosztu regularnie
**nie** mergują → problem nie jest w koszcie (patrz EV/cap); jeśli ci sami gracze mają essence
poniżej kosztu w momencie odblokowania progu (odblokowują duplikaty szybciej niż essence) → koszt
za wysoki względem tempa essence, obniż.

### C. EV — matematyka, nie deklaracja

Dwa różne pytania wymagają dwóch różnych porównań EV:

**C1. "Czy merge jest tańszą drogą do tego samego niż rolowanie wprost?"** (musi wyjść: NIE —
decyzja #4). Tu liczy się PEŁNY koszt, łącznie z essence już wydaną na zdobycie 5 duplikatów
(bo to jest realna alternatywa gracza: farmić duplikaty+merge, czy rolować wprost o dany tier):

| Krok | Koszt "farm+merge" (5×koszt-jednego-Common/Uncommon-z-rolla + opłata) | Koszt bezpośredniego rolla losowego itemu tego tieru | Merge droższy o |
|---|---|---|---|
| →Uncommon | 5×96.3 + 50 = **531.5** essence | 50/0.255 = **196.1** essence | **2.71×** |
| →Rare | 5×196.1 + 150 = **1130.5** essence | 50/0.147 = **340.1** essence | **3.32×** |

Merge jest wyraźnie droższą drogą do "jakiegoś itemu tego tieru" niż zwykłe rolowanie — rośnie to
nawet z tierem (2.71× → 3.32×), bo koszt (×3 na krok) rośnie szybciej niż wartość (tier-value rośnie
tylko ~1.7× między Uncommon a Rare). To celowe: im wyżej, tym mocniej merge ma być "gorszym
skrótem", nie lepszym.

**C2. "Czy warto zmergować duplikaty, które i tak już mam (bo wypadły przy okazji rolowania po coś
innego)?"** (musi wyjść: TAK, >0 — inaczej merge to pułapka, gorsza niż trzymanie śmieci). Tu liczy
się TYLKO krańcowy koszt (opłata) — 5 duplikatów nie mają dziś żadnego innego zastosowania, więc
ich koszt alternatywny = 0:

| Krok | Wartość losowego itemu tego tieru (roll-equivalent) | Opłata merge | Zysk netto | Mnożnik zwrotu |
|---|---|---|---|---|
| →Uncommon | 196.1 essence | 50 essence | **+146.1** | **3.92×** |
| →Rare | 340.1 essence | 150 essence | **+190.1** | **2.27×** |

Obie ścieżki dają dodatni zysk krańcowy (merge > trzymanie śmieci), a mnożnik zwrotu spada z
tierem (3.92× → 2.27×) — spójne z C1: im wyżej, tym mniej "hojny" jest merge, ale nigdy nie
schodzi poniżej progu opłacalności.

*Gate-sygnał:* jeśli suma essence wydawanej na merge zaczyna dorównywać/przewyższać sumę essence
wydawanej na zwykłe rolle u aktywnych graczy → C1 nie działa w praktyce (merge zbyt atrakcyjny),
podnieś koszt/próg; jeśli >Z% graczy z odblokowanym progiem i essence na koszt nigdy nie klika
merge → C2 nie jest odczuwalne jako "zysk", zbadaj UI/komunikację zanim ruszysz liczby.

### D. Losowanie wyniku w tierze wyżej: płaskie

**HIPOTEZA: płaski (uniform) rozkład wśród wszystkich Stworków tieru+1**, nie ważony rzadkością.

Uzasadnienie: w obrębie jednego tieru wszystkie Stworki dziś dzielą DOKŁADNIE tę samą wagę
(`RarityConfig.TierWeight` jest per-tier, nie per-Stworek — `selectTotem` w `RollService` już
traktuje np. wszystkie 5 Uncommonów jako równie prawdopodobne przy zwykłym rollu). "Ważenie
rzadkością wewnątrz tieru" nie ma dziś żadnego sygnału do ważenia po — nie istnieje pojęcie
"rzadszego Uncommona niż inny Uncommon". Płaski rozkład w merge jest więc nie tylko prostszy, ale
**spójny z tym, czego gracz już doświadcza przy zwykłym rollu tego tieru** — merge nie wprowadza
nowej, innej krzywej szans, tylko przenosi znaną.

Pod kątem odczucia "zmergowałem 5 i dostałem najgorszego": to uczucie dotyczy SUBIEKTYWNEJ mocy
Stworka w rozgrywce (mocMult, synergie), nie szansy dropu — a tego żadne ważenie rzadkością nie
naprawia (to problem balansu `TotemConfig`, nie merge'a). Ważenie szansy dropu "w dół" dla
subiektywnie słabszych Stworków byłoby w tym miejscu niewidzialne dla gracza (nie zna wag), więc
nie rozwiąże realnego źródła frustracji.

*Gate-sygnał:* jeśli feedback (Discord/support) regularnie i konkretnie wskazuje "merge zawsze daje
mi najgorszego Stworka" mimo matematycznie płaskiego rozkładu (potwierdzone logiem wyników merge)
→ to sygnał do przebalansowania SIŁY konkretnych Stworków w `TotemConfig`, nie do zmiany algorytmu
merge'a na ważony.

### E. Sink dla nadmiaru Rare

Cap (#2) oznacza, że Rare to ślepy zaułek merge'a — duplikaty Rare nie mają dokąd pójść, dokładnie
ten sam problem strukturalny, który merge rozwiązuje dla Common/Uncommon, teraz piętro wyżej.

**HIPOTEZA: Disenchant — każda kopia Rare ponad pierwszą (ten sam id+wariant) → 30 essence.**

Dlaczego 30, nie więcej: 30 essence to ~9% realnej wartości świeżego Rare (340 essence
roll-equivalent) i ~60% kosztu jednego rolla (50) — celowo mocno stratny sink, żeby nie powstała
pętla arbitrażu. Sanity check przeciw pętli "merguj Uncommon→Rare, natychmiast disenchant": koszt
kroku Uncommon→Rare krańcowo to 150 essence opłaty, disenchant oddaje tylko 30 — czysta strata 120
essence na cyklu, więc pętla się nie opłaca nawet w najbardziej optymistycznym dla gracza wariancie
(nie licząc nawet kosztu 5 Uncommonów).

Disenchant celowo NIE skaluje się wariantem (Foil Rare disenchantuje się tak samo jak Normal Rare
za 30 essence) — dotarcie do duplikatu Rare+Foil jest już samo w sobie ekstremalnie rzadkie (patrz
punkt A), więc racjonalny gracz i tak nie odda takiego itemu za 30 essence; nie trzeba tego osobno
zabezpieczać.

*Gate-sygnał:* jeśli gracze disenchantują Rare natychmiast po zdobyciu pierwszej kopii (nie trzymają
nawet jednej na kolekcję) → wartość za atrakcyjna względem alternatyw, obniż; jeśli >W% graczy z ≥2
tym samym Rare nigdy nie używa disenchant → wartość niewidoczna/za niska, podnieś albo popraw
ekspozycję w UI.

### Metryki retencji do poprawy (2-3) i jak je mierzyć

1. **Merge engagement rate** — % aktywnych graczy (WAU) z ≥1 merge/tydzień. Licznik serwerowy
   analogiczny do `lifetimeRolls`, agregowany tygodniowo. Cel: nietrywialny % (nie ~0%, co
   oznaczałoby martwy feature).
2. **Retencja/długość sesji: kohorta "odblokował merge" (≥5 duplikatów Common) vs. reszta** —
   standardowa telemetria sesji, segmentowana flagą `hasEligibleMerge`. Cel: gracze z dostępnym
   merge wracają częściej/grają dłużej niż porównywalna kohorta bez (merge jako dodatkowy powód do
   powrotu, "mam coś do zrobienia z kolekcją").
3. **Trend liczby niezmergowanych duplikatów Common per gracz w czasie** — okresowy snapshot
   agregujący `profile.totems`. Cel: trend W DÓŁ po wdrożeniu merge (duplikaty faktycznie znikają
   przez sink), nie płaski/rosnący (co oznaczałoby, że merge jest ignorowany, próg/koszt za wysokie).

### Ryzyka przeregulowania — per dźwignia

| Dźwignia | Objaw "za dużo" | Objaw "za mało" |
|---|---|---|
| **Próg** | Nikt nie dobija (0% engagement), duplikaty piętrzą się jako demoralizujący śmietnik, feature de facto nie istnieje | Merge trafia się co chwilę, dewaluuje "mały sukces" 5 duplikatów, losowy-tier-up zaczyna konkurować z samym rollowaniem (koliduje z decyzją #4) |
| **Koszt essence** | Gracze wolą oszczędzać na rolle, merge ignorowany mimo dostępnych duplikatów (essence-constrained, nie duplicate-constrained) | Merge tańszy niż rolowanie o ten sam tier (łamie C1) — gracze farmią duplikaty+merge zamiast rollować, kanibalizuje rdzeń gacha |
| **EV (hojność wyniku vs koszt)** | EV merge zbliża się/przewyższa EV rolla — racjonalny gracz przelewa CAŁĄ essence w farm+merge zamiast w rolle, zabija zmienność/emocję rollowania (i przychód) | EV merge ujemne lub bliskie zeru mimo poniesionego kosztu zbierania 5 duplikatów — gracz czuje się "oszukany" po włożonym wysiłku, gorsze dla retencji niż brak feature'u |
| **Cap (tylko do Rare)** | (nie dotyczy dziś — cap zablokowany decyzją #2; gdyby kiedyś podniesiony do Epic/Legendary, zniszczyłby ekskluzywność premium-tierów) | Cap sam w sobie tworzy nowy problem: Epic/Legendary duplikaty nie mają ŻADNEGO sinku (patrz flaga poniżej) |

### Uwaga na końcu — napięcie z ustalonymi decyzjami (nie zmienia decyzji, tylko flaguje)

1. **Cap na Rare (#2) tworzy nowy, nieobsłużony problem piętro wyżej: Epic/Legendary.** Merge
   rozwiązuje duplikaty Common/Uncommon (sink) i Rare dostaje disenchant (punkt E) — ale Epic i
   Legendary, najrzadsze i najbardziej "wyczekane" trafienia, dziś nie mają ŻADNEGO sinku dla
   duplikatów. To może być gorsze dla retencji niż problem, który merge miał rozwiązać — nadmiar
   Epic/Legendary to inwestycja emocjonalna gracza, więc martwe duplikaty tam bolą bardziej niż
   martwe Commony. Nie zmieniam capu (decyzja #2 stoi), ale to prawdopodobnie następny krok po
   merge (disenchant Epic/Legendary, analogiczny do punktu E) — do rozważenia osobno, nie dziś.
2. **Decyzja #1 (losowy wynik) × decyzja #5 (warianty osobno) najmocniej bolą przy Foilach.**
   Zdobycie 2-5× tego samego Foila to (patrz punkt A) rząd 400-1000 rolli — ekstremalnie kosztowna
   inwestycja. Dla takiej stawki pełna losowość wyniku ("włożyłem setki rolli i tak nie wiem co
   dostanę") może czuć się nieproporcjonalnie surowo względem Common, gdzie stawka jest niska więc
   losowość nie boli. Nie proponuję zmiany #1 (rozjechałoby się z uzasadnieniem "merge nie może
   zdewaluować rollowania") — flaguję to jako miejsce, które przy realnych danych z bramki może
   wymagać osobnej rozmowy (np. czy Foile w ogóle powinny iść przez ten sam merge co Normal, czy
   potrzebują własnego, mniej losowego sinku — poza zakresem dzisiejszych 5 decyzji).
