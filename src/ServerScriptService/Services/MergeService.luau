--!nonstrict
-- ServerScriptService/Services/MergeService.luau — System 3 (Merge/Craft), zatwierdzone
-- MERGE_PLAN_PROPOSAL.md sekcja 7+8 (2026-08-18). 5x Stworek (wariant Normal) tieru T -> 1x losowy
-- Stworek tieru T+1 (ważony ku nieodkrytym w tym tierze, uniform-fallback gdy tier skompletowany) +
-- essence cost. Disenchant: nadmiarowa kopia Rare (dowolny wariant, count>1) -> essence po stałym
-- kursie (bez essenceMult, patrz EconomyService.AwardEssenceFlat).
--
-- ANTY-DUPE (Andreas, /rc): walidacja "ma 5 + ma essence" i mutacja "skonsumuj 5 + odejmij essence +
-- przyznaj 1" żyją w JEDNYM synchronicznym wywołaniu Merge()/Disenchant() -- zero yieldów (brak
-- task.wait/DataStore/Invoke) między sprawdzeniem a zapisem do profile.totems, dokładnie wzorzec
-- RunShopService.buy/PurchaseService.ProcessReceipt. Dwa szybkie remote calle NIE mogą oba przejść
-- walidację przed czyjąkolwiek mutacją, bo Luau na serwerze jest single-threaded per wywołanie i tu
-- nic nie oddaje kontroli między check a write.
--
-- collectionScoped: wynik merge trafia do profile.totems/IndexService dokładnie jak roll (RollService)
-- -- zero nowego kodu ścieżki ranked, bo RunShopService.rankedTotemPool czyta WYŁĄCZNIE
-- RankedConfig.TotemIds (stała lista), IndexService.IsDiscovered nigdy nie jest wołane w tej gałęzi
-- (RunShopService.luau:45-46,50-61) -- zweryfikowane w kodzie 2026-08-18, nie założone.
-- deps: ProfileService, EconomyService, IndexService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))
local MergeConfig = require(Shared:WaitForChild("MergeConfig"))

local NORMAL = "Normal"

local MergeService = {}

local _profile, _economy, _index = nil, nil, nil

-- tier -> {id,...} cache (roster jest statyczny w runtime, wzorzec RollService.totemsSorted).
local _byTier = nil
local function totemsByTier()
	if _byTier then
		return _byTier
	end
	local map = {}
	for id, totem in TotemConfig.Totems do
		map[totem.tier] = map[totem.tier] or {}
		table.insert(map[totem.tier], id)
	end
	_byTier = map
	return map
end

