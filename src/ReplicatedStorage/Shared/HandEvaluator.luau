--!strict
-- HandEvaluator — pure, deterministic Zaklęcie detection (Framework, no Roblox deps). Given a
-- set of Runes (a played selection, or a full hand for client auto-suggest), finds the highest-
-- REALIZED-SCORE Zaklęcie achievable from ANY subset of those Runes — this is a subset search,
-- not an exact-play-count requirement (odpowiedź #1): leftover unmatched Runes still contribute
-- their own Moc later, in ScoreEngine's rune loop, HandEvaluator only decides WHICH Zaklęcie won.
--
-- Priority = highest realized score wins (odpowiedź #3), not a fixed hierarchy — so a shop-bought
-- Ulepszenie Zaklęcia (spellUpgrades) can make a normally-weaker Zaklęcie win the comparison.

local RuneConfig = require("./Configs/RuneConfig")
local SpellConfig = require("./Configs/SpellConfig")

type Rune = RuneConfig.Rune

-- rezMult: multiplikatywne ulepszenie Rezonansu bazowego (ZMIANA 2, Faza 3) — mnoży, nie dodaje.
-- mocBonus: zachowane jako flat Moc hook (nieużywane przez sklep na razie, ale HandEvaluator go
-- honoruje, żeby nie zamykać drogi do przyszłych źródeł mocBonus poza sklepem).
export type SpellUpgrade = { mocBonus: number?, rezMult: number? }

export type EvalResult = {
	spellId: string,
	baseMoc: number,
	baseRezonans: number,
	matchedRunes: { number }, -- 1-based indices into the input `runes` list
}

local HandEvaluator = {}

-- All k-combinations of {1..n}, as ascending index lists. n,k are small in practice (n<=7, k<=5).
local function combinations(n: number, k: number): { { number } }
	local result = {}
	if k > n or k < 0 then
		return result
	end
	local combo = {}
	local function recurse(start: number)
		if #combo == k then
			table.insert(result, table.clone(combo))
			return
		end
		for i = start, n do
			table.insert(combo, i)
			recurse(i + 1)
			table.remove(combo)
		end
	end
	recurse(1)
	return result
end

function HandEvaluator.evaluate(runes: { Rune }, spellUpgrades: { [string]: SpellUpgrade }?): EvalResult?
	if #runes == 0 then
		return nil
	end
	local upgrades = spellUpgrades or {}

	local best: EvalResult? = nil
	local bestScore = -1
	local bestOrder = -1

	for order, spell in SpellConfig.Spells do
		if spell.size > #runes then
			continue
		end
		for _, idxs in combinations(#runes, spell.size) do
			local subset = {}
			for _, idx in idxs do
				table.insert(subset, runes[idx])
			end
			if spell.matches(subset) then
				local upgrade = upgrades[spell.id]
				local moc = spell.baseMoc + (upgrade and upgrade.mocBonus or 0)
				local rez = spell.baseRez * (upgrade and upgrade.rezMult or 1)
				local runeSum = 0
				for _, rune in subset do
					runeSum += RuneConfig.power(rune)
				end
				local previewScore = (moc + runeSum) * rez
				if previewScore > bestScore or (previewScore == bestScore and order > bestOrder) then
					bestScore = previewScore
					bestOrder = order
					best = {
						spellId = spell.id,
						baseMoc = moc,
						baseRezonans = rez,
						matchedRunes = idxs,
					}
				end
			end
		end
	end

	return best
end

return HandEvaluator
