# ⚡ ROLL A RUNE (tytuł roboczy) — Game Design Document v1
### Roguelike deckbuilder × RNG-kolekcja pod Roblox — zaprojektowany pod retencję, monetyzację i szybkie wykonanie

---

## 0. Jedno zdanie
**"Balatro bez pokera, ubrany w Sol's RNG"** — rollujesz Runy i Totemy z rzadkościami "1 na N", składasz z nich talię i grasz krótkie 8–12 min runy, w których liczby rosną wykładniczo, a między runami wraca pętla rollowania, kolekcji i leaderboardów.

Dlaczego ta hybryda (wprost z researchu):
- Czysty Balatro na Robloxie **nie wystartował nigdy** (wszystkie klony ~0 CCU) — bo single-player bez pętli społecznej umiera na tej platformie.
- Czyste RNG+karty **wystartowało spektakularnie** (Anime Card Clash: ~475M wizyt, szczyt 40K CCU) — ale nie ma głębi "jeszcze jeden run".
- My łączymy: głębia i dopamina liczb z Balatro + kompulsja rollowania i kolekcji z Sol's RNG + leaderboardy per-seed jako warstwa społeczna.

**Twarde ograniczenia projektowe (nie do negocjacji):**
1. ZERO kart do gry, terminologii pokerowej, estetyki kasyna → motyw run/żywiołów (unikamy polityki hazardowej Roblox i etykiety 17+, która odcina ~73% graczy).
2. ZERO customowych modeli 3D i animacji postaci → cała gra to 2D UI (Frames, ImageLabels, TweenService, ParticleEmitter). Nasza słabość nie istnieje w tym projekcie.
3. Każdy płatny roll ma **jawną tabelę szans** (obowiązek Paid Random Items — suma 100%, widoczna przed zakupem).

---

## 1. RDZEŃ — pojedynczy run (8–12 minut)

### 1.1 Ekran gry
Portret, mobile-first. Góra: licznik wyniku (duży, płonie przy dużych wynikach) + próg do pobicia. Środek: ręka 7 Run (duże karty-ImageLabels). Dół: przyciski ZAGRAJ / WYMIEŃ + podgląd Totemów (rządek 5 slotów nad ręką).

### 1.2 Runy (zamiast kart)
- Talia startowa: **40 Run** = 5 żywiołów (🔥 Ogień, 💧 Woda, 🌿 Natura, ⚡ Błysk, 🌑 Cień) × wartości 1–8.
- Każda Runa ma: **Moc** (bazowe punkty = wartość×5) i żywioł.

### 1.3 Zaklęcia (zamiast układów pokerowych)
Zagrywasz 1–5 Run z ręki; gra wykrywa najlepsze Zaklęcie:

| Zaklęcie | Warunek | Moc bazowa | Rezonans bazowy |
|---|---|---|---|
| Iskra | 1 dowolna runa | 10 | 1 |
| Echo | 2 tej samej wartości | 20 | 2 |
| Triada | 3 tej samej wartości | 40 | 3 |
| Żywioł | 3 tego samego żywiołu | 35 | 3 |
| Kaskada | 4 rosnące wartości | 60 | 4 |
| Nawałnica | 5 tego samego żywiołu | 100 | 6 |
| Konwergencja | 5 rosnących, 5 różnych żywiołów | 160 | 10 |

**Wynik zagrania = (Moc bazowa + suma Mocy run + bonusy Totemów) × (Rezonans + mnożniki Totemów).**
Ta sama matematyka co Chip×Mult Balatro — serce dopaminy. Liczby MUSZĄ eskalować wizualnie: popup każdej składowej, licznik kręcący się w górę, screen shake i płomień od progu ×10.

