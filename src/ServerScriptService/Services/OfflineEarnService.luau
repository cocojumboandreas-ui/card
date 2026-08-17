--!strict
-- ServerScriptService/Services/OfflineEarnService.luau (Faza 3, Architektura §2 "PORT 1:1 z RNG")
-- Flat-rate Esencji za czas offline, cap OfflineConfig.CapHours. 3 guardy portowane 1:1 z
-- D:/RobloxProjects/rng EconomyService.computeOfflineRaw:
--   1. first-login (profile.offlineTs==0) -> 0, NIE licz od epoki 1970.
--   2. clock-skew (now - offlineTs < 0) -> 0, nie ufaj cofniętemu zegarowi.
--   3. cap capHours -> elapsed przycięty, nie płacimy za nieskończone offline.
--
-- Guard przeciw podwójnemu naliczeniu (race ProfileReleasing / szybki re-login): baseline offlineTs
-- jest ZAWSZE świeży, z dwóch niezależnych miejsc — (a) ProfileService.onPlayerRemoving stempluje
-- profile.Data.offlineTs = os.time() PRZED EndSession (patrz ProfileService.luau:89, już istnieje,
-- nic tu nie trzeba dokładać), (b) ComputeOfflineEarnings sam resetuje offlineTs=now natychmiast po
-- policzeniu, zanim EconomyService.AwardEssence w ogóle ruszy -- więc crash-rejoin (serwer padł,
-- ProfileReleasing nigdy nie odpalił) i tak nie może naliczyć drugi raz z tego samego okna, bo drugi
-- ProfileLoaded na tym samym profilu w międzyczasie nie mógł nastąpić (session-lock ProfileStore).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local OfflineConfig = require(Shared.Configs.OfflineConfig)

local OfflineEarnService = {}

local _profile, _stat, _economy = nil, nil, nil
local _offlineRemote = nil

-- PURE: raw esencja (BEZ essenceMult -- ten mnożnik nakłada EconomyService.AwardEssence) + capped
-- sekundy. offlineRateBonus = Stats.offlineRate (delta ze skilli, Faza 2b+; 0 dziś -> no-op).
local function computeOfflineRaw(offlineTs: number, now: number, offlineRateBonus: number, capHours: number): (number, number, boolean)
	if offlineTs == 0 then
		return 0, 0, true -- first-login -> brak zarobków
	end
	local elapsed = now - offlineTs
	if elapsed < 0 then
		return 0, 0, false -- clock-skew -> brak zarobków, nie ufaj cofniętemu zegarowi
	end
	local capSeconds = capHours * 3600
	local seconds = math.min(elapsed, capSeconds)
	local raw = (seconds / 3600) * OfflineConfig.EssencePerHour * (1 + offlineRateBonus)
	return raw, seconds, false
end

-- Liczone na ProfileLoaded. Resetuje offlineTs=now NATYCHMIAST (anti double-grant, patrz komentarz
-- na górze pliku), potem przyznaje przez EconomyService.AwardEssence (essenceMult raz).
function OfflineEarnService.ComputeOfflineEarnings(player: Player): { essence: number, seconds: number }
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return { essence = 0, seconds = 0 }
	end
	local now = os.time()
	local stats = _stat and _stat.Get(player)
	local offlineRateBonus = (stats and stats.offlineRate) or 0
	local raw, seconds = computeOfflineRaw(data.offlineTs or 0, now, offlineRateBonus, OfflineConfig.CapHours)
	data.offlineTs = now
	local gained = (raw > 0) and _economy.AwardEssence(player, raw, "offline") or 0
	return { essence = gained, seconds = seconds }
end

function OfflineEarnService.Init() end

function OfflineEarnService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_stat = ServiceRegistry.get("StatProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_offlineRemote = Net.get("OfflineEarnings")

	_profile.ProfileLoaded:Connect(function(player: Player)
		local result = OfflineEarnService.ComputeOfflineEarnings(player)
		if result.essence > 0 then
			_offlineRemote:FireClient(player, result)
		end
	end)
end

-- Hook TYLKO do testów.
function OfflineEarnService._ComputeOfflineRawForTest(offlineTs: number, now: number, offlineRateBonus: number, capHours: number)
	return computeOfflineRaw(offlineTs, now, offlineRateBonus, capHours)
end
function OfflineEarnService._InjectForTest(deps: { profile: any, stat: any, economy: any })
	_profile, _stat, _economy = deps.profile, deps.stat, deps.economy
end

return OfflineEarnService
