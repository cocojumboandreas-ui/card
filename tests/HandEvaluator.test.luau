--!strict
-- Headless tests for HandEvaluator: subset-search matching, "highest realized score wins" spell
-- priority (incl. spellUpgrades), consecutive-straight semantics for Kaskada/Konwergencja, and
-- auto-suggest over a full 7-Rune hand. No Studio required.
--   luau tests/HandEvaluator.test.luau

local HandEvaluator = require("../src/ReplicatedStorage/Shared/HandEvaluator")

local failures = 0
local function check(label: string, cond: boolean)
	if cond then
		print("ok    " .. label)
	else
		failures += 1
		print("FAIL  " .. label)
	end
end

local function idxEqual(a: { number }, b: { number }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

-- Iskra: pojedyncza runa zawsze pasuje.
do
	local runes = { { element = "Fire", value = 4 } }
	local result = HandEvaluator.evaluate(runes)
	check("single rune -> Iskra", result ~= nil and result.spellId == "Iskra")
	check("Iskra base 10/1", result.baseMoc == 10 and result.baseRezonans == 1)
	check("matchedRunes == {1}", idxEqual(result.matchedRunes, { 1 }))
end

-- Echo bije Iskrę, gdy dwie runy mają tę samą wartość.
do
	local runes = { { element = "Fire", value = 3 }, { element = "Water", value = 3 } }
	local result = HandEvaluator.evaluate(runes)
	check("same-value pair -> Echo (beats Iskra)", result ~= nil and result.spellId == "Echo")
	check("matchedRunes == {1,2}", idxEqual(result.matchedRunes, { 1, 2 }))
end

-- Triada (3× ta sama wartość, różne żywioły) vs Zywiol (3× ten sam żywioł, różne wartości) —
-- rozróżnienie subset-match, nie fixed-hierarchy.
do
	local triadaRunes = { { element = "Fire", value = 4 }, { element = "Water", value = 4 }, { element = "Nature", value = 4 } }
	local result = HandEvaluator.evaluate(triadaRunes)
	check("3x same value, diff elements -> Triada", result ~= nil and result.spellId == "Triada")
	check("Triada matchedRunes == {1,2,3}", idxEqual(result.matchedRunes, { 1, 2, 3 }))

	local zywiolRunes = { { element = "Fire", value = 2 }, { element = "Fire", value = 5 }, { element = "Fire", value = 7 } }
	local result2 = HandEvaluator.evaluate(zywiolRunes)
	check("3x same element, diff values -> Zywiol", result2 ~= nil and result2.spellId == "Zywiol")
end

-- Kaskada: 4 KOLEJNE wartości (nie dowolne 4 różne, posortowane).
do
	local straight = {
		{ element = "Fire", value = 3 },
		{ element = "Water", value = 4 },
		{ element = "Nature", value = 5 },
		{ element = "Lightning", value = 6 },
	}
	local result = HandEvaluator.evaluate(straight)
	check("4 consecutive values -> Kaskada", result ~= nil and result.spellId == "Kaskada")

	local gapped = {
		{ element = "Fire", value = 3 },
		{ element = "Water", value = 4 },
		{ element = "Nature", value = 6 },
		{ element = "Lightning", value = 7 },
	}
	local result2 = HandEvaluator.evaluate(gapped)
	-- 3,4,6,7 nie są kolejne (dziura 4->6) -> brak Kaskady; jedyny kandydat to Iskra na
	-- najsilniejszej runie (Lightning,7, power 35).
	check("non-consecutive 4 values -> NOT Kaskada", result2 ~= nil and result2.spellId == "Iskra")
	check("falls back to strongest single rune (index 4)", idxEqual(result2.matchedRunes, { 4 }))
end

-- Nawalnica: 5x ten sam żywiół (wartości dowolne) bije Zywiol/Iskra na tym samym zbiorze.
do
	local runes = {
		{ element = "Fire", value = 1 },
		{ element = "Fire", value = 3 },
		{ element = "Fire", value = 5 },
		{ element = "Fire", value = 6 },
		{ element = "Fire", value = 8 },
	}
	local result = HandEvaluator.evaluate(runes)
	check("5x same element -> Nawalnica", result ~= nil and result.spellId == "Nawalnica")
	check("Nawalnica matchedRunes == {1,2,3,4,5}", idxEqual(result.matchedRunes, { 1, 2, 3, 4, 5 }))
end

-- Konwergencja: 5 kolejnych wartości + 5 różnych żywiołów, bije zagnieżdżoną Kaskadę (4-subset).
do
	local runes = {
		{ element = "Fire", value = 2 },
		{ element = "Water", value = 3 },
		{ element = "Nature", value = 4 },
		{ element = "Lightning", value = 5 },
		{ element = "Shadow", value = 6 },
	}
	local result = HandEvaluator.evaluate(runes)
	check("5 consecutive values + 5 distinct elements -> Konwergencja", result ~= nil and result.spellId == "Konwergencja")
	check("Konwergencja matchedRunes == {1,2,3,4,5}", idxEqual(result.matchedRunes, { 1, 2, 3, 4, 5 }))
end

-- spellUpgrades mogą zmienić zwycięzcę: Iskra z dużym rezMult bije normalnie silniejsze Echo.
-- (ZMIANA 2, Faza 3: ulepszenia są multiplikatywne na Rezonansie, nie flat.)
do
	local runes = { { element = "Fire", value = 3 }, { element = "Water", value = 3 } }
	local upgrades = { Iskra = { rezMult = 6 } }
	local result = HandEvaluator.evaluate(runes, upgrades)
	-- Echo un-upgraded: (20+30)*2 = 100. Iskra upgraded: (10+15)*(1*6) = 150 > 100.
	check("upgraded Iskra beats un-upgraded Echo", result ~= nil and result.spellId == "Iskra")
	check("upgrade applied: baseRezonans == 6", result.baseRezonans == 6)
end

-- Auto-suggest: 7-Runowa ręka, ukryta Triada (3 szóstki) w szumie innych run.
do
	local hand = {
		{ element = "Fire", value = 1 }, -- 1
		{ element = "Water", value = 2 }, -- 2
		{ element = "Nature", value = 6 }, -- 3
		{ element = "Lightning", value = 6 }, -- 4
		{ element = "Shadow", value = 6 }, -- 5
		{ element = "Fire", value = 7 }, -- 6
		{ element = "Water", value = 8 }, -- 7
	}
	local result = HandEvaluator.evaluate(hand)
	check("7-rune hand finds hidden Triada", result ~= nil and result.spellId == "Triada")
	check("hidden Triada matchedRunes == {3,4,5}", idxEqual(result.matchedRunes, { 3, 4, 5 }))
end

-- Determinizm: to samo wejście -> ten sam wynik.
do
	local runes = { { element = "Shadow", value = 5 }, { element = "Fire", value = 5 } }
	local r1 = HandEvaluator.evaluate(runes)
	local r2 = HandEvaluator.evaluate(runes)
	check("determinism: same spellId", r1.spellId == r2.spellId)
	check("determinism: same matchedRunes", idxEqual(r1.matchedRunes, r2.matchedRunes))
end

if failures > 0 then
	error(`{failures} HandEvaluator test(s) failed`)
end
print("All HandEvaluator tests passed.")
