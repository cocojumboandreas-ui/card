--!strict
-- TotemConfig — the 15 ★ MVP Stworki (RUNE_RNG_STWORKI.md, canonical wherever it disagrees with
-- the GDD's superseded 6-Totem draft — odpowiedź #11/#12). Totem == Stworek: ONE system. Every
-- entry is pure data; `condition`/`effect` keys are resolved by TotemEngine's library, never by
-- this file. `phase` gates WHEN a Totem is evaluated (onScore/onPlay/onSwap/onShop/onRoundStart/
-- onFail); `condition`+`conditionArg` gate WHETHER it fires; `effect` describes WHAT it does.

export type TotemDef = {
	id: string,
	name: string,
	tier: string,
	element: string?,
	phase: string,
	condition: string,
	conditionArg: any,
	effect: { [string]: any },
}

local TotemConfig = {}

-- Balance pass (Faza 3, po 25-seed walidacji): 5 flat / 5 multiplikatywnych / 5 skalujących w runie.
-- Flat = early-game onboarding (niezmienione). Multiplikatywne = główna dźwignia late-game (rezMult/
-- mocMult warunkowe). Skalujące = drugie geometryczne źródło mocy — rosną co aplikację przez
-- TotemEngine's `scalingFlat`/`scalingGold` (perTrigger * stacks), stan w run.totemState.
--
-- Eskalacja liczb (Faza 3, runda 2, po 25-seed walidacji #1: ściana się NIE przesunęła, mediana
-- ratio spadła poniżej 1.0 już na starciu 8, 0/25 ukończeń). Wszystkie perTrigger ~x3, wszystkie
-- mult-factory podniesione proporcjonalnie do kingosaura (1.5->2.2) — nie tylko przykładowa trójka
-- z decyzji, cały roster spójnie, żeby run bez akurat TEGO jednego totemu też skorzystał.
--
-- Korekta w dół (Faza 3, runda 4, po naprawie thresholdWarden): mediana ratio na starciu 12 nadal
-- 2.9-3.2x (target 1.0-1.3x) niezależnie od tuningu Strażnika, a ukończenia wyskoczyły do 64-76%
-- (target 30-60%) — SKALUJĄCE totemy rosną cały run bez limitu, więc to one, nie Strażnik, ciągną
-- late-game overshoot. Cięcie ~20-33% na wszystkich 5 (multiplikatywne bez zmian).
--
-- Korekta w dół (Faza 3, runda 5, WYCOFANA w rundzie 6): cięcie multiplikatywnych o ~15% było oparte
-- o walidację 25-seedów ze ZEPSUTYM harnessem (PlayService.play wołany ze złym argumentem — pcall
-- łykał błąd, każdy seed "przegrywał" starcie 1 z ratio 0.00, więc żadna z liczb rund 2-5 nie była
-- realna). Po naprawie harnessu (runda 6): starcie 12 wychodzi 1.11-1.15x (W WIDEŁKACH) już na
-- wartościach rundy 4, a ukończenia spadły do 16% z klifem na starciu 8 — runda 5 cięła coś, co nie
-- było przewinieniem. Wartości MULTIPLIKATYWNE przywrócone do stanu sprzed rundy 5.
TotemConfig.Totems = {
	-- Common starter foursome: +20 Moc flat when the play contains their element.
	capybop = {
		id = "capybop",
		name = "Capybop",
		tier = "Common",
		element = "Nature",
		phase = "onScore",
		condition = "playContainsElement",
		conditionArg = "Nature",
		effect = { mocFlat = 20 },
	} :: TotemDef,
	lotti = {
		id = "lotti",
		name = "Lotti",
		tier = "Common",
		element = "Water",
		phase = "onScore",
		condition = "playContainsElement",
		conditionArg = "Water",
		effect = { mocFlat = 20 },
	} :: TotemDef,
	emberpup = {
		id = "emberpup",
		name = "Emberpup",
		tier = "Common",
		element = "Fire",
		phase = "onScore",
		condition = "playContainsElement",
		conditionArg = "Fire",
		effect = { mocFlat = 20 },
	} :: TotemDef,
	voltmouse = {
		id = "voltmouse",
		name = "Voltmouse",
		tier = "Common",
		element = "Lightning",
		phase = "onScore",
		condition = "playContainsElement",
		conditionArg = "Lightning",
		effect = { mocFlat = 20 },
	} :: TotemDef,
	shadowkit = {
		id = "shadowkit",
		name = "Shadowkit",
		tier = "Common",
		element = "Shadow",
		phase = "onScore",
		condition = "playContainsElement",
		conditionArg = "Shadow",
		effect = { mocFlat = 20 },
	} :: TotemDef,

	-- MULTIPLIKATYWNE (5) — główna dźwignia late-game, warunkowe rezMult/mocMult.
	pixiespark = {
		id = "pixiespark",
		name = "Pixie Spark",
		tier = "Uncommon",
		element = "Lightning",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Kaskada",
		effect = { rezMult = 2.7 },
	} :: TotemDef,

	thunderwolf = {
		id = "thunderwolf",
		name = "Thunderwolf",
		tier = "Epic",
		element = "Lightning",
		phase = "onScore",
		condition = "playedCountAtLeast",
		conditionArg = 4,
		effect = { rezMult = 2.7 },
	} :: TotemDef,

	frostfawn = {
		id = "frostfawn",
		name = "Frostfawn",
		tier = "Rare",
		element = "Water",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { mocMultElement = { element = "Water", factor = 2.7 } },
	} :: TotemDef,

	drakelet = {
		id = "drakelet",
		name = "Drakelet",
		tier = "Uncommon",
		element = "Fire",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Zywiol",
		effect = { rezMult = 2.0 },
	} :: TotemDef,

	kingosaur = {
		id = "kingosaur",
		name = "Kingosaur",
		tier = "Legendary",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { mocMult = 2.2 },
	} :: TotemDef,

	-- SKALUJĄCE (5) — rosną W RUNIE (perTrigger * stacks, stan w run.totemState), drugie geometryczne
	-- źródło mocy obok multiplikatywnych. Bez ponownego zakupu — stack rośnie automatycznie co aplikację.
	quackers = {
		id = "quackers",
		name = "Quackers",
		tier = "Common",
		phase = "onScore",
		condition = "exactPlayedCount",
		conditionArg = 2,
		effect = { scalingFlat = { stat = "rez", perTrigger = 2 } },
	} :: TotemDef,

	blobby = {
		id = "blobby",
		name = "Blobby",
		tier = "Common",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { scalingFlat = { stat = "moc", perTrigger = 12 } },
	} :: TotemDef,

	coinpurr = {
		id = "coinpurr",
		name = "Coinpurr",
		tier = "Uncommon",
		phase = "onPlay",
		condition = "always",
		conditionArg = nil,
		effect = { scalingGold = { perTrigger = 3 } },
	} :: TotemDef,

	lavacat = {
		id = "lavacat",
		name = "Lavacat",
		tier = "Epic",
		element = "Fire",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { scalingFlat = { stat = "rez", perTrigger = 2 } },
	} :: TotemDef,

	merlynx = {
		id = "merlynx",
		name = "Merlynx",
		tier = "Rare",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Triada",
		effect = { scalingFlat = { stat = "moc", perTrigger = 32 } },
	} :: TotemDef,

	-- System 2 (nowe Stworki, 2026-08-18) — 10 dodatkowych, art z cardsw/Meshy_AI_*, wycięte tłem
	-- (scripts/bg_remove -- patrz STATUS.md). Efekty tematyczne wg żywiołu/charakteru, ale KAŻDY
	-- trzyma się DOKŁADNIE jednego z 4 sprawdzonych archetypów istniejących 15 (flat-elemental /
	-- warunkowy mult / mocMultElement / scalingFlat) -- zero nowych prymitywów silnika (procChance/
	-- revive/elementWildcard zostają nieużyte, brak danych kalibracyjnych z produkcji). Bramka
	-- balansu: tests/BalanceHarness.studio.luau, decki z nowymi Stworkami, FULL-SMART 30-55%.
	-- Bramka #1 (2026-08-18, deck=dokladnie tych 10, n=50): NAIVE 18%, FULL-SMART 58% -- PRZESTRZAL.
	-- Galaxeon (mocMult 4.0 na Konwergencji) byl podejrzanym #1 wg przewidywania -- WYKLUCZONY przez
	-- ablację (zjazd 4.0->1.0 przy n=50 dal identyczny wynik: 58%==58%, zero wplywu). Prawdziwi
	-- winowajcy znalezieni sweepem ablacyjnym per-totem (n=20): oba SCALINGFLAT bez warunku
	-- (condition="always") -- Vinelet (+10pp przy neutralizacji) i Shardmaw (+20pp przy neutralizacji,
	-- razem +40pp) -- dokladnie ten sam wzorzec co Faza 3 runda 4 (skalujące bez limitu ciągną
	-- late-game). Boltpup i Emberwing przetestowane ablacyjnie jako OBOJĘTNE (zero wpływu). Naprawa:
	-- perTrigger obu ściętych o 50% (Vinelet 16->8, Shardmaw 24->12) -- przy n=20 dalo 45% (środek
	-- widelek), potwierdzone przy n=50 ponizej. Galaxeon zostawiony na 3.5 (nieszkodliwa normalizacja
	-- wzgledem reszty rosteru, nie jest przyczyną, nie ma powodu cofać).
	pebblit = {
		id = "pebblit",
		name = "Pebblit",
		tier = "Common",
		element = "Nature",
		phase = "onScore",
		condition = "playContainsElement",
		conditionArg = "Nature",
		effect = { mocFlat = 20 },
	} :: TotemDef,

	sparkfly = {
		id = "sparkfly",
		name = "Sparkfly",
		tier = "Common",
		element = "Lightning",
		phase = "onScore",
		condition = "exactPlayedCount",
		conditionArg = 1,
		effect = { scalingFlat = { stat = "rez", perTrigger = 2 } },
	} :: TotemDef,

	puffcap = {
		id = "puffcap",
		name = "Puffcap",
		tier = "Common",
		element = "Nature",
		phase = "onPlay",
		condition = "always",
		conditionArg = nil,
		effect = { scalingGold = { perTrigger = 1 } },
	} :: TotemDef,

	frostnib = {
		id = "frostnib",
		name = "Frostnib",
		tier = "Uncommon",
		element = "Water",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Nawalnica",
		effect = { rezMult = 2.7 },
	} :: TotemDef,

	-- Retem (2026-08-18): po cięciu 16->8 Vinelet był strictly gorszy od blobby (Common, moc+12
	-- zawsze) -- sama stat + sam warunek, więc czyste porównanie liczb, Uncommon przegrywał
	-- Common. Zero bezwarunkowego Common scalingFlat na "rez" w rosterze (quackers/sparkfly to
	-- Common ale WARUNKOWE; jedyny bezwarunkowy rez-scaler to lavacat, Epic, perTrigger=2) --
	-- przeniesiony na inną statystykę (rez) zamiast moc, żeby nie było już bezpośredniego
	-- porównania 1:1 z blobby. perTrigger=1 < lavacat (Epic, unconditional, perTrigger=2), żeby
	-- Uncommon nie dorównywał Epic. Motyw "pnącza" (oplatające/wzmacniające) bez zmian.
	-- Bramka po fixie (n=50, deck=dokladnie tych 10 nowych, ta sama sciezka co Bramka #1): NAIVE
	-- 18% (bez zmian), FULL-SMART 50% (bylo 46% przed fixem, w widelkach 30-55%) -- PASS. Pick
	-- share Vineleta 50% (nie martwa karta, nie dominuje). Przy okazji naprawiony desync Studio:
	-- live Bootstrap.server.luau nie mial "DeckService" w ORDER (brak na dysku od MAX-SLOT), wiec
	-- SetDeck/GetDeck realnie nie dzialaly zanim to zauwazono -- napraw recznie po kazdym resyncu
	-- placu, patrz STATUS.md.
	-- Znaleziony przy okazji, NIE naprawiony (poza scope tej sesji): shardmaw (Epic) po cięciu
	-- 24->12 ma DOKLADNIE ta sama wartosc co blobby (Common) -- oba scalingFlat{moc}, condition=
	-- always, perTrigger=12. Nie "strictly gorszy" (remis, nie dominacja), ale ten sam wzorzec co
	-- Vinelet: Epic nie powinien byc rownowazny Common. Do rozwazenia w kolejnej rundzie balansu.
	vinelet = {
		id = "vinelet",
		name = "Vinelet",
		tier = "Uncommon",
		element = "Nature",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { scalingFlat = { stat = "rez", perTrigger = 1 } },
	} :: TotemDef,

	boltpup = {
		id = "boltpup",
		name = "Boltpup",
		tier = "Rare",
		element = "Lightning",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { mocMultElement = { element = "Lightning", factor = 2.7 } },
	} :: TotemDef,

	tidalox = {
		id = "tidalox",
		name = "Tidalox",
		tier = "Rare",
		element = "Water",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Echo",
		effect = { scalingFlat = { stat = "rez", perTrigger = 2 } },
	} :: TotemDef,

	emberwing = {
		id = "emberwing",
		name = "Emberwing",
		tier = "Epic",
		element = "Fire",
		phase = "onScore",
		condition = "playedCountAtLeast",
		conditionArg = 4,
		effect = { mocMultElement = { element = "Fire", factor = 3.5 } },
	} :: TotemDef,

	-- Fix (2026-08-18): scalingFlat{moc,12} unconditional byl LICZBOWO ROWNY blobby (Common) -- ten
	-- sam wzorzec co Vinelet powyzej (bezwarunkowe skalowanie = winowajca overshootu, patrz komentarz
	-- "Nowe Stworki"). Przeniesiony na warunkowy mocMult (wzor Emberwing/Thunderwolf -- Epic to tier
	-- MULTIPLIKATYWNY), NIE dalszy scalingFlat -- rez zajety przez Vinelet/Lavacat, moc-scalingFlat
	-- to dokladnie ta nisza co spowodowala przestrzal. playedCountAtLeast(5) = pelna reka
	-- (GameConfig.MaxPlaySize=5), ostrzejszy prog niz Thunderwolf/Emberwing (4) -- temat "odlamki
	-- krysztalu pekaja gdy reka pelna", odrebna nisza "finiszera" zamiast duplikowac ich trigger.
	-- mocMult=2.0 zwalidowane bramka (2026-08-18, n=50, deck z tymi 10 totemami, PO naprawie
	-- crowd-out buga w BalanceHarness.studio.luau -- patrz STATUS.md "Gate PASS po naprawie
	-- harnessu"): FULL-SMART 44% (widelki 30-55%), PASS. Shardmaw pick share 44-50%, uzywany, nie
	-- martwy.
	shardmaw = {
		id = "shardmaw",
		name = "Shardmaw",
		tier = "Epic",
		phase = "onScore",
		condition = "playedCountAtLeast",
		conditionArg = 5,
		effect = { mocMult = 2.0 },
	} :: TotemDef,

	-- Galaxeon 3.5->4.0 (2026-08-18): ablacja "Nowe Stworki" udowodnila 0 wplywu na FULL-SMART przy
	-- n=50 (zjazd 4.0->1.0 = identyczny wynik) -- niekauzalny w tym decku, wiec podbicie feelu
	-- Legendary bez ryzyka balansowego, bramka nie wymaga ponownego pomiaru tej zmiany osobno.
	galaxeon = {
		id = "galaxeon",
		name = "Galaxeon",
		tier = "Legendary",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Konwergencja",
		effect = { mocMult = 4.0 },
	} :: TotemDef,
}

return TotemConfig
