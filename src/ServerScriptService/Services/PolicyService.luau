--!strict
-- ServerScriptService/Services/PolicyService.luau (Faza 4 Krok 4)
-- Compliance: Paid Random Items disclosure. Cienki serwis, jedna funkcja OddsTable() -- CZYTA
-- TotemPool/VariantConfig/RarityConfig, NIGDY nie duplikuje liczb w osobnej tabeli (gdyby ktos
-- zmienil roster w TotemConfig i zapomnial tu, tabela w UI klamalaby o realnych szansach). TotemPool
-- jest JEDYNYM źródłem puli (współdzielone z RollService.selectTotem, patrz TotemPool.luau) --
-- strukturalnie niemożliwe, żeby display i roll czytały różne dane. Statyczna (configi sie nie
-- zmieniaja w runtime), wiec liczona raz i cache'owana.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Net = require(Framework:WaitForChild("Net"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local TotemPool = require(Shared:WaitForChild("TotemPool"))

local PolicyService = {}

-- PURE (testowalna): EXACT model of RollService.selectTotem's cascade (RollService.luau, `selectTotem`)
-- -- reads the SAME pool as the real roll (TotemPool.sorted(), one entry PER TOTEM, not per tier).
-- FIXED 2026-08-18 (odds-bug): the old version assumed exactly one pool entry per tier (as if every
-- tier had a single totem), so it silently understated every non-Common tier by 2-4x once the roster
-- grew past 1 totem/tier (Common 10/Uncommon 5/Rare 4/Epic 4/Legendary 2 today) -- see STATUS.md.
--
-- Within a tier of k totems sharing weight w, EVERY totem gets its OWN independent 1/w trial before
-- the cascade falls through to the next (more common) tier, so "land somewhere in this tier" is
-- 1-(1-1/w)^k, not a single 1/w draw. The pool's LAST tier (most common) still absorbs whatever
-- survives everything before it (RollService's forced fallback), so the whole table still sums to
-- EXACTLY 100% by construction -- same closed-form guarantee as before, now with the right per-totem
-- math feeding it.
local function computeTierOdds(pool: { TotemPool.PoolEntry }): { { tier: string, pct: number } }
	local groups: { [string]: { weight: number, count: number } } = {}
	for _, entry in pool do
		local g = groups[entry.tier]
		if not g then
			g = { weight = entry.weight, count = 0 }
			groups[entry.tier] = g
		end
		g.count += 1
	end

	local arr = {}
	for tier, g in groups do
		table.insert(arr, { tier = tier, weight = g.weight, count = g.count })
	end
	table.sort(arr, function(a, b)
		return a.weight > b.weight
	end)

	local result = {}
	local survive = 1 -- P(every totem in every earlier, rarer tier missed its own trial)
	for i, g in ipairs(arr) do
		if i == #arr then
			table.insert(result, { tier = g.tier, pct = survive * 100 })
		else
			local missAll = (1 - 1 / g.weight) ^ g.count
			local landHere = survive * (1 - missAll)
			table.insert(result, { tier = g.tier, pct = landHere * 100 })
			survive *= missAll
		end
	end
	return result
end

local _cached = nil

function PolicyService.OddsTable(): { [string]: any }
	if _cached then
		return _cached
	end
	local variants = {}
	for _, v in VariantConfig.ladder do
		table.insert(variants, { id = v.id, pct = v.pct })
	end
	_cached = {
		tiers = computeTierOdds(TotemPool.sorted()),
		tiersNote = "przy bazowym Szczesciu (luck=1) - bonus Szczescia zwieksza te szanse",
		variants = variants,
		variantsExcluded = { VariantConfig.Void }, -- Void nie jest w rollowalnej puli (VariantConfig.luau:24-26)
		pity = { threshold = RarityConfig.Pity.threshold, guaranteeTier = RarityConfig.Pity.guaranteeTier },
	}
	return _cached
end

function PolicyService.Init() end

function PolicyService.Start()
	Net.get("GetOddsTable").OnServerInvoke = function(_player)
		return PolicyService.OddsTable()
	end
end

-- Hook TYLKO do testow: czysta kaskada bez remote'a. pool = TotemPool.sorted()-shaped array.
function PolicyService._ComputeTierOddsForTest(pool)
	return computeTierOdds(pool)
end

return PolicyService
