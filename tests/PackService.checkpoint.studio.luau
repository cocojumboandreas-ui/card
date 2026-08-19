--!strict
-- PackService.checkpoint.studio.luau — T4 math checkpoint (mandatory gate per Andreas' T4 approval:
-- "Symulacja obowiazkowa: N=10-20k per paczka, tabela empiryczne-vs-wyswietlane w STATUS.md, + twarde
-- potwierdzenie ze we WSZYSTKICH otwarciach Legend karta #10 = Legendary").
--
-- NOT a headless test (like RollService.checkpoint.studio.luau): PackService requires TotemPool ->
-- TotemConfig/RarityConfig which are fine standalone, but for realism this also requires RollService
-- (for the real RollVariant wrapper) which calls game:GetService(...) at module top-level -- needs a
-- live Roblox Studio server VM. Paste into mcp Roblox_Studio execute_luau, datamodel_type="Server",
-- inside an active solo-playtest session (same isolation gotchas as RollService.checkpoint.studio.luau:
-- fresh module-require cache, Init()/Start() never ran, zero risk to real player data since
-- PackService._RollPackCardsForTest is PURE -- takes rng + rollVariantFn as params, touches no profile
-- state at all, no injection even needed for this specific check).

local ok, result = pcall(function()
	local SSS = game:GetService("ServerScriptService")
	local RS = game:GetService("ReplicatedStorage")

	local Configs = RS:WaitForChild("Shared"):WaitForChild("Configs")
	local PackConfig = require(Configs:WaitForChild("PackConfig"))

	local PackService = require(SSS.Services.PackService)
	local RollService = require(SSS.Services.RollService)

	local out = {}
	local function log(s)
		table.insert(out, s)
	end

	local N_BY_PACK = { Mega = 10000, Super = 10000, Legend = 20000 }
	local TIER_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

	local allOk = true

	for _, packKey in { "Mega", "Super", "Legend" } do
		local cfg = PackConfig.Packs[packKey]
		local N = N_BY_PACK[packKey]
		local rng = Random.new()

		local tierCounts = {}
		local totalDrawnCards = 0
		local guaranteeViolations = 0
		local guaranteedSlotsChecked = 0

		for _ = 1, N do
			local cards = PackService._RollPackCardsForTest(packKey, rng, RollService.RollVariant)
			for i, card in cards do
				local isGuaranteedSlot = cfg.guaranteeLegendaryLast and i == cfg.cards
				if isGuaranteedSlot then
					guaranteedSlotsChecked += 1
					if card.tier ~= "Legendary" then
						guaranteeViolations += 1
					end
				else
					tierCounts[card.tier] = (tierCounts[card.tier] or 0) + 1
					totalDrawnCards += 1
				end
			end
		end

		log(("=== %s: N=%d packs opened (%d cards/pack, guaranteeLegendaryLast=%s) ==="):format(
			packKey,
			N,
			cfg.cards,
			tostring(cfg.guaranteeLegendaryLast)
		))
		log(("  non-guaranteed draws sampled: %d"):format(totalDrawnCards))
		log("  tier          displayed%   empirical%    delta")
		local maxDelta = 0
		for _, tier in TIER_ORDER do
			local displayedPct = 0
			for _, entry in cfg.tierTable do
				if entry.tier == tier then
					displayedPct = entry.pct
				end
			end
			local empiricalCount = tierCounts[tier] or 0
			local empiricalPct = totalDrawnCards > 0 and (empiricalCount / totalDrawnCards * 100) or 0
			local delta = math.abs(empiricalPct - displayedPct)
			maxDelta = math.max(maxDelta, delta)
			log(("  %-10s   %8.3f%%   %8.3f%%   %6.3f pp"):format(tier, displayedPct, empiricalPct, delta))
		end
		log(("  max |empirical - displayed| delta = %.3f pp"):format(maxDelta))

		if cfg.guaranteeLegendaryLast then
			log(
				("  GUARANTEE CHECK: card #%d checked in %d/%d packs, violations=%d -> ALL Legendary: %s"):format(
					cfg.cards,
					guaranteedSlotsChecked,
					N,
					guaranteeViolations,
					tostring(guaranteeViolations == 0 and guaranteedSlotsChecked == N)
				)
			)
			if guaranteeViolations > 0 or guaranteedSlotsChecked ~= N then
				allOk = false
			end
		end
		if maxDelta > 1.0 then
			allOk = false
		end
	end

	log(("=== OVERALL: %s ==="):format(allOk and "PASS" or "FAIL"))
	return table.concat(out, "\n")
end)
if ok then
	return result
else
	return "ERROR: " .. tostring(result)
end
