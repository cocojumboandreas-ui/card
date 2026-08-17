--!strict
-- Controllers/RunFlowController.luau (Architektura §3, kontroler #4) — ekrany runu: start, intro
-- starcia (poziom + zapowiedź debuffu Strażnika PRZED starciem, RunSessionService ujawnia
-- deadElement zawczasu specjalnie po to), WIN/LOSE summary.
--
-- Uproszczenie vs Architektura §3 "Steruje widocznością HandController": zamiast RunFlowController
-- pchającego widoczność do HandController (kolejność-require pułapka), HandController/TotemBar/
-- Hud same czytają NetController.state.status -- ten kontroler odpowiada WYŁĄCZNIE za własne ekrany.
-- Meta-kolekcyjny "pick 1 z 3 Totemów" na start ma WŁASNY kontroler (StartPickController, Faza 4
-- Krok 0) -- ten plik już go nie dotyczy.

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)

local RunFlowController = {}

local _startScreen: Frame
local _endScreen: Frame
local _endTitle: TextLabel
local _endBody: TextLabel
local _banner: Frame
local _bannerLabel: TextLabel

local _lastEncounterIndex: number? = nil
local _bannerGeneration = 0

local function showBanner(state: { [string]: any })
	_bannerGeneration += 1
	local myGen = _bannerGeneration

	local parts = { `Level {state.level} · Encounter {state.encounterIndex}/12` }
	if state.activeGuardian then
		table.insert(parts, `⚠ Guardian: {state.activeGuardian.name}`)
	end
	if state.deadElement then
		table.insert(parts, `{state.deadElement} nullified this fight`)
	end
	_bannerLabel.Text = table.concat(parts, string.char(10))
	_banner.Visible = true

	task.delay(2.2, function()
		if myGen == _bannerGeneration then
			_banner.Visible = false
		end
	end)
end

local function render(state: { [string]: any }?)
	if state == nil then
		_startScreen.Visible = true
		_endScreen.Visible = false
		_banner.Visible = false
		return
	end

	_startScreen.Visible = false

	if state.status == "active" then
		_endScreen.Visible = false
		if state.encounterIndex ~= _lastEncounterIndex then
			_lastEncounterIndex = state.encounterIndex
			showBanner(state)
		end
		return
	end

	-- won / lost / abandoned
	_lastEncounterIndex = nil
	_banner.Visible = false
	if state.status == "won" then
		_endTitle.Text = "RUN WON!"
		_endTitle.TextColor3 = Color3.fromRGB(120, 230, 140)
	elseif state.status == "abandoned" then
		_endTitle.Text = "RUN ENDED"
		_endTitle.TextColor3 = Color3.fromRGB(230, 200, 120)
	else
		_endTitle.Text = "RUN LOST"
		_endTitle.TextColor3 = Color3.fromRGB(230, 90, 90)
	end
	_endBody.Text = `Reached encounter {state.encounterIndex}/12 · Final gold {state.gold}`
	_endScreen.Visible = true
end

function RunFlowController.Init() end

function RunFlowController.Start()
	local gui = UIRootController.Get("RunFlow")

	_startScreen = UIFactory.panel(gui, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(18, 18, 22) })
	UIFactory.label(_startScreen, "ROLL A RUNE", {
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.new(0, 0, 0.32, 0),
		TextColor3 = Color3.fromRGB(255, 210, 100),
	})
	local startRow = UIFactory.row(_startScreen, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.5, 0) })
	UIFactory.button(startRow, "PLAY", { Size = UDim2.new(0, 180, 0, 56) }, function()
		NetController.Invoke("StartRun", "free")
	end)

	_endScreen = UIFactory.panel(gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(18, 18, 22),
		Visible = false,
	})
	_endTitle = UIFactory.label(_endScreen, "", {
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.new(0, 0, 0.3, 0),
	})
	_endBody = UIFactory.label(_endScreen, "", {
		Size = UDim2.new(0.9, 0, 0, 40),
		Position = UDim2.new(0.05, 0, 0.42, 0),
		TextColor3 = Color3.fromRGB(210, 210, 215),
		Font = Enum.Font.Gotham,
	})
	local endRow = UIFactory.row(_endScreen, { Size = UDim2.new(1, 0, 0, 60), Position = UDim2.new(0, 0, 0.55, 0) })
	UIFactory.button(endRow, "PLAY AGAIN", { Size = UDim2.new(0, 200, 0, 56) }, function()
		NetController.Invoke("StartRun", "free")
	end)

	_banner = UIFactory.panel(gui, {
		Size = UDim2.new(0.8, 0, 0, 90),
		Position = UDim2.new(0.1, 0, 0.06, 0),
		BackgroundColor3 = Color3.fromRGB(40, 30, 60),
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	_bannerLabel = UIFactory.label(_banner, "", { TextSize = 18, TextWrapped = true })

	NetController.StateChanged:Connect(render)
	render(NetController.state)
end

return RunFlowController
