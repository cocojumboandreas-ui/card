--!strict
-- Controllers/StartPickController.luau (Faza 4 Krok 0) — modal "wybierz 1 z 3/5 Totemów na start
-- runu" (GDD §2.7). Wzorzec skopiowany z RunShopController (kartowy layout, tierColor/artImage),
-- ale bez ceny/reroll -- to jest darmowy, jednorazowy wybor. Widoczny gdy
-- state.startPickOptions ma pozycje i state.startPickDone==false; znika natychmiast po wyborze
-- (RunStateSync push z serwera po udanym PickStartTotem czysci startPickOptions).
-- "brzydko-ale-działająco" (Faza 4 brief): kolorowe karty, zero animacji -- ladna wersja w Fazie 5.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local CardArtConfig = require(ReplicatedStorage.Shared.Configs.CardArtConfig)

local StartPickController = {}

local _modal: Frame
local _optionsRow: Frame

local function hasPick(state: { [string]: any }): boolean
	return state.status == "active"
		and state.startPickDone == false
		and state.startPickOptions ~= nil
		and #state.startPickOptions > 0
end

local function buildOptionCard(totem: { [string]: any })
	local card = UIFactory.panel(_optionsRow, {
		Size = UDim2.new(0, 150, 0, 190),
		BackgroundColor3 = UIFactory.tierColor(totem.tier),
	})

	local art = UIFactory.artImage(card, CardArtConfig.get(totem.id), {
		Size = UDim2.new(1, -8, 0, 100),
		Position = UDim2.new(0, 4, 0, 6),
	})

	local titleLabel = UIFactory.label(card, `{totem.tier}{string.char(10)}{totem.id}`, {
		Size = UDim2.new(1, -8, 0, 100),
		Position = UDim2.new(0, 4, 0, 6),
		TextSize = 16,
		TextWrapped = true,
	})
	if art then
		titleLabel.TextStrokeTransparency = 0
		titleLabel.ZIndex = 2
	end

	UIFactory.button(card, "PICK", {
		Size = UDim2.new(1, -16, 0, 44),
		Position = UDim2.new(0, 8, 1, -52),
		BackgroundColor3 = Color3.fromRGB(90, 200, 120),
	}, function()
		NetController.Invoke("PickStartTotem", totem.id)
	end)
end

local function render(state: { [string]: any }?)
	if state == nil or not hasPick(state) then
		_modal.Visible = false
		return
	end

	_modal.Visible = true
	for _, child in _optionsRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for _, totem in state.startPickOptions do
		buildOptionCard(totem)
	end
end

function StartPickController.Init() end

function StartPickController.Start()
	local gui = UIRootController.Get("StartPick")

	_modal = UIFactory.panel(gui, {
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(10, 10, 14),
		BackgroundTransparency = 0.15,
		Visible = false,
	})
	UIFactory.label(_modal, "CHOOSE YOUR STARTING TOTEM", {
		Size = UDim2.new(1, 0, 0, 50),
		Position = UDim2.new(0, 0, 0.22, 0),
		TextColor3 = Color3.fromRGB(255, 210, 100),
		TextSize = 22,
	})
	_optionsRow = UIFactory.row(_modal, {
		Size = UDim2.new(1, -20, 0, 200),
		Position = UDim2.new(0, 10, 0.34, 0),
		BackgroundTransparency = 1,
	})

	NetController.StateChanged:Connect(render)
	render(NetController.state)
end

return StartPickController
