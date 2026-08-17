--!strict
-- RunShopService — sklep W RUNIE (Architektura §2: "generacja 3 ofert z run-seeda (stream `shop`),
-- BuyShopItem(slotId), re-roll za złoto"). 3 STAŁE sloty (GDD §1.5): Totem / Ulepszenie Zaklęcia /
-- Zwój — Zwój jest ZAWSZE manipulacją talią (ShopConfig.ScrollKinds), więc gwarancja "min. 1 Zwój
-- manipulacji talią na wizytę" jest spełniona strukturalnie, nie osobną regułą.
--
-- Ceny/tuning w ShopConfig (świadomie NOWY plik tej sesji — GDD/Architektura nie podają liczb).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared

local TotemConfig = require(Shared.Configs.TotemConfig)
local SpellConfig = require(Shared.Configs.SpellConfig)
local ShopConfig = require(Shared.Configs.ShopConfig)
local GameConfig = require(Shared.Configs.GameConfig)
local RankedConfig = require(Shared.Configs.RankedConfig)
local SeedUtil = require(Shared.SeedUtil)

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Net = require(Framework:WaitForChild("Net"))

local RunSessionService = require(script.Parent.RunSessionService)
type RunState = RunSessionService.RunState
local IndexService = require(script.Parent.IndexService) -- IsDiscovered = "posiadane" (profile.totems), Start() ordered przed nami w Bootstrap

local RunShopService = {}

local function logLine(run: RunState, msg: string)
	table.insert(run.log, msg)
end

-- Stały starter (task #1, otwarte zadania STATUS.md): wszystkie tiery Common z TotemConfig — świeży
-- gracz bez ani jednego rolla wciąż ma co kupić w pierwszym runie. Filtr jest dynamiczny (nie
-- twarda lista id), więc zawsze łapie aktualny zestaw Common z TotemConfig bez ręcznej synchronizacji
-- (dziś 7: capybop/lotti/emberpup/voltmouse/shadowkit/quackers/blobby — zweryfikowane D1 harnessem
-- 2026-08-17, patrz STATUS.md).
local STARTER_TIER = "Common"

-- Pula totemów dostępnych w sklepie = (posiadane przez gracza, profile.totems ∩ TotemConfig, przez
-- IndexService.IsDiscovered) UNION (stały starter Common) MINUS totemy już w TYM runie (run.totems,
-- filtr niezmieniony). W STABILNEJ (alfabetycznej po id) kolejności — TotemConfig.Totems jest
-- dict-em; pairs() nie gwarantuje kolejności między procesami, więc sortujemy jawnie, żeby ten sam
-- seed zawsze dawał tę samą ofertę niezależnie od hash-seed danego uruchomienia Luau.
-- Faza 3 krok #4 (zasada 12): ranked NIGDY nie czyta kolekcji gracza (IndexService.IsDiscovered
-- w ogóle nie jest wywoływane w tej gałęzi) -- pula to wyłącznie RankedConfig.TotemIds, stały
-- porządek, bez sortowania (już deterministyczny z definicji listy). To jest fundament bramki
-- determinizmu: rich-collection i empty-collection gracz na tym samym Seed Dnia MUSZĄ dostać
-- identyczną ofertę sklepu.
local function rankedTotemPool(run: RunState): { any }
	local excluded = {}
	for _, t in run.totems do
		excluded[t.id] = true
	end
	local pool = {}
	for _, id in RankedConfig.TotemIds do
		if not excluded[id] then
			table.insert(pool, TotemConfig.Totems[id])
		end
	end
	return pool
end

local function availableTotemPool(run: RunState): { any }
	if run.mode == "ranked" then
		return rankedTotemPool(run)
	end

	local excluded = {}
	for _, t in run.totems do
		excluded[t.id] = true
	end

	local pool = {}
	for id, totem in TotemConfig.Totems do
		if not excluded[id] then
			local isStarter = totem.tier == STARTER_TIER
			local isOwned = run.owner ~= nil and IndexService.IsDiscovered(run.owner, id)
			if isStarter or isOwned then
				table.insert(pool, totem)
			end
		end
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	return pool
end

-- Bramka D1 (2026-08-17, tests/BalanceHarness.studio.luau, n=50, pool=starter przez owner=nil):
-- FULL-SMART completion 30% (>=20%, PASS). NAIVE (zero-decyzji floor) 2% — oczekiwane, ten bot
-- nigdy nie swapuje/nie kupuje mądrze, to zawsze był floor a nie realistyczny fresh-player proxy.
-- Szczegoly w STATUS.md.

-- Faza 4 Krok 0: Start-of-run Totem Pick (GDD §2.7 "1 z 3"). Wolane leniwie z
-- RunSessionService.startRunForPlayer (ServiceRegistry.has, unika cyklu require -- ten modul juz
-- wymaga RunSessionService). Rownowaznik open()/rollTotemOffer ale: (1) wlasny strumien "startPick"
-- (nie "shop" -- nie chcemy przesuwac sekwencji pozniejszych reroll'i sklepu), (2) draw BEZ
-- powtorzen przez SeedUtil.shuffle+take (nie nextInt per slot jak rollTotemOffer, bo tam
-- powtorzenia sa OK -- tu maja byc unikalne opcje), (3) darmowe, nie kosztuje zlota.
function RunShopService.startPick(run: RunState, pickSize: number)
	local pool = availableTotemPool(run)
	if #pool == 0 then
		run.startPickOptions = {}
		return
	end
	local shuffled = SeedUtil.shuffle(pool, run.streams.startPick)
	local options = {}
	for i = 1, math.min(pickSize, #shuffled) do
		table.insert(options, shuffled[i])
	end
	run.startPickOptions = options
	local ids = {}
	for _, t in options do
		table.insert(ids, t.id)
	end
	logLine(run, `start pick offered ({#options}): {table.concat(ids, ", ")}`)
end

-- Wstawia wybrany totem do run.totems ZA DARMO (nie sklep -- to jest bezplatny wybor startowy, nie
-- zakup). Blokuje ponowny pick w tym runie przez run.startPickDone (flaga na runie, jak
-- run.shopOffers dla sklepu).
function RunShopService.choosePick(run: RunState, totemId: string): { ok: boolean, reason: string? }
	if run.startPickDone then
		return { ok = false, reason = "already picked" }
	end
	local options = run.startPickOptions
	if options == nil or #options == 0 then
		return { ok = false, reason = "no pick available" }
	end
	local chosen = nil
	for _, t in options do
		if t.id == totemId then
			chosen = t
			break
		end
	end
	if chosen == nil then
		return { ok = false, reason = "totemId not in offered options" }
	end
	if #run.totems >= GameConfig.TotemSlots then
		return { ok = false, reason = "totem slots full" }
	end

	table.insert(run.totems, chosen)
	run.startPickDone = true
	run.startPickOptions = nil
	logLine(run, `start pick chosen: {totemId}`)
	return { ok = true }
end

local function rollTotemOffer(run: RunState): { [string]: any }?
	local pool = availableTotemPool(run)
	if #pool == 0 then
		return nil
	end
	local totem = pool[run.streams.shop.nextInt(1, #pool)]
	return { kind = "totem", totemId = totem.id, tier = totem.tier, price = ShopConfig.TotemPriceByTier[totem.tier] }
end

local function rollUpgradeOffer(run: RunState): { [string]: any }
	local spell = SpellConfig.Spells[run.streams.shop.nextInt(1, #SpellConfig.Spells)]
	return {
		kind = "upgrade",
		spellId = spell.id,
		rezMultFactor = ShopConfig.SpellUpgradeRezMultPerPurchase,
		price = ShopConfig.SpellUpgradePrice,
	}
end

local function rollScrollOffer(run: RunState): { [string]: any }
	local scrollKind = ShopConfig.ScrollKinds[run.streams.shop.nextInt(1, #ShopConfig.ScrollKinds)]
	return { kind = "scroll", scrollKind = scrollKind, price = ShopConfig.ScrollPrice }
end

-- Generuje/regeneruje wszystkie 3 sloty ofert (jedna wizyta w sklepie = jedno wywołanie open()).
function RunShopService.open(run: RunState)
	run.shopOffers = {
		totem = rollTotemOffer(run),
		upgrade = rollUpgradeOffer(run),
		scroll = rollScrollOffer(run),
	}
	run.shopRerollCost = ShopConfig.RerollBaseCost
	logLine(run, `shop open: totem={run.shopOffers.totem and run.shopOffers.totem.totemId or "none"} upgrade={run.shopOffers.upgrade.spellId} scroll={run.shopOffers.scroll.scrollKind}`)
end

function RunShopService.reroll(run: RunState): { ok: boolean, reason: string? }
	if run.gold < run.shopRerollCost then
		return { ok = false, reason = "not enough gold" }
	end
	run.gold -= run.shopRerollCost
	run.shopOffers = {
		totem = rollTotemOffer(run),
		upgrade = rollUpgradeOffer(run),
		scroll = rollScrollOffer(run),
	}
	logLine(run, `shop reroll (cost {run.shopRerollCost}): totem={run.shopOffers.totem and run.shopOffers.totem.totemId or "none"} upgrade={run.shopOffers.upgrade.spellId} scroll={run.shopOffers.scroll.scrollKind}`)
	run.shopRerollCost += ShopConfig.RerollCostStep
	return { ok = true }
end

function RunShopService.buy(run: RunState, slotKey: string): { ok: boolean, reason: string? }
	if not run.shopOffers then
		return { ok = false, reason = "shop not open" }
	end
	local offer = run.shopOffers[slotKey]
	if not offer then
		return { ok = false, reason = "no offer in that slot" }
	end
	if run.gold < offer.price then
		return { ok = false, reason = "not enough gold" }
	end

	if slotKey == "totem" then
		if #run.totems >= GameConfig.TotemSlots then
			return { ok = false, reason = "totem slots full" }
		end
		run.gold -= offer.price
		table.insert(run.totems, TotemConfig.Totems[offer.totemId])
		logLine(run, `buy totem {offer.totemId} for {offer.price}g`)
	elseif slotKey == "upgrade" then
		run.gold -= offer.price
		local existing = run.spellUpgrades[offer.spellId] or { rezMult = 1 }
		local newRezMult = (existing.rezMult or 1) * offer.rezMultFactor
		run.spellUpgrades[offer.spellId] = { rezMult = newRezMult }
		logLine(run, `buy upgrade {offer.spellId} (rezMult -> {newRezMult}) for {offer.price}g`)
	elseif slotKey == "scroll" then
		if #run.scrolls >= GameConfig.ScrollSlots then
			return { ok = false, reason = "scroll slots full" }
		end
		run.gold -= offer.price
		table.insert(run.scrolls, { kind = offer.scrollKind })
		logLine(run, `buy scroll {offer.scrollKind} for {offer.price}g`)
	else
		return { ok = false, reason = "unknown slot" }
	end

	run.shopOffers[slotKey] = nil
	return { ok = true }
end

function RunShopService.Init() end

function RunShopService.Start()
	local buyShopItem = Net.get("BuyShopItem")
	local rerollShop = Net.get("RerollShop")
	local pickStartTotem = Net.get("PickStartTotem")
	local runStateSync = Net.get("RunStateSync")

	-- Minimalny debounce, jak w RunSessionService/PlayService.Start() -- patrz komentarz tam.
	local lastCall: { [Player]: number } = {}
	local function debounced(player: Player): boolean
		local now = os.clock()
		if now - (lastCall[player] or 0) < 0.1 then
			return true
		end
		lastCall[player] = now
		return false
	end

	local function pushState(player: Player, run: RunState)
		runStateSync:FireClient(player, RunSessionService.snapshot(run))
	end

	buyShopItem.OnServerInvoke = function(player: Player, slotKey: string)
		local run = RunSessionService.getRun(player)
		if run == nil then
			return { ok = false, reason = "no active run" }
		end
		if debounced(player) then
			return { ok = false, reason = "rate limited" }
		end
		local result = RunShopService.buy(run, slotKey)
		if result.ok then
			pushState(player, run)
		end
		return result
	end

	rerollShop.OnServerInvoke = function(player: Player)
		local run = RunSessionService.getRun(player)
		if run == nil then
			return { ok = false, reason = "no active run" }
		end
		if debounced(player) then
			return { ok = false, reason = "rate limited" }
		end
		local result = RunShopService.reroll(run)
		if result.ok then
			pushState(player, run)
		end
		return result
	end

	pickStartTotem.OnServerInvoke = function(player: Player, totemId: string)
		local run = RunSessionService.getRun(player)
		if run == nil then
			return { ok = false, reason = "no active run" }
		end
		if debounced(player) then
			return { ok = false, reason = "rate limited" }
		end
		local result = RunShopService.choosePick(run, totemId)
		if result.ok then
			pushState(player, run)
		end
		return result
	end
end

return RunShopService
