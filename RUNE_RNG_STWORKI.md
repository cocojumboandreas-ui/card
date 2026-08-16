# ⚡ ROLL A RUNE — KOLEKCJA STWORKÓW v1 (spec dla CC + przewodnik generacji artu)

> Czytaj razem z RUNE_RNG_GDD.md i RUNE_RNG_ARCHITEKTURA.md.
> Ten dokument = CAŁA zawartość kolekcji: roster 29 Stworków (4 tiery), efekty w formacie TotemConfig,
> system wariantów, layout karty, oraz opisy wizualne + prompty do generacji artu (sekcja B — dla Andreasa).

---

# CZĘŚĆ A — SYSTEM (dla CC)

## A1. Zasady rosteru (z researchu dziecięcego "WOW")
- Proporcje tierów: Common ~38% / Rare ~28% / Epic ~21% / Legendary ~14%.
- Rzadkość musi być WIDOCZNA bez czytania: ramka, glow, cząsteczki eskalują z tierem.
- Każdy Stworek ma JEDNĄ wyróżniającą cechę sylwetki (zasada Pokémon: rozpoznawalny jako czarny kontur).
- Nazwy: wymyślone zbitki (portmanteau), 2-3 sylaby, globalnie wymawialne, angielskie. Lokalizacja PL w osobnym pliku stringów.
- Jeden bazowy art na Stworka. Warianty (Foil/Gold/Galaxy/Rainbow/Void) = NAKŁADKI W SILNIKU (patrz A4), NIE osobne grafiki.

## A2. Kolory i ramki tierów
| Tier | Kolor ramki | Efekt ramki |
|---|---|---|
| Common | #9E9E9E (szary) | brak |
| Rare | #4FC3F7 (niebieski) | delikatny glow (UIStroke + przezroczysty gradient) |
| Epic | #AB47BC (fiolet) | glow + wolne cząsteczki na ramce |
| Legendary | #FFD54F (złoto) | animowany UIGradient na ramce + cząsteczki + złota nazwa w UI |

## A3. Format wpisu TotemConfig (kontrakt z TotemEngine z architektury)
```lua
["capybop"] = {
  name = "Capybop", tier = "Common", element = "Nature",
  phase = "onScore",                 -- onScore / onPlay / onShop / onRoundStart / onFail
  condition = "playContainsElement", -- klucz do biblioteki warunków w TotemEngine
  conditionArg = "Nature",
  effect = { mocFlat = 20 },         -- mocFlat / rezFlat / rezMult / mocMultElement / goldFlat / extraPlay / extraSwap / scalingRezPerSpell / procChance...
},
```
Nowy Stworek = nowy wpis + 1 PNG. Zero zmian w silniku.

## A4. System wariantów (nakładki w silniku — jedna grafika bazowa)
| Wariant | Technika w Roblox UI | Szansa bazowa (jawna tabela!) |
|---|---|---|
| Normal | — | 84.9% |
| Foil | obracający się UIGradient (biały połysk, transparency 0.7) przesuwany tweenem po ImageLabel | 10% |
| Gold | ImageColor3 tint złoty + ciepły glow | 4% |
| Galaxy | druga ImageLabel z teksturą gwiazd (jeden wspólny asset) w trybie overlay + wolny scroll | 1% |
| Rainbow | animowany UIGradient pełne spektrum, cykl 3s (wzór Mega Neon z Adopt Me) | 0.1% |
| Void | tint ciemny + fioletowe cząsteczki + inwersja tła karty (tylko Epic/Legendary) | NIGDY w płatnym rollu — wyłącznie nagroda eventowa/questowa/pity |

**COMPLIANCE (twarde):** tabela płatnego rolla sumuje się DOKŁADNIE do 100.0% (84.9+10+4+1+0.1). Void świadomie NIE występuje w żadnym rollu płatnym ani opłacanym walutą kupowalną za Robux — dzięki temu nie podlega tabeli Paid Random Items. Jeśli kiedykolwiek Void wejdzie do płatnej puli, MUSI wejść do tabeli (wtedy Normal spada do 84.89%). Szanse do VariantConfig — UI tabeli szans renderuje się Z TEGO SAMEGO configa, z którego losuje RollService.

**WYDAJNOŚĆ (mobile):** animowane nakładki (Foil/Galaxy/Rainbow) renderują się TYLKO na: (a) karcie w revealu, (b) karcie w panelu detalu, (c) maks. 6 kartach widocznej siatki naraz (pooling animacji — jeden zestaw tweenów krąży po widocznych kartach). Pozostałe karty siatki pokazują statyczny tint + ikonę wariantu. Test na najsłabszym telefonie zespołu, nie na PC.