### 1.4 Struktura runu
- **6 poziomów × 2 starcia** (zwykłe + Strażnik/boss) = 12 progów. Dokładnie połowa długości Balatro → run 8–12 min.
- Na starcie: **4 zagrania + 3 wymiany** na starcie (wymiana = odrzuć do 5 run, dobierz nowe).
- Progi punktowe (do zbicia sumą zagrań): 100 → 180 → 320 → 550 → 950 → 1 600 → 2 700 → 4 500 → 7 500 → 12 500 → 21 000 → 35 000. (~×1.7 kroku; tuning po playtestach.)
- **Strażnicy** (bossy) nakładają widoczny wcześniej debuff: "Runy Ognia dają 0 Mocy", "masz o 1 zagranie mniej", "ręka −2 karty", "próg ×1.5, nagroda ×2".
- Przegrana = koniec runu, ale **waluta meta (Esencja) zostaje**. Wygrana = bonus Esencji + wpis na leaderboard.

### 1.5 Sklep między starciami (w runie, za złoto runowe — NIE za Robux)
3 sloty: Totem / Ulepszenie Zaklęcia (permanentnie w tym runie podnosi Moc+Rezonans jednego Zaklęcia — odpowiednik Planet) / Konsumowalny Zwój (jednorazowy — odpowiednik Tarota: "zmień żywioł 2 run", "usuń runę z talii", "duplikuj runę"). Re-roll sklepu za złoto (rosnący koszt).
**GWARANCJA KONTROLI TALII:** sklep w KAŻDEJ wizycie oferuje min. 1 Zwój manipulacji talią (usuń/duplikuj/zmień żywioł). To nie dodatek, tylko centralna mechanika: Nawałnica z bazowej talii 40 run to ~0.8% szans z ręki 7 — bez zwężania/kształtowania talii krzywa progów ×1.7 jest nieosiągalna i gracze utkną w połowie runu.

### 1.6 Totemy (zamiast Jokerów) — silnik synergii
5 slotów. Aktywacja lewo→prawo (kolejność ma znaczenie = głębia). MVP: **30 Totemów**, docelowo 100+. Rzadkości: Zwykły 70% / Rzadki 25% / Epicki 5% / Legendarny tylko ze specjalnych źródeł.

Przykłady (po jednym z każdej kategorii mechanicznej — CC dostanie pełną listę 30):
- **Płaski bonus:** "Żar" — +30 Mocy jeśli zagrano Runę Ognia.
- **Mnożnik warunkowy:** "Lawina" — ×2 Rezonans przy Zaklęciu z 4+ run.
- **Skalujący (rośnie w runie):** "Kolekcjoner" — +1 Rezonans za każdą Nawałnicę zagraną w tym runie (na stałe do końca runu).
- **Ekonomiczny:** "Skarbnik" — +1 złoto za każde zagranie.
- **Ryzyko/nagroda:** "Hazardzista Cienia" — ×3 Rezonans, ale −1 zagranie na starcie starcia.
- **Transformujący:** "Pryzmat" — wszystkie Runy liczą się jako każdy żywioł.

---

## 2. META — pętla poza runem (tu żyje retencja i monetyzacja)

### 2.1 Rollowanie Totemów (mechanika Sol's RNG — nasz najsilniejszy hak)
- Za **Esencję** (waluta z runów + offline earn) rollujesz nowe Totemy do PERMANENTNEJ kolekcji.
- Reveal "1 na N" ze skalą efektów od rzadkości (dokładnie wzorzec, który mamy już zrobiony w WAR RNG — kod reveala do przeniesienia niemal 1:1).
- Globalny announcement na serwerze przy dropach 1/10 000+.
- Posiadanie Totemu w kolekcji = pojawia się w puli sklepów w twoich runach + startowy pick 1 z 3 posiadanych na początku runu (deckbuilding meta!).
- **Tabela szans zawsze widoczna** (Paid Random Items compliance).

### 2.2 Warianty (Foil / Prismo / Galaxy / Void)
Osobna oś rolla (jak nasze shiny/galaxy z WAR RNG — kod istnieje): wariant = wizual + wpis w kolekcji + drobny stały bonus (np. Foil +2% Esencji). Tradeable w przyszłości. To jest paliwo kolekcjonerskie i handlowe.

