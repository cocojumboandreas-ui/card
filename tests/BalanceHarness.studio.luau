--!strict
-- BalanceHarness — 25-seed run simulator used for Faza 3 balance validation.
--
-- NOT a headless test (unlike the other files in tests/): RunSessionService/PlayService/
-- RunShopService call `game:GetService(...)`, so this requires a live Roblox Studio server VM.
-- Run it by pasting into mcp Roblox_Studio/robloxstudio execute_luau with target="server" inside
-- an active solo_playtest session (RunSessionService etc. are ServerScriptService-only).
--
-- History: the original version of this harness called PlayService.play(run, playerId) instead of
-- PlayService.play(run, indices) and invented nonexistent RunShopService functions
-- (getShopState/buyTotem/buySpellUpgrade/buyScroll). Every seed silently errored inside pcall and
-- "lost" encounter 1 with score 0 -- every balance number produced by that version (Faza 3 rounds
-- 2-5) was fake. The `assertHarnessSanity` block below exists specifically so that bug class can
-- never again masquerade as a real result: if it reappears (or a similar API drift happens), this
-- harness now fails LOUDLY instead of printing a plausible-looking report.
--
-- Two bots are included:
--   naivePlayIndices  -- always plays hand-slots 1..min(5,#hand) in draw order. This is the
--                         "current bot" whose numbers are the ones balance decisions were made against.
--   smartPlayIndices  -- brute-forces every 1..5-card subset of the hand via a read-only
--                         ScoreEngine.score call and plays whichever maximizes finalScore this turn.
--                         Still a greedy per-turn maximizer (no swaps, no scroll usage, no lookahead)
--                         -- a LOWER BOUND on how well an attentive human could do, used to estimate
--                         the naive-bot-vs-human skill margin.
--
-- Known harness limitation: shopVisit buys scrolls opportunistically but never applies their
-- deck-manipulation effect (changeElement/removeRune/duplicateRune) -- a real human would use them,
-- so even the "smart" bot number is an underestimate of true human ceiling.

local RunSessionService = require(game.ServerScriptService.Services.RunSessionService)
local RunShopService = require(game.ServerScriptService.Services.RunShopService)
local PlayService = require(game.ServerScriptService.Services.PlayService)
local HandEvaluator = require(game.ReplicatedStorage.Shared.HandEvaluator)
local ScoreEngine = require(game.ReplicatedStorage.Shared.ScoreEngine)
local GameConfig = require(game.ReplicatedStorage.Shared.Configs.GameConfig)
local TotemConfig = require(game.ReplicatedStorage.Shared.Configs.TotemConfig)

local function median(list)
	local sorted = table.clone(list)
	table.sort(sorted)
	local n = #sorted
	if n == 0 then return nil end
	if n % 2 == 1 then return sorted[(n + 1) // 2] end
	return (sorted[n // 2] + sorted[n // 2 + 1]) / 2
end

local function shopVisit(run, sixSlotVariant)
	RunShopService.open(run)
	local slotsCap = sixSlotVariant and 6 or GameConfig.TotemSlots
	local offers = run.shopOffers
	if offers.totem and run.gold >= offers.totem.price and #run.totems < slotsCap then
		if #run.totems >= GameConfig.TotemSlots then
			-- ZMIANA-4 six-slot variant: bypass RunShopService.buy's hard TotemSlots cap directly.
			run.gold -= offers.totem.price
			table.insert(run.totems, TotemConfig.Totems[offers.totem.totemId])
			offers.totem = nil
		else
			RunShopService.buy(run, "totem")
		end
	end
	if offers.upgrade and run.gold >= offers.upgrade.price then
		RunShopService.buy(run, "upgrade")
	end
	if offers.scroll and run.gold >= offers.scroll.price and #run.scrolls < GameConfig.ScrollSlots then
		RunShopService.buy(run, "scroll")
	end
end

local function naivePlayIndices(run)
	local n = math.min(GameConfig.MaxPlaySize, #run.hand)
	local indices = {}
	for i = 1, n do indices[i] = i end
	return indices
end

local function smartPlayIndices(run)
	local hand = run.hand
	local n = #hand
	local maxSize = math.min(GameConfig.MaxPlaySize, n)
	local bestScore = -1
	local bestIndices = nil
	local chosen = {}
	local function evalChosen()
		local playedRunes = {}
		for _, idx in ipairs(chosen) do table.insert(playedRunes, hand[idx]) end
		local handEval = HandEvaluator.evaluate(playedRunes, run.spellUpgrades)
		if not handEval then return end
		local scoreResult = ScoreEngine.score(playedRunes, {
			spellId = handEval.spellId, baseMoc = handEval.baseMoc, baseRezonans = handEval.baseRezonans,
		}, { totems = run.totems, totemState = run.totemState, elementNullifiers = run.elementNullifiers }, {})
		if scoreResult.finalScore > bestScore then
			bestScore = scoreResult.finalScore
			bestIndices = table.clone(chosen)
		end
	end
	local function combos(start)
		if #chosen > 0 then evalChosen() end
		if #chosen == maxSize then return end
		for i = start, n do
			table.insert(chosen, i)
			combos(i + 1)
			table.remove(chosen)
		end
	end
	combos(1)
	return bestIndices or naivePlayIndices(run)
end

local function simulateRun(seed, sixSlotVariant, pickIndicesFn)
	local run = RunSessionService.startRun(seed, "seedtest_" .. tostring(seed))
	local history = {}
	local lossEncounter = nil
	local completed = false

	while run.status == "active" do
		local encIdx = run.encounterIndex
		local thresholdBefore = run.threshold
		local encScore = 0
		local lastOutcome = nil

		while run.status == "active" and run.encounterIndex == encIdx and run.playsRemaining > 0 and run.score < run.threshold do
			local indices = pickIndicesFn(run)
			local outcome = PlayService.play(run, indices)
			lastOutcome = outcome
			if not outcome.ok then break end
			if outcome.scoreResult then encScore += outcome.scoreResult.finalScore end
			if outcome.encounterResult then break end
		end

		local won
		if lastOutcome and lastOutcome.encounterResult then
			won = lastOutcome.encounterResult.won
		elseif run.status == "active" and run.encounterIndex == encIdx then
			local voluntary = PlayService.endEncounterVoluntary(run)
			won = voluntary.encounterResult and voluntary.encounterResult.won
		else
			won = false
		end

		table.insert(history, { enc = encIdx, ratio = encScore / thresholdBefore, won = won and true or false })

		if not won then lossEncounter = encIdx; break end
		if run.status == "won" then completed = true; break end
		shopVisit(run, sixSlotVariant)
	end

	local totemPicks = {}
	for _, t in run.totems do totemPicks[t.id] = (totemPicks[t.id] or 0) + 1 end
	return { history = history, lossEncounter = lossEncounter, completed = completed, finalGold = run.gold, totemPicks = totemPicks }
end

local function runBatch(sixSlotVariant, pickIndicesFn, label)
	local SEEDS = {}
	for i = 1, 25 do table.insert(SEEDS, i * 101 + 7) end

	local completedCount = 0
	local lossHist = {}
	local ratiosByEnc = {}
	local totemPickTotal = {}
	local goldList = {}

	for _, seed in ipairs(SEEDS) do
		local ok, result = pcall(simulateRun, seed, sixSlotVariant, pickIndicesFn)
		if ok then
			if result.completed then completedCount += 1 end
			if result.lossEncounter then lossHist[result.lossEncounter] = (lossHist[result.lossEncounter] or 0) + 1 end
			for _, h in ipairs(result.history) do
				ratiosByEnc[h.enc] = ratiosByEnc[h.enc] or {}
				table.insert(ratiosByEnc[h.enc], h.ratio)
			end
			for id, count in pairs(result.totemPicks) do totemPickTotal[id] = (totemPickTotal[id] or 0) + count end
			table.insert(goldList, result.finalGold)
		else
			print("RUN ERROR seed=" .. seed .. " err=" .. tostring(result))
		end
	end

	-- HARNESS SANITY CHECK. A broken API call (wrong PlayService.play signature, invented
	-- RunShopService function, etc.) gets silently swallowed by the pcall above, and the symptom is
	-- always the same: every seed "loses" encounter 1 with score 0, and/or the shop never buys
	-- anything. If either pattern reappears, abort loudly instead of reporting numbers that look
	-- like a balance result. This is the exact bug that invalidated Faza 3 rounds 2-5.
	local lossEnc1 = lossHist[1] or 0
	if lossEnc1 / #SEEDS > 0.5 then
		error(string.format(
			"HARNESS SANITY CHECK FAILED [%s]: %d/%d seeds lost at encounter 1 (>50%%). "
				.. "Harness is almost certainly broken (bad API call swallowed by pcall), NOT a real "
				.. "balance result. Verify PlayService.play/RunShopService.open/RunShopService.buy "
				.. "signatures against the actual service source before trusting any report.",
			label,
			lossEnc1,
			#SEEDS
		))
	end
	local totalPicks = 0
	for _, c in pairs(totemPickTotal) do totalPicks += c end
	if totalPicks == 0 then
		error(string.format(
			"HARNESS SANITY CHECK FAILED [%s]: zero totems purchased across %d seeds. Shop API is almost certainly broken.",
			label,
			#SEEDS
		))
	end

	print(string.format("=== %s ===", label))
	print(string.format("Completion: %d/25 (%.0f%%)", completedCount, completedCount / 25 * 100))
	print("Loss histogram:")
	for enc = 1, 12 do
		if lossHist[enc] then print(string.format("  enc%d: %d", enc, lossHist[enc])) end
	end
	print("Median ratio per encounter:")
	for enc = 1, 12 do
		if ratiosByEnc[enc] then print(string.format("  enc%d: %.2f (n=%d)", enc, median(ratiosByEnc[enc]), #ratiosByEnc[enc])) end
	end
	print(string.format("Median final gold: %.0f", median(goldList) or 0))
	return completedCount
end

return {
	shopVisit = shopVisit,
	naivePlayIndices = naivePlayIndices,
	smartPlayIndices = smartPlayIndices,
	simulateRun = simulateRun,
	runBatch = runBatch,
}
