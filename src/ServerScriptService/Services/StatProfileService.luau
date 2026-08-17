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
	-- Faza 2b: bonus luck z Indeksu (ODEBRANE progi, IndexService.ClaimLuck) — pobrane LENIWIE przez
	-- ServiceRegistry (nie top-level require) żeby uniknąć cyklu load-order z IndexService, który
	-- sam woła StatProfileService.Recompute po każdym claimie. compute() zostaje CZYSTE/testowalne;
	-- ten dopisek żyje tylko tutaj, w Recompute (ma player, compute() celowo go nie ma).
	if ServiceRegistry.has("IndexService") then
		stats.luck += ServiceRegistry.get("IndexService").GetLuckBonus(player)
	end
	_cache[player] = stats
	if StatProfileService.StatsChanged then
		StatProfileService.StatsChanged:Fire(player, stats)
	end
	return stats
end

-- Faza 4 (Ustalenie #2, brief "p2w nie przecieka do ranked"): pola które bezpośrednio zmieniają
-- mechanikę runu (ile razy gracz może zagrać/swapnąć/ile totemów wybrać na start) — zamknięta
-- lista, zweryfikowana grepem wszystkich call site'ów każdego STAT_FIELDS. luck/essenceMult/
-- offlineRate/fastRoll NIE są tu, bo dowodliwie nie dotykają rankScore ani mechaniki runu (patrz
-- plan Fazy 4) — nie karzemy p2w graczy na polach, które nie psują uczciwości Seed Dnia.
local RANKED_NEUTRAL_FIELDS = { "extraPlays", "extraSwaps", "startPickSize" }

-- mode=="ranked": zwraca staty z RANKED_NEUTRAL_FIELDS przywróconymi do GameConfig.StatBase,
-- niezależnie od skilli/indeksu/gamepassów w cache'u — Seed Dnia startuje z identycznymi
-- warunkami runu dla każdego gracza. Jedyny call site z mode: RunSessionService.startRunForPlayer.
function StatProfileService.Get(player: Player, mode: string?)
	local cached = _cache[player]
	if cached == nil then
		cached = StatProfileService.Recompute(player)
	end
	if mode == "ranked" then
		local neutral = table.clone(cached)
		for _, field in RANKED_NEUTRAL_FIELDS do
			neutral[field] = GameConfig.StatBase[field]
		end
		return neutral
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
-- Hook TYLKO do testow: wstrzyknij gotowe staty wprost do cache'a gracza, z pominieciem
-- Recompute/compute -- pozwala symulowac bonus z gamepassa/skilla (ktorych jeszcze nie ma w
-- kodzie, Faza 4 Krok 2/3) i sprawdzic mode-aware neutralizacje w Get() bez czekania na nie.
function StatProfileService._InjectStatsForTest(player: Player, stats)
	_cache[player] = stats
end

return StatProfileService
