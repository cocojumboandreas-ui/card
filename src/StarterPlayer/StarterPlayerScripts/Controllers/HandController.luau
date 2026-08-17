--!strict
-- Controllers/HandController.luau (Architektura §3, kontroler #5) — ręka Run + tap-select +
-- AUTO-SUGGEST kliencki. Refinement #2 (użytkownik, ta sesja): auto-suggest MA działać w 2a, nie
-- 2b -- woła TEN SAM HandEvaluator co serwer (Framework, zero Roblox API), więc podświetlenie
-- zawsze zgadza się z tym, co serwer faktycznie zaakceptuje przy ZAGRAJ. To tylko podpowiedź:
-- serwer nadal jest autorytatywny (PlayService.play przelicza od zera), klient nigdy nie ufa
-- własnemu evaluate() do niczego poza podświetleniem.
--
-- Karty kolorowane wg ELEMENTU (nie tieru -- Runy nie mają tieru, to atrybut przedmiotów sklepu,
-- patrz UIFactory.TierColors vs ElementColors).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HandEvaluator = require(ReplicatedStorage.Shared.HandEvaluator)

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local ScoreFxController = require(script.Parent.ScoreFxController)

local HandController = {}

local _container: Frame
local _suggestLabel: TextLabel
local _handRow: Frame
local _playBtn: TextButton
local _swapBtn: TextButton
local _remainingLabel: TextLabel

local _selected: { [number]: boolean } = {}
local _cards: { [number]: TextButton } = {}
local _suggested: { [number]: boolean } = {}

local SELECTED_STROKE = Color3.fromRGB(120, 220, 255)
local SUGGEST_STROKE = Color3.fromRGB(255, 220, 110)

local function strokeOf(card: TextButton): UIStroke
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Thickness = 0
		stroke.Parent = card
	end
	return stroke :: UIStroke
end

local function restyleCard(idx: number)
	local card = _cards[idx]
	if not card then
		return
	end
	local stroke = strokeOf(card)
	if _selected[idx] then
		stroke.Thickness = 4
		stroke.Color = SELECTED_STROKE
	elseif _suggested[idx] then
		stroke.Thickness = 3
		stroke.Color = SUGGEST_STROKE
	else
		stroke.Thickness = 0
	end
end

local function restyleAll()
	for idx in _cards do
		restyleCard(idx)
	end
end

local function toggleSelect(idx: number)
	_selected[idx] = if _selected[idx] then nil else true
	restyleCard(idx)
end

local function selectedIndices(): { number }
	local out = {}
	for idx, on in _selected do
		if on then
			table.insert(out, idx)
		end
	end
	table.sort(out)
	return out
end

local function rebuildCards(hand: { { element: string, value: number } })
	for _, child in _handRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	_cards = {}
	_selected = {}

	local count = math.max(1, #hand)
	local cardW = math.clamp(320 / count, 44, 74)

	for i, rune in hand do
		local card = UIFactory.button(_handRow, tostring(rune.value), {
			Size = UDim2.new(0, cardW, 0, 84),
			BackgroundColor3 = UIFactory.elementColor(rune.element),
			LayoutOrder = i,
		}, function()
			toggleSelect(i)
		end)
		UIFactory.label(card, string.upper(string.sub(rune.element, 1, 4)), {
			Size = UDim2.new(1, 0, 0, 16),
			Position = UDim2.new(0, 0, 1, -16),
			TextSize = 11,
			Font = Enum.Font.Gotham,
			TextColor3 = Color3.fromRGB(20, 20, 20),
		})
		_cards[i] = card
	end
end

local function applySuggestion(state: { [string]: any })
	_suggested = {}
	local result = HandEvaluator.evaluate(state.hand, state.spellUpgrades)
	if result then
		for _, idx in result.matchedRunes do
			_suggested[idx] = true
		end
		_suggestLabel.Text = `Suggested: {result.spellId}`
		_suggestLabel.Visible = true
	else
		_suggestLabel.Visible = false
	end
	restyleAll()
end

local function render(state: { [string]: any }?)
	if state == nil or state.status ~= "active" then
		_container.Visible = false
		return
	end
	_container.Visible = true
	rebuildCards(state.hand)
	applySuggestion(state)
	_remainingLabel.Text = `Plays left: {state.playsRemaining}  ·  Swaps left: {state.swapsRemaining}`
	_swapBtn.BackgroundTransparency = state.swapsRemaining > 0 and 0 or 0.6
end

function HandController.Init() end

function HandController.Start()
	local gui = UIRootController.Get("Hand")

	_container = UIFactory.panel(gui, {
		Size = UDim2.new(1, -20, 0, 220),
		Position = UDim2.new(0, 10, 1, -230),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})

	_suggestLabel = UIFactory.label(_container, "", {
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.new(0, 10, 0, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = SUGGEST_STROKE,
		TextSize = 18,
		Font = Enum.Font.GothamBold,
	})

	_handRow = UIFactory.row(_container, {
		Size = UDim2.new(1, -20, 0, 100),
		Position = UDim2.new(0, 10, 0, 34),
		BackgroundTransparency = 1,
	})

	_remainingLabel = UIFactory.label(_container, "", {
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 0, 138),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(190, 190, 195),
		TextSize = 14,
		Font = Enum.Font.Gotham,
	})

	local actionRow = UIFactory.row(_container, {
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.new(0, 10, 0, 162),
		BackgroundTransparency = 1,
	})

	-- Scale (0.25) zamiast fixed Offset -- 4x100px offset przelewało się poza 400px portret
	-- (playtest dotykowy, Faza 2a krok 8); wysokość 44px = min. mobilny cel dotykowy.
	_playBtn = UIFactory.button(actionRow, "PLAY", {
		Size = UDim2.new(0.25, -10, 0, 44),
		BackgroundColor3 = Color3.fromRGB(90, 200, 120),
	}, function()
		local indices = selectedIndices()
		if #indices == 0 then
			return
		end
		local ok, outcome = NetController.Invoke("PlayRunes", indices)
		if ok then
			ScoreFxController.showPlayOutcome(outcome)
		end
	end)

	_swapBtn = UIFactory.button(actionRow, "SWAP", {
		Size = UDim2.new(0.25, -10, 0, 44),
		BackgroundColor3 = Color3.fromRGB(200, 160, 60),
	}, function()
		local indices = selectedIndices()
		if #indices == 0 then
			return
		end
		NetController.Invoke("SwapRunes", indices)
	end)

	UIFactory.button(actionRow, "USE\nSUGGESTED", {
		Size = UDim2.new(0.25, -10, 0, 44),
		BackgroundColor3 = Color3.fromRGB(90, 90, 200),
		TextSize = 13,
	}, function()
		_selected = table.clone(_suggested)
		restyleAll()
	end)

	UIFactory.button(actionRow, "END\nENCOUNTER", {
		Size = UDim2.new(0.25, -10, 0, 44),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
		TextSize = 13,
	}, function()
		local ok, outcome = NetController.Invoke("EndEncounterVoluntary")
		if ok then
			ScoreFxController.showPlayOutcome(outcome)
		end
	end)

	NetController.StateChanged:Connect(render)
	render(NetController.state)
end

return HandController
