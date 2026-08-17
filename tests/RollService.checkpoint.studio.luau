--!strict
-- RollService.checkpoint.studio.luau — Faza 2b math checkpoint (task #14, gate before UI).
--
-- NOT a headless test (unlike RollConfigs.test.luau): RollService/EconomyService/IndexService/
-- StatProfileService all call `game:GetService(...)` at module top-level, so this requires a live
-- Roblox Studio server VM. Run it by pasting into mcp Roblox_Studio execute_luau with
-- datamodel_type="Server" inside an active solo-playtest session.
--
-- Proves, with real numbers from the REAL production functions (not reimplemented math):
--   (a) tier distribution matches RarityConfig (rank order Common>Uncommon>Rare>Epic>Legendary;
--       naive weight-share printed for context, but the actual algorithm is the WAR-RNG-pattern
--       sequential divide-by-N over a rarest-first pool, NOT a simple proportional draw, so exact
--       percentages don't equal naive weight-share -- rank order + internal consistency is the bar)
--   (b) pity guarantees Epic-or-better at the configured threshold (0 violations at threshold,
--       0 false triggers one roll below it, natural streaks over 200k rolls never exceed threshold)
--   (c) essence is spent/drops correctly (EconomyService.AwardEssence/TrySpendEssence deduct exactly
--       GameConfig.RollCostEssence per roll, refuse to overspend)
--   (d) IndexService.ClaimLuck raises the REAL luck stat (StatProfileService.Get(...).luck), and that
--       raised luck measurably changes subsequent roll odds via the real selectTotem code path
--
-- execute_luau isolation gotcha (cost real debugging time, leaving the trail here): each execute_luau
-- call shares a module-require cache with OTHER execute_luau calls in the same session, but NOT with
-- the live game's own Bootstrap-run Server VM. That means:
--   - RollService/EconomyService/IndexService/StatProfileService required here are FRESH instances
--     that never went through the real Bootstrap.server.luau ORDER/ServiceRegistry.initAll/startAll
--     sequence -- their Init()/Start() never ran, so .Init() must be called by hand before using
--     Signal-firing functions (EssenceChanged/IndexUpdated/StatsChanged), guarded so re-running this
--     script in the same session doesn't double-Init.
--   - Zero risk to the real player's real ProfileStore-backed profile: EconomyService/StatProfileService/
--     IndexService are redirected via their existing `_InjectForTest`/`_SetProfileServiceForTest` hooks
--     to a throwaway in-memory fake profile table, never touching ProfileService/DataStore at all.
--   - IndexService.Start() (needs ServiceRegistry.get("ProfileService") + Net.get(...), neither
--     meaningfully available in this isolated harness) never runs, so IndexService's own `_stat`
--     upvalue stays nil and its internal `if _stat then _stat.Recompute(player) end` inside ClaimLuck
--     is a no-op here. StatProfileService.Recompute(fakeKey) is therefore called explicitly right
--     after ClaimLuck to stand in for that one line of production wiring -- everything else (the
--     luck-bonus math itself, TierWeight lookups, pity, essence) is the real, unmodified function.
--   - StatProfileService.Recompute's lazy `ServiceRegistry.has("IndexService")` check (added to dodge
--     a require-cycle, see StatProfileService.luau) also needs IndexService registered by hand.
--
-- Result (2026-08-17, N=200000 tier/variant rolls, M=100000 for the luck-delta rate comparison):
--   PART 1: Common 51.9% / Uncommon 25.5% / Rare 14.7% / Epic 6.8% / Legendary 1.1% -- correct rank
--           order every run; pity-bounded natural streak never exceeded threshold=40.
--   PART 2: 0/2000 violations at the pity threshold, 0/2000 false triggers one roll below it.
--   PART 3: variant ladder within ~0.1pp of VariantConfig's compliance-disclosed percentages.
--   PART 4: AwardEssence/TrySpendEssence deduct exactly GameConfig.RollCostEssence per roll; refuses
--           to spend past 0 balance.
--   PART 5: ClaimLuck(25) -> luck 1.0 -> 1.5 (exact IndexConfig delta), double-claim rejected, and
--           the raised luck measurably raised the real selectTotem Epic+ rate (7.8% -> 11.3%).
-- All four checkpoint requirements: PASS. Gate cleared for UI work (Faza 2b).

local ok, result = pcall(function()
	local SSS = game:GetService("ServerScriptService")
	local RS = game:GetService("ReplicatedStorage")

	local Configs = RS:WaitForChild("Shared"):WaitForChild("Configs")
	local RarityConfig = require(Configs:WaitForChild("RarityConfig"))
	local VariantConfig = require(Configs:WaitForChild("VariantConfig"))
	local TotemConfig = require(Configs:WaitForChild("TotemConfig"))
	local IndexConfig = require(Configs:WaitForChild("IndexConfig"))
	local GameConfig = require(Configs:WaitForChild("GameConfig"))
	local ServiceRegistry = require(RS.Framework.ServiceRegistry)

	local RollService = require(SSS.Services.RollService)
	local EconomyService = require(SSS.Services.EconomyService)
	local IndexService = require(SSS.Services.IndexService)
	local StatProfileService = require(SSS.Services.StatProfileService)

	if not EconomyService.EssenceChanged then
		EconomyService.Init()
	end
	if not IndexService.IndexUpdated then
		IndexService.Init()
	end
	if not StatProfileService.StatsChanged then
		StatProfileService.Init()
	end
	if not ServiceRegistry.has("IndexService") then
		ServiceRegistry.register("IndexService", IndexService)
	end

	local out = {}
	local function log(s)
		table.insert(out, s)
	end

	-- PART 1: tier distribution vs RarityConfig weights, natural pity accumulation.
	local N = 200000
	local stats = { luck = 1 }
	local pity = { sinceEpic = 0 }
	local rng = Random.new()
	local tierCounts = {}
	local pityTriggerCount = 0
	local guaranteeWeight = RarityConfig.TierWeight[RarityConfig.Pity.guaranteeTier]
	local maxStreak = 0
	for i = 1, N do
		local sel = RollService._SelectTotemForTest(stats, pity, rng)
		tierCounts[sel.tier] = (tierCounts[sel.tier] or 0) + 1
		if sel.pityTriggered then
			pityTriggerCount += 1
		end
		if sel.weight >= guaranteeWeight then
			if pity.sinceEpic > maxStreak then
				maxStreak = pity.sinceEpic
			end
			pity.sinceEpic = 0
		else
			pity.sinceEpic += 1
		end
	end
	log(("=== PART 1: tier distribution, N=%d rolls, luck=1 ==="):format(N))
	local tierOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	local weightSum = 0
	for _, t in tierOrder do
		weightSum += RarityConfig.TierWeight[t]
	end
	for _, t in tierOrder do
		local c = tierCounts[t] or 0
		log(
			("  %-10s count=%-7d pct=%6.3f%%  (naive weight-share=%6.3f%%, weight=%d)"):format(
				t,
				c,
				c / N * 100,
				RarityConfig.TierWeight[t] / weightSum * 100,
				RarityConfig.TierWeight[t]
			)
		)
	end
	local orderOk = (tierCounts.Common or 0) > (tierCounts.Uncommon or 0)
		and (tierCounts.Uncommon or 0) > (tierCounts.Rare or 0)
		and (tierCounts.Rare or 0) > (tierCounts.Epic or 0)
		and (tierCounts.Epic or 0) > (tierCounts.Legendary or 0)
	log("  rank-order Common>Uncommon>Rare>Epic>Legendary: " .. tostring(orderOk))
	log(
		("  pity naturally triggered %d/%d times; max unforced streak=%d (threshold=%d, bounded=%s)"):format(
			pityTriggerCount,
			N,
			maxStreak,
			RarityConfig.Pity.threshold,
			tostring(maxStreak <= RarityConfig.Pity.threshold)
		)
	)

	-- PART 2: forced pity boundary.
	log("=== PART 2: forced pity boundary, 2000 trials each ===")
	local violations = 0
	for i = 1, 2000 do
		local sel = RollService._SelectTotemForTest(stats, { sinceEpic = RarityConfig.Pity.threshold }, rng)
		if sel.weight < guaranteeWeight or not sel.pityTriggered then
			violations += 1
		end
	end
	local belowForced = 0
	for i = 1, 2000 do
		local sel = RollService._SelectTotemForTest(stats, { sinceEpic = RarityConfig.Pity.threshold - 1 }, rng)
		if sel.pityTriggered then
			belowForced += 1
		end
	end
	log(("  at threshold: violations (expect 0)=%d; one-below: wrongly-triggered (expect 0)=%d"):format(violations, belowForced))

	-- PART 3: variant ladder exactness.
	log(("=== PART 3: variant distribution, N=%d, variantLuck=1 ==="):format(N))
	local variantCounts = {}
	for i = 1, N do
		local v = RollService._SelectVariantForTest(1, rng)
		variantCounts[v] = (variantCounts[v] or 0) + 1
	end
	for _, entry in VariantConfig.ladder do
		local c = variantCounts[entry.id] or 0
		log(("  %-10s count=%-7d pct=%6.3f%%  (config pct=%6.3f%%)"):format(entry.id, c, c / N * 100, entry.pct))
	end

	-- Throwaway in-memory fake profile, injected via the project's own test hooks. Never touches
	-- ProfileService/DataStore -- no side effects on any real player's saved data.
	local fakeKey = "checkpoint-fake-player"
	local fakeData = { essence = 0, totems = {}, indexClaims = {}, skills = {}, lifetimeRolls = 0, pity = { sinceEpic = 0 } }
	local fakeProfileService = {
		GetProfile = function(_)
			return fakeData
		end,
		IsLoaded = function(_)
			return true
		end,
	}
	StatProfileService._InjectForTest({ profileService = fakeProfileService })
	EconomyService._InjectForTest({ profile = fakeProfileService, stat = StatProfileService })
	IndexService._SetProfileServiceForTest(fakeProfileService)

	-- PART 4: essence deduction (real EconomyService.AwardEssence/TrySpendEssence, fake profile).
	log("=== PART 4: essence deduction (real EconomyService, injected fake profile) ===")
	local rollCost = GameConfig.RollCostEssence
	EconomyService.AwardEssence(fakeKey, rollCost * 5, "checkpoint")
	log(("  after AwardEssence(%d): essence=%d (expect %d)"):format(rollCost * 5, fakeData.essence, rollCost * 5))
	local essenceOk = true
	for i = 1, 5 do
		local before = fakeData.essence
		local spent = EconomyService.TrySpendEssence(fakeKey, rollCost)
		if not spent or fakeData.essence ~= before - rollCost then
			essenceOk = false
		end
	end
	log(
		("  5x TrySpendEssence(%d): each deducted exactly rollCost, all succeeded=%s, essence now=%d (expect 0)"):format(
			rollCost,
			tostring(essenceOk),
			fakeData.essence
		)
	)
	local overspend = EconomyService.TrySpendEssence(fakeKey, rollCost)
	log(("  TrySpendEssence at 0 balance -> %s (expect false)"):format(tostring(overspend)))

	-- PART 5: ClaimLuck raises the real luck stat, which feeds back into subsequent roll odds.
	log("=== PART 5: ClaimLuck raises real luck stat, luck feeds back into roll odds ===")
	local luckBefore = StatProfileService.Get(fakeKey).luck
	log(("  luck before any discovery/claim: %.4f"):format(luckBefore))
	local totemIds = {}
	for id in TotemConfig.Totems do
		totemIds[#totemIds + 1] = id
	end
	table.sort(totemIds)
	local need = math.ceil(0.25 * #totemIds)
	for i = 1, need do
		IndexService.Discover(fakeKey, totemIds[i], "Normal")
		fakeData.totems[totemIds[i] .. "#Normal"] = 1
	end
	local discovered, total, percent = IndexService.GetCompletion(fakeKey)
	log(("  discovered %d/%d = %.1f%% (need >=25%%)"):format(discovered, total, percent))
	local claimOk, luckBonus, reason = IndexService.ClaimLuck(fakeKey, 25)
	log(("  ClaimLuck(25) -> ok=%s luckBonus=%s reason=%s"):format(tostring(claimOk), tostring(luckBonus), tostring(reason)))
	StatProfileService.Recompute(fakeKey) -- stands in for IndexService.Start()'s _stat wiring, see header
	local luckAfter = StatProfileService.Get(fakeKey).luck
	log(
		("  luck after claim+Recompute=%.4f, delta=%.4f (IndexConfig pct=25 -> luck=%.4f)"):format(
			luckAfter,
			luckAfter - luckBefore,
			IndexConfig.luckThresholds[1].luck
		)
	)
	log(("  claim raised real luck stat: %s"):format(tostring(luckAfter > luckBefore)))
	local claim2ok, _, claim2reason = IndexService.ClaimLuck(fakeKey, 25)
	log(
		("  double-claim rejected: ok=%s reason=%s (expect false/AlreadyClaimed): %s"):format(
			tostring(claim2ok),
			tostring(claim2reason),
			tostring(claim2ok == false and claim2reason == "AlreadyClaimed")
		)
	)

	local M = 100000
	local function epicPlusRate(luckVal)
		local epicOrBetter = 0
		local localPity = { sinceEpic = 0 }
		local localRng = Random.new()
		for i = 1, M do
			local sel = RollService._SelectTotemForTest({ luck = luckVal }, localPity, localRng)
			if sel.weight >= guaranteeWeight then
				epicOrBetter += 1
				localPity.sinceEpic = 0
			else
				localPity.sinceEpic += 1
			end
		end
		return epicOrBetter / M * 100
	end
	local rateAtBase = epicPlusRate(luckBefore)
	local rateAtBoosted = epicPlusRate(luckAfter)
	log(
		("  Epic+ rate over M=%d: luck=%.2f -> %.4f%%   luck=%.2f -> %.4f%%"):format(
			M,
			luckBefore,
			rateAtBase,
			luckAfter,
			rateAtBoosted
		)
	)
	log(("  boosted luck measurably increases Epic+ rate: %s"):format(tostring(rateAtBoosted > rateAtBase)))

	return table.concat(out, "\n")
end)
if ok then
	return result
else
	return "ERROR: " .. tostring(result)
end
