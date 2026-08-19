--!strict
-- ServerScriptService/Services/PackService.luau (T4) — trzy płatne paczki (Mega/Super/Legend):
-- N kart naraz, własny niezależny tor od RollService.RollTotem (paczki NIE dotykają data.pity ani
-- data.lifetimeRolls -- decyzja Andreasa, T4 plan: pity to pole rolli-za-esencję, mieszanie by
-- niesprawiedliwie karmiło/resetowało je zakupami paczek).
--
-- selectPackTier = WŁASNY, dokładny cumulative-walk PER PACZKA (wzorzec RollService.selectVariant,
-- NIE RollService.selectTotem -- ta druga to globalna przybliżająca kaskada dzieląca N na wagi,
-- niezależna od konkretnej paczki; paczki potrzebują trzech NIEZALEŻNYCH, jawnie eskalujących tabel).
-- Totem w obrębie wylosowanego tieru: uniform przez TotemPool.byTier (nowość T4). Wariant: reużywa
-- RollService.RollVariant (publiczny wrapper na selectVariant, T4) -- nie duplikujemy tej matematyki.
--
-- OddsTable = BEZPOŚREDNIA referencja do PackConfig.Packs[key].tierTable, zero transformacji --
-- silniejsza gwarancja single-source-of-truth niż nawet PolicyService (tam jest domknięta matematyka
-- kaskady). "?" (GetPackOdds) czytany przez klienta PRZED każdym zakupem (PackController).
--
-- Robux: kredyt idempotentny reużywa PurchaseService (JEDYNY writer profile.purchases) --
-- PackService konsumuje przez PurchaseService.ConsumePackCredit, nigdy nie dotyka
-- profile.purchases.packCredits wprost. Esencja: atomowa, bezpośrednio przez EconomyService.TrySpendEssence
-- w tym samym wywołaniu serwera co roll (brak async receipt flow, więc brak potrzeby kredytu).
--
-- deps: ProfileService, EconomyService, IndexService, PurchaseService, RollService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))
local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local PackConfig = require(Shared:WaitForChild("PackConfig"))
local TotemPool = require(Shared:WaitForChild("TotemPool"))

local PackService = {}

local _profile, _economy, _index, _purchase, _roll = nil, nil, nil, nil, nil

