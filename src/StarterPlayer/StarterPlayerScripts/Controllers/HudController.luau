--!strict
-- Controllers/HudController.luau (Architektura §3, kontroler #3) — pasek Esencji (zawsze widoczny)
-- + podczas runu: złoto, poziom/starcie, pasek Wynik/Próg. Faza 2b (task #4, otwarte zadania
-- STATUS.md): dopięte 2 wejścia -- Roll (RollRevealController.RequestRoll) i Indeks
-- (IndexController.Open) -- w prawym górnym rogu, nad przyciskiem SHOP (widocznym tylko w runie,
-- patrz RunShopController), więc zero kolizji z esencją/paskiem runu/barem totemów po lewej.
-- Faza 4 Krok 4b (compliance fix): 3. wejście "?" tuż obok Roll -- otwiera MonetizationController.
-- OpenOddsView() (ta sama tabela szans co gate zakupu luck-gamepassu, widok informacyjny). Roll za
-- Esencję kupioną za Robux to TEŻ paid random item -- gracz musi mieć permanentny dostęp do szans
-- w tym samym panelu co Roll, nie tylko przy zakupie innego produktu.

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local RollRevealController = require(script.Parent.RollRevealController)
local IndexController = require(script.Parent.IndexController)
local DeckController = require(script.Parent.DeckController)
local MonetizationController = require(script.Parent.MonetizationController)

local HudController = {}

local _essenceLabel: TextLabel
local _goldLabel: TextLabel
local _levelLabel: TextLabel
local _scoreBarFill: Frame
local _scoreLabel: TextLabel
local _runRow: Frame

local function render(state: { [string]: any }?)
	if state == nil or state.status ~= "active" then
		_runRow.Visible = false
		return
	end
	_runRow.Visible = true
	_goldLabel.Text = `Gold: {state.gold}`
	_levelLabel.Text = `Lvl {state.level} · Enc {state.encounterIndex}/12`
	local threshold = math.max(1, state.threshold)
	local pct = math.clamp(state.score / threshold, 0, 1)
	_scoreBarFill.Size = UDim2.new(pct, 0, 1, 0)
	_scoreLabel.Text = `{math.floor(state.score)} / {math.floor(state.threshold)}`
end

function HudController.Init() end

function HudController.Start()
	local gui = UIRootController.Get("Hud")

	local essenceBar = UIFactory.panel(gui, {
		Size = UDim2.new(0, 200, 0, 40),
		Position = UDim2.new(0, 12, 0, 12),
		BackgroundColor3 = Color3.fromRGB(255, 196, 61),
	})
	_essenceLabel = UIFactory.label(essenceBar, "Essence: 0", { TextColor3 = Color3.fromRGB(40, 30, 0) })

	UIFactory.button(gui, "Talia", {
		Size = UDim2.new(0, 70, 0, 50),
		Position = UDim2.new(1, -316, 0, 12),
		BackgroundColor3 = Color3.fromRGB(120, 90, 190),
	}, function()
		DeckController.Open()
	end)

	UIFactory.button(gui, "Indeks", {
		Size = UDim2.new(0, 70, 0, 50),
		Position = UDim2.new(1, -238, 0, 12),
		BackgroundColor3 = Color3.fromRGB(90, 90, 200),
	}, function()
		IndexController.Open()
	end)

	UIFactory.button(gui, "Roll", {
		Size = UDim2.new(0, 70, 0, 50),
		Position = UDim2.new(1, -160, 0, 12),
		BackgroundColor3 = Color3.fromRGB(200, 160, 60),
	}, function()
		RollRevealController.RequestRoll()
	end)

	-- Faza 4 Krok 4b: "?" tuz obok Roll -- permanentny dostep do tabeli szans, w tej samej
	-- sesji/ekranie co Roll, PRZED kliknieciem, nie tylko przy zakupie luck-gamepassu.
	UIFactory.button(gui, "?", {
		Size = UDim2.new(0, 30, 0, 50),
		Position = UDim2.new(1, -84, 0, 12),
		BackgroundColor3 = Color3.fromRGB(255, 210, 100),
		TextColor3 = Color3.fromRGB(40, 30, 0),
	}, function()
		MonetizationController.OpenOddsView()
	end)

	_runRow = UIFactory.panel(gui, {
		Size = UDim2.new(1, -24, 0, 70),
		Position = UDim2.new(0, 12, 0, 60),
		BackgroundTransparency = 1,
		Visible = false,
	})

	_levelLabel = UIFactory.label(_runRow, "", {
		Size = UDim2.new(0.35, 0, 0, 24),
		Position = UDim2.new(0, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	_goldLabel = UIFactory.label(_runRow, "Gold: 0", {
		Size = UDim2.new(0.3, 0, 0, 24),
		Position = UDim2.new(0.7, 0, 0, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Color3.fromRGB(255, 210, 90),
	})

	local barBg = UIFactory.panel(_runRow, {
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.new(0, 0, 0, 30),
		BackgroundColor3 = Color3.fromRGB(20, 20, 24),
	})
	_scoreBarFill = UIFactory.panel(barBg, {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(90, 210, 120),
	})
	_scoreLabel = UIFactory.label(barBg, "0 / 0", { ZIndex = 2 })

	NetController.StateChanged:Connect(render)
	NetController.EssenceChanged:Connect(function(balance: number)
		_essenceLabel.Text = `Essence: {balance}`
	end)
end

return HudController