## A5. Layout karty (UITemplate "StworekCard")
Proporcja 3:4 (portret). Od góry: pasek nazwy (kolor tieru) → art 1:1 (ImageLabel, bazowy PNG 1024×1024 przycięty) → pasek żywiołu (ikona+kolor) → pole efektu (2 linie max, TextScaled, min 14pt na telefonie) → róg: klejnot rzadkości. Test: karta czytelna przy szerokości 110px.

## A6. ROSTER — 29 Stworków (★ = zestaw MVP Fazy 1, 15 szt.)

### COMMON (11) — proste bonusy, onboarding żywiołów
| # | Nazwa | Żywioł | Efekt |
|---|---|---|---|
| ★1 | **Capybop** (kapibara) | 🌿 | +20 Mocy, gdy zagranie zawiera Runę Natury |
| ★2 | **Lotti** (aksolotl) | 💧 | +20 Mocy, gdy zagranie zawiera Runę Wody |
| ★3 | **Emberpup** (ognisty szczeniak) | 🔥 | +20 Mocy, gdy zagranie zawiera Runę Ognia |
| ★4 | **Voltmouse** (mysz-błyskawica) | ⚡ | +20 Mocy, gdy zagranie zawiera Runę Błysku |
| ★5 | **Shadowkit** (kotek-cień) | 🌑 | +20 Mocy, gdy zagranie zawiera Runę Cienia |
| ★6 | **Quackers** (kaczka) | — | +1 Rezonans, gdy zagrano dokładnie 2 runy |
| ★7 | **Blobby** (blob) | — | +5 Mocy za każdą runę w zagraniu |
| 8 | **Pebble** (żółwik-kamyk) | — | +30 Mocy, gdy zagrano pojedynczą runę (Iskra) |
| ★9 | **Coinpurr** (kot-skarbonka) | — | +1 złoto po każdym zagraniu |
| 10 | **Sprouty** (kiełek) | 🌿 | Po użyciu wymiany: następne zagranie +25 Mocy |
| 11 | **Puffowl** (puchata sówka) | — | +15 Mocy do każdego zagrania |

### RARE (8) — archetypy baśniowe (public domain), warunkowe wzmocnienia
| # | Nazwa | Żywioł | Efekt |
|---|---|---|---|
| ★12 | **Drakelet** (smoczątko) | 🔥 | Zaklęcie Żywioł (3 ten sam żywioł): +2 Rezonans |
| ★13 | **Pixie Spark** (wróżka) | ⚡ | Zaklęcie Kaskada: ×2 Rezonans |
| 14 | **Lampkin** (dżinek z lampy) | — | Pierwszy re-roll sklepu w starciu darmowy; ceny −1 złota |
| ★15 | **Merlynx** (ryś-czarodziej) | — | Zaklęcie Triada: +40 Mocy i +2 Rezonans |
| ★16 | **Frostfawn** (lodowy jelonek) | 💧 | Runy Wody dają podwójną Moc |
| 17 | **Thornbun** (królik z cierniową różą) | 🌿 | −1 wymiana na starcie, ale +2 Rezonans zawsze (ryzyko/nagroda) |
| 18 | **Wispling** (duszek-płomyczek) | 🌑 | +4 Mocy za każdą runę POZOSTAWIONĄ w ręce |
| 19 | **Grimmpaw** (wilczek w czerwonym kapturku — mrugnięcie do baśni) | 🌑 | Zagranie z 2+ Runami Cienia: +3 Rezonans |

### EPIC (6) — absurd-cute hybrydy, silniki skalujące
| # | Nazwa | Żywioł | Efekt |
|---|---|---|---|
| ★20 | **Lavacat** (kot z lawy) | 🔥 | +1 Rezonans NA STAŁE (do końca runu) za każdą zagraną Nawałnicę |
| ★21 | **Thunderwolf** (wilk-burza) | ⚡ | ×2 Rezonans, gdy zagranie zawiera 4+ run |
| 22 | **Capyballoon** (kapibara-balon) | — | +1 zagranie na starcie każdego starcia |
| 23 | **Rainbowfin** (tęczowa rybka) | — | Wszystkie runy liczą się jako KAŻDY żywioł |
| 24 | **Jesterling** (chochlik-błazen) | — | 50% szansy: ×3 Rezonans (proc losowy — jackpot feeling) |
| 25 | **Clockhog** (jeż-zegarek) | — | Co trzecie zagranie w starciu: cały wynik ×2 |

### LEGENDARY (4) — opad szczęki, efekty zmieniające grę
| # | Nazwa | Żywioł | Efekt |
|---|---|---|---|
| 26 | **Astrodrake** (galaktyczny smok) | — | Rezonans ×2; Konwergencja: ×4 |
| 27 | **Dawn Phoenix** (feniks świtu) | 🔥 | Raz na starcie: gdy próg niezbity ostatnim zagraniem — odradza się i daje +1 dodatkowe zagranie (ratunek!) |
| ★28 | **Kingosaur** (dinozaur-król) | — | +100 Mocy do każdego zagrania |
| 29 | **Voidlord** (władca pustki — dla starszych 10-16) | 🌑 | Runy Cienia ×2 Moc; zagranie SAMYCH Run Cienia: ×3 Rezonans |

