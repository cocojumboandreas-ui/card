--!nonstrict
-- ServerScriptService/Services/IndexService.luau (Faza 2b, port z WAR RNG Etap 2+4 — uproszczony)
-- Kolekcja Stworków: discovery + progi kompletności + klaimowalny bonus luck. Warianty (Foil/Gold/
-- Galaxy/Rainbow) NIE mają własnej zakładki (WAR RNG miał osobne zakładki per-wariant) — tu są
-- DRUGĄ WARSTWĄ, sczytywaną z klucza "totemId#variant" tego samego totemId (Architektura §6:
-- "warianty jako druga warstwa po samych Stworkach").
--
-- BRAK oddzielnej tabeli profile.index: profile.totems["totemId#variant"]=count JEST już ledgerem
-- odkryć (rośnie tylko, nigdy nie jest zużywany gdzie indziej — inaczej niż WAR RNG-owy Inventory,
-- który się zużywa, więc tam osobny profile.index był konieczny). Discovered(totemId) = istnieje
-- klucz "totemId#<jakikolwiek wariant>" z count>0. Jedno źródło prawdy, zero migracji.
--
-- ETAP 4 (WAR RNG): luck = NAJWYŻSZY ODEBRANY (claimed) próg, nie najwyżej OSIĄGNIĘTY — trzeba
-- ODBIERZ. deps: ProfileService. Czytany leniwie przez StatProfileService (patrz tamtego pliku).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Signal = require(Framework:WaitForChild("Signal"))
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))
local IndexConfig = require(Shared:WaitForChild("IndexConfig"))

local IndexService = {}

local _profileService = nil
local _stat = nil -- StatProfileService (Recompute po ClaimLuck — luck się zmienił)

-- true jesli GRACZ ma JAKIKOLWIEK wariant tego totemId w profile.totems (count>0).
function IndexService.IsDiscovered(player: Player, totemId: string): boolean
	local data = _profileService and _profileService.GetProfile(player)
	if not data then
		return false
	end
	for _, v in VariantConfig.ladder do
		if (data.totems[totemId .. "#" .. v.id] or 0) > 0 then
			return true
		end
	end
	return (data.totems[totemId .. "#" .. VariantConfig.Void] or 0) > 0
end

-- (discoveredCount, total, percent) po CAŁYM rosterze MVP (TotemConfig.Totems).
function IndexService.GetCompletion(player: Player): (number, number, number)
	local discovered, total = 0, 0
	for id in TotemConfig.Totems do
		total += 1
		if IndexService.IsDiscovered(player, id) then
			discovered += 1
		end
	end
	local percent = total > 0 and (discovered / total * 100) or 0
	return discovered, total, percent
end

-- luck = NAJWYŻSZY ODEBRANY (claimed) prog. Samo osiagniecie % NIE daje luck — trzeba ODBIERZ.
function IndexService.GetLuckBonus(player: Player): number
	local data = _profileService and _profileService.GetProfile(player)
	local claims = (data and data.indexClaims) or {}
	local best = 0
	for _, t in IndexConfig.luckThresholds do
		if claims[t.pct] and t.luck > best then
			best = t.luck
		end
	end
	return best
end

-- ODBIERZ (claim) prog. Warunek: osiagniety (percent>=pct) i nieodebrany. Serwer-autorytatywny.
-- Zwraca (ok, luckBonus?, reason?). reason: NoProfile|UnknownThreshold|AlreadyClaimed|NotReached.
function IndexService.ClaimLuck(player: Player, pct: number): (boolean, number?, string?)
	local data = _profileService and _profileService.GetProfile(player)
	if not data then
		return false, nil, "NoProfile"
	end
	local thr
	for _, t in IndexConfig.luckThresholds do
		if t.pct == pct then
			thr = t
			break
		end
	end
	if not thr then
		return false, nil, "UnknownThreshold"
	end
	data.indexClaims = data.indexClaims or {}
	if data.indexClaims[pct] then
		return false, nil, "AlreadyClaimed"
	end
	local _, _, percent = IndexService.GetCompletion(player)
	if percent < pct then
		return false, nil, "NotReached"
	end
	data.indexClaims[pct] = true -- JEDYNY zapis profile.indexClaims
	if _stat then
		_stat.Recompute(player) -- luck sie zmienil (GetLuckBonus czyta claims) -> przelicz Stats + StatsSync
	end
	return true, IndexService.GetLuckBonus(player), nil
end

-- Wolane przez RollService PRZED zapisem do profile.totems (kolejność ma znaczenie: discovery
-- state jest WYLICZANY z profile.totems, więc trzeba sprawdzić ZANIM ten rzut dopisze klucz).
-- Zwraca true jesli to byl NOWY totemId (jakikolwiek wariant), false jesli juz znany.
function IndexService.Discover(player: Player, totemId: string, variant: string?): boolean
	local wasNew = not IndexService.IsDiscovered(player, totemId)
	if wasNew then
		IndexService.IndexUpdated:Fire(player, totemId, variant)
	end
	return wasNew
end

function IndexService.Init()
	IndexService.IndexUpdated = Signal.new() -- (player, totemId, variant) -- TYLKO gdy totemId nowy
end

function IndexService.Start()
	_profileService = ServiceRegistry.get("ProfileService")
	_stat = ServiceRegistry.get("StatProfileService")

	Net.get("ClaimIndexLuck").OnServerInvoke = function(player, pct)
		if type(pct) ~= "number" then
			return { ok = false, reason = "BadArg" }
		end
		local ok, luckBonus, reason = IndexService.ClaimLuck(player, pct)
		return { ok = ok, luckBonus = luckBonus, reason = reason }
	end

	Net.get("GetIndexState").OnServerInvoke = function(player)
		local data = _profileService.GetProfile(player)
		local entries = {}
		local discovered, total = 0, 0
		for id, totem in TotemConfig.Totems do
			total += 1
			local isDiscovered = IndexService.IsDiscovered(player, id)
			if isDiscovered then
				discovered += 1
			end
			entries[#entries + 1] = { id = id, name = totem.name, tier = totem.tier, discovered = isDiscovered }
		end
		table.sort(entries, function(a, b)
			return a.id < b.id
		end)
		local percent = total > 0 and (discovered / total * 100) or 0
		local claims = (data and data.indexClaims) or {}
		local thresholds = {}
		for _, t in IndexConfig.luckThresholds do
			thresholds[#thresholds + 1] = { pct = t.pct, luck = t.luck, reached = percent >= t.pct, claimed = claims[t.pct] == true }
		end
		return {
			entries = entries,
			overall = { count = discovered, total = total, percent = percent },
			luckBonus = IndexService.GetLuckBonus(player),
			thresholds = thresholds,
		}
	end
end

-- Hooki TYLKO do testow.
function IndexService._SetProfileServiceForTest(fake)
	_profileService = fake
end

return IndexService
