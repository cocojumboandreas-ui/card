--!strict
-- ServerScriptService/Services/EssenceTickService.luau (T3, pasywna esencja) — online tyk esencji z
-- wystawionych kart na plocie. Stawka = PlotService.RatePerSecond(profile.plotSlots) (JEDYNE
-- źródło, współdzielone z OfflineEarnService -- ta sama dyscyplina co TierColorConfig/TotemPool).
--
-- Pętla task.spawn/while/task.wait, wzorzec 1:1 z LeaderboardService (jeden globalny loop, nie
-- osobny timer per gracz). Akumulator ułamkowy (_pending) na gracza -- bez niego pojedyncza Common
-- (rate << 1/tick przy TickIntervalSeconds=5) nigdy nie przekroczyłaby math.floor i esencja realnie
-- by nie rosła mimo poprawnej matematycznie stawki -- to NIE jest zaokrąglanie w dół co tyk, tylko
-- przenoszenie reszty do następnego.
--
-- Juice "za darmo": EssenceGenerator dostaje 2 atrybuty co udany tyk -- LastTickAmount (wartość do
-- popupu) i LastTickSeq (rosnący licznik, WYŁĄCZNIE po to, żeby AttributeChangedSignal odpalił na
-- kliencie nawet gdy dwa kolejne tyki dają identyczną kwotę -- Roblox nie fire'uje sygnału zmiany
-- atrybutu, gdy jego wartość się nie zmienia). Zero remote'u, ten sam wzorzec replikacji co karty
-- na slotach w PlotService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))

local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local EssenceRateConfig = require(Shared:WaitForChild("EssenceRateConfig"))

local EssenceTickService = {}

local _profile, _economy, _plot = nil, nil, nil
local _pending: { [Player]: number } = {}
local _tickSeq = 0

local function tickPlayer(player: Player)
	local data = _profile.GetProfile(player)
	if not data then
		return
	end
	local rate = _plot.RatePerSecond(data.plotSlots or {})
	if rate <= 0 then
		return
	end
	_pending[player] = (_pending[player] or 0) + rate * EssenceRateConfig.TickIntervalSeconds
	local award = math.floor(_pending[player])
	if award < 1 then
		return
	end
	_pending[player] -= award
	local gained = _economy.AwardEssence(player, award, "passive")
	if gained <= 0 then
		return
	end
	local plotModel = _plot.GetPlotModel(player)
	local gen = plotModel and plotModel:FindFirstChild("EssenceGenerator")
	if gen then
		_tickSeq += 1
		gen:SetAttribute("LastTickAmount", gained)
		gen:SetAttribute("LastTickSeq", _tickSeq)
	end
end

function EssenceTickService.Init() end

function EssenceTickService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_plot = ServiceRegistry.get("PlotService")

	_profile.ProfileReleasing:Connect(function(player: Player)
		_pending[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(EssenceRateConfig.TickIntervalSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				tickPlayer(player)
			end
		end
	end)
end

-- Hooki TYLKO do testów.
function EssenceTickService._TickPlayerForTest(player: Player)
	tickPlayer(player)
end
function EssenceTickService._InjectForTest(deps: { profile: any, economy: any, plot: any })
	_profile, _economy, _plot = deps.profile, deps.economy, deps.plot
end

return EssenceTickService
