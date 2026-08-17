--!strict
-- Controllers/MonetizationController.luau (Faza 4 Krok 4) — sklep Robux (gamepassy + dev producty,
-- MarketplaceConfig.luau) + compliance gate. Zasada (Paid Random Items): dla kazdego produktu ktory
-- dotyczy losowania (stat/tempBuff/serverBuff == "luck") pokazujemy panel z tabela szans (PolicyService
-- przez remote GetOddsTable) PRZED wywolaniem Prompt*Purchase, z przyciskiem "Kontynuuj do zakupu".
-- Esencja-pakiety i inne nie-luck produkty ida prosto do Prompt*Purchase (proste 1:1, nie loot-box).
-- "brzydko-ale-działająco" (Faza 4 brief): lista tekstowa, zero ladnych kart -- ladna wersja Faza 5.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local MarketplaceConfig = require(ReplicatedStorage.Shared.Configs.MarketplaceConfig)

local MonetizationController = {}

local _catalogModal: Frame
local _catalogList: ScrollingFrame
local _oddsModal: Frame
local _oddsList: Frame
local _pendingConfirm: (() -> ())? = nil

-- Domyslne Prompt* -- nadpisywalne przez _InjectForTest, zeby testowac gating bez prawdziwego
-- Marketplace UI (placeholder id=0 i tak nie otworzy prawdziwego prompta w studio-playteście).
local _promptGamePass = function(id: number)
	pcall(function()
		MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, id)
	end)
end
local _promptProduct = function(id: number)
	pcall(function()
		MarketplaceService:PromptProductPurchase(Players.LocalPlayer, id)
	end)
end

-- PURE (testowalna): czy ten config dotyczy losowania -> wymaga gate'u tabeli szans. Czytane
-- WYLACZNIE z pol configu (stat/tempBuff/serverBuff), zero osobnej hardkodowanej listy kluczy --
-- jesli kiedys ktos doda nowy produkt z luck-em, automatycznie dostanie gate bez zmiany tego pliku.
local function isLuckAffecting(cfg: { [string]: any }): boolean
	if cfg.stat == "luck" then
		return true
	end
	if cfg.tempBuff and cfg.tempBuff.stat == "luck" then
		return true
	end
	if cfg.serverBuff and cfg.serverBuff.stat == "luck" then
		return true
	end
	return false
end

local _oddsCache = nil :: { [string]: any }?
local function fetchOdds(): { [string]: any }?
	if _oddsCache then
		return _oddsCache
	end
	local ok, result = NetController.Invoke("GetOddsTable")
	if ok then
		_oddsCache = result
	end
	return _oddsCache
end

local function closeOddsModal()
	_oddsModal.Visible = false
	_pendingConfirm = nil
end

