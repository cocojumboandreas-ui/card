--!strict
-- ServerScriptService/Services/PolicyService.luau (Faza 4 Krok 4)
-- Compliance: Paid Random Items disclosure. Cienki serwis, jedna funkcja OddsTable() -- CZYTA
-- RarityConfig/VariantConfig, NIGDY nie duplikuje liczb w osobnej tabeli (gdyby ktos zmienil wagi w
-- RarityConfig i zapomnial tu, tabela w UI klamalaby o realnych szansach). Statyczna (configi sie
-- nie zmieniaja w runtime), wiec liczona raz i cache'owana.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Net = require(Framework:WaitForChild("Net"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))

local PolicyService = {}

-- PURE (testowalna): port TEJ SAMEJ kaskady co RollService.selectTotem (RollService.luau:44-73) --
-- posortowane malejaco po wadze (najrzadszy pierwszy), przy luck=1 kazdy tier ma 1/weight szans
-- "trafienia" w swojej turze w petli, inaczej sprawa przechodzi do nastepnego (mniej rzadkiego)
-- tieru. Ostatni (najczestszy) tier w RollService dostaje sie tam ZAWSZE gdy zadien wczesniejszy
-- nie trafil -- fallback wybiera go bez wzgledu na WLASNY rzut -- wiec jego realna szansa to caly
-- pozostaly "remaining", nie (1/waga)*poprzednik jak dla reszty. Ten zamkniety wzor gwarantuje sume
-- DOKLADNIE 100% (compliance), zero dryfu z zaokraglania per-tier.
local function computeTierOdds(tierWeights: { [string]: number }): { { tier: string, pct: number } }
	local arr = {}
	for tier, weight in pairs(tierWeights) do
		table.insert(arr, { tier = tier, weight = weight })
	end
	table.sort(arr, function(a, b)
		return a.weight > b.weight
	end)

	local result = {}
	local remaining = 1
	for i, t in ipairs(arr) do
		if i == #arr then
			table.insert(result, { tier = t.tier, pct = remaining * 100 })
		else
			local p = remaining * (1 / t.weight)
			table.insert(result, { tier = t.tier, pct = p * 100 })
			remaining -= p
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
		tiers = computeTierOdds(RarityConfig.TierWeight),
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

-- Hook TYLKO do testow: czysta kaskada bez remote'a.
function PolicyService._ComputeTierOddsForTest(tierWeights)
	return computeTierOdds(tierWeights)
end

return PolicyService