### 2.3 Indeks kolekcji
4 zakładki (Totemy / Foil / Galaxy / Strażnicy-bestiariusz). Progi kompletności → klaimowalny bonus luck (przycisk ODBIERZ — dokładnie nasz system z WAR RNG Etap 4, do przeniesienia).

### 2.4 Drzewko meta (Esencja)
Lean, 3 gałęzie: Szczęście rolli / Ekonomia runu (start +1 zagranie, +złoto) / Offline earn. Nasz kod skill tree z WAR RNG do adaptacji.

### 2.5 Pętla dzienna/tygodniowa
- **Seed Dnia:** wszyscy grają identyczny run (ten sam RNG), leaderboard globalny + wśród znajomych. Główny hak powrotu D1→D2.
- Daily login streak (nagrody eskalujące D7/D14/D30), 3 questy dzienne ("zagraj Nawałnicę ×3", "pokonaj 2 Strażników").
- Event tygodniowy: limitowany Totem do wyrollowania tylko w ten weekend (FOMO).

### 2.5b DWA TRYBY + model monetyzacji (decyzja rozstrzygnięta — fundament tożsamości gry)
Rozdzielamy grę na dwa tryby, żeby pogodzić agresywną monetyzację z uczciwym rankingiem:

- **TRYB SWOBODNY (95% czasu gracza, 100% miejsc gdzie płaci):** własne runy, progresja meta, "Najwyższy Wynik w Ogóle", flex kolekcji. Tu kolekcja Stworków I płatne boosty DZIAŁAJĄ W PEŁNI (p2w jest OK): 2× Esencja, 2× Luck, lepsze/rzadsze Stworki, mocniejsze warianty, starter packi, ulepszenia. To jest silnik przychodu — bez ograniczeń.
- **TRYB RANKINGOWY (Seed Dnia — jedyny wyrównany):** wszyscy startują z NEUTRALNĄ, identyczną pulą Totemów; kolekcja z rolli NIE działa. Liczy się wyłącznie umiejętność (kto najlepiej rozegra ten sam seed). To jedno uczciwe miejsce, które trzyma graczy w codziennym powrocie — a powroty napędzają rolle i zakupy w trybie swobodnym.

**Dlaczego tak (nie p2w w rankingu):** leaderboard, który da się kupić, przestaje motywować (gracz widzi, że top to portfele, i rezygnuje) → traci funkcję retencyjną → spada Creator Rewards i długoterminowi wydający. Model wyżej daje PEŁNĄ monetyzację tam, gdzie ludzie realnie płacą (własna progresja/kolekcja/flex), a ranking zostawia czysty jako motor codziennego zaangażowania. Zero utraconego przychodu, zachowana retencja.

Konsekwencja techniczna (patrz architektura zasada 11 i §Leaderboard): Seed Dnia liczy wynik z neutralnej puli → dwóch graczy na tym samym seedzie z tymi samymi decyzjami dostaje identyczny wynik (test determinizmu ma sens). W trybie swobodnym wynik zależy od kolekcji i to jest zamierzone (nie trafia na wyrównany leaderboard).

### 2.6 Warstwa społeczna (bez niej umieramy — wniosek z researchu)
- Lobby-hub: widzisz innych graczy i ich rolle (announcementy rzadkich dropów budują zazdrość/aspirację).
- Leaderboard per-seed + all-time + tygodniowy.
- "Wyzwij znajomego": wyślij mu swój seed, porównanie wyników side-by-side.
- Trading Totemów/wariantów — POST-MVP (wymaga starannego anti-scam, robimy po stabilizacji).

### 2.7 ONBOARDING — pierwsze 2 minuty (największe ryzyko strategiczne, rozwiązanie)
Problem: publiczność RNG to casual, który chce "rolluj i zbieraj". Deckbuilder to złożoność (7 kart, 5 Totemów, 7 Zaklęć, sklep). Jeśli casual nie zrozumie w 2 min bez czytania — ucieka. Rozwiązanie: gra uczy przez GRANIE, nie przez tekst.

