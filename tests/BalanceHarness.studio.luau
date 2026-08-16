--!strict
-- BalanceHarness — run simulator used for Faza 3 balance validation.
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
-- Second lesson (Faza 3, "full-smart" round): n=25 is noisy right at the guarded encounters
-- (enc9/10/12) where losses concentrate -- one seed flipping is a 4pp swing. A 60% reading at n=25
-- turned out to be sampling noise around a true ~56% at n=50 for the same config. Prefer n=50 (the
-- `n` param below) when a measurement is close to a target boundary and the decision has real cost.
--
-- TWO bots, always reported side by side:
--   naivePlayIndices  -- always plays hand-slots 1..min(5,#hand) in draw order, never swaps, never
--                         uses scrolls. This is the "floor" -- how badly the run goes if the player
--                         makes no real decisions.
--   smartPlayIndices  -- the "FULL-SMART" human proxy, three parts:
--                         1) per-turn play: brute-forces every 1..5-card subset of the hand via a
--                            read-only ScoreEngine.score call, plays whichever maximizes finalScore.
--                         2) swaps: at encounter start, if the best achievable play doesn't clear an
--                            even share of the remaining threshold (score < threshold/playsRemaining),
--                            swaps out the cards NOT in that best subset (up to swapsRemaining times).
--                            Committal, like a real swap -- no preview of the redraw.
--                         3) scrolls: applied immediately on purchase (no production consumption
--                            mechanic exists yet -- see caveat below). removeRune thins the worst
--                            card out of the deck; duplicateRune clones the single best rune
--                            currently visible (hand+drawPile); changeElement retargets the deck's
--                            worst card toward whichever element the run's owned totems favor most.
--                         Still a greedy-per-turn/per-encounter maximizer (no multi-turn lookahead,
--                         no shop-spend optimization beyond "buy if affordable") -- likely a LOWER
--                         bound on true human ceiling, not an exact one.
--
-- Known harness/production gap: RunShopService.buy(run,"scroll") only appends {kind=...} to
-- run.scrolls -- there is no PlayService.useScroll or similar anywhere in src/. The harness's
-- applyScrollStrategically therefore simulates the effect directly on RunState (harness-only, not
-- touching production code) and immediately "consumes" the scroll. If/when Phase 2+ adds a real
-- scroll-consumption UI/API, revisit whether the harness's heuristic still matches actual player
-- affordance.
--
-- Six-slot totem variant (an exploratory TotemSlots=6 bypass carried alongside 5-slot through most
-- of Faza 3) was DROPPED: it badly overshot (full-smart 76-80% vs 5-slot's ~54-64%) and was never a
-- committed feature. This harness now only simulates the shipped 5-slot design.
--
-- Faza 3 final validated result (thresholdWarden.thresholdMult = 1.5, n=50): naive 18%, full-smart
-- 54% (target band 30-55%), enc12 median ratio 1.11 (target band 1.0-1.3). Gate met.

local RunSessionService = require(game.ServerScriptService.Services.RunSessionService)
local RunShopService = require(game.ServerScriptService.Services.RunShopService)
local PlayService = require(game.ServerScriptService.Services.PlayService)
local HandEvaluator = require(game.ReplicatedStorage.Shared.HandEvaluator)
local ScoreEngine = require(game.ReplicatedStorage.Shared.ScoreEngine)
local GameConfig = require(game.ReplicatedStorage.Shared.Configs.GameConfig)
local TotemConfig = require(game.ReplicatedStorage.Shared.Configs.TotemConfig)
local RuneConfig = require(game.ReplicatedStorage.Shared.Configs.RuneConfig)

local function median(list)
	local sorted = table.clone(list)
	table.sort(sorted)
	local n = #sorted
	if n == 0 then return nil end
	if n % 2 == 1 then return sorted[(n + 1) // 2] end
	return (sorted[n // 2] + sorted[n // 2 + 1]) / 2
end

-- Shared by smartPlayIndices and trySwapForBetterHand: brute-force the best-scoring subset
-- (size 1..MaxPlaySize) of the current hand via a read-only ScoreEngine.score call.
local function bestSubset(run)
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
	return { indices = bestIndices, score = bestScore }
end

local function naivePlayIndices(run)
	local n = math.min(GameConfig.MaxPlaySize, #run.hand)
	local indices = {}
	for i = 1, n do indices[i] = i end
	return indices
end

local function smartPlayIndices(run)
	local best = bestSubset(run)
	return best.indices or naivePlayIndices(run)
end

local function trySwapForBetterHand(run)
	local guard = 0
	while run.swapsRemaining > 0 and guard < GameConfig.SwapsPerEncounter do
		guard += 1
		local best = bestSubset(run)
		local playsRemaining = math.max(run.playsRemaining, 1)
		local weakBar = run.threshold / playsRemaining
		if best.score >= weakBar then break end
		local inBest = {}
		if best.indices then
			for _, idx in ipairs(best.indices) do inBest[idx] = true end
		end
		local deadIdx = {}
		for i = 1, #run.hand do
			if not inBest[i] then table.insert(deadIdx, i) end
		end
		if #deadIdx == 0 then break end
		if #deadIdx > 5 then
			local capped = {}
			for i = 1, 5 do capped[i] = deadIdx[i] end
			deadIdx = capped
		end
		local outcome = PlayService.swap(run, deadIdx)
		if not outcome.ok then break end
	end
end

local function applyScrollStrategically(run, scrollKind)
	if scrollKind == "removeRune" then
		if #run.drawPile == 0 then return end
		local worstIdx, worstVal = 1, run.drawPile[1].value
		for i, rune in ipairs(run.drawPile) do
			if rune.value < worstVal then worstIdx, worstVal = i, rune.value end
		end
		table.remove(run.drawPile, worstIdx)
	elseif scrollKind == "duplicateRune" then
		local bestRune, bestVal = nil, -1
		for _, rune in ipairs(run.hand) do
			if rune.value > bestVal then bestRune, bestVal = rune, rune.value end
		end
		for _, rune in ipairs(run.drawPile) do
			if rune.value > bestVal then bestRune, bestVal = rune, rune.value end
		end
		if bestRune then
			table.insert(run.drawPile, { element = bestRune.element, value = bestRune.value })
		end
	elseif scrollKind == "changeElement" then
		if #run.drawPile == 0 then return end
		local elementCounts = {}
		for _, t in ipairs(run.totems) do
			if t.element then elementCounts[t.element] = (elementCounts[t.element] or 0) + 1 end
		end
		local targetElement, targetCount = nil, 0
		for el, count in pairs(elementCounts) do
			if count > targetCount then targetElement, targetCount = el, count end
		end
		targetElement = targetElement or RuneConfig.Elements[1]
		local worstIdx, worstVal = 1, run.drawPile[1].value
		for i, rune in ipairs(run.drawPile) do
			if rune.value < worstVal then worstIdx, worstVal = i, rune.value end
		end
		run.drawPile[worstIdx] = { element = targetElement, value = run.drawPile[worstIdx].value }
	end
end

-- 5-slot design only (six-slot exploratory variant dropped -- see header history).
local function shopVisit(run, humanLike)
	RunShopService.open(run)
	local offers = run.shopOffers
	if offers.totem and run.gold >= offers.totem.price then
		RunShopService.buy(run, "totem")
	end
	if offers.upgrade and run.gold >= offers.upgrade.price then
		RunShopService.buy(run, "upgrade")
	end
	if offers.scroll and run.gold >= offers.scroll.price and #run.scrolls < GameConfig.ScrollSlots then
		local scrollKind = offers.scroll.scrollKind
		local result = RunShopService.buy(run, "scroll")
		if humanLike and result.ok then
			applyScrollStrategically(run, scrollKind)
			table.remove(run.scrolls) -- consumed immediately by the human-proxy bot
		end
	end
end

-- opts: { useSwaps: boolean?, useScrolls: boolean? } -- both false/nil for the naive bot.
local function simulateRun(seed, pickIndicesFn, opts)
	opts = opts or {}
	local run = RunSessionService.startRun(seed, "seedtest_" .. tostring(seed))
	local history = {}
	local lossEncounter = nil
	local completed = false

	while run.status == "active" do
		local encIdx = run.encounterIndex
		if opts.useSwaps then trySwapForBetterHand(run) end
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
		shopVisit(run, opts.useScrolls)
	end

	-- Totem pick share is derived from the final owned-totems list, not tracked per shop visit --
	-- reading a shop offer's fields AFTER calling RunShopService.buy is a trap: buy() nils out
	-- run.shopOffers[slotKey] on success, and `offers` above is the SAME table (not a copy), so
	-- `offers.totem.totemId` read post-buy indexes nil. Bit this exact bug once; don't reintroduce it.
	local totemPicks = {}
	for _, t in run.totems do totemPicks[t.id] = (totemPicks[t.id] or 0) + 1 end
	return { history = history, lossEncounter = lossEncounter, completed = completed, finalGold = run.gold, totemPicks = totemPicks }
end

local function runBatch(pickIndicesFn, opts, label, n)
	n = n or 25
	local SEEDS = {}
	for i = 1, n do table.insert(SEEDS, i * 101 + 7) end

	local completedCount = 0
	local lossHist = {}
	local ratiosByEnc = {}
	local totemPickTotal = {}
	local goldList = {}

	for _, seed in ipairs(SEEDS) do
		local ok, result = pcall(simulateRun, seed, pickIndicesFn, opts)
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
	print(string.format("Completion: %d/%d (%.0f%%)", completedCount, n, completedCount / n * 100))
	print("Loss histogram:")
	for enc = 1, 12 do
		if lossHist[enc] then print(string.format("  enc%d: %d", enc, lossHist[enc])) end
	end
	print("Median ratio per encounter:")
	for enc = 1, 12 do
		if ratiosByEnc[enc] then print(string.format("  enc%d: %.2f (n=%d)", enc, median(ratiosByEnc[enc]), #ratiosByEnc[enc])) end
	end
	print(string.format("Median final gold: %.0f", median(goldList) or 0))
	local pickIds = {}
	for id, _ in pairs(TotemConfig.Totems) do table.insert(pickIds, id) end
	table.sort(pickIds)
	local pickStrs = {}
	for _, id in ipairs(pickIds) do
		local pct = math.floor((totemPickTotal[id] or 0) / n * 100 + 0.5)
		table.insert(pickStrs, id .. ":" .. pct .. "%")
	end
	print("Totem pick share: " .. table.concat(pickStrs, ", "))
	return completedCount
end

-- Standard invocation: always report naive (floor) vs full-smart (human proxy) side by side.
-- Prefer n=50 when a config change is near a target boundary (see header note on n=25 noise).
-- runBatch(naivePlayIndices, {}, "NAIVE (floor), 5-slot", 50)
-- runBatch(smartPlayIndices, {useSwaps = true, useScrolls = true}, "FULL-SMART (human proxy), 5-slot", 50)

return {
	shopVisit = shopVisit,
	naivePlayIndices = naivePlayIndices,
	smartPlayIndices = smartPlayIndices,
	trySwapForBetterHand = trySwapForBetterHand,
	applyScrollStrategically = applyScrollStrategically,
	simulateRun = simulateRun,
	runBatch = runBatch,
}
