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

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Net = require(Framework:WaitForChild("Net"))

local RunSessionService = require(script.Parent.RunSessionService)
type RunState = RunSessionService.RunState

local RunShopService = {}

local function logLine(run: RunState, msg: string)
	table.insert(run.log, msg)
end

-- Pula totemów NIE jeszcze posiadanych, w STABILNEJ (alfabetycznej po id) kolejności — TotemConfig
-- .Totems jest dict-em; pairs() nie gwarantuje kolejności między procesami, więc sortujemy jawnie,
-- żeby ten sam seed zawsze dawał tę samą ofertę niezależnie od hash-seed danego uruchomienia Luau.
local function availableTotemPool(run: RunState): { any }
	local owned = {}
	for _, t in run.totems do
		owned[t.id] = true
	end
	local pool = {}
	for id, totem in TotemConfig.Totems do
		if not owned[id] then
			table.insert(pool, totem)
		end
	end
	table.sort(pool, function(a, b)
		return a.id < b.id
	end)
	return pool
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
end

return RunShopService