- **Sekunda 0-10:** żadnego menu, żadnej ściany tutorialu. Od razu ręka 7 Run, jedno Zaklęcie już podświetlone na zielono, wielka pulsująca strzałka i przycisk "ZAGRAJ". Jeden tap.
- **Sekunda 10-30 (pierwszy power-spike):** wynik wystrzeliwuje z juice'em (płomień, screen shake, liczby lecą w górę), próg zbity, "POZIOM 1 ✓". Dziecko czuje dopaminę ZANIM cokolwiek zrozumie. To jest haczyk.
- **Auto-suggest domyślnie ON:** przez cały FTUE (i dalej, opcjonalnie) gra sama podświetla najlepsze Zaklęcie w ręce (HandEvaluator client-side — już w architekturze). Casual gra tapając podświetlone; głębia dostępna, ale nie wymagana od pierwszej sekundy.
- **Sekunda 30-60 (pierwszy Totem):** po 1. starciu wymuszony darmowy wybór 1 z 3 Totemów, każdy z JEDNOZDANIOWYM opisem i podglądem efektu. Gracz stawia pierwszą synergię — uczy się, że Totemy = moc.
- **Sekunda 60-120 (pierwszy sklep + pierwsza rzadka rzecz):** prosty sklep (kup 1 rzecz za złoto), potem pierwszy mini-roll Stworka z pełnym revealem "1 na N". Casual dostaje pierwszy kolekcjonerski dopamine hit — most do pętli, którą zna z RNG.
- **Reguła twarda:** pierwszy power-spike MUSI paść przed 90 sekundą. Zero ścian tekstu, zero modali "przeczytaj zasady". Tutorial = 3-4 wymuszone tapnięcia wplecione w prawdziwy run, flaga `ftueDone` w profilu.
- **Metryka bramkowa:** jeśli test pokaże, że casual nie robi drugiego runu (retencja w sesji <50%), onboarding jest zepsuty — upraszczaj dalej, zanim dodasz cokolwiek innego.

---

## 3. MONETYZACJA (katalog z cenami — kalibracja z researchu i wzorca sklepu, który już mamy w memory)

**Zasada: agresywna monetyzacja w TRYBIE SWOBODNYM (kolekcja, boosty, luck, kosmetyka — p2w OK), zero wpływu na TRYB RANKINGOWY (Seed Dnia wyrównany). Patrz §2.5b.**

