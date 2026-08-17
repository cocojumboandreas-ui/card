--!strict
-- LeaderboardService (Faza 3 krok #5, Architektura §2 linia 73) — 2 tablice:
--   • daily (Seed Dnia) — WYŁĄCZNIE runy ranked (Andreas, wprost: "Seed Dnia ranking używa
--     WYNIKU RANKED, nie swobodnego — inaczej mieszasz dwa światy"). Publikowany wpis = MEDIANA
--     z top-3 najlepszych runów gracza danego dnia (anti-skrypt: jeden podkradziony "idealny"
--     ciąg decyzji nie wjeżdża na szczyt, trzeba 3 dobrych podejść). Żelazna zasada, bez cięcia.
--   • allTime — najlepszy pojedynczy run z KAŻDEGO trybu (swobodny legalnie korzysta z kolekcji —
--     to jest "flex" board, nie wyrównany; jedyny wyrównany to daily, patrz wyżej).
-- Tygodniowy leaderboard z Architektury świadomie WYCIĘTY tej rundy (STATUS.md cut-list,
-- zaakceptowane wcześniej) — daily+allTime pokrywają "dlaczego wracać jutro" i "dlaczego kolekcja
-- ma znaczenie", trzeci wymiar nie jest krytyczny dla retencji D1/D7.
--
-- Zapis TYLKO z RunSessionService.RunEnded (serwer liczy encounterIndex/gold, klient nigdy nie
-- dotyka wyniku). Żadnego bezpośredniego OrderedDataStore:SetAsync z eventu — wszystko idzie
-- przez pending-bufor i leci do DataStore w rytmie RefreshIntervalSeconds (throttle, limity Roblox).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local LeaderboardConfig = require(Shared.Configs.LeaderboardConfig)

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Net = require(Framework:WaitForChild("Net"))
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))

local LeaderboardService = {}

local _allTimeStore = nil
local _pendingDaily: { [number]: number } = {} -- userId -> mediana do zapisu (nadpisywana aż do flush)
local _pendingAllTime: { [number]: number } = {}
local _cache = {
	daily = { list = {}, updatedAt = 0 },
	allTime = { list = {}, updatedAt = 0 },
}

-- rankScore = encounterIndex jako dominująca cyfra, gold jako remis (patrz LeaderboardConfig).
local function computeRankScore(result: { encounterIndex: number, gold: number }): number
	local gold = math.clamp(result.gold, 0, LeaderboardConfig.GoldWeight - 1)
	return result.encounterIndex * LeaderboardConfig.GoldWeight + gold
end

local function getDailyStore(SeedService)
	return DataStoreService:GetOrderedDataStore(LeaderboardConfig.DailyStoreName, SeedService.DailyKey())
end

local function flushAndBroadcast(kind: string, store, pending: { [number]: number }, cacheEntry, leaderboardSync: RemoteEvent)
	local toWrite = {}
	for userId, score in pairs(pending) do
		toWrite[userId] = score
		pending[userId] = nil
	end
	for userId, score in pairs(toWrite) do
		local ok, err = pcall(function()
			store:SetAsync(tostring(userId), score)
		end)
		if not ok then
			warn(`[LeaderboardService] SetAsync failed kind={kind} userId={userId}: {err}`)
		end
	end

	local ok, pagesOrErr = pcall(function()
		return store:GetSortedAsync(false, LeaderboardConfig.TopN)
	end)
	if not ok then
		warn(`[LeaderboardService] GetSortedAsync failed kind={kind}: {pagesOrErr}`)
		return
	end

	local page = pagesOrErr:GetCurrentPage()
	local list = {}
	for rank, item in ipairs(page) do
		table.insert(list, { rank = rank, userId = tonumber(item.key), score = item.value })
	end
	cacheEntry.list = list
	cacheEntry.updatedAt = os.clock()
	leaderboardSync:FireAllClients(kind, list)
end

function LeaderboardService.Init() end

function LeaderboardService.Start()
	local RunSessionService = ServiceRegistry.get("RunSessionService")
	local ProfileService = ServiceRegistry.get("ProfileService")
	local SeedService = ServiceRegistry.get("SeedService")

	_allTimeStore = DataStoreService:GetOrderedDataStore(LeaderboardConfig.AllTimeStoreName)

	local getLeaderboard = Net.get("GetLeaderboard")
	local leaderboardSync = Net.get("LeaderboardSync")

	RunSessionService.RunEnded:Connect(function(player: Player, result)
		local profile = ProfileService.GetProfile(player)
		if profile == nil then
			return
		end
		local score = computeRankScore(result)

		if score > (profile.bestScores.allTime or 0) then
			profile.bestScores.allTime = score
			_pendingAllTime[player.UserId] = score
		end

		if result.mode ~= "ranked" then
			return
		end

		local dateKey = SeedService.DailyKey()
		local daily = profile.bestScores.daily
		-- daily[dateKey] = { scores = {top-3 malejąco}, median = number? }. Trzymamy TYLKO dzisiejszy
		-- klucz — poprzednie dni są śmieciem (Seed Dnia jest efemeryczny z definicji, allTime już to
		-- pamięta osobno powyżej).
		for k in pairs(daily) do
			if k ~= dateKey then
				daily[k] = nil
			end
		end
		local entry = daily[dateKey]
		if type(entry) ~= "table" then
			entry = { scores = {} }
			daily[dateKey] = entry
		end
		table.insert(entry.scores, score)
		table.sort(entry.scores, function(a, b)
			return a > b
		end)
		while #entry.scores > LeaderboardConfig.DailyTopCount do
			table.remove(entry.scores)
		end

		if #entry.scores >= LeaderboardConfig.DailyTopCount then
			-- posortowane malejąco top-3: środkowy element JEST medianą.
			local median = entry.scores[math.ceil(LeaderboardConfig.DailyTopCount / 2)]
			entry.median = median
			_pendingDaily[player.UserId] = median
		end
	end)

	getLeaderboard.OnServerInvoke = function(_player: Player, kind: string)
		if kind ~= "daily" and kind ~= "allTime" then
			return { ok = false, reason = "unknown kind" }
		end
		local cacheEntry = _cache[kind]
		return { ok = true, list = cacheEntry.list, updatedAt = cacheEntry.updatedAt }
	end

	task.spawn(function()
		while true do
			flushAndBroadcast("allTime", _allTimeStore, _pendingAllTime, _cache.allTime, leaderboardSync)
			flushAndBroadcast("daily", getDailyStore(SeedService), _pendingDaily, _cache.daily, leaderboardSync)
			task.wait(LeaderboardConfig.RefreshIntervalSeconds)
		end
	end)
end

return LeaderboardService
