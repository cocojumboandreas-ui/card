--!strict
-- Headless tests for TotemEngine: condition library, effect application, phase dispatch
-- (including onSwap/onFail, which no ★MVP totem currently uses but the effect library must
-- still support), scalingFlat/scalingGold state threading, procChance via a SeedUtil stream. No
-- Studio required.
--   luau tests/TotemEngine.test.luau

local TotemEngine = require("../src/ReplicatedStorage/Shared/TotemEngine")
local SeedUtil = require("../src/ReplicatedStorage/Shared/SeedUtil")
local TotemConfig = require("../src/ReplicatedStorage/Shared/Configs/TotemConfig")

local failures = 0
local function check(label: string, cond: boolean)
	if cond then
		print("ok    " .. label)
	else
		failures += 1
		print("FAIL  " .. label)
	end
end

-- playContainsElement (Capybop).
do
	local ctx = { playedRunes = { { element = "Nature", value = 3 } }, spellId = "Iskra", totemState = {} }
	local results = TotemEngine.apply({ TotemConfig.Totems.capybop }, "onScore", ctx)
	check("Capybop fires on Nature play", results[1].applies == true and results[1].delta.mocFlat == 20)

	local ctxNo = { playedRunes = { { element = "Fire", value = 3 } }, spellId = "Iskra", totemState = {} }
	local resultsNo = TotemEngine.apply({ TotemConfig.Totems.capybop }, "onScore", ctxNo)
	check("Capybop does not fire without Nature", resultsNo[1].applies == false)
end

-- exactPlayedCount (Quackers).
do
	local ctx2 = {
		playedRunes = { { element = "Fire", value = 1 }, { element = "Water", value = 2 } },
		spellId = "Echo",
		totemState = {},
	}
	local r2 = TotemEngine.apply({ TotemConfig.Totems.quackers }, "onScore", ctx2)
	check("Quackers fires on exactly 2 played", r2[1].applies == true and r2[1].delta.rezFlat == 3)

	local ctx3 = {
		playedRunes = { { element = "Fire", value = 1 }, { element = "Water", value = 2 }, { element = "Nature", value = 3 } },
		spellId = "Triada",
		totemState = {},
	}
	local r3 = TotemEngine.apply({ TotemConfig.Totems.quackers }, "onScore", ctx3)
	check("Quackers does not fire on 3 played", r3[1].applies == false)
end

-- scalingFlat (Blobby): stack++ EVERY application (condition=always), amount = perTrigger * stacks.
-- State threading across calls, same pattern PlayService uses (statePatch persisted by caller).
do
	local totemState = {}
	local ctx1 = { playedRunes = {}, spellId = "Iskra", totemState = totemState }
	local r1 = TotemEngine.apply({ TotemConfig.Totems.blobby }, "onScore", ctx1)
	check("Blobby 1st trigger -> mocFlat 15 (perTrigger 15 * stack 1)", r1[1].delta.mocFlat == 15)
	totemState.blobby = r1[1].statePatch -- caller (PlayService) persists this; simulated here

	local ctx2 = { playedRunes = {}, spellId = "Iskra", totemState = totemState }
	local r2 = TotemEngine.apply({ TotemConfig.Totems.blobby }, "onScore", ctx2)
	check("Blobby 2nd trigger -> mocFlat 30 (perTrigger 15 * stack 2)", r2[1].delta.mocFlat == 30)
end

