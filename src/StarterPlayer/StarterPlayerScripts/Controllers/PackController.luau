--!strict
-- Controllers/PackController.luau (T4) — katalog paczek Mega/Super/Legend: jeden rządek na paczkę
-- ("?" tabela szans / Ess {cena} / R$ {cena}), sekwencyjny reveal reużywający RollRevealController.
-- PlayReveal (System 3/Merge robią to samo -- jeden beat reveal, nie druga implementacja UI).
--
-- Compliance: "?" (GetPackOdds) czytany PRZED każdym zakupem -- katalog buduje się DOPIERO po
-- pierwszym udanym fetchPackOdds (buildCatalog woła się raz w Start, po nim ceny/przyciski są zawsze
-- widoczne obok "?" tej samej paczki, więc gracz fizycznie nie może trafić w Ess/R$ bez wcześniejszego
-- dostępu do tabeli szans w tym samym katalogu). Legend: gwarancja ujawniana LITERALNIE -- karty
-- 1..cards-1 wg tierTable + osobna linia "Karta {cards}: GWARANTOWANY Legendary (100%)", ZERO
-- zblendowanej matematyki (decyzja Andreasa, T4 plan) -- patrz renderPackOdds.
--
-- Sekwencyjny reveal: RollRevealController.RollCompleted:Fire(result) (RollRevealController.luau:130)
-- odpala się PRZED tym jak wrapper PlayReveal (tamże:135-144) zdąży ustawić _busy=false (Fire ->
-- Signal:Fire -> task.spawn(handler) resumuje handler SYNCHRONICZNIE do jego pierwszego yielda, więc
-- nasz handler biegnie jeszcze WEWNĄTRZ tego samego wywołania playReveal, zanim `_busy=false` w ogóle
-- zdąży wykonać się w wątku-rodzicu). Inline PlayReveal(nextCard) tutaj trafiłby więc w busy-guard i
-- CICHO nic by się nie stało (karta znika z sekwencji, sequencer wisi w nieskończoność). Fix:
-- task.defer -- odkłada wywołanie na koniec BIEŻĄCEGO cyklu wznowień, czyli PO tym jak playReveal
-- zdąży w pełni wrócić do wrappera i ustawić _busy=false.
--
-- Robux flow: PromptProductPurchase -> ProcessReceipt (PurchaseService) granuje idempotentny kredyt
-- asynchronicznie -> PromptProductPurchaseFinished(isPurchased=true) na kliencie triggeruje
-- OpenPack(method="robux") z krótkim retry na "NoCredits" (kredyt może replikować się z małym
-- opóźnieniem względem zakończenia prompta, wzorzec retry jak EssenceTickController.waitForOwnGenerator).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local RollRevealController = require(script.Parent.RollRevealController)
local MarketplaceConfig = require(ReplicatedStorage.Shared.Configs.MarketplaceConfig)

local PackController = {}

local PACK_KEYS = { "Mega", "Super", "Legend" }

local _catalogModal: Frame
local _catalogList: ScrollingFrame
local _oddsModal: Frame
local _oddsList: Frame
local _statusLabel: TextLabel
local _toastGui: ScreenGui

local _oddsCache: { [string]: any }? = nil
local function fetchPackOdds(): { [string]: any }?
	if _oddsCache then
		return _oddsCache
	end
	local ok, result = NetController.Invoke("GetPackOdds")
	if ok and type(result) == "table" then
		_oddsCache = result
	end
	return _oddsCache
end

local function renderPackOdds(packKey: string, odds: { [string]: any })
	for _, child in _oddsList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local drawCount = odds.guaranteeLegendaryLast and (odds.cards - 1) or odds.cards
	UIFactory.label(_oddsList, `{packKey} -- {odds.cards} kart, R$ {odds.priceRobux} / {odds.priceEssence} Esencji`, {
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 1,
		ZIndex = 11,
	})
	UIFactory.label(_oddsList, `Karty 1-{drawCount} (każda niezależnie):`, {
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		ZIndex = 11,
	})
	for i, t in odds.tiers do
		UIFactory.label(_oddsList, `  {t.tier}: {string.format("%.1f", t.pct)}%`, {
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 2 + i,
			ZIndex = 11,
		})
	end
	if odds.guaranteeLegendaryLast then
		UIFactory.label(_oddsList, `Karta {odds.cards}: GWARANTOWANY Legendary (100%)`, {
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 210, 90),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = 100,
			ZIndex = 11,
		})
	end
