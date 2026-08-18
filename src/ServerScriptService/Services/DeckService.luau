--!strict
-- DeckService (MAX-SLOT) — profile.activeDeck: gracz wybiera do GameConfig.DeckSize totemów ze
-- swojej kolekcji jako pulę zasilającą RunShopService.availableTotemPool (WYŁĄCZNIE free mode —
-- ranked czyta RankedConfig.TotemIds, DeckService nigdy nie jest wołany w tej gałęzi, zero
-- przecieku kolekcji do rankingu, ten sam fundament determinizmu co Faza 3 krok #4).
--
-- "Pusty deck = jeszcze nie wybrany" jest TRWAŁYM niezmiennikiem, nie jednorazową flagą migracji:
-- EnsureDefaultDeck wypełnia pusty profile.activeDeck domyślnym (starter Common ∪ posiadane,
-- ucięte do DeckSize) za każdym razem gdy go zastaje pustym. To jednocześnie migracja istniejących
-- graczy (ProfileStore Reconcile() dopisuje pusty {} do starych profili — nic więcej nie trzeba) i
-- safety-net, gdyby kiedyś powstał inny sposób na wyzerowanie decku niż SetDeck.
--
-- STARTER_TIER = "Common" zdublowane z RunShopService.luau (świadomie, 2 miejsca, jedna stała) —
-- trzymaj obie w sync jeśli kiedyś zmieni się definicja "starter".

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local TotemConfig = require(Shared.Configs.TotemConfig)
local GameConfig = require(Shared.Configs.GameConfig)

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local DeckService = {}

local STARTER_TIER = "Common"

local _profileService = nil
local _indexService = nil

local function isSelectable(player: Player, totemId: string): boolean
	local totem = TotemConfig.Totems[totemId]
	if not totem then
		return false
	end
	if totem.tier == STARTER_TIER then
		return true
	end
	return _indexService ~= nil and _indexService.IsDiscovered(player, totemId) == true
end

-- Starter Common ∪ posiadane, stabilna (alfabetyczna) kolejność, ucięte do DeckSize — ten sam
-- porządek co RunShopService.availableTotemPool, żeby domyślny deck był deterministyczny.
local function defaultDeck(player: Player): { string }
	local ids = {}
	for id in TotemConfig.Totems do
		if isSelectable(player, id) then
			table.insert(ids, id)
		end
	end
	table.sort(ids)
	local capped = {}
	for i = 1, math.min(GameConfig.DeckSize, #ids) do
		capped[i] = ids[i]
	end
	return capped
end

-- Wypełnia profile.activeDeck domyślnym gdy jest pusty. Idempotentne, mutuje profil w miejscu,
-- zwraca aktualny deck (pusty {} jeśli profil nie istnieje).
function DeckService.EnsureDefaultDeck(player: Player): { string }
	local data = _profileService and _profileService.GetProfile(player)
	if not data then
		return {}
	end
	data.activeDeck = data.activeDeck or {}
	if #data.activeDeck == 0 then
		data.activeDeck = defaultDeck(player)
	end
	return data.activeDeck
end

-- Odczyt dla RunShopService: deck PRZEFILTROWANY przez starter-lub-owned (pas bezpieczeństwa —
-- deck mógł się zdezaktualizować, np. totem przestał być starter w przyszłej rewizji configu).
function DeckService.GetDeck(player: Player): { string }
	local raw = DeckService.EnsureDefaultDeck(player)
	local filtered = {}
	for _, id in raw do
		if isSelectable(player, id) then
			table.insert(filtered, id)
		end
	end
	return filtered
end

-- Zapis serwer-autorytatywny: KAŻDY id musi istnieć w TotemConfig i być starter-lub-owned, #ids w
-- [1, DeckSize], zero duplikatów. Odrzucone W CAŁOŚCI (nie best-effort obcięcie) przy pierwszym
-- naruszeniu — gracz zawsze widzi jawny błąd zamiast cichej różnicy między klikiem a zapisem.
function DeckService.SetDeck(player: Player, ids: { any }): { ok: boolean, reason: string? }
	local data = _profileService and _profileService.GetProfile(player)
	if not data then
		return { ok = false, reason = "NoProfile" }
	end
	if type(ids) ~= "table" then
		return { ok = false, reason = "BadArg" }
	end
	if #ids < 1 or #ids > GameConfig.DeckSize then
		return { ok = false, reason = "BadSize" }
	end
	local seen = {}
	local clean = {}
	for _, id in ids do
		if type(id) ~= "string" then
			return { ok = false, reason = "BadArg" }
		end
		if seen[id] then
			return { ok = false, reason = "Duplicate" }
		end
		seen[id] = true
		if not isSelectable(player, id) then
			return { ok = false, reason = "NotSelectable" }
		end
		table.insert(clean, id)
	end
	data.activeDeck = clean -- JEDYNY zapis profile.activeDeck poza EnsureDefaultDeck
	return { ok = true }
end

function DeckService.Init() end

function DeckService.Start()
	_profileService = ServiceRegistry.get("ProfileService")
	_indexService = ServiceRegistry.get("IndexService")

	Net.get("GetDeck").OnServerInvoke = function(player: Player)
		local deck = DeckService.EnsureDefaultDeck(player)
		local inDeck = {}
		for _, id in deck do
			inDeck[id] = true
		end
		local entries = {}
		for id, totem in TotemConfig.Totems do
			table.insert(entries, {
				id = id,
				name = totem.name,
				tier = totem.tier,
				selectable = isSelectable(player, id),
				inDeck = inDeck[id] == true,
			})
		end
		table.sort(entries, function(a, b)
			return a.id < b.id
		end)
		return { ok = true, deck = deck, deckSize = GameConfig.DeckSize, entries = entries }
	end

	Net.get("SetDeck").OnServerInvoke = function(player: Player, ids: any)
		return DeckService.SetDeck(player, ids)
	end
end

-- Hooki TYLKO do testów (wzorzec IndexService._SetProfileServiceForTest).
function DeckService._SetProfileServiceForTest(fake)
	_profileService = fake
end

function DeckService._SetIndexServiceForTest(fake)
	_indexService = fake
end

return DeckService
