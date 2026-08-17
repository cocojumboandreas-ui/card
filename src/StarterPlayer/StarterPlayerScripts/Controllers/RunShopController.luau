--!strict
-- Controllers/RunShopController.luau (Architektura §3, kontroler #8) — modal 3-slotowy sklep
-- (Totem/Ulepszenie Zaklęcia/Zwój, GDD §1.5). RunShopService.open() NIE jest osobną fazą-blokerem:
-- woła się w tej samej ramce co reset nowego starcia (patrz komentarz nad `maybeOpenShop` w
-- PlayService), więc ręka pod spodem jest już aktywna -- ten kontroler jest zamykalnym OVERLAYEM,
-- nie ekranem pauzy. "Nowa wizyta" wykrywana przez zmianę encounterIndex (1:1 z każdym open()),
-- żeby modal auto-otwierał się raz na wizytę, ale gracz mógł go odłożyć bez blokowania ręki.

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)

local RunShopController = {}

local _badge: TextButton
local _modal: Frame
local _slotsRow: Frame
local _rerollBtn: TextButton

local _lastShopEncounterIndex: number? = nil
local _closed = false

local function hasAnyOffer(state: { [string]: any }): boolean
	local offers = state.shopOffers
	return offers ~= nil and (offers.totem ~= nil or offers.upgrade ~= nil or offers.scroll ~= nil)
end

local function buildOfferCard(state: { [string]: any }, slotKey: string)
	local offers = state.shopOffers
	local offer = offers and offers[slotKey]

	local color = Color3.fromRGB(60, 60, 68)
	local title = "SOLD"
	local price = nil

	if offer then
		price = offer.price
		if slotKey == "totem" then
			color = UIFactory.tierColor(offer.tier)
			title = `Totem\n{offer.totemId}`
		elseif slotKey == "upgrade" then
			color = Color3.fromRGB(90, 90, 200)
			title = `Upgrade\n{offer.spellId}\n(Rez x{offer.rezMultFactor})`
		elseif slotKey == "scroll" then
			color = Color3.fromRGB(90, 170, 90)
			title = `Scroll\n{offer.scrollKind}`
		end
	end

	local card = UIFactory.panel(_slotsRow, {
		Size = UDim2.new(0, 140, 0, 160),
		BackgroundColor3 = color,
	})
	UIFactory.label(card, title, {
		Size = UDim2.new(1, -8, 0, 90),
		Position = UDim2.new(0, 4, 0, 6),
		TextSize = 16,
		TextWrapped = true,
	})

	if offer then
		UIFactory.button(card, `BUY {price}g`, {
			Size = UDim2.new(1, -16, 0, 40),
			Position = UDim2.new(0, 8, 1, -48),
			BackgroundColor3 = Color3.fromRGB(90, 200, 120),
		}, function()
			NetController.Invoke("BuyShopItem", slotKey)
		end)
	end
end

local function renderModal(state: { [string]: any })
	for _, child in _slotsRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	buildOfferCard(state, "totem")
	buildOfferCard(state, "upgrade")
	buildOfferCard(state, "scroll")
	_rerollBtn.Text = `REROLL ({state.shopRerollCost}g)`
end

local function render(state: { [string]: any }?)
	if state == nil or state.status ~= "active" or not hasAnyOffer(state) then
		_badge.Visible = false
		_modal.Visible = false
		return
	end

	if state.encounterIndex ~= _lastShopEncounterIndex then
		_lastShopEncounterIndex = state.encounterIndex
		_closed = false
	end

	_badge.Visible = true
	_modal.Visible = not _closed
	if _modal.Visible then
		renderModal(state)
	end
end

function RunShopController.Init() end

function RunShopController.Start()
	local gui = UIRootController.Get("Shop")

	_badge = UIFactory.button(gui, "SHOP", {
		Size = UDim2.new(0, 70, 0, 50),
		Position = UDim2.new(1, -82, 0, 12),
		BackgroundColor3 = Color3.fromRGB(255, 196, 61),
		Visible = false,
	}, function()
		_closed = false
		local state = NetController.state
		if state then
			render(state)
		end
	end)

	_modal = UIFactory.panel(gui, {
		Size = UDim2.new(1, -40, 0, 260),
		Position = UDim2.new(0, 20, 0.5, -130),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})
	UIFactory.label(_modal, "SHOP", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 6),
		TextColor3 = Color3.fromRGB(255, 196, 61),
	})
	UIFactory.button(_modal, "X", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -42, 0, 4),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	}, function()
		_closed = true
		_modal.Visible = false
	end)

	_slotsRow = UIFactory.row(_modal, {
		Size = UDim2.new(1, -16, 0, 170),
		Position = UDim2.new(0, 8, 0, 40),
		BackgroundTransparency = 1,
	})

	_rerollBtn = UIFactory.button(_modal, "REROLL", {
		Size = UDim2.new(0, 160, 0, 40),
		Position = UDim2.new(0.5, -80, 1, -48),
		BackgroundColor3 = Color3.fromRGB(200, 160, 60),
	}, function()
		NetController.Invoke("RerollShop")
	end)

	NetController.StateChanged:Connect(render)
	render(NetController.state)
end

return RunShopController
