--!strict
-- Framework/Net.luau — JEDNO zrodlo nazw remote'ow (Architektura §5 "Remotes").
-- Server: tworzy instancje remote'ow w ReplicatedStorage.Net przy require.
-- Client: Net.get(name) czeka na zreplikowana instancje.
-- Serwis/kontroler NIGDY nie tworzy remote'ow recznie ani nie hardkoduje nazw.
-- Port wzorca z D:/RobloxProjects/rng/src/ReplicatedStorage/Framework/Net.luau, REMOTES tabela
-- wlasna dla Roll a Rune (Faza 2a: run lifecycle + essence; Faza 2b dokłada Roll/Index remotes).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Net"

-- name -> ClassName. Kierunek/payload = komentarz obok; tu tylko klasa instancji.
local REMOTES: { [string]: string } = {
	-- Faza 2a: run lifecycle
	StartRun = "RemoteFunction", -- C->S (mode:string?) -> RunState (snapshot na start; mode="free" jedyny obslugiwany w 2a)
	AbandonRun = "RemoteEvent", -- C->S () — gracz porzuca aktywny run (cash-out zlota->essence, patrz EconomyService)
	PlayRunes = "RemoteFunction", -- C->S (indices:{number}) -> PlayOutcome
	SwapRunes = "RemoteFunction", -- C->S (indices:{number}) -> PlayOutcome
	EndEncounterVoluntary = "RemoteFunction", -- C->S () -> PlayOutcome
	BuyShopItem = "RemoteFunction", -- C->S (slotKey:"totem"|"upgrade"|"scroll") -> {ok, reason?}
	RerollShop = "RemoteFunction", -- C->S () -> {ok, reason?}
	PickStartTotem = "RemoteFunction", -- C->S (totemId:string) -> {ok, reason?} — start-of-run pick (Faza 4 Krok 0), opcje w RunState.startPickOptions
	RunStateSync = "RemoteEvent", -- S->C RunState (push po kazdej mutacji: play/swap/shop) — klient renderuje z tego, nie z return value

	-- Faza 2a: persystencja (Essence)
	EssenceSync = "RemoteEvent", -- S->C {balance:number}

	-- Faza 2b: roll + indeks
	RollTotem = "RemoteFunction", -- C->S () -> RollResult{ok, totemId?, tier?, variant?, isNewDiscovery?, pityTriggered?, essence?, reason?}
	ClaimIndexLuck = "RemoteFunction", -- C->S (pct:number) -> {ok, luckBonus?, reason?}
	GetIndexState = "RemoteFunction", -- C->S () -> IndexState{entries, overall, luckBonus, thresholds}

	-- Faza 3: retencja
	OfflineEarnings = "RemoteEvent", -- S->C {essence:number, seconds:number} — jednorazowy popup po ProfileLoaded, tylko gdy essence>0
	GetLeaderboard = "RemoteFunction", -- C->S (kind:"daily"|"allTime") -> {ok, list?:{{rank,userId,score}}, updatedAt?, reason?}
	LeaderboardSync = "RemoteEvent", -- S->C (kind:"daily"|"allTime", list:{{rank,userId,score}}) — push po każdym cache-refresh (co 60s)
	ClaimStreak = "RemoteFunction", -- C->S (days:number) -> {ok, essence?, reason?}
	GetStreakState = "RemoteFunction", -- C->S () -> {ok, count, milestones:{{days,essence,reached,claimed}}}
	ClaimQuest = "RemoteFunction", -- C->S (questId:string) -> {ok, essence?, reason?}
	GetQuestState = "RemoteFunction", -- C->S () -> {ok, dateKey, list:{{questId,desc,target,rewardEssence,progress,claimed}}}
	AnnouncementSync = "RemoteEvent", -- S->C {name, totemId, tier, variant} — push z MessagingService:SubscribeAsync callbacku (patrz AnnouncementService)

	-- Faza 4: monetyzacja
	GetOddsTable = "RemoteFunction", -- C->S () -> {tiers:{{tier,pct}}, tiersNote, variants:{{id,pct}}, variantsExcluded, pity} (PolicyService, cache-owane raz po stronie serwera)

	-- Faza 4 Krok 5: FTUE
	FtueSync = "RemoteEvent", -- S->C {ftueDone:boolean} — push raz po ProfileLoaded (FtueService)
	MarkFtueDone = "RemoteEvent", -- C->S () — klient (FTUEController) sygnalizuje koniec sekwencji onboardingu; serwer ustawia profile.ftueDone=true (idempotent, fire-and-forget)
}

local Net = {}

local function ensureServerFolder(): Folder
	local f = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if f == nil then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = ReplicatedStorage
	end
	return f :: Folder
end

-- Server: zbuduj wszystkie remote'y raz (idempotentnie).
if RunService:IsServer() then
	local folder = ensureServerFolder()
	for name, className in pairs(REMOTES) do
		local existing = folder:FindFirstChild(name)
		if existing ~= nil and existing.ClassName ~= className then
			existing:Destroy()
			existing = nil
		end
		if existing == nil then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
end

-- Zwraca instancje remote'a. Server: gotowa; Client: czeka na replikacje.
function Net.get(name: string): Instance
	assert(REMOTES[name] ~= nil, "Net: unknown remote '" .. tostring(name) .. "'")
	if RunService:IsServer() then
		return ensureServerFolder():WaitForChild(name)
	else
		local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
		return folder:WaitForChild(name)
	end
end

-- Lista zdefiniowanych nazw (do testow/diagnostyki).
function Net.list(): { string }
	local names = {}
	for name in pairs(REMOTES) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

function Net.classOf(name: string): string?
	return REMOTES[name]
end

return Net
