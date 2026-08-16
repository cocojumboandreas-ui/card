--!nonstrict
-- ServerScriptService/Services/StatProfileService.luau
-- JEDYNE zrodlo statow (Architektura §2). Docelowo: bazy (GameConfig.StatBase) + delty skilli
-- (Faza 2b: SkillTreeService) + bonusy indeksu/gamepassow (POST-BRAMKA). Faza 2a: TRIMMED —
-- Recompute() zwraca same bazy (profile.skills jest zawsze pusty w tej fazie, wiec agregacja
-- skilli jest no-opem), ale ksztalt funkcji jest juz finalny zeby dolozenie Fazy 2b nie bylo
-- refaktorem (ten sam wzorzec co ranked-hook w ScoreEngine).
-- REGULA: zaden inny serwis nie liczy statow sam. RunSessionService czyta stad extraPlays/
-- extraSwaps/startPickSize, EconomyService czyta essenceMult.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Signal = require(Framework:WaitForChild("Signal"))
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("GameConfig"))

local STAT_FIELDS = { "luck", "essenceMult", "extraPlays", "extraSwaps", "startPickSize", "offlineRate", "fastRoll" }

local StatProfileService = {}

local _cache: { [Player]: any } = {}
local _profileService = nil

-- Swieza kopia baz z configu (nigdy nie mutujemy wspoldzielonej tabeli GameConfig.StatBase).
local function freshBase()
	local base = GameConfig.StatBase
	local out = {}
	for _, k in ipairs(STAT_FIELDS) do
		out[k] = base[k]
	end
	return out
end

-- Czysta agregacja: bazy + delty rankow skilli. Faza 2a: profileData.skills jest zawsze {} (brak
-- SkillTreeService), wiec ta petla nigdy nic nie dopisuje -- zostawiona zeby Faza 2b byla
-- podlaczeniem GameConfig.Skill.nodes, nie przepisaniem funkcji.
local function compute(profileData)
	local stats = freshBase()
	local skills = profileData and profileData.skills
	if type(skills) == "table" then
		local skillCfg = GameConfig.Skill
		local nodes = skillCfg and skillCfg.nodes
		if nodes then
			for nodeId, rank in pairs(skills) do
				local node = nodes[nodeId]
				if node and node.effect and type(rank) == "number" then
					local stat = node.effect.stat
					if stats[stat] ~= nil then
						stats[stat] = stats[stat] + node.effect.perRank * rank
					end
				end
			end
		end
	end
	return stats
end

function StatProfileService.Init()
	StatProfileService.StatsChanged = Signal.new() -- (player, Stats)
end

function StatProfileService.Recompute(player: Player)
	local data = _profileService and _profileService.GetProfile(player) or nil
	local stats = compute(data)
	_cache[player] = stats
	if StatProfileService.StatsChanged then
		StatProfileService.StatsChanged:Fire(player, stats)
	end
	return stats
end

function StatProfileService.Get(player: Player)
	local cached = _cache[player]
	if cached == nil then
		cached = StatProfileService.Recompute(player)
	end
	return cached
end

function StatProfileService.Start()
	_profileService = ServiceRegistry.get("ProfileService")

	_profileService.ProfileLoaded:Connect(function(player: Player)
		StatProfileService.Recompute(player)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		_cache[player] = nil
	end)

	-- Profile zaladowane zanim serwis wystartowal (load async).
	for _, player in ipairs(Players:GetPlayers()) do
		if _profileService.IsLoaded(player) then
			StatProfileService.Recompute(player)
		end
	end
end

-- Hook TYLKO do testow: policz bazy bez gracza/profilu (skille = 0).
function StatProfileService._ComputeBaseForTest()
	return compute(nil)
end
-- Hook TYLKO do testow: policz staty dla podanego profileData (bazy + delty skilli).
function StatProfileService._ComputeForTest(profileData)
	return compute(profileData)
end
-- Hook TYLKO do testow: wstrzyknij zaleznosci (profileService) do pelnego Recompute.
function StatProfileService._InjectForTest(deps)
	if deps.profileService ~= nil then
		_profileService = deps.profileService
	end
end

return StatProfileService
