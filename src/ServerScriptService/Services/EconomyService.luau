--!nonstrict
-- ServerScriptService/Services/EconomyService.luau (Architektura §2)
-- Esencja (persistent): JEDYNY writer profile.essence. Złoto runowe (per-run, ulotne) NIE żyje
-- tutaj — to własność RunState/RunSessionService (Faza 1 decyzja, wciąż aktualna). Offline earn =
-- POST-BRAMKA (nie w zakresie Fazy 2a, patrz cut-lista Architektura §8). deps: ProfileService,
-- StatProfileService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Signal = require(Framework:WaitForChild("Signal"))
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local EconomyService = {}

local _profile, _stat = nil, nil
local _essenceSync = nil -- cache remote'a (guard: nil w edit-mode tescie)

function EconomyService.GetEssence(player): number
	local data = _profile and _profile.GetProfile(player)
	return data and data.essence or 0
end

local function pushBalance(player, balance)
	if _essenceSync then
		_essenceSync:FireClient(player, { balance = balance })
	end
	EconomyService.EssenceChanged:Fire(player, balance)
end

-- amount x Stats.essenceMult; zwraca faktycznie dodana esencje
function EconomyService.AwardEssence(player, amount: number, reason: string?): number
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return 0
	end
	local mult = (_stat and _stat.Get(player).essenceMult) or 1
	local gained = math.floor(amount * mult + 0.5)
	data.essence += gained
	pushBalance(player, data.essence)
	return gained
end

-- amount BEZ Stats.essenceMult — dla konwersji po stałym kursie (np. MergeService.Disenchant), nie
-- "nagroda". Gracz z essenceMult z gamepassa nie ma dostawać więcej essence za tę samą kartę, inaczej
-- disenchant przestaje być jednakowo stratnym sinkiem dla płacących i niepłacących.
function EconomyService.AwardEssenceFlat(player, amount: number): number
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return 0
	end
	data.essence += amount
	pushBalance(player, data.essence)
	return amount
end

function EconomyService.TrySpendEssence(player, amount: number): boolean
	local data = _profile and _profile.GetProfile(player)
	if not data or data.essence < amount then
		return false
	end
	data.essence -= amount
	pushBalance(player, data.essence)
	return true
end

function EconomyService.Init()
	EconomyService.EssenceChanged = Signal.new() -- (player, newBalance)
end

function EconomyService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_stat = ServiceRegistry.get("StatProfileService")
	_essenceSync = Net.get("EssenceSync")

	_profile.ProfileLoaded:Connect(function(player)
		pushBalance(player, EconomyService.GetEssence(player))
	end)
end

-- Hooki TYLKO do testow.
function EconomyService._InjectForTest(deps)
	_profile, _stat = deps.profile, deps.stat
end

return EconomyService
