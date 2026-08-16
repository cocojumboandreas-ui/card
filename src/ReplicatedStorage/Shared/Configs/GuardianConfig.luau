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
		effect = { thresholdMult = 1.25, rewardMult = 2, playsDelta = 0 },
	} :: Guardian,
}

return GuardianConfig
