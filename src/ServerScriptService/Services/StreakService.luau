--!strict
-- StreakService (Faza 3 krok #6, Architektura §2 linia 70) — daily login streak, kamienie milowe
-- D7/D14/D30, jawny claim (wzorzec IndexService.ClaimIndexLuck: osiągnięcie progu != odbiór).
--
-- "guard przeciw skew" (Architektura, wzorzec z offline earn RNG): OfflineEarnService broni się
-- przed cofniętym zegarem przez odejmowanie (elapsed = now-offlineTs, elapsed<0 -> 0). Tu nie ma
-- takiego wektora -- porównujemy WYŁĄCZNIE dateKey stringi z os.time() SERWERA (ten sam zaufany
-- zegar co SeedService.DailySeed gdzie indziej), nigdy elapsed ani nic od klienta. Jedyne 3 stany:
-- ten sam dzień (no-op), dokładnie wczoraj (kontynuacja), cokolwiek innego w tym luka >1 dzień i
-- HIPOTETYCZNY skok zegara wstecz (reset do 1) -- oba "dziwne" przypadki lądują bezpiecznie we
-- "wrong bucket" reset, nigdy w ujemnym/nieskończonym naliczeniu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StreakConfig = require(Shared.Configs.StreakConfig)

local StreakService = {}

local _profile, _economy, _seed = nil, nil, nil

-- PURE: nowy count z lastDateKey vs dzisiejszy/wczorajszy klucz. Ten sam dzień -> no-op (drugi
-- login tego samego dnia nie liczy się dwa razy). Dokładnie wczoraj -> +1. Cokolwiek innego
-- (pierwszy login, luka >1 dzień, cofnięty zegar) -> reset do 1.
local function computeNextCount(prevCount: number, lastDateKey: string, todayKey: string, yesterdayKey: string): number
	if lastDateKey == todayKey then
		return prevCount
	elseif lastDateKey == yesterdayKey then
		return prevCount + 1
	else
		return 1
	end
end

-- Wołane raz na ProfileLoaded (jedna aktualizacja dziennie na sesję).
function StreakService.TouchLogin(player: Player)
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return
	end
	local now = os.time()
	local todayKey = _seed.DailyKey(now)
	local yesterdayKey = _seed.DailyKey(now - 86400)
	data.streak = data.streak or { count = 0, lastDateKey = "", claimed = {} }
	data.streak.claimed = data.streak.claimed or {}
	data.streak.count = computeNextCount(data.streak.count, data.streak.lastDateKey, todayKey, yesterdayKey)
	data.streak.lastDateKey = todayKey
end

function StreakService.Claim(player: Player, days: number): (boolean, number?, string?)
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return false, nil, "NoProfile"
	end
	local milestone = nil
	for _, m in StreakConfig.Milestones do
		if m.days == days then
			milestone = m
			break
		end
	end
	if not milestone then
		return false, nil, "UnknownMilestone"
	end
	data.streak.claimed = data.streak.claimed or {}
	if data.streak.claimed[days] then
		return false, nil, "AlreadyClaimed"
	end
	if data.streak.count < days then
		return false, nil, "NotReached"
	end
	data.streak.claimed[days] = true -- JEDYNY zapis profile.streak.claimed
	local gained = _economy.AwardEssence(player, milestone.essence, "streak")
	return true, gained, nil
end

function StreakService.Init() end

function StreakService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_seed = ServiceRegistry.get("SeedService")

	_profile.ProfileLoaded:Connect(function(player: Player)
		StreakService.TouchLogin(player)
	end)

	Net.get("ClaimStreak").OnServerInvoke = function(player: Player, days: number)
		if type(days) ~= "number" then
			return { ok = false, reason = "BadArg" }
		end
		local ok, gained, reason = StreakService.Claim(player, days)
		return { ok = ok, essence = gained, reason = reason }
	end

	Net.get("GetStreakState").OnServerInvoke = function(player: Player)
		local data = _profile.GetProfile(player)
		if not data then
			return { ok = false, reason = "NoProfile" }
		end
		local claimed = (data.streak and data.streak.claimed) or {}
		local milestones = {}
		for _, m in StreakConfig.Milestones do
			table.insert(milestones, {
				days = m.days,
				essence = m.essence,
				reached = (data.streak.count or 0) >= m.days,
				claimed = claimed[m.days] == true,
			})
		end
		return { ok = true, count = (data.streak and data.streak.count) or 0, milestones = milestones }
	end
end

-- Hook TYLKO do testów.
function StreakService._ComputeNextCountForTest(prevCount: number, lastDateKey: string, todayKey: string, yesterdayKey: string)
	return computeNextCount(prevCount, lastDateKey, todayKey, yesterdayKey)
end

return StreakService
