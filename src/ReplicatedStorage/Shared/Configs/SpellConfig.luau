--!strict
-- SpellConfig — the 7 Zaklęcia (RUNE_RNG_GDD.md §1.3). Each entry is a REQUIRED-subset size plus
-- a pure `matches(subset)` predicate. HandEvaluator searches subsets of the played Runes and asks
-- each Spell "does this exact subset satisfy you" — unmatched leftover Runes are NOT required to
-- be empty; they simply don't get spent on the Spell match itself (their own Moc is added later,
-- in ScoreEngine's rune loop). See odpowiedź #1: subset-search, not fixed-hierarchy/exact-count.

local RuneConfig = require("./RuneConfig")

type Rune = RuneConfig.Rune

export type Spell = {
	id: string,
	size: number,
	baseMoc: number,
	baseRez: number,
	matches: (subset: { Rune }) -> boolean,
}

local function sortedValues(subset: { Rune }): { number }
	local values = {}
	for _, rune in subset do
		table.insert(values, rune.value)
	end
	table.sort(values)
	return values
end

local function allSameValue(subset: { Rune }): boolean
	local first = subset[1].value
	for _, rune in subset do
		if rune.value ~= first then
			return false
		end
	end
	return true
end

local function allSameElement(subset: { Rune }): boolean
	local first = subset[1].element
	for _, rune in subset do
		if rune.element ~= first then
			return false
		end
	end
	return true
end

-- "Rosnące" = ciąg KOLEJNYCH wartości (consecutive integers), nie dowolny posortowany zbiór
-- różnych wartości (odpowiedź #2). Duplikaty w subset automatycznie failują (nie są "kolejne").
local function isConsecutiveStraight(subset: { Rune }): boolean
	local values = sortedValues(subset)
	for i = 2, #values do
		if values[i] ~= values[i - 1] + 1 then
			return false
		end
	end
	return true
end

local function allDistinctElements(subset: { Rune }): boolean
	local seen = {}
	local count = 0
	for _, rune in subset do
		if not seen[rune.element] then
			seen[rune.element] = true
			count += 1
		end
	end
	return count == #RuneConfig.Elements and count == #subset
end

local SpellConfig = {}

SpellConfig.Spells = {
	{
		id = "Iskra",
		size = 1,
		baseMoc = 10,
		baseRez = 1,
		matches = function(_subset: { Rune }): boolean
			return true -- każda pojedyncza runa
		end,
	},
	{
		id = "Echo",
		size = 2,
		baseMoc = 20,
		baseRez = 2,
		matches = function(subset: { Rune }): boolean
			return allSameValue(subset)
		end,
	},
	{
		id = "Triada",
		size = 3,
		baseMoc = 40,
		baseRez = 3,
		matches = function(subset: { Rune }): boolean
			return allSameValue(subset)
		end,
	},
	{
		id = "Zywiol",
		size = 3,
		baseMoc = 35,
		baseRez = 3,
		matches = function(subset: { Rune }): boolean
			return allSameElement(subset)
		end,
	},
	{
		id = "Kaskada",
		size = 4,
		baseMoc = 60,
		baseRez = 4,
		matches = function(subset: { Rune }): boolean
			return isConsecutiveStraight(subset)
		end,
	},
	{
		id = "Nawalnica",
		size = 5,
		baseMoc = 100,
		baseRez = 6,
		matches = function(subset: { Rune }): boolean
			return allSameElement(subset)
		end,
	},
	{
		id = "Konwergencja",
		size = 5,
		baseMoc = 160,
		baseRez = 10,
		matches = function(subset: { Rune }): boolean
			return isConsecutiveStraight(subset) and allDistinctElements(subset)
		end,
	},
}

return SpellConfig
