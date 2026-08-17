--!strict
-- Sanity tests for RarityConfig/VariantConfig (Faza 2b). No Studio required.
--   luau tests/RollConfigs.test.luau

local RarityConfig = require("../src/ReplicatedStorage/Shared/Configs/RarityConfig")
local VariantConfig = require("../src/ReplicatedStorage/Shared/Configs/VariantConfig")
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

-- VariantConfig: COMPLIANCE — paid ladder sums to EXACTLY 100.0% (STWORKI.md §A4).
local sumPct = 0
for _, v in VariantConfig.ladder do
	sumPct += v.pct
end
check("VariantConfig.ladder sums to exactly 100.0%", math.abs(sumPct - 100.0) < 0.0001)
check("VariantConfig.fallback is Normal", VariantConfig.fallback == "Normal")
local hasVoid = false
for _, v in VariantConfig.ladder do
	if v.id == "Void" then
		hasVoid = true
	end
end
check("Void is NOT in the paid ladder", not hasVoid)
check("VariantConfig.Void constant exists (reserved, unused by ladder)", VariantConfig.Void == "Void")

-- RarityConfig: every TotemConfig tier has a weight, weights strictly increase with rarity.
local seenTiers = {}
for _, totem in TotemConfig.Totems do
	seenTiers[totem.tier] = true
	check("TotemConfig tier '" .. totem.tier .. "' has a RarityConfig.TierWeight entry", RarityConfig.TierWeight[totem.tier] ~= nil)
end
check(
	"tier weights strictly increase Common < Uncommon < Rare < Epic < Legendary",
	RarityConfig.TierWeight.Common < RarityConfig.TierWeight.Uncommon
		and RarityConfig.TierWeight.Uncommon < RarityConfig.TierWeight.Rare
		and RarityConfig.TierWeight.Rare < RarityConfig.TierWeight.Epic
		and RarityConfig.TierWeight.Epic < RarityConfig.TierWeight.Legendary
)
check(
	"Pity.guaranteeTier resolves to a real TierWeight entry",
	RarityConfig.TierWeight[RarityConfig.Pity.guaranteeTier] ~= nil
)

if failures > 0 then
	error(`{failures} RollConfigs test(s) failed`)
end
print("All RollConfigs tests passed.")
