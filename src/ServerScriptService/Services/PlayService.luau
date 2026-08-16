--!strict
-- PlayService — CIENKI orkiestrator (Architektura §2: "orkiestruje, ale NIE liczy sam"). Woła
-- HandEvaluator -> ScoreEngine -> TotemEngine i TYLKO aplikuje zwrócone delty/mutacje do RunState.
-- Żadna wzorowa matematyka (Moc/Rezonans/finalScore) nie żyje w tym pliku — to własność
-- ScoreEngine/TotemEngine (Framework, czyste moduły z Fazy 1).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local HandEvaluator = require(Shared.HandEvaluator)
local ScoreEngine = require(Shared.ScoreEngine)
local TotemEngine = require(Shared.TotemEngine)

local RunSessionService = require(script.Parent.RunSessionService)
type RunState = RunSessionService.RunState

local PlayService = {}

local function logLine(run: RunState, msg: string)
	table.insert(run.log, msg)
end

-- Aplikuje statePatch/gold/extraPlay/extraSwap z totemResults (onPlay/onScore) do RunState.
-- Wspólne dla play() i swap() — ScoreEngine/TotemEngine tylko ZWRACAJĄ delty, nigdy nie mutują.
local function applyTotemResults(run: RunState, totemResults: { any })
	for _, res in totemResults do
		if not res.applies then
			continue
		end
		if res.statePatch then
			run.totemState[res.totemId] = res.statePatch
		end
		if res.delta.goldFlat then
			run.gold += res.delta.goldFlat
		end
		if res.delta.extraPlay then
			run.playsRemaining += res.delta.extraPlay
		end
		if res.delta.extraSwap then
			run.swapsRemaining += res.delta.extraSwap
		end
	end
end

export type PlayOutcome = {
	ok: boolean,
	reason: string?,
	scoreResult: ScoreEngine.PlayResult?,
	encounterResult: { won: boolean, excessGold: number, baseGold: number, revived: boolean }?,
}

-- PlayRunes(indices): walidacja -> HandEvaluator -> ScoreEngine(+TotemEngine) -> mutacja RunState.
function PlayService.play(run: RunState, indices: { number }): PlayOutcome
	if run.status ~= "active" then
		return { ok = false, reason = "run not active" }
	end
	if run.playsRemaining <= 0 then
		return { ok = false, reason = "no plays remaining" }
	end
	local seen = {}
	for _, idx in indices do
		if idx < 1 or idx > #run.hand or seen[idx] then
			return { ok = false, reason = "invalid hand index" }
		end
		seen[idx] = true
	end
	if #indices < 1 or #indices > 5 then -- GameConfig.MaxPlaySize
		return { ok = false, reason = "invalid play size" }
	end

	-- indeksy rosnąco, żeby wynik był deterministyczny wobec kolejności ręki
	local sortedIdx = table.clone(indices)
	table.sort(sortedIdx)

	local playedRunes = {}
	for _, idx in sortedIdx do
		table.insert(playedRunes, run.hand[idx])
	end

	local handEval = HandEvaluator.evaluate(playedRunes, run.spellUpgrades)
	assert(handEval ~= nil, "PlayService: HandEvaluator returned nil for a non-empty play")

	local scoreCtx = { rngStream = run.streams.totemProc, ranked = run.mode == "ranked" }
	local scoreResult = ScoreEngine.score(playedRunes, {
		spellId = handEval.spellId,
		baseMoc = handEval.baseMoc,
		baseRezonans = handEval.baseRezonans,
	}, {
		totems = run.totems,
		totemState = run.totemState,
		elementNullifiers = run.elementNullifiers,
	}, scoreCtx)

	applyTotemResults(run, scoreResult.totemResults)
	run.score += scoreResult.finalScore

	-- onPlay phase (ekonomia, np. Coinpurr) — osobny wywołanie TotemEngine, osobna faza.
	local onPlayResults = TotemEngine.apply(run.totems, "onPlay", {
		playedRunes = playedRunes,
		spellId = handEval.spellId,
		totemState = run.totemState,
	})
	applyTotemResults(run, onPlayResults)

	-- zagrane runy -> discard; usuń z ręki (od najwyższego indeksu, żeby nie przesunąć reszty)
	for i = #sortedIdx, 1, -1 do
		local idx = sortedIdx[i]
		table.insert(run.discardPile, run.hand[idx])
		table.remove(run.hand, idx)
	end

	run.playsRemaining -= 1

	-- dobierz do pełnej ręki
	local refill = RunSessionService._drawCards(run, run.handSize - #run.hand)
	for _, rune in refill do
		table.insert(run.hand, rune)
	end

	logLine(
		run,
		`play [{table.concat(sortedIdx, ",")}] -> {handEval.spellId}: +{scoreResult.finalScore} (moc={scoreResult.moc} rez={scoreResult.rezonans}) | score={run.score}/{run.threshold} | playsRemaining={run.playsRemaining}`
	)

	local outcome: PlayOutcome = { ok = true, scoreResult = scoreResult }

	if run.playsRemaining <= 0 then
		outcome.encounterResult = RunSessionService.endEncounter(run, false)
	end

	return outcome
end

-- SwapRunes(indices): odrzuć do 5 run, dobierz nowe. onSwap-phase totemy aplikowane generycznie.
function PlayService.swap(run: RunState, indices: { number }): PlayOutcome
	if run.status ~= "active" then
		return { ok = false, reason = "run not active" }
	end
	if run.swapsRemaining <= 0 then
		return { ok = false, reason = "no swaps remaining" }
	end
	local seen = {}
	for _, idx in indices do
		if idx < 1 or idx > #run.hand or seen[idx] then
			return { ok = false, reason = "invalid hand index" }
		end
		seen[idx] = true
	end
	if #indices < 1 or #indices > 5 then
		return { ok = false, reason = "invalid swap size" }
	end

	local sortedIdx = table.clone(indices)
	table.sort(sortedIdx)

	for i = #sortedIdx, 1, -1 do
		local idx = sortedIdx[i]
		table.insert(run.discardPile, run.hand[idx])
		table.remove(run.hand, idx)
	end

	local onSwapResults = TotemEngine.apply(run.totems, "onSwap", {
		totemState = run.totemState,
	})
	applyTotemResults(run, onSwapResults)

	local refill = RunSessionService._drawCards(run, run.handSize - #run.hand)
	for _, rune in refill do
		table.insert(run.hand, rune)
	end

	run.swapsRemaining -= 1
	logLine(run, `swap [{table.concat(sortedIdx, ",")}] | swapsRemaining={run.swapsRemaining}`)

	return { ok = true }
end

-- EndEncounter: dobrowolne zakończenie starcia (Wariant B — hook w v1, bez profitu z dobrowolnego
-- zakończenia poza zwykłym excess->gold, które i tak dzieje się zawsze w endEncounter).
function PlayService.endEncounterVoluntary(run: RunState): PlayOutcome
	if run.status ~= "active" then
		return { ok = false, reason = "run not active" }
	end
	local result = RunSessionService.endEncounter(run, true)
	return { ok = true, encounterResult = result }
end

return PlayService