end

local function openPackOddsModal(packKey: string)
	local all = fetchPackOdds()
	local odds = all and all[packKey]
	if not odds then
		return
	end
	renderPackOdds(packKey, odds)
	_oddsModal.Visible = true
end

local function showPackCompleteToast(cards: { { [string]: any } })
	local newCount = 0
	for _, c in cards do
		if c.isNewDiscovery then
			newCount += 1
		end
	end
	local panel = UIFactory.panel(_toastGui, {
		Size = UDim2.new(0, 320, 0, 80),
		Position = UDim2.new(0.5, -160, 0, 24),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	})
	UIFactory.label(panel, `Paczka otwarta! {#cards} kart, {newCount} nowych odkryć`, {
		Size = UDim2.new(1, -48, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 210, 90),
	})
	UIFactory.button(panel, "X", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 4),
		BackgroundColor3 = Color3.fromRGB(60, 60, 68),
	}, function()
		panel:Destroy()
	end)
	task.delay(4, function()
		if panel.Parent then
			panel:Destroy()
		end
	end)
end

-- Sekwencyjny reveal, jedna karta na raz -- patrz komentarz na górze pliku dla task.defer.
local function playSequential(cards: { { [string]: any } }, index: number, onDone: () -> ())
	if index > #cards then
		onDone()
		return
	end
	local conn
	conn = RollRevealController.RollCompleted:Connect(function()
		conn:Disconnect()
		task.defer(playSequential, cards, index + 1, onDone)
	end)
	RollRevealController.PlayReveal(cards[index])
end

local function handleOpenResult(ok: boolean, result: any): boolean
	if not (ok and type(result) == "table" and result.ok) then
		local reason = (ok and type(result) == "table" and result.reason) or "error"
		_statusLabel.Text = `Paczka: {reason}`
		task.delay(2, function()
			_statusLabel.Text = ""
		end)
		return false
	end
	_catalogModal.Visible = false
	playSequential(result.cards, 1, function()
		showPackCompleteToast(result.cards)
	end)
	return true
end

local function openPackFlow(packKey: string, method: string)
	_statusLabel.Text = ""
	handleOpenResult(NetController.Invoke("OpenPack", packKey, method))
end

-- Robux: kredyt granulowany asynchronicznie przez ProcessReceipt, może nie być jeszcze widoczny w
-- momencie PromptProductPurchaseFinished -- krótki retry na "NoCredits" (patrz nagłówek pliku).
local function openPackFlowWithRetry(packKey: string, method: string, attemptsLeft: number)
	local ok, result = NetController.Invoke("OpenPack", packKey, method)
	if ok and type(result) == "table" and result.ok then
		handleOpenResult(ok, result)
		return
	end
	local reason = (ok and type(result) == "table" and result.reason) or "error"
	if reason == "NoCredits" and attemptsLeft > 0 then
		task.wait(1)
		openPackFlowWithRetry(packKey, method, attemptsLeft - 1)
		return
	end
	handleOpenResult(ok, result)
end