local function renderOddsModal(odds: { [string]: any })
	for _, child in _oddsList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	UIFactory.label(_oddsList, "TIER (" .. odds.tiersNote .. ")", {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
	for _, t in odds.tiers do
		UIFactory.label(_oddsList, `{t.tier}: {string.format("%.2f", t.pct)}%`, {
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
		})
	end
	UIFactory.label(_oddsList, "WARIANT", {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
	for _, v in odds.variants do
		UIFactory.label(_oddsList, `{v.id}: {v.pct}%`, {
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 10,
		})
	end
	UIFactory.label(_oddsList, `Pity: gwarancja {odds.pity.guaranteeTier} po {odds.pity.threshold} rollach bez`, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 10,
	})
end

-- Otwiera gate tabeli szans; onConfirm wola sie TYLKO po kliknieciu "Kontynuuj do zakupu".
local function openOddsGate(onConfirm: () -> ())
	local odds = fetchOdds()
	if odds == nil then
		-- Serwer niedostepny -- nie blokuj gracza w nieskonczonosc, ale tez nie omijaj gate'u cicho.
		return
	end
	renderOddsModal(odds)
	_pendingConfirm = onConfirm
	_oddsModal.Visible = true
end

-- Publiczna sciezka zakupu -- wolana z przyciskow katalogu ORAZ z testow.
local function attemptPurchase(kind: "gamepass" | "devproduct", key: string)
	local cfg = if kind == "gamepass" then MarketplaceConfig.GamePasses[key] else MarketplaceConfig.DevProducts[key]
	if not cfg then
		return
	end
	local function doPrompt()
		if kind == "gamepass" then
			_promptGamePass(cfg.id)
		else
			_promptProduct(cfg.id)
		end
	end
	if isLuckAffecting(cfg) then
		openOddsGate(doPrompt)
	else
		doPrompt()
	end
end

local function buildCatalogRow(label: string, kind: "gamepass" | "devproduct", key: string, priceRobux: number)
	local row = UIFactory.panel(_catalogList, {
		Size = UDim2.new(1, -12, 0, 44),
		BackgroundColor3 = Color3.fromRGB(40, 40, 48),
	})
	UIFactory.label(row, label, {
		Size = UDim2.new(0.6, 0, 1, 0),
		Position = UDim2.new(0, 8, 0, 0),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UIFactory.button(row, `R$ {priceRobux}`, {
		Size = UDim2.new(0.35, -12, 0, 34),
		Position = UDim2.new(0.65, 0, 0, 5),
		BackgroundColor3 = Color3.fromRGB(90, 200, 120),
	}, function()
		attemptPurchase(kind, key)
	end)
end

local function buildCatalog()
	for _, child in _catalogList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for key, cfg in pairs(MarketplaceConfig.GamePasses) do
		buildCatalogRow(key, "gamepass", key, cfg.priceRobux)
	end
	for key, cfg in pairs(MarketplaceConfig.DevProducts) do
		buildCatalogRow(key, "devproduct", key, cfg.priceRobux)
	end
	_catalogList.CanvasSize = UDim2.new(0, 0, 0, #_catalogList:GetChildren() * 48)
end

function MonetizationController.Init() end

function MonetizationController.Start()
	local gui = UIRootController.Get("Monetization")

	UIFactory.button(gui, "STORE", {
		Size = UDim2.new(0, 70, 0, 50),
		Position = UDim2.new(1, -316, 0, 12),
		BackgroundColor3 = Color3.fromRGB(90, 200, 200),
	}, function()
		_catalogModal.Visible = true
	end)

	_catalogModal = UIFactory.panel(gui, {
		Size = UDim2.new(1, -60, 0, 360),
		Position = UDim2.new(0, 30, 0.5, -180),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})
	UIFactory.label(_catalogModal, "STORE", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 6),
		TextColor3 = Color3.fromRGB(90, 200, 200),
	})
	UIFactory.button(_catalogModal, "X", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -42, 0, 4),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	}, function()
		_catalogModal.Visible = false
	end)

	_catalogList = Instance.new("ScrollingFrame")
	_catalogList.Size = UDim2.new(1, -16, 1, -50)
	_catalogList.Position = UDim2.new(0, 8, 0, 42)
	_catalogList.BackgroundTransparency = 1
	_catalogList.BorderSizePixel = 0
	_catalogList.ScrollBarThickness = 8
	_catalogList.CanvasSize = UDim2.new(0, 0, 0, 0)
	_catalogList.Parent = _catalogModal
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 4)
	listLayout.Parent = _catalogList
	buildCatalog()

	-- Gate tabeli szans -- OSOBNY modal NAD katalogiem (kolejne dziecko tego samego root-a, wyzszy ZIndex).
	_oddsModal = UIFactory.panel(gui, {
		Size = UDim2.new(1, -60, 0, 440),
		Position = UDim2.new(0, 30, 0.5, -220),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		Visible = false,
		ZIndex = 10,
	})
	UIFactory.label(_oddsModal, "SZANSE (przed zakupem)", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 6),
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 210, 100),
		ZIndex = 10,
	})
	_oddsList = UIFactory.column(_oddsModal, {
		Size = UDim2.new(1, -16, 0, 350),
		Position = UDim2.new(0, 8, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 10,
	})
	UIFactory.button(_oddsModal, "Anuluj", {
		Size = UDim2.new(0, 140, 0, 40),
		Position = UDim2.new(0, 20, 1, -48),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
		ZIndex = 10,
	}, function()
		closeOddsModal()
	end)
	UIFactory.button(_oddsModal, "Kontynuuj do zakupu", {
		Size = UDim2.new(0, 220, 0, 40),
		Position = UDim2.new(1, -240, 1, -48),
		BackgroundColor3 = Color3.fromRGB(90, 200, 120),
		ZIndex = 10,
	}, function()
		local confirm = _pendingConfirm
		closeOddsModal()
		if confirm then
			confirm()
		end
	end)
end

-- Hooki TYLKO do testow.
function MonetizationController._InjectForTest(deps: { [string]: any })
	if deps.promptGamePass then
		_promptGamePass = deps.promptGamePass
	end
	if deps.promptProduct then
		_promptProduct = deps.promptProduct
	end
end
function MonetizationController._IsLuckAffectingForTest(cfg)
	return isLuckAffecting(cfg)
end
-- Symuluje pelna sciezke zakupu bez klikania UI: confirmGate=true/false/nil (nil = brak gate'u
-- oczekiwanego -- jesli gate mimo to by sie otworzyl, onConfirm NIE zostanie wywolane, co widac
-- w wyniku _promptCalled==false).
function MonetizationController._AttemptPurchaseForTest(kind, key, confirmGate: boolean?)
	attemptPurchase(kind, key)
	if _oddsModal.Visible and confirmGate ~= nil then
		if confirmGate then
			local confirm = _pendingConfirm
			closeOddsModal()
			if confirm then
				confirm()
			end
		else
			closeOddsModal()
		end
	end
end
function MonetizationController._GateVisibleForTest(): boolean
	return _oddsModal.Visible
end

return MonetizationController
