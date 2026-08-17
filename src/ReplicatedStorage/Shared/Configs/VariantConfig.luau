--!strict
-- VariantConfig — collectible finish rolled independently of Totem tier (STWORKI.md §A4).
-- COMPLIANCE (hard rule): `ladder` sums to EXACTLY 100.0%. The odds table shown in UI MUST render
-- from THIS table, never a hardcoded copy (Paid Random Items disclosure requirement).
--
-- Deliberate deviation from RollService's tier selection (RarityConfig, sequential divide-by-N
-- cascade): that cascade only approximates its target percentages. The variant ladder is a
-- COMPLIANCE-DISCLOSED exact percentage table, so RollService rolls it with a direct weighted-bucket
-- pick (cumulative pct walk) instead — exact by construction, and luck-scalable (see rollVariant in
-- RollService: every non-fallback bucket's pct is multiplied by variantLuck; `fallback` silently
-- absorbs whatever remains, so scaling never has to touch this table).
local VariantConfig = {}

VariantConfig.fallback = "Normal"

VariantConfig.ladder = {
	{ id = "Rainbow", pct = 0.1 },
	{ id = "Galaxy", pct = 1 },
	{ id = "Gold", pct = 4 },
	{ id = "Foil", pct = 10 },
	{ id = "Normal", pct = 84.9 },
}

-- Void: reward-only finish (event/quest/pity). Deliberately absent from `ladder` so RollService's
-- normal paid-roll path can never select it. If Void is ever added to a paid pool, STWORKI.md §A4
-- requires it enter THIS table (and Normal drops to 84.89%) — never a silent side channel.
VariantConfig.Void = "Void"

return VariantConfig