local function buildPackRow(packKey: string, cfg: { [string]: any })
	local row = UIFactory.panel(_catalogList, {
		Size = UDim2.new(1, -12, 0, 64),
		BackgroundColor3 = Color3.fromRGB(40, 40, 48),
	})
	UIFactory.label(row, `{packKey} ({cfg.cards} kart{cfg.guaranteeLegendaryLast and ", gwar. Legendary" or ""})`, {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 0, 2),
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UIFactory.button(row, "?", {
		Size = UDim2.new(0, 30, 0, 26),
		Position = UDim2.new(0, 8, 0, 30),
		BackgroundColor3 = Color3.fromRGB(255, 210, 100),
		TextColor3 = Color3.fromRGB(40, 30, 0),
	}, function()
		openPackOddsModal(packKey)
	end)
	UIFactory.button(row, `{cfg.priceEssence} Ess`, {
		Size = UDim2.new(0, 110, 0, 26),
		Position = UDim2.new(0, 46, 0, 30),
		BackgroundColor3 = Color3.fromRGB(120, 90, 190),
	}, function()
		openPackFlow(packKey, "essence")
	end)
	UIFactory.button(row, `R$ {cfg.priceRobux}`, {
		Size = UDim2.new(0, 100, 0, 26),
		Position = UDim2.new(0, 164, 0, 30),
		BackgroundColor3 = Color3.fromRGB(90, 200, 120),
	}, function()
		local devCfg = MarketplaceConfig.DevProducts["Pack" .. packKey]
		if not devCfg then
			return
		end
		pcall(function()
			MarketplaceService:PromptProductPurchase(Players.LocalPlayer, devCfg.id)
		end)
	end)
end

local function buildCatalog()
	for _, child in _catalogList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local odds = fetchPackOdds()
	if not odds then
		return
	end
	for _, key in PACK_KEYS do
		if odds[key] then
			buildPackRow(key, odds[key])
		end
	end
	_catalogList.CanvasSize = UDim2.new(0, 0, 0, #PACK_KEYS * 72)
end

function PackController.Init() end

function PackController.Start()
	local gui = UIRootController.Get("Packs")
	_toastGui = UIRootController.Get("Toast")

	-- Pozycja: LEWO od "Talia" (-316), przed istniejącym STORE/Talia zachodzeniem (Monetization
	-- STORE i HudController Talia dzielą tę samą pozycję -316 na różnych rootach -- pre-existing bug,
	-- poza zakresem T4). -394 dokłada się do rządka Talia/Indeks/Roll/? bez trzeciego nakładania.
	UIFactory.button(gui, "Paczki", {
		Size = UDim2.new(0, 78, 0, 50),
		Position = UDim2.new(1, -394, 0, 12),
		BackgroundColor3 = Color3.fromRGB(220, 140, 60),
	}, function()
		_catalogModal.Visible = true
	end)

	_catalogModal = UIFactory.panel(gui, {
		Size = UDim2.new(1, -60, 0, 320),
		Position = UDim2.new(0, 30, 0.5, -160),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})
	UIFactory.label(_catalogModal, "PACZKI", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 6),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(220, 140, 60),
	})
	UIFactory.button(_catalogModal, "X", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -42, 0, 4),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	}, function()
		_catalogModal.Visible = false
	end)

	_catalogList = Instance.new("ScrollingFrame")
	_catalogList.Size = UDim2.new(1, -16, 1, -76)
	_catalogList.Position = UDim2.new(0, 8, 0, 42)
	_catalogList.BackgroundTransparency = 1
	_catalogList.BorderSizePixel = 0
	_catalogList.ScrollBarThickness = 8
	_catalogList.CanvasSize = UDim2.new(0, 0, 0, 0)
	_catalogList.Parent = _catalogModal
	local listLayout = Instance.new("UIListLayout")
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = _catalogList

	_statusLabel = UIFactory.label(_catalogModal, "", {
		Size = UDim2.new(1, -16, 0, 24),
		Position = UDim2.new(0, 8, 1, -30),
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 120, 120),
	})

	_oddsModal = UIFactory.panel(gui, {
		Size = UDim2.new(1, -60, 0, 380),
		Position = UDim2.new(0, 30, 0.5, -190),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		Visible = false,
		ZIndex = 10,
	})
	UIFactory.label(_oddsModal, "SZANSE PACZKI", {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 6),
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 210, 100),
		ZIndex = 10,
	})
	_oddsList = UIFactory.column(_oddsModal, {
		Size = UDim2.new(1, -16, 0, 300),
		Position = UDim2.new(0, 8, 0, 36),
		BackgroundTransparency = 1,
		ZIndex = 10,
	})
	UIFactory.button(_oddsModal, "Zamknij", {
		Size = UDim2.new(0, 140, 0, 40),
		Position = UDim2.new(0.5, -70, 1, -48),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
		ZIndex = 10,
	}, function()
		_oddsModal.Visible = false
	end)

	buildCatalog()

	MarketplaceService.PromptProductPurchaseFinished:Connect(function(_playerId, productId, isPurchased)
		if not isPurchased then
			return
		end
		for _, key in PACK_KEYS do
			local devCfg = MarketplaceConfig.DevProducts["Pack" .. key]
			if devCfg and devCfg.id == productId then
				openPackFlowWithRetry(key, "robux", 8)
				return
			end
		end
	end)
end

return PackController
