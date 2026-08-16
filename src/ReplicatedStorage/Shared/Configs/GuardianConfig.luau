--!strict
-- GuardianConfig — 3 typy Strażników dla Fazy 1 (Architektura odpowiedź #7). Debuff jest czystą
-- daną, czytaną przez RunSessionService/ScoreEngine, tak jak efekty Totemów. Ten config nie
-- zawiera logiki ani RNG — "który żywioł jest martwy" dla elementEater rozstrzyga
-- RunSessionService ze strumienia SeedUtil "guardian", NIE ten plik.

export type GuardianEffect = {
	handSizeDelta: number?,
	deadElementRandom: boolean?,
	thresholdMult: number?,
	rewardMult: number?,
	playsDelta: number?,
}

export type Guardian = {
	id: string,
	name: string,
	appliesToLevels: { number },
	effect: GuardianEffect,
}

local GuardianConfig = {}

GuardianConfig.Guardians = {
	hungryShadow = {
		id = "hungryShadow",
		name = "Głodny Cień",
		appliesToLevels = { 1, 2 },
		effect = { handSizeDelta = -1 }, -- ręka 6 zamiast 7
	} :: Guardian,
	elementEater = {
		id = "elementEater",
		name = "Pożeracz Żywiołów",
		appliesToLevels = { 3, 4 },
		effect = { deadElementRandom = true }, -- losowy żywioł (stream "guardian") daje 0 Mocy w tym starciu
	} :: Guardian,
	thresholdWarden = {
		id = "thresholdWarden",
		name = "Strażnik Progu",
		appliesToLevels = { 5, 6 },
		-- Faza 3, runda 3: thresholdMult 1.5->1.25, playsDelta -1->0. Kombinacja "+50% progu I -1 zagranie"
		-- tworzyła urwisko na starciu 10 (25-seed walidacja: 6/12 przegranych właśnie tam) i nadmiarowy
		-- overshoot na starciu 12 dla ocalałych (mediana ratio 2.7-3.5x zamiast 1.0-1.3x) — kto przeżył
		-- bramkę enc10 miał już duży stos totemów skalujących i rozjeżdżał enc12 z marginesem.
		-- ZMIANA 5 (Faza 3, po dodaniu pełnego smart-bota z wymianami+zwojami jako proxy człowieka):
		-- sam podniesiony krok progów 9-12 (x1.575) zbił naive-bota do celu (44%->28%), ale pełny
		-- smart-bot nadal robił 64% (cel 30-55%). Drugi lever z kolejki użytkownika: dokręcić WYŁĄCZNIE
		-- Strażnika (enc10/enc12), nie ruszać playsDelta (poprzednia przyczyna urwiska).
		-- ZMIANA 7: 1.4 dało smart-bota na 56% (1pp nad sufitem 55%). Naive-bot NIE jest bramką
		-- (użytkownik: cel wiążący to pełny smart-bot; naive niżej = "trudno bezmyślnie", to OK).
		-- Mały domiar tylko na Strażniku.
		-- ZMIANA 8: n=25 po ZMIANIE 7 pokazał 60% (w złą stronę) -- zweryfikowane jako szum próbki:
		-- n=50 na TYM SAMYM 1.45 dał 56%, identycznie jak przed ZMIANĄ 7. 56% wciąż 1pp nad sufitem,
		-- więc kolejny mały krok 1.45->1.5, mierzony od razu na n=50 (nie n=25) dla wiarygodności.
		effect = { thresholdMult = 1.5, rewardMult = 2, playsDelta = 0 },
	} :: Guardian,
}

return GuardianConfig
