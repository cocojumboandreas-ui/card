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
		effect = { scalingFlat = { stat = "rez", perTrigger = 3 } },
	} :: TotemDef,

	blobby = {
		id = "blobby",
		name = "Blobby",
		tier = "Common",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { scalingFlat = { stat = "moc", perTrigger = 15 } },
	} :: TotemDef,

	coinpurr = {
		id = "coinpurr",
		name = "Coinpurr",
		tier = "Uncommon",
		phase = "onPlay",
		condition = "always",
		conditionArg = nil,
		effect = { scalingGold = { perTrigger = 4 } },
	} :: TotemDef,

	lavacat = {
		id = "lavacat",
		name = "Lavacat",
		tier = "Epic",
		element = "Fire",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { scalingFlat = { stat = "rez", perTrigger = 3 } },
	} :: TotemDef,

	merlynx = {
		id = "merlynx",
		name = "Merlynx",
		tier = "Rare",
		phase = "onScore",
		condition = "spellIs",
		conditionArg = "Triada",
		effect = { scalingFlat = { stat = "moc", perTrigger = 40 } },
	} :: TotemDef,
}

return TotemConfig
