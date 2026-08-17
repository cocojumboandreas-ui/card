--!strict
-- QuestService (Faza 3 krok #7, Architektura §2 linia 69) — 3 questy dzienne (reset UTC),
-- progres eventowy z sygnałów JUŻ istniejących (PlayService.SpellPlayed, RunSessionService.
-- GuardianDefeated/RunEnded, RollService.Rolled — zero nowych sygnałów), claim jawny (wzorzec
-- IndexService.ClaimIndexLuck/StreakService.Claim: osiągnięcie targetu != odbiór).
--
-- Reroll dnia: `ensureTodayQuests` wołane NA WEJŚCIU każdego handlera progresu (nie tylko na
-- ProfileLoaded) — gracz online w okolicy północy UTC dostaje świeżą listę przy pierwszym evencie
-- po rolowaniu dnia, bez potrzeby relogu (ten sam wzorzec co LeaderboardService czyszczący stare
-- dateKey przy każdym zapisie).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Configs.QuestConfig)

local QuestService = {}

local _profile, _economy, _seed = nil, nil, nil

local function poolEntry(id: string)
	for _, t in QuestConfig.Pool do
		if t.id == id then
			return t
		end
	end
	return nil
end

-- Fisher-Yates skrócony do N -- bez powtórzeń typu questa w jednym dniu.
local function pickDailyQuestIds(): { string }
	local ids = {}
	for _, t in QuestConfig.Pool do
		table.insert(ids, t.id)
	end
	local rng = Random.new()
	for i = #ids, 2, -1 do
		local j = rng:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end
	local picked = {}
	for i = 1, math.min(QuestConfig.DailyQuestCount, #ids) do
		table.insert(picked, ids[i])
	end
	return picked
end

local function ensureTodayQuests(player: Player)
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return nil
	end
	local todayKey = _seed.DailyKey(os.time())
	data.quests = data.quests or { dateKey = "", list = {} }
	if data.quests.dateKey ~= todayKey then
		local list = {}
		for _, id in pickDailyQuestIds() do
			table.insert(list, { questId = id, progress = 0, claimed = false })
		end
		data.quests.dateKey = todayKey
		data.quests.list = list
	end
	return data
end

-- Awansuje progres KAŻDEGO nieklaimowanego questa dnia, ktorego eventType pasuje i (jesli
-- matchFn podany) matchFn(template) zwraca true. Kilka questow tego samego eventType (nie
-- powinno sie zdarzyc przy DailyQuestCount<=#Pool bez powtorzen, ale kod nie zaklada tego).
local function progressForEvent(player: Player, eventType: string, matchFn: ((any) -> boolean)?)
	local data = ensureTodayQuests(player)
	if not data then
		return
	end
	for _, entry in data.quests.list do
		if not entry.claimed then
			local template = poolEntry(entry.questId)
			if template and template.eventType == eventType and (matchFn == nil or matchFn(template)) then
				entry.progress = math.min(entry.progress + 1, template.targetCount)
			end
		end
	end
end

function QuestService.Claim(player: Player, questId: string): (boolean, number?, string?)
	local data = ensureTodayQuests(player)
	if not data then
		return false, nil, "NoProfile"
	end
	local entry = nil
	for _, e in data.quests.list do
		if e.questId == questId then
			entry = e
			break
		end
	end
	if not entry then
		return false, nil, "UnknownQuest"
	end
	if entry.claimed then
		return false, nil, "AlreadyClaimed"
	end
	local template = poolEntry(questId)
	if not template or entry.progress < template.targetCount then
		return false, nil, "NotReached"
	end
	entry.claimed = true -- JEDYNY zapis profile.quests.list[].claimed
	local gained = _economy.AwardEssence(player, template.rewardEssence, "quest")
	return true, gained, nil
end

function QuestService.Init() end

function QuestService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_seed = ServiceRegistry.get("SeedService")
	local RunSessionService = ServiceRegistry.get("RunSessionService")
	local PlayService = ServiceRegistry.get("PlayService")
	local RollService = ServiceRegistry.get("RollService")

	_profile.ProfileLoaded:Connect(function(player: Player)
		ensureTodayQuests(player)
	end)

	PlayService.SpellPlayed:Connect(function(player: Player, spellId: string, _score: number)
		progressForEvent(player, "spellPlayed", function(t)
			return t.spellId == spellId
		end)
	end)

	RunSessionService.GuardianDefeated:Connect(function(player: Player, _guardianId: string)
		progressForEvent(player, "guardianDefeated")
	end)

	RunSessionService.RunEnded:Connect(function(player: Player, result)
		if result.status == "won" then
			progressForEvent(player, "runWon")
		end
	end)

	RollService.Rolled:Connect(function(player: Player, result)
		if result.ok then
			progressForEvent(player, "totemRolled")
		end
	end)

	Net.get("ClaimQuest").OnServerInvoke = function(player: Player, questId: string)
		if type(questId) ~= "string" then
			return { ok = false, reason = "BadArg" }
		end
		local ok, gained, reason = QuestService.Claim(player, questId)
		return { ok = ok, essence = gained, reason = reason }
	end

	Net.get("GetQuestState").OnServerInvoke = function(player: Player)
		local data = ensureTodayQuests(player)
		if not data then
			return { ok = false, reason = "NoProfile" }
		end
		local list = {}
		for _, entry in data.quests.list do
			local template = poolEntry(entry.questId)
			table.insert(list, {
				questId = entry.questId,
				desc = template and template.desc or "",
				target = template and template.targetCount or 0,
				rewardEssence = template and template.rewardEssence or 0,
				progress = entry.progress,
				claimed = entry.claimed,
			})
		end
		return { ok = true, dateKey = data.quests.dateKey, list = list }
	end
end

-- Hook TYLKO do testów.
function QuestService._PoolEntryForTest(id: string)
	return poolEntry(id)
end

return QuestService