-- PURE (testowalna): dokładny ważony rzut tieru DLA JEDNEJ PACZKI. Czyta cfg.tierTable -- TĘ SAMĄ
-- tabelę, którą PackService.OddsTable zwraca bez transformacji (patrz nagłówek pliku).
local function selectPackTier(packKey: string, rng: Random): string
	local cfg = PackConfig.Packs[packKey]
	assert(cfg, "PackService: unknown pack '" .. tostring(packKey) .. "'")
	local roll = rng:NextNumber() * 100
	local cumulative = 0
	local lastTier = cfg.tierTable[#cfg.tierTable].tier
	for _, entry in cfg.tierTable do
		cumulative += entry.pct
		if roll < cumulative then
			return entry.tier
		end
	end
	return lastTier -- zaokrąglenie float na samej górze przedziału
end

-- PURE-ish (testowalna, rollVariantFn wstrzykiwany jako parametr -- NIE upvalue -- żeby dało się
-- symulować N=10-20k razy bez żadnego stanu serwisu, wzorzec RollService._SelectTotemForTest).
-- Karta #cfg.cards, gdy cfg.guaranteeLegendaryLast: pomija selectPackTier, tier="Legendary" NA
-- SZTYWNO (deterministyczne, nie probabilistyczne) -- totem i wariant nadal losowane niezależnie,
-- więc gwarantowana karta może wylądować z dowolnym wariantem (włącznie z Rainbow).
local function rollPackCards(packKey: string, rng: Random, rollVariantFn: (number?, Random) -> string)
	local cfg = PackConfig.Packs[packKey]
	assert(cfg, "PackService: unknown pack '" .. tostring(packKey) .. "'")
	local cards = {}
	for i = 1, cfg.cards do
		local tier
		if cfg.guaranteeLegendaryLast and i == cfg.cards then
			tier = "Legendary"
		else
			tier = selectPackTier(packKey, rng)
		end
		local pool = TotemPool.byTier(tier)
		assert(#pool > 0, "PackService: TotemPool has no totems for tier '" .. tostring(tier) .. "'")
		local totemId = pool[rng:NextInteger(1, #pool)]
		local variant = rollVariantFn(nil, rng)
		cards[#cards + 1] = { totemId = totemId, tier = tier, variant = variant }
	end
	return cards
end

-- Handler Net.OpenPack: waliduje paczkę/metodę płatności, pobiera opłatę (esencja atomowo / Robux
-- kredyt), rzuca karty, zapisuje do profilu (data.totems, TAK SAMO jak RollService.RollTotem), zwraca
-- listę kart do sekwencyjnego reveal na kliencie.
function PackService.OpenPack(player: Player, packKey: string, method: string)
	local cfg = PackConfig.Packs[packKey]
	if not cfg then
		return { ok = false, reason = "UnknownPack" }
	end
	if not (_profile and _profile.IsLoaded(player)) then
		return { ok = false, reason = "NotLoaded" }
	end
	local data = _profile.GetProfile(player)

	if method == "essence" then
		if not _economy.TrySpendEssence(player, cfg.priceEssence) then
			return { ok = false, reason = "InsufficientEssence" }
		end
	elseif method == "robux" then
		if not _purchase.ConsumePackCredit(player, packKey) then
			return { ok = false, reason = "NoCredits" }
		end
	else
		return { ok = false, reason = "BadMethod" }
	end

	local rng = Random.new() -- MetaRNG (Zasada 11): NIGDY seedowany, ten roll żyje poza runem
	local rolled = rollPackCards(packKey, rng, _roll.RollVariant)

	local cards = {}
	for _, c in rolled do
		local isNewDiscovery = (_index ~= nil) and _index.Discover(player, c.totemId, c.variant) or false
		local key = c.totemId .. "#" .. c.variant
		data.totems[key] = (data.totems[key] or 0) + 1
		cards[#cards + 1] = {
			totemId = c.totemId,
			tier = c.tier,
			variant = c.variant,
			isNewDiscovery = isNewDiscovery,
		}
	end

	return {
		ok = true,
		packKey = packKey,
		cards = cards,
		essence = _economy.GetEssence(player),
	}
end

-- BEZPOŚREDNIA referencja do cfg.tierTable -- zero transformacji między tym co gracz widzi w "?" a
-- tym co selectPackTier faktycznie iteruje (patrz nagłówek pliku).
function PackService.OddsTable(packKey: string): { [string]: any }?
	local cfg = PackConfig.Packs[packKey]
	if not cfg then
		return nil
	end
	return {
		cards = cfg.cards,
		guaranteeLegendaryLast = cfg.guaranteeLegendaryLast,
		priceRobux = cfg.priceRobux,
		priceEssence = cfg.priceEssence,
		tiers = cfg.tierTable,
	}
end

local _oddsAllCache = nil
function PackService.OddsAll(): { [string]: any }
	if _oddsAllCache then
		return _oddsAllCache
	end
	local all = {}
	for key in PackConfig.Packs do
		all[key] = PackService.OddsTable(key)
	end
	_oddsAllCache = all
	return all
end

function PackService.Init() end

function PackService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_index = ServiceRegistry.get("IndexService")
	_purchase = ServiceRegistry.get("PurchaseService")
	_roll = ServiceRegistry.get("RollService")

	Net.get("OpenPack").OnServerInvoke = function(player, packKey, method)
		if type(packKey) ~= "string" or type(method) ~= "string" then
			return { ok = false, reason = "BadArg" }
		end
		return PackService.OpenPack(player, packKey, method)
	end

	Net.get("GetPackOdds").OnServerInvoke = function(_player)
		return PackService.OddsAll()
	end
end

-- Hooki TYLKO do testow: czysta selekcja/rzut kart bez serwisow (patrz tests/PackService.checkpoint.studio.luau).
function PackService._SelectPackTierForTest(packKey: string, rng: Random)
	return selectPackTier(packKey, rng)
end
function PackService._RollPackCardsForTest(packKey: string, rng: Random, rollVariantFn: (number?, Random) -> string)
	return rollPackCards(packKey, rng, rollVariantFn)
end
function PackService._InjectForTest(deps: { profile: any, economy: any, index: any, purchase: any, roll: any })
	_profile, _economy, _index, _purchase, _roll = deps.profile, deps.economy, deps.index, deps.purchase, deps.roll
end

return PackService
