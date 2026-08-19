--!strict
-- Controllers/PlotController.luau (T2, pivot tycoon) — tap na CardFrame slotu na WŁASNYM plocie
-- otwiera panel kolekcji (WYŁĄCZNIE odkryte Stworki, reużyty GetIndexState + filtr discovered),
-- klik na kartę = natychmiastowy zapis (SetPlotSlot), nie batch jak DeckController -- spec T2
-- p.3: "wybór karty -> przypisanie do slotu -> update wyświetlenia + zapis" to jeden krok.
--
-- ClickDetector to NOWY wzorzec w tym repo (grep na starcie T2: zero ClickDetector/ProximityPrompt
-- gdziekolwiek) -- wybrany nad ProximityPrompt bo spec mówi "tap na slot", nie "podejdź i przytrzymaj";
-- gracz i tak stoi na swoim plocie.
--
-- GetMyPlot to RemoteFunction zwracająca ŻYWĄ referencję Model spod Workspace (replikowana, więc
-- przejście przez remote działa) -- alokacja jest async po ProfileLoaded, więc retry z odstępem
-- zamiast jednego strzału.

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)

local SLOT_COUNT = 10
local CLICK_MAX_DISTANCE = 64 -- plot 64x64, gracz może stać w dowolnym rogu

local PlotController = {}

local _gui: ScreenGui
local _modal: Frame
local _titleLabel: TextLabel
local _msgLabel: TextLabel
local _grid: ScrollingFrame

local _plotModel: Model? = nil
local _openSlotIndex: number? = nil
local _entries: { any } = {}

local function currentTotemIdForSlot(slotIndex: number): string
	if not _plotModel then
		return ""
	end
	local slotModel = _plotModel:FindFirstChild("Slot" .. slotIndex)
	local cardFrame = slotModel and slotModel:FindFirstChild("CardFrame")
	local frame = cardFrame and cardFrame:FindFirstChild("Frame")
	return (frame and frame:GetAttribute("TotemId")) or ""
end

local function assignSlot(totemId: string?)
	local slotIndex = _openSlotIndex
	if not slotIndex then
		return
	end
	local ok, res = NetController.Invoke("SetPlotSlot", slotIndex, totemId)
	if ok and type(res) == "table" and res.ok then
		_msgLabel.Text = "Zapisano."
		PlotController.Close()
	else
		local reason = (ok and type(res) == "table" and res.reason) or "błąd"
		_msgLabel.Text = `Nie zapisano: {reason}`
	end
end

local function renderGrid()
	for _, child in _grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local currentId = _openSlotIndex and currentTotemIdForSlot(_openSlotIndex) or ""

	-- Pierwsza komórka: wyczyść slot.
	do
		local cell = UIFactory.panel(_grid, {
			Size = UDim2.new(0, 80, 0, 90),
			BackgroundColor3 = currentId == "" and Color3.fromRGB(70, 150, 90) or Color3.fromRGB(60, 60, 66),
			LayoutOrder = 0,
		})
		UIFactory.label(cell, "PUSTY", { TextSize = 14 })
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Size = UDim2.fromScale(1, 1)
		btn.Parent = cell
		btn.Activated:Connect(function()
			assignSlot(nil)
		end)
	end

	for i, e in ipairs(_entries) do
		local isCurrent = e.id == currentId
		local bg = isCurrent and Color3.fromRGB(70, 150, 90) or UIFactory.tierColor(e.tier)
		local cell = UIFactory.panel(_grid, {
			Size = UDim2.new(0, 80, 0, 90),
			BackgroundColor3 = bg,
			LayoutOrder = i,
		})
		UIFactory.label(cell, e.name, {
			Size = UDim2.new(1, -6, 0, 40),
			Position = UDim2.new(0, 3, 0, 4),
			TextSize = 12,
		})
		UIFactory.label(cell, isCurrent and "WYSTAWIONA" or "WYSTAW", {
			Size = UDim2.new(1, -6, 0, 30),
			Position = UDim2.new(0, 3, 1, -34),
			TextSize = 11,
			TextColor3 = Color3.fromRGB(230, 230, 235),
		})
		local btn = Instance.new("TextButton")
		btn.BackgroundTransparency = 1
		btn.Text = ""
		btn.Size = UDim2.fromScale(1, 1)
		btn.Parent = cell
		btn.Activated:Connect(function()
			assignSlot(e.id)
		end)
	end
end

local function refreshCollection()
	local ok, state = NetController.Invoke("GetIndexState")
	if not (ok and type(state) == "table") then
		_entries = {}
		return
	end
	_entries = {}
	for _, e in state.entries or {} do
		if e.discovered then
			table.insert(_entries, e)
		end
	end
end

local function openPanel(slotIndex: number)
	_openSlotIndex = slotIndex
	_titleLabel.Text = `SLOT {slotIndex}`
	_msgLabel.Text = ""
	refreshCollection()
	renderGrid()
	_modal.Visible = true
end

function PlotController.Close()
	_modal.Visible = false
	_openSlotIndex = nil
end

local function wireSlotClickDetectors(plotModel: Model)
	for i = 1, SLOT_COUNT do
		local slotModel = plotModel:FindFirstChild("Slot" .. i)
		local cardFrame = slotModel and slotModel:FindFirstChild("CardFrame")
		local frame = cardFrame and cardFrame:FindFirstChild("Frame")
		if frame and frame:IsA("BasePart") then
			local detector = frame:FindFirstChildOfClass("ClickDetector") or Instance.new("ClickDetector")
			detector.MaxActivationDistance = CLICK_MAX_DISTANCE
			detector.Parent = frame
			detector.MouseClick:Connect(function()
				openPanel(i)
			end)
		end
	end
end

local function waitForMyPlot()
	task.spawn(function()
		for _ = 1, 30 do
			local ok, res = NetController.Invoke("GetMyPlot")
			if ok and type(res) == "table" and res.ok and res.plotModel then
				_plotModel = res.plotModel
				wireSlotClickDetectors(_plotModel :: Model)
				return
			end
			task.wait(1)
		end
		warn("[PlotController] GetMyPlot: brak plotu po 30 próbach")
	end)
end

function PlotController.Init() end

function PlotController.Start()
	_gui = UIRootController.Get("Plot")

	_modal = UIFactory.panel(_gui, {
		Size = UDim2.new(1, -40, 0, 420),
		Position = UDim2.new(0, 20, 0.5, -210),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})

	_titleLabel = UIFactory.label(_modal, "SLOT", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 6),
		TextColor3 = Color3.fromRGB(255, 196, 61),
	})
	UIFactory.button(_modal, "X", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -42, 0, 4),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	}, PlotController.Close)

	_msgLabel = UIFactory.label(_modal, "", {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 38),
		TextSize = 12,
		TextColor3 = Color3.fromRGB(220, 220, 100),
	})

	_grid = Instance.new("ScrollingFrame")
	_grid.Size = UDim2.new(1, -16, 0, 300)
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

	waitForMyPlot()
end

return PlotController