Balans (sanity check vs progi GDD 100→35 000): Common daje wczesne +20-30% wyniku; Epic/Legendary to power-spike ~×2-4 — zgodnie z krzywą progów ~×1.7/starcie. Wszystkie wartości w TotemConfig, tuning po playtestach.

---

# CZĘŚĆ B — GENERACJA ARTU (dla Andreasa)

## B1. Pipeline — rekomendacja: Meshy 3D → render Blenderem (nasz most) → PNG karty
Meshy generuje 3D, karty są 2D — ale to NASZA PRZEWAGA: model 3D wyrenderowany stałą kamerą i światłem daje idealnie spójne karty (spójność z setupu renderu, nie z loterii promptów). Bonus: modele 3D zostają na później (podgląd w lobby, ewentualny merch).

**Stały setup renderu (CC oskryptuje przez most :9876, jeden skrypt dla wszystkich):**
kamera ¾ z przodu, 15° nad horyzontem, ogniskowa 50mm; światło 3-punktowe miękkie (key ciepły z góry-lewej, fill chłodny, rim z tyłu); tło transparentne; render 1024×1024 PNG; model wyśrodkowany, zajmuje ~80% kadru.

**Plan awaryjny (czysty 2D):** jeśli Meshy nie uniesie stylu chibi — generator obrazów 2D z JEDNYM zablokowanym stylem (stały suffix promptu poniżej + ta sama referencja stylu dla wszystkich kart). Nigdy nie mieszać kart z obu pipeline'ów w jednym tierze.

## B2. Styl (obowiązuje KAŻDĄ kartę — to jest nasz "art bible")
Suffix do każdego promptu:
`cute chibi creature, oversized head (50% of body), big sparkling eyes, tiny body, soft rounded shapes, bold clean silhouette, bright saturated colors, cel-shaded, single character, centered, neutral pose facing 3/4 left, no text, no background`
Zasady QA (odrzucaj co nie przejdzie): 1) rozpoznawalny jako czarna sylwetka; 2) czytelny przy 110px szerokości; 3) max 3 kolory dominujące; 4) JEDNA cecha wyróżniająca widoczna w konturze; 5) mina: przyjazna (Common/Rare), pewna siebie (Epic), majestatyczna (Legendary).
Palety żywiołów: 🔥 #FF6D3F+#FFC53F · 💧 #4FC3F7+#B3E5FC · 🌿 #66BB6A+#C5E1A5 · ⚡ #FFEE58+#B39DDB · 🌑 #7E57C2+#37474F.

## B3. Opisy generacyjne per Stworek (wklejasz do Meshy/generatora + suffix z B2)

**COMMON — proste bryły, zero efektów, maks. urok:**
1. **Capybop:** `round capybara, warm brown fur, tiny green leaf on top of head, sleepy happy eyes, sitting upright like a loaf` — cecha: listek na głowie.
2. **Lotti:** `pink axolotl standing upright, six feathery external gills like a crown, wide smile, big dark eyes, tiny arms` — cecha: korona skrzeli.
3. **Emberpup:** `small puppy made of soft orange flame, flame-shaped floppy ears, tail is a candle flame, cheerful` — cecha: ogon-płomyk świeczki.
4. **Voltmouse:** `tiny yellow mouse, lightning-bolt shaped tail, spiky static-charged fur tuft, excited expression` — cecha: ogon-piorun. (UWAGA: żółta mysz = ryzyko skojarzenia z Pikachu — daj jej NIEBIESKIE pasy na grzbiecie i okrągłe uszy-anteny, żeby sylwetka była inna.)
5. **Shadowkit:** `small kitten made of dark purple smoke, glowing violet eyes, wispy smoke tail, mischievous smile` — cecha: dymny ogon.
6. **Quackers:** `plump white duckling, oversized orange beak, tiny rubber-duck proportions, one feather sticking up` — cecha: piórko-antenka.
7. **Blobby:** `teal gelatinous blob creature, simple dot eyes and wide smile, small drip on top like a water droplet crown` — cecha: kropelka na czubku.
8. **Pebble:** `tiny turtle with a smooth round rock as shell, moss patch on shell, calm smile` — cecha: mech na skorupie.
9. **Coinpurr:** `chubby golden cat shaped like a piggy bank, coin slot on back, coin held in mouth, greedy happy eyes` — cecha: szczelina na monety.
10. **Sprouty:** `small seed creature with two big green leaves as arms, sprout on head, dirt pot as lower body, eager expression` — cecha: doniczka zamiast nóg.
11. **Puffowl:** `extremely fluffy round owl, feathers like a pompom, huge round eyes, tiny beak barely visible in fluff` — cecha: kula puchu.