Gamepassy (permanentne):
| Pass | Cena | Efekt |
|---|---|---|
| 2× Esencja | 99 R$ | podwójna waluta z runów |
| Szczęśliwa Gwiazda (2× Luck) | 149 R$ | lepsze szanse rolli (jawna tabela "z passem") |
| Szybkie Rolle | 79 R$ | skip animacji reveala ("human rights pass" z Sol's RNG) |
| +2 Sloty startowego picku | 199 R$ | pick 1 z 5 zamiast 1 z 3 na start runu |
| VIP | 449 R$ | +25% Esencji, +1 quest dzienny, tag, dostęp do VIP-lobby |

Dev products (konsumowalne):
| Produkt | Ceny |
|---|---|
| Paczki Esencji | 49 / 99 / 249 / 499 R$ (środkowa oznaczona "BEST VALUE") |
| Potion Luck ×2 (15 min) | 29 R$ |
| Potion Esencja ×2 (15 min) | 29 R$ |
| Re-roll sklepu runowego ×5 | 29 R$ |
| Server Luck ×2 (30 min, cały serwer — social pressure) | 79 R$ |
| Starter Pack (jednorazowy: Esencja + 1 gwarantowany Epicki Totem + potiony) | 199 R$ |

Sezon (post-MVP): Pas Sezonowy ~799 R$ — kosmetyczne warianty run, tła stołu, efekty zagrań.

**Cel KPI:** D1 ≥30%, konwersja ≥2%, ARPPU ≥60 R$. Progi korekty jak w raporcie (D1<25% → skróć run i przyspiesz pierwszy power-spike).

---

## 4. DLACZEGO TO SZYBKIE DLA NAS (mapowanie na istniejący kod)

| System nowej gry | Skąd bierzemy |
|---|---|
| Roll + reveal "1 na N" + mutacje/warianty | WAR RNG RollService + reveal VFX — adaptacja, nie budowa |
| Indeks 4 zakładki + klaimowalny luck | WAR RNG IndexService Etap 2+4 — adaptacja |
| Drzewko skilli (2 waluty) | WAR RNG SkillTree — okrojona adaptacja |
| Offline earn | WAR RNG (flat rate + guardy) — kopiuj |
| ProfileStore, ServiceRegistry, StatProfile | Framework — kopiuj |
| Scoring engine Zaklęć (NOWE) | ~3 czyste moduły Luau: HandEvaluator, ScoreEngine, TotemEngine — server-authoritative, testowalne bez Studio |
| UI kart + juice (NOWE) | TweenService + UIGradient (foil) + popupy — zero animacji szkieletowych, zero meshy |

**Nie istnieje w tym projekcie:** mapa 3D, NPC, pathfinding, sync 300 wrogów, modele, rigi, animacje, bronie. Cała nasza dotychczasowa strata czasu jest strukturalnie wycięta.

---

## 5. MVP — plan budowy (cel: grywalne w 3 tygodnie, publikacja w 4–5)

**Faza 1 (tydz. 1): Rdzeń matematyczny.** HandEvaluator (7 Zaklęć), ScoreEngine (Moc×Rezonans, server-side), struktura runu 6×2, progi, 15 Totemów, sklep runowy. Test: pełny run grywalny brzydkim UI.
**Faza 2 (tydz. 2): Juice + meta-minimum.** UI kart z tweenami, popupy liczb, płonący licznik, screen shake; ProfileStore; Esencja; roll Totemów z revealem (port z RNG); indeks v1.
**Faza 3 (tydz. 3): Retencja + social.** Seed Dnia + leaderboard (OrderedDataStore), daily streak, questy dzienne, lobby z announcementami.
**Faza 4 (tydz. 4): Monetyzacja + polish.** 3 gamepassy (2×Esencja, Luck, Szybkie Rolle), paczki Esencji, Starter Pack, tabele szans (PolicyService), FTUE (pierwszy run prowadzony, power-spike w <3 min), soft launch.
**CUT z v1 (świadomie):** trading, pas sezonowy, warianty Galaxy/Void (zostaje sam Foil), co-op, eventy limitowane, Strażnicy powyżej 3 typów.

---

## 6. RYZYKA I BEZPIECZNIKI
1. **Moderacja/hazard:** motyw run, zero pokera, jawne szanse, brak wymiany o realnej wartości. Nazwy i art w 100% własne (prawnie: mechanika niekopiowalna, assety tak — trzymamy dystans od Balatro w warstwie wizualnej).
2. **"Za trudne dla dzieci":** FTUE z jednym przyciskiem, Zaklęcia podświetlane automatycznie (gra sama pokazuje najlepszy układ w ręce — opcja "auto-suggest" domyślnie ON), liczby duże i kolorowe.
3. **Run za długi na mobile:** twardy budżet 12 min; jeśli mediana >12 → tnij do 5 poziomów.
3b. **PRIORYTET PLAYTESTU #1 — krzywa balansu:** progi 100→35 000 to ×350 wzrostu wyniku przez 12 starć. Musi być osiągalne przez kumulację Totemów + ulepszeń Zaklęć + zwężanie talii. Test PRZED budową kolekcji i generowaniem artu: ≥20 runów na samych modułach Fazy 1 (brzydkie UI wystarczy). Jeśli krzywa nie działa — tuning progów/efektów, nie dokładanie skórki. Rdzeń najpierw, skórka potem.
4. **Ekonomia się wysypie:** wszystkie stałe w jednym GameConfig (nasz standard), zero magic numbers w kodzie.
5. **Klon nas skopiuje:** przewaga = tempo update'ów (nowe Totemy co tydzień to czysty config + 1 grafika).

---

*Dokument gotowy do pocięcia na briefy dla CC. Pierwszy brief = Faza 1: HandEvaluator + ScoreEngine jako czyste moduły z testami.*
