--!strict
-- Controllers/DeckController.luau (MAX-SLOT) — ekran wyboru aktywnej puli totemów (profile.activeDeck).
-- Brzydko-ale-działająco (Faza 5 zrobi redesign, jak reszta ekranów): JEDNA siatka całej kolekcji
-- (UIFactory.panel/label/button, wzorzec IndexController) zamiast dwóch kolumn drag&drop -- klik na
-- kartę w decku ją usuwa, klik na kartę selectable-poza-deckiem ją dodaje (do GetDeck().deckSize).
-- Serwer jest autorytatywny (DeckService.SetDeck) -- Zapisz wysyła CAŁĄ listę, klient nigdy nie
-- zakłada że jego lokalny stan się przyjął bez odpowiedzi.

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)

local DeckController = {}

local _gui: ScreenGui
local _modal: Frame
local _countLabel: TextLabel
local _msgLabel: TextLabel
local _grid: ScrollingFrame

local _deckSize = 10
local _deckSet: { [string]: boolean } = {} -- lokalny working-set, PRZED Zapisz -- nie profil
local _entries: { any } = {}

local refresh: () -> ()

local function renderGrid()
	for _, child in _grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, e in ipairs(_entries) do
		local inDeck = _deckSet[e.id] == true
		local bg = Color3.fromRGB(45, 45, 50)
		if inDeck then
			bg = Color3.fromRGB(70, 150, 90) -- w decku -- zielona ramka koloru, prosto, bez artu
		elseif e.selectable then
			bg = UIFactory.tierColor(e.tier)
		end
		local cell = UIFactory.panel(_grid, {
			Size = UDim2.new(0, 80, 0, 90),
			BackgroundColor3 = bg,
			LayoutOrder = i,
		})
		UIFactory.label(cell, e.name, {
			Size = UDim2.new(1, -6, 0, 40),
			Position = UDim2.new(0, 3, 0, 4),
			TextSize = 12,
			TextColor3 = e.selectable and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(120, 120, 125),
		})
		UIFactory.label(cell, inDeck and "W DECKU" or (e.selectable and "DODAJ" or "brak"), {
			Size = UDim2.new(1, -6, 0, 30),
			Position = UDim2.new(0, 3, 1, -34),
			TextSize = 11,
			TextColor3 = Color3.fromRGB(230, 230, 235),
		})
		if e.selectable then
			local btn = Instance.new("TextButton")
			btn.BackgroundTransparency = 1
			btn.Text = ""
			btn.Size = UDim2.fromScale(1, 1)
			btn.Parent = cell
			btn.Activated:Connect(function()
				if inDeck then
					_deckSet[e.id] = nil
				else
					local count = 0
					for _ in _deckSet do
						count += 1
					end
					if count >= _deckSize then
						_msgLabel.Text = `Deck pełny ({_deckSize}) — usuń coś, żeby dodać.`
						return
					end
					_deckSet[e.id] = true
				end
				_msgLabel.Text = ""
				renderGrid()
				local count = 0
				for _ in _deckSet do
					count += 1
				end
				_countLabel.Text = `Deck: {count}/{_deckSize}`
			end)
		end
	end
end

refresh = function()
	local ok, state = NetController.Invoke("GetDeck")
	if not (ok and type(state) == "table" and state.ok) then
		return
	end
	_deckSize = state.deckSize or 10
	_entries = state.entries or {}
	_deckSet = {}
	for _, id in state.deck or {} do
		_deckSet[id] = true
	end
	_msgLabel.Text = ""
	local count = 0
	for _ in _deckSet do
		count += 1
	end
	_countLabel.Text = `Deck: {count}/{_deckSize}`
	renderGrid()
end

local function openPanel()
	_modal.Visible = true
	refresh()
end

local function closePanel()
	_modal.Visible = false
end

local function saveDeck()
	local ids = {}
	for id in _deckSet do
		table.insert(ids, id)
	end
	local ok, res = NetController.Invoke("SetDeck", ids)
	if ok and type(res) == "table" and res.ok then
		_msgLabel.Text = "Zapisano."
	else
		local reason = (ok and type(res) == "table" and res.reason) or "błąd"
		_msgLabel.Text = `Nie zapisano: {reason}`
		refresh() -- serwer odrzucił -- cofnij lokalny stan do tego co faktycznie jest w profilu
	end
end

function DeckController.Init() end

function DeckController.Start()
	_gui = UIRootController.Get("Deck")

	_modal = UIFactory.panel(_gui, {
		Size = UDim2.new(1, -40, 0, 420),
		Position = UDim2.new(0, 20, 0.5, -210),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})

	UIFactory.label(_modal, "TALIA", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 6),
		TextColor3 = Color3.fromRGB(255, 196, 61),
	})
	UIFactory.button(_modal, "X", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -42, 0, 4),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	}, closePanel)

	_countLabel = UIFactory.label(_modal, "Deck: 0/10", {
		Size = UDim2.new(0.5, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 38),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	_msgLabel = UIFactory.label(_modal, "", {
		Size = UDim2.new(0.5, -16, 0, 22),
		Position = UDim2.new(0.5, 8, 0, 38),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 220, 100),
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	_grid = Instance.new("ScrollingFrame")
	_grid.Size = UDim2.new(1, -16, 0, 280)
	_grid.Position = UDim2.new(0, 8, 0, 64)
	_grid.BackgroundTransparency = 1
	_grid.BorderSizePixel = 0
	_grid.ScrollBarThickness = 6
	_grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	_grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_grid.Parent = _modal
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 80, 0, 90)
	gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = _grid

	UIFactory.button(_modal, "ZAPISZ", {
		Size = UDim2.new(0, 160, 0, 40),
		Position = UDim2.new(0, 8, 1, -46),
		BackgroundColor3 = Color3.fromRGB(70, 150, 90),
	}, saveDeck)

	DeckController.Open = openPanel
	DeckController.Close = closePanel
end

return DeckController
