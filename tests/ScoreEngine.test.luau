--!strict
-- Headless tests for ScoreEngine: base formula, elemental pre-pass (Frostfawn), totem order
-- sensitivity (flat-then-mult per totem, slot order changes the final score), Strażnik
-- element-nullifier debuff, determinism. No Studio required.
--   luau tests/ScoreEngine.test.luau

local ScoreEngine = require("../src/ReplicatedStorage/Shared/ScoreEngine")
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

-- Bez totemów: Iskra na runie wartości 4 (Moc runy = 20). (10+20)*1 = 30.
do
	local runes = { { element = "Fire", value = 4 } }
	local spell = { spellId = "Iskra", baseMoc = 10, baseRezonans = 1 }
	local result = ScoreEngine.score(runes, spell, nil, nil)
	check("Iskra bez totemów: finalScore == 30", result.finalScore == 30)
	check("moc == 30, rezonans == 1", result.moc == 30 and result.rezonans == 1)
end

-- Echo: dwie runy wartości 3 (power 15 każda). (20+30)*2 = 100.
do
	local runes = { { element = "Fire", value = 3 }, { element = "Water", value = 3 } }
	local spell = { spellId = "Echo", baseMoc = 20, baseRezonans = 2 }
	local result = ScoreEngine.score(runes, spell, nil, nil)
	check("Echo bez totemów: finalScore == 100", result.finalScore == 100)
end

-- Frostfawn: Woda daje podwójną Moc, aplikowane w pętli run (PRZED sumą flat totemów).
do
	local runes = { { element = "Water", value = 4 }, { element = "Fire", value = 2 } }
	local spell = { spellId = "Echo", baseMoc = 20, baseRezonans = 2 }
	local runState = { totems = { TotemConfig.Totems.frostfawn } }
	local result = ScoreEngine.score(runes, spell, runState, nil)
	-- Water(4): power 20 -> x2.7 (eskalacja Faza 3 runda 2) = 54. Fire(2): power 10 (bez zmian).
	-- Moc = 20(spell) + 54 + 10 = 84.
	check("Frostfawn multiplies Water rune Moc: moc == 84", result.moc == 84)
	check("Frostfawn: finalScore == 168", result.finalScore == 168)
end

-- Kolejność totemów zmienia wynik: flat totem PRZED mult totem vs PO (syntetyczne totemy,
-- izolują mechanizm od warunków konkretnych ★Stworków).
do
	local runes = {}
	local spell = { spellId = "Iskra", baseMoc = 10, baseRezonans = 1 }
	local flatTotem = { id = "flat", name = "flat", tier = "Common", phase = "onScore", condition = "always", conditionArg = nil, effect = { rezFlat = 5 } }
	local multTotem = { id = "mult", name = "mult", tier = "Common", phase = "onScore", condition = "always", conditionArg = nil, effect = { rezMult = 2 } }

	local flatFirst = ScoreEngine.score(runes, spell, { totems = { flatTotem, multTotem } }, nil)
	local multFirst = ScoreEngine.score(runes, spell, { totems = { multTotem, flatTotem } }, nil)

	-- flatFirst: rez = (1+5)*2 = 12. multFirst: rez = (1*2)+5 = 7.
	check("flat-then-mult order: rezonans == 12", flatFirst.rezonans == 12)
	check("mult-then-flat order: rezonans == 7", multFirst.rezonans == 7)
	check("totem order changes the final score", flatFirst.finalScore ~= multFirst.finalScore)
end

-- To samo, na realnym totemie z rosteru (Merlynx: scalingFlat moc, warunkowany na Triadzie,
-- 1. trigger -> +15 moc) sparowanym z syntetycznym mocMult -- oba na tej samej osi (moc), żeby
-- kolejność faktycznie coś zmieniała (Merlynx po redesignie Fazy 3 nie dotyka już Rezonansu).
do
	local runes = { { element = "Fire", value = 4 }, { element = "Water", value = 4 }, { element = "Nature", value = 4 } }
	local spell = { spellId = "Triada", baseMoc = 40, baseRezonans = 3 }
	local mocMultOnTriada =
		{ id = "synthMult", name = "synthMult", tier = "Common", phase = "onScore", condition = "spellIs", conditionArg = "Triada", effect = { mocMult = 2 } }

	-- moc bez totemów = 40(spell) + 20*3(runy, value4->power20) = 100. Merlynx perTrigger=40 (eskalacja
	-- Faza 3 runda 2).
	local merlynxFirst = ScoreEngine.score(runes, spell, { totems = { TotemConfig.Totems.merlynx, mocMultOnTriada } }, nil)
	local multFirst2 = ScoreEngine.score(runes, spell, { totems = { mocMultOnTriada, TotemConfig.Totems.merlynx } }, nil)
	-- Merlynx-then-mult: (100+40)*2 = 280. mult-then-Merlynx: (100*2)+40 = 240.
	check("Merlynx-then-mult moc == 280", merlynxFirst.moc == 280)
	check("mult-then-Merlynx moc == 240", multFirst2.moc == 240)
	check("real-totem order changes finalScore too", merlynxFirst.finalScore ~= multFirst2.finalScore)
end

-- Strażnik "Pożeracz Żywiołów": nullifikowany żywioł daje 0 Mocy w tej rundzie.
do
	local runes = { { element = "Fire", value = 6 }, { element = "Water", value = 2 } }
	local spell = { spellId = "Echo", baseMoc = 20, baseRezonans = 2 }
	local runState = { elementNullifiers = { Fire = true } }
	local result = ScoreEngine.score(runes, spell, runState, nil)
	-- Fire(6) power=30 -> nullified to 0. Water(2) power=10 niezmieniona. Moc = 20+0+10=30.
	check("nullified Fire rune contributes 0 Moc", result.moc == 30)
end

-- Determinizm: identyczne wejście -> identyczny wynik i identyczny breakdown.
do
	local runes = { { element = "Shadow", value = 5 }, { element = "Fire", value = 5 } }
	local spell = { spellId = "Echo", baseMoc = 20, baseRezonans = 2 }
	local runState = { totems = { TotemConfig.Totems.kingosaur } }
	local r1 = ScoreEngine.score(runes, spell, runState, nil)
	local r2 = ScoreEngine.score(runes, spell, runState, nil)
	check("determinism: same finalScore", r1.finalScore == r2.finalScore)
	check("determinism: same breakdown length", #r1.breakdown == #r2.breakdown)
end

if failures > 0 then
	error(`{failures} ScoreEngine test(s) failed`)
end
print("All ScoreEngine tests passed.")