-- phase filtering: Coinpurr is onPlay, must NOT fire under onScore.
do
	local ctx = { playedRunes = { { element = "Fire", value = 1 } }, spellId = "Iskra", totemState = {} }
	local rOnScore = TotemEngine.apply({ TotemConfig.Totems.coinpurr }, "onScore", ctx)
	check("Coinpurr does not appear under onScore phase", #rOnScore == 0)
	local rOnPlay = TotemEngine.apply({ TotemConfig.Totems.coinpurr }, "onPlay", ctx)
	check("Coinpurr fires under onPlay with +4 gold (scalingGold 1st trigger)", rOnPlay[1].applies == true and rOnPlay[1].delta.goldFlat == 4)
end

-- scalingFlat (Lavacat, rez axis): stacks persist across calls via totemState threading,
-- condition=always so every onScore application counts regardless of spellId.
do
	local totemState = {}
	local ctxPlay1 = { playedRunes = {}, spellId = "Nawalnica", totemState = totemState }
	local r1 = TotemEngine.apply({ TotemConfig.Totems.lavacat }, "onScore", ctxPlay1)
	check("Lavacat 1st trigger -> +3 Rez", r1[1].delta.rezFlat == 3)
	totemState.lavacat = r1[1].statePatch -- caller (PlayService) persists this; simulated here

	local ctxPlay2 = { playedRunes = {}, spellId = "Iskra", totemState = totemState }
	local r2 = TotemEngine.apply({ TotemConfig.Totems.lavacat }, "onScore", ctxPlay2)
	check("Lavacat 2nd trigger (any spell, condition=always) -> +6 Rez", r2[1].delta.rezFlat == 6)
	totemState.lavacat = r2[1].statePatch

	local ctxPlay3 = { playedRunes = {}, spellId = "Nawalnica", totemState = totemState }
	local r3 = TotemEngine.apply({ TotemConfig.Totems.lavacat }, "onScore", ctxPlay3)
	check("Lavacat 3rd trigger -> +9 Rez", r3[1].delta.rezFlat == 9)
end

-- procChance via SeedUtil "totemProc" stream (synthetic totem — not in ★MVP, covered here for
-- roster-effect-key completeness).
do
	local jesterling = {
		id = "jesterling_synthetic",
		name = "Jesterling (test)",
		tier = "Epic",
		phase = "onScore",
		condition = "always",
		conditionArg = nil,
		effect = { procChance = { chance = 1.0, onSuccess = { rezMult = 3 } } },
	}
	local stream = SeedUtil.newStream(42, "totemProc")
	local ctx = { playedRunes = {}, spellId = "Iskra", totemState = {}, rngStream = stream }
	local r = TotemEngine.apply({ jesterling }, "onScore", ctx)
	check("procChance=1.0 always succeeds -> rezMult applied", r[1].delta.rezMult == 3)

	local jesterlingNever = table.clone(jesterling)
	jesterlingNever.effect = { procChance = { chance = 0.0, onSuccess = { rezMult = 3 } } }
	local r2 = TotemEngine.apply({ jesterlingNever }, "onScore", ctx)
	check("procChance=0.0 never succeeds -> no rezMult", r2[1].delta.rezMult == nil)
end

-- onSwap phase (Sprouty-style, not in ★MVP) — proves the phase enum/dispatch works generically.
do
	local sprouty = {
		id = "sprouty_synthetic",
		name = "Sprouty (test)",
		tier = "Common",
		phase = "onSwap",
		condition = "always",
		conditionArg = nil,
		effect = { mocFlat = 25 },
	}
	local ctx = { playedRunes = {}, spellId = nil, totemState = {} }
	local rSwap = TotemEngine.apply({ sprouty }, "onSwap", ctx)
	check("onSwap phase totem fires under onSwap", rSwap[1].applies == true and rSwap[1].delta.mocFlat == 25)
	local rScore = TotemEngine.apply({ sprouty }, "onScore", ctx)
	check("onSwap phase totem does not fire under onScore", #rScore == 0)
end

-- onFail / revive (Dawn Phoenix-style, not in ★MVP) — "raz na starcie" gate via totemState.used.
do
	local phoenix = {
		id = "phoenix_synthetic",
		name = "Dawn Phoenix (test)",
		tier = "Legendary",
		phase = "onFail",
		condition = "notYetTriggeredThisEncounter",
		conditionArg = nil,
		effect = { revive = true, reviveExtraPlay = 1 },
	}
	local totemState = {}
	local ctx1 = { playedRunes = {}, spellId = nil, totemState = totemState }
	local r1 = TotemEngine.apply({ phoenix }, "onFail", ctx1)
	check("Phoenix revives the first time", r1[1].applies == true and r1[1].delta.revive == true and r1[1].delta.extraPlay == 1)
	totemState.phoenix_synthetic = r1[1].statePatch -- PlayService would persist this

	local ctx2 = { playedRunes = {}, spellId = nil, totemState = totemState }
	local r2 = TotemEngine.apply({ phoenix }, "onFail", ctx2)
	check("Phoenix does not revive twice in the same encounter", r2[1].applies == false)
end

-- Kolejność slotów jest ZACHOWANA w wynikach (aplikację order-sensitive robi ScoreEngine —
-- patrz ScoreEngine.test.luau dla dowodu liczbowego (base+5)*2 vs (base*2)+5).
do
	local flatTotem = { id = "flat", name = "flat", tier = "Common", phase = "onScore", condition = "always", conditionArg = nil, effect = { rezFlat = 5 } }
	local multTotem = { id = "mult", name = "mult", tier = "Common", phase = "onScore", condition = "always", conditionArg = nil, effect = { rezMult = 2 } }
	local ctx = { playedRunes = {}, spellId = "Iskra", totemState = {} }

	local orderA = TotemEngine.apply({ flatTotem, multTotem }, "onScore", ctx)
	local orderB = TotemEngine.apply({ multTotem, flatTotem }, "onScore", ctx)
	check("apply() preserves slot order A", orderA[1].totemId == "flat" and orderA[2].totemId == "mult")
	check("apply() preserves slot order B", orderB[1].totemId == "mult" and orderB[2].totemId == "flat")
end

if failures > 0 then
	error(`{failures} TotemEngine test(s) failed`)
end
print("All TotemEngine tests passed.")