-- PURE (testowalna): wynik merge w resultTier, ważony ku nieodkrytym (isDiscovered:(id)->boolean) --
-- uniform-fallback na CAŁY tier gdy wszystkie jego id już odkryte (Andreas /rc poprawka #1: "hak =
-- kompletuj indeks", 6. kopia tego samego przy merge to feel-bad; cap na Rare i tak chroni paczki,
-- więc szybsze kompletowanie Uncommon/Rare nie szkodzi monetyzacji).
local function selectMergeResult(resultTier: string, isDiscovered: (string) -> boolean, rng: Random): string?
	local candidates = totemsByTier()[resultTier]
	if not candidates or #candidates == 0 then
		return nil
	end
	local undiscovered = {}
	for _, id in candidates do
		if not isDiscovered(id) then
			table.insert(undiscovered, id)
		end
	end
	local pool = #undiscovered > 0 and undiscovered or candidates
	return pool[rng:NextInteger(1, #pool)]
end

-- Handler Net.MergeTotem: 5x totemId#Normal (tier Common|Uncommon) + essence -> 1x losowy tier+1.
function MergeService.Merge(player: Player, totemId: string)
	if not (_profile and _profile.IsLoaded(player)) then
		return { ok = false, reason = "NotLoaded" }
	end
	local totem = TotemConfig.Totems[totemId]
	if not totem then
		return { ok = false, reason = "UnknownTotem" }
	end
	local resultTier = MergeConfig.NextTier[totem.tier]
	if not resultTier then
		return { ok = false, reason = "TierCapped" }
	end

	local data = _profile.GetProfile(player)
	local key = totemId .. "#" .. NORMAL
	local count = data.totems[key] or 0
	local threshold = MergeConfig.Threshold.Normal
	if count < threshold then
		return { ok = false, reason = "NotEligible" }
	end

	local cost = MergeConfig.EssenceCost[totem.tier]
	if not _economy.TrySpendEssence(player, cost) then
		return { ok = false, reason = "InsufficientEssence" }
	end

	-- Od TEGO punktu do końca funkcji: ŻADEN yield (anty-dupe, patrz komentarz na górze pliku).
	local rng = Random.new()
	local resultId = selectMergeResult(resultTier, function(id)
		return _index.IsDiscovered(player, id)
	end, rng)
	if not resultId then
		-- Nie powinno się zdarzyć (każdy tier w NextTier ma >=1 Stworka w rosterze), ale essence już
		-- wydana pod TrySpendEssence powyżej -- oddaj ją, nie zjadaj essence za nic.
		_economy.AwardEssenceFlat(player, cost)
		return { ok = false, reason = "NoCandidates" }
	end

	-- Discover PRZED zapisem klucza (stan odkrycia liczony z profile.totems, wzorzec RollService).
	local isNewDiscovery = _index.Discover(player, resultId, NORMAL)

	data.totems[key] = count - threshold
	local resultKey = resultId .. "#" .. NORMAL
	data.totems[resultKey] = (data.totems[resultKey] or 0) + 1
	data.lifetimeMerges += 1

	return {
		ok = true,
		resultTotemId = resultId,
		resultTier = resultTier,
		resultVariant = NORMAL,
		isNewDiscovery = isNewDiscovery,
		essence = _economy.GetEssence(player),
	}
end

-- Handler Net.DisenchantTotem: nadmiarowa kopia Rare (dowolny wariant, count>1) -> essence stały kurs.
function MergeService.Disenchant(player: Player, totemId: string, variant: string)
	if not (_profile and _profile.IsLoaded(player)) then
		return { ok = false, reason = "NotLoaded" }
	end
	local totem = TotemConfig.Totems[totemId]
	if not totem or totem.tier ~= MergeConfig.DisenchantTier then
		return { ok = false, reason = "NotRare" }
	end

	local data = _profile.GetProfile(player)
	local key = totemId .. "#" .. variant
	local count = data.totems[key] or 0
	if count <= 1 then
		return { ok = false, reason = "OnlyCopy" }
	end

	-- Od TEGO punktu do końca funkcji: ŻADEN yield (anty-dupe).
	data.totems[key] = count - 1
	data.lifetimeDisenchants += 1
	_economy.AwardEssenceFlat(player, MergeConfig.DisenchantValueEssence)

	return { ok = true, essence = _economy.GetEssence(player) }
end

-- GetMergeState: co gracz może zmergować (Common/Uncommon, liczone WYŁĄCZNIE po wariancie Normal --
-- mix Normal+Foil NIE sumuje się do progu, patrz Andreas /rc poprawka #3) i disenchantować (Rare,
-- dowolny wariant, count>1). UI (IndexController) woła to obok GetIndexState przy otwarciu panelu.
function MergeService.GetMergeState(player: Player)
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return { mergeable = {}, disenchantable = {} }
	end

	local mergeable = {}
	for tier, cost in MergeConfig.EssenceCost do
		for id, totem in TotemConfig.Totems do
			if totem.tier == tier then
				local count = data.totems[id .. "#" .. NORMAL] or 0
				if count > 0 then
					table.insert(mergeable, {
						id = id,
						name = totem.name,
						tier = tier,
						count = count, -- Normal-only, NIE suma wariantów -- UI musi pokazać "Normal: x/5"
						cost = cost,
						eligible = count >= MergeConfig.Threshold.Normal,
					})
				end
			end
		end
	end
	table.sort(mergeable, function(a, b)
		return a.id < b.id
	end)

	local disenchantable = {}
	for key, count in data.totems do
		if count > 1 then
			local id, variant = key:match("^(.+)#(.+)$")
			if id then
				local totem = TotemConfig.Totems[id]
				if totem and totem.tier == MergeConfig.DisenchantTier then
					table.insert(disenchantable, {
						id = id,
						variant = variant,
						name = totem.name,
						count = count,
						value = MergeConfig.DisenchantValueEssence,
					})
				end
			end
		end
	end
	table.sort(disenchantable, function(a, b)
		return a.id .. a.variant < b.id .. b.variant
	end)

	return { mergeable = mergeable, disenchantable = disenchantable }
end

function MergeService.Init() end

function MergeService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_index = ServiceRegistry.get("IndexService")

	Net.get("MergeTotem").OnServerInvoke = function(player, totemId)
		if type(totemId) ~= "string" then
			return { ok = false, reason = "BadArg" }
		end
		return MergeService.Merge(player, totemId)
	end

	Net.get("DisenchantTotem").OnServerInvoke = function(player, totemId, variant)
		if type(totemId) ~= "string" or type(variant) ~= "string" then
			return { ok = false, reason = "BadArg" }
		end
		return MergeService.Disenchant(player, totemId, variant)
	end

	Net.get("GetMergeState").OnServerInvoke = function(player)
		local state = MergeService.GetMergeState(player)
		return { ok = true, mergeable = state.mergeable, disenchantable = state.disenchantable }
	end
end

-- Hooki TYLKO do testow: czysta selekcja wyniku bez serwisow.
function MergeService._SelectMergeResultForTest(resultTier, isDiscovered, rng)
	return selectMergeResult(resultTier, isDiscovered, rng)
end

return MergeService