**RARE — dodaj: delikatny glow jednego elementu (`soft glowing accent`):**
12. **Drakelet:** `baby dragon, red-orange scales, oversized head with stubby horns, tiny wings too small to fly, small flame breath puff, proud expression` — cecha: mini-skrzydełka.
13. **Pixie Spark:** `tiny fairy creature with glowing electric-yellow wings shaped like lightning bolts, trailing sparkles, playful grin` — cecha: skrzydła-pioruny.
14. **Lampkin:** `small genie creature emerging from a tiny brass oil lamp, lower body is swirl of turquoise smoke, granting-wish hand pose, warm smile` — cecha: lampa jako dolna połowa.
15. **Merlynx:** `lynx cub wearing an oversized deep-blue wizard hat with stars, ear tufts poking through holes in hat, glowing rune floating on paw` — cecha: kapelusz z dziurami na uszy.
16. **Frostfawn:** `baby deer made of pale blue ice, crystalline tiny antlers, snowflake spots on back, gentle breath of frost, serene eyes` — cecha: kryształkowe poroże.
17. **Thornbun:** `white rabbit holding a single red rose with thorny stem, one bandaged paw, determined cute expression, petal falling` — cecha: róża większa od królika.
18. **Wispling:** `tiny ghost-flame spirit, translucent violet teardrop body, small glowing core visible inside like a lantern, curious face` — cecha: świecący rdzeń w środku.
19. **Grimmpaw:** `wolf cub wearing a red riding hood cape, hood up with ears poking through, innocent-but-sly grin, oversized paws` — cecha: czerwony kapturek.

**EPIC — dodaj: wyraźny efekt żywiołu (`glowing particles, elemental effects`):**
20. **Lavacat:** `cat made of cooling lava, black rock plates with glowing orange magma cracks between them, ember particles rising, smug expression` — cecha: pęknięcia magmy.
21. **Thunderwolf:** `wolf cub with fur made of storm clouds, small lightning bolts arcing between ears, glowing electric-blue eyes, mid-howl pose` — cecha: chmury zamiast futra.
22. **Capyballoon:** `capybara body shaped like an inflated balloon, tied balloon knot as tail, floating slightly above ground, string dangling, blissful face` — cecha: supełek balonika.
23. **Rainbowfin:** `round pufferfish-like fish floating in air, scales shifting through rainbow colors, prismatic light rays, bubble particles, joyful open mouth` — cecha: tęczowe łuski.
24. **Jesterling:** `small imp in a two-tone jester outfit (purple and gold), oversized jingle-bell hat with three points, juggling two glowing dice-like crystals, wild grin` — cecha: trójrożna czapka z dzwoneczkami.
25. **Clockhog:** `hedgehog with brass clockwork gears instead of spines, small pocket-watch face embedded in belly, steam puff, focused expression` — cecha: tarcza zegarka na brzuchu.

**LEGENDARY — dodaj: pełna aura (`majestic aura, dramatic particles, epic lighting`); mina majestatyczna:**
26. **Astrodrake:** `dragon whose body is made of deep-space galaxy texture, stars and nebulae visible inside silhouette, glowing white eyes, cosmic dust trailing from wings, regal pose` — cecha: gwiazdy WEWNĄTRZ sylwetki.
27. **Dawn Phoenix:** `phoenix chick reborn from golden sunrise flames, gradient feathers from deep red through orange to sunrise gold, halo of light behind head, wings spread upward, tiny ember feathers falling` — cecha: aureola świtu.
28. **Kingosaur:** `chubby t-rex cub wearing an oversized golden crown tilted to one side, royal red cape, tiny arms crossed, supremely confident smirk` — cecha: przekrzywiona korona.
29. **Voidlord:** `small hooded figure made of living void, star-speckled darkness under the hood with two glowing violet eyes, reality cracking slightly around it, floating ominously, purple mist` — cecha: pęknięcia rzeczywistości wokół.

## B4. Kolejność produkcji
1. Wygeneruj najpierw 3 karty testowe z RÓŻNYCH tierów (Capybop, Merlynx, Astrodrake) → oceń spójność stylu na wspólnej planszy → dopiero potem seryjnie.
2. MVP = 15 gwiazdek (★) z rosteru. Reszta w update'ach po premierze (nowy Stworek co tydzień = paliwo algorytmu).
3. Renderuj/generuj WSZYSTKIE karty jednego dnia jednym setupem — nie rozciągaj na tygodnie (dryf stylu).
