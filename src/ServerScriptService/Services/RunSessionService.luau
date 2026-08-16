--!strict
-- RunSessionService — JEDYNY właściciel RunState (Architektura §2: "Cykl życia runu... JEDYNY
-- właściciel RunState"). Talia/ręka/złoto/totemy/scrolls/activeGuardian/budżet zagrań-wymian per
-- starcie żyją WYŁĄCZNIE tutaj; PlayService/RunShopService czytają i mutują RunState WYŁĄCZNIE
-- przez funkcje tego modułu.
--
-- Zakres uproszczony vs Architektura §2's "Czyta" (świadoma decyzja, ujawniona w raporcie ze
-- smoke-testu): ProfileService/StatProfileService/EconomyService/SeedService NIE istnieją jeszcze
-- (Faza 2+ per Architektura §7 — budowane PO tym kroku). RunSessionService jest więc na razie
-- samowystarczalny: złoto runowe trzymane wprost w RunState (uzasadnienie: EconomyService's own
-- opis rozróżnia "Esencja (persistent) + złoto runowe (per-run, ulotne)" — tylko ulotna połowa jest
-- w zakresie teraz), start z PUSTYM paskiem totemów (meta-kolekcyjny "pick 1 z 3" z GDD odłożony,
-- bo wymaga RollService/kolekcji, których nie ma).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local SeedUtil = require(Shared.SeedUtil)
local RuneConfig = require(Shared.Configs.RuneConfig)
local GameConfig = require(Shared.Configs.GameConfig)
local GuardianConfig = require(Shared.Configs.GuardianConfig)

type Rune = RuneConfig.Rune
type Stream = SeedUtil.Stream
type TotemDef = { [string]: any }
type Guardian = GuardianConfig.Guardian

