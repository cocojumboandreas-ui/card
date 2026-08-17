--!nonstrict
-- ServerScriptService/Services/RollService.luau (Faza 2b, port z WAR RNG)
-- META-roll Stworka za Esencję: rzut tieru (dzielenie mianownikow floor(weight/luck), pool
-- najrzadszy-pierwszy — wzorzec z WAR RNG), pity, NIEZALEŻNY rzut wariantu, zapis do profilu,
-- RollResult do klienta. Zasada 11 (Architektura): MetaRNG = Random.new() za KAŻDYM razem — NIGDY
-- SeedUtil/RunRNG, ten roll żyje POZA runem.
-- deps: ProfileService, StatProfileService, EconomyService, IndexService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Signal = require(Framework:WaitForChild("Signal"))
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local GameConfig = require(Shared:WaitForChild("GameConfig"))
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))
local VariantConfig = require(Shared:WaitForChild("VariantConfig"))

local RollService = {}

local _profile, _stat, _economy, _index = nil, nil, nil, nil

-- Totemy posortowane MALEJĄCO po tier-weight (najrzadsze pierwsze) — raz, cache.
local _totemsSorted = nil
local function totemsSorted()
	if _totemsSorted then
		return _totemsSorted
	end
	local arr = {}
	for id, totem in TotemConfig.Totems do
		local weight = RarityConfig.TierWeight[totem.tier]
		assert(weight ~= nil, "RollService: TotemConfig tier '" .. tostring(totem.tier) .. "' has no RarityConfig.TierWeight entry")
		arr[#arr + 1] = { id = id, tier = totem.tier, weight = weight }
	end
	table.sort(arr, function(a, b)
		return a.weight > b.weight
	end)
	_totemsSorted = arr
	return arr
end

-- PURE (testowalna): wybor tieru. stats={luck}; pity={sinceEpic}; rng=Random. Zwraca {id,tier,weight,pityTriggered}.
local function selectTotem(stats, pity, rng)
	local pool = totemsSorted()
	local pityTriggered = false
	if pity and pity.sinceEpic and pity.sinceEpic >= RarityConfig.Pity.threshold then
		local minWeight = RarityConfig.TierWeight[RarityConfig.Pity.guaranteeTier]
		local filt = {}
		for _, t in pool do
			if t.weight >= minWeight then
				filt[#filt + 1] = t
			end
		end
		if #filt > 0 then
			pool = filt
			pityTriggered = true
		end
	end
	local luck = (stats and stats.luck) or 1
	local chosen = nil
	for _, t in pool do
		local nEff = math.max(1, math.floor(t.weight / luck))
		if rng:NextInteger(1, nEff) == 1 then
			chosen = t
			break
		end
	end
	if not chosen then
		chosen = pool[#pool] -- fallback = najmniej rzadki (ostatni w posortowanej puli malejąco)
	end
	return { id = chosen.id, tier = chosen.tier, weight = chosen.weight, pityTriggered = pityTriggered }
end

-- PURE (testowalna): niezależny rzut wariantu, WAŻONY DOKŁADNIE (nie cascade-N — patrz komentarz w
-- VariantConfig.luau: to tabela compliance, musi trafiać dokładnie w podane %). variantLuck skaluje
-- KAŻDY nie-fallback bucket w górę; fallback po prostu wchłania resztę.
local function selectVariant(variantLuck, rng)
	variantLuck = variantLuck or 1
	local roll = rng:NextNumber() * 100
	local cumulative = 0
	for _, v in VariantConfig.ladder do
		if v.id ~= VariantConfig.fallback then
			cumulative += math.min(v.pct * variantLuck, 100)
			if roll < cumulative then
				return v.id
			end
		end
	end
	return VariantConfig.fallback
end

-- Handler Net.RollTotem: waliduje profil, wydaje Esencję, losuje, zapisuje, zwraca RollResult.
function RollService.RollTotem(player: Player)
	if not (_profile and _profile.IsLoaded(player)) then
		return { ok = false, reason = "NotLoaded" }
	end
	local data = _profile.GetProfile(player)
	if not _economy.TrySpendEssence(player, GameConfig.RollCostEssence) then
		return { ok = false, reason = "InsufficientEssence" }
	end

	local stats = _stat.Get(player)
	local rng = Random.new() -- MetaRNG (Zasada 11): NIGDY seedowany
	local sel = selectTotem(stats, data.pity, rng)
	local variant = selectVariant(nil, rng) -- v1: brak osobnego statu variantLuck, zawsze 1

	local isNewDiscovery = (_index ~= nil) and _index.Discover(player, sel.id, variant) or false

	local key = sel.id .. "#" .. variant
	data.totems[key] = (data.totems[key] or 0) + 1
	data.lifetimeRolls += 1
	local guaranteeWeight = RarityConfig.TierWeight[RarityConfig.Pity.guaranteeTier]
	if sel.weight >= guaranteeWeight then
		data.pity.sinceEpic = 0
	else
		data.pity.sinceEpic += 1
	end

	local result = {
		ok = true,
		totemId = sel.id,
		tier = sel.tier,
		variant = variant,
		isNewDiscovery = isNewDiscovery,
		pityTriggered = sel.pityTriggered,
		essence = _economy.GetEssence(player),
	}
	RollService.Rolled:Fire(player, result) -- Faza 3 hook: AnnouncementService subskrybuje TU (rzadkie dropy)
	return result
end

function RollService.Init()
	-- Faza 3 krok 0: to JEST sygnał "TotemRolled" z Architektury §2 linia 78 (payload {totemId, tier,
	-- variant, isNewDiscovery, ...} pokrywa i przewyższa `(player, totemId, rarityN, variant)`) —
	-- świadomie NIE tworzymy drugiego sygnału, żeby nie duplikować. QuestService/IndexService/
	-- AnnouncementService subskrybują TEN.
	RollService.Rolled = Signal.new() -- (player, RollResult)
end

function RollService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_stat = ServiceRegistry.get("StatProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_index = ServiceRegistry.get("IndexService")

	Net.get("RollTotem").OnServerInvoke = function(player)
		return RollService.RollTotem(player)
	end

	-- Faza 3 hook (NIE implementować tu): AnnouncementService.Start() dopisze
	-- RollService.Rolled:Connect(...) i ogłosi rzadkie dropy (np. tier>=Epic lub variant~=Normal).
end

-- Hooki TYLKO do testow: czysta selekcja tieru/wariantu bez serwisow.
function RollService._SelectTotemForTest(stats, pity, rng)
	return selectTotem(stats, pity, rng)
end
function RollService._SelectVariantForTest(variantLuck, rng)
	return selectVariant(variantLuck, rng)
end

return RollService
