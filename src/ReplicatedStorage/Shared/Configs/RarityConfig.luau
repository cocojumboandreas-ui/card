--!strict
-- RarityConfig — RollService MetaRNG tuning (Faza 2b, Zasada 11: unseeded per-player rolls).
-- Per-TIER "1 in N at luck=1" weight for divide-by-luck selection (WAR RNG pattern: nEff =
-- floor(weight/luck), pool built from TotemConfig and iterated rarest-first, first hit wins,
-- fallback = most common tier). All 15 MVP totems in a tier share that tier's weight.
--
-- TotemConfig has 5 tiers (Common/Uncommon/Rare/Epic/Legendary); STWORKI.md §A1 states a 4-tier
-- INTENT for the eventual 29-roster (Common 38% / Rare 28% / Epic 21% / Legendary 14%). Uncommon is
-- folded into the Common band here, split roughly by unit count (Common=7, Uncommon=3 of that 10):
-- Common 26% + Uncommon 11% ≈ 37%, close to the 38% intent.
--
-- PLACEHOLDER — first pass, not simulated against the sequential divide-by-N cascade (which does NOT
-- reproduce these percentages exactly, only rank-orders them). Validate empirically against the Faza
-- 2b math checkpoint (N rolls, tabulate tier distribution) before treating these as final; retune
-- there, not here.
local RarityConfig = {}

RarityConfig.TierWeight = {
	Common = 3,
	Uncommon = 8,
	Rare = 12,
	Epic = 30,
	Legendary = 90,
}

-- Pity: profile.pity.sinceEpic counts rolls since the last Epic-or-better. At/above threshold, the
-- selection pool is filtered to tiers with weight >= TierWeight[guaranteeTier] (Epic or Legendary).
RarityConfig.Pity = {
	threshold = 40,
	guaranteeTier = "Epic",
}

return RarityConfig