export type RunState = {
	seed: number,
	mode: string, -- "free" | "ranked" (iron rule #12 — parametr istnieje, zachowanie na razie identyczne)
	streams: { [string]: Stream },

	level: number, -- 1..6
	encounterIndex: number, -- 1..12
	status: string, -- "active" | "won" | "lost"

	drawPile: { Rune },
	discardPile: { Rune },
	hand: { Rune },
	handSize: number,

	score: number, -- skumulowany wynik BIEŻĄCEGO starcia
	threshold: number,
	playsRemaining: number,
	swapsRemaining: number,

	gold: number,
	totems: { TotemDef },
	totemState: { [string]: any },
	spellUpgrades: { [string]: { mocBonus: number?, rezMult: number? } },
	scrolls: { any },

	elementNullifiers: { [string]: boolean },
	activeGuardian: Guardian?,
	deadElement: string?, -- odsłonięty PRZED starciem (GDD: debuff widoczny zawczasu)

	shopOffers: { [string]: any }?,
	shopRerollCost: number,

	log: { string },
}

local RunSessionService = {}

local function guardianForLevel(level: number): Guardian?
	for _, guardian in GuardianConfig.Guardians do
		if table.find(guardian.appliesToLevels, level) then
			return guardian
		end
	end
	return nil
end

local function levelForEncounter(encounterIndex: number): number
	return math.ceil(encounterIndex / GameConfig.EncountersPerLevel)
end

local function logLine(run: RunState, msg: string)
	table.insert(run.log, msg)
end

-- Dobiera `n` kart z drawPile; jeśli się wyczerpie, tasuje discardPile z powrotem strumieniem
-- "deck" (ta sama nazwana sekwencja, dalej deterministyczna) i kontynuuje.
local function drawCards(run: RunState, n: number): { Rune }
	local drawn = {}
	for _ = 1, n do
		if #run.drawPile == 0 then
			if #run.discardPile == 0 then
				break -- talia i stos odrzuconych puste — nie ma czym dobrać
			end
			run.drawPile = SeedUtil.shuffle(run.discardPile, run.streams.deck)
			run.discardPile = {}
			logLine(run, "reshuffle: discard -> drawPile")
		end
		local card = table.remove(run.drawPile)
		if card then
			table.insert(drawn, card)
		end
	end
	return drawn
end
RunSessionService._drawCards = drawCards -- eksponowane dla PlayService (refill ręki)

function RunSessionService.startEncounter(run: RunState)
	run.level = levelForEncounter(run.encounterIndex)
	local isGuardianEncounter = (run.encounterIndex % GameConfig.EncountersPerLevel) == 0
	local guardian = isGuardianEncounter and guardianForLevel(run.level) or nil
	run.activeGuardian = guardian

	local effect = guardian and guardian.effect or {}
	run.threshold = GameConfig.Thresholds[run.encounterIndex] * (effect.thresholdMult or 1)
	run.handSize = GameConfig.HandSize + (effect.handSizeDelta or 0)
	run.playsRemaining = GameConfig.PlaysPerEncounter + (effect.playsDelta or 0)
	run.swapsRemaining = GameConfig.SwapsPerEncounter
	run.score = 0
	run.elementNullifiers = {}
	run.deadElement = nil

	if effect.deadElementRandom then
		local idx = run.streams.guardian.nextInt(1, #RuneConfig.Elements)
		local element = RuneConfig.Elements[idx]
		run.elementNullifiers[element] = true
		run.deadElement = element -- odsłonięte PRZED starciem (log/UI czyta to pole)
	end

	-- odrzuć aktualną rękę, dobierz świeżą do handSize
	for _, rune in run.hand do
		table.insert(run.discardPile, rune)
	end
	run.hand = drawCards(run, run.handSize)

	logLine(
		run,
		`--- Encounter {run.encounterIndex} (level {run.level}) start: threshold={run.threshold} guardian={guardian and guardian.name or "none"} deadElement={run.deadElement or "none"} plays={run.playsRemaining} swaps={run.swapsRemaining} handSize={run.handSize} ---`
	)
end

function RunSessionService.startRun(seed: number, mode: string?): RunState
	local streams = SeedUtil.streams(seed)
	local drawPile = SeedUtil.shuffle(RuneConfig.buildDeck(), streams.deck)

	local run: RunState = {
		seed = seed,
		mode = mode or "free",
		streams = streams,

		level = 1,
		encounterIndex = 1,
		status = "active",

		drawPile = drawPile,
		discardPile = {},
		hand = {},
		handSize = GameConfig.HandSize,

		score = 0,
		threshold = 0,
		playsRemaining = 0,
		swapsRemaining = 0,

		gold = 0,
		totems = {}, -- pusty pasek startowy (meta pick odłożony, patrz komentarz na górze pliku)
		totemState = {},
		spellUpgrades = {},
		scrolls = {},

		elementNullifiers = {},
		activeGuardian = nil,
		deadElement = nil,

		shopOffers = nil,
		shopRerollCost = 0,

		log = {},
	}

	RunSessionService.startEncounter(run)
	return run
end

-- Wariant B: próg NIE kończy starcia automatycznie. Wywoływane przez PlayService gdy
-- playsRemaining==0 LUB gdy gracz dobrowolnie kończy przez EndEncounter (voluntary=true).
function RunSessionService.endEncounter(run: RunState, voluntary: boolean?): { won: boolean, excessGold: number, baseGold: number, revived: boolean }
	local reached = run.score >= run.threshold
	local excess = math.max(0, run.score - run.threshold)
	local excessGold = math.min(GameConfig.ExcessGoldCap, math.floor(excess / GameConfig.ExcessToGoldRate))
	run.gold += excessGold

	if reached then
		local rewardMult = (run.activeGuardian and run.activeGuardian.effect.rewardMult) or 1
		local baseGold = GameConfig.EncounterGoldReward * rewardMult
		run.gold += baseGold

		logLine(
			run,
			`Encounter {run.encounterIndex} CLEARED: score={run.score} threshold={run.threshold} excessGold={excessGold} baseGold={baseGold} totalGold={run.gold}`
		)

		run.encounterIndex += 1
		if run.encounterIndex > GameConfig.Levels * GameConfig.EncountersPerLevel then
			run.status = "won"
			logLine(run, "RUN WON: all 12 encounters cleared.")
		else
			RunSessionService.startEncounter(run)
		end

		return { won = true, excessGold = excessGold, baseGold = baseGold, revived = false }
	end

	-- Próg nieosiągnięty i budżet wyczerpany (lub dobrowolne zakończenie) -> sprawdź onFail (revive).
	local TotemEngine = require(Shared.TotemEngine)
	local failResults = TotemEngine.apply(run.totems, "onFail", { totemState = run.totemState })
	local revived = false
	for _, res in failResults do
		if res.applies and res.delta.revive then
			revived = true
			run.playsRemaining += (res.delta.extraPlay or 0)
			if res.statePatch then
				run.totemState[res.totemId] = res.statePatch
			end
			logLine(run, `onFail revive: totem={res.totemId} +{res.delta.extraPlay or 0} plays`)
		end
	end

	if revived and run.playsRemaining > 0 then
		logLine(run, `Encounter {run.encounterIndex} continues after revive (voluntary={tostring(voluntary or false)})`)
		return { won = false, excessGold = excessGold, baseGold = 0, revived = true }
	end

	run.status = "lost"
	logLine(
		run,
		`RUN LOST at encounter {run.encounterIndex}: score={run.score} threshold={run.threshold} voluntary={tostring(voluntary or false)}`
	)
	return { won = false, excessGold = excessGold, baseGold = 0, revived = false }
end

return RunSessionService
