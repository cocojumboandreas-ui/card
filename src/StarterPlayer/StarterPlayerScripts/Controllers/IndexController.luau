--!strict
-- Controllers/IndexController.luau (Faza 2b, kontroler #10) — panel kolekcji Stworków. W ODRÓŻNIENIU
-- od WAR RNG (place-owned StarterGui.Index) tu UI jest CAŁE w kodzie (UIFactory), zgodnie z
-- resztą projektu (Architektura §3, patrz komentarz na górze UIFactory.luau) — zero inwestycji w
-- wygląd, siatka kolorowych bloków. Dane z GetIndexState (RF): entries/overall/luckBonus/thresholds
-- (kontrakt server-side patrz IndexService.luau). Open()/Close() publiczne -- wołane przez HUD entry
-- (task #4, osobny kontroler), IndexController sam NIE rysuje przycisku wejścia.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local RollRevealController = require(script.Parent.RollRevealController)
local CardArtConfig = require(ReplicatedStorage.Shared.Configs.CardArtConfig)
local MergeConfig = require(ReplicatedStorage.Shared.Configs.MergeConfig)

local IndexController = {}

local _gui: ScreenGui
local _modal: Frame
local _pctLabel: TextLabel
local _barFill: Frame
local _grid: ScrollingFrame
local _claimRow: Frame
local _busyMerge = false -- guard: jeden Merge/Disenchant call naraz, jak RollRevealController._busy

local refresh: () -> ()

-- Merge System 3: przycisk "Połącz" liczy WYŁĄCZNIE wariant Normal (Andreas /rc poprawka #3) --
-- pokazujemy to wprost jako "Normal: x/5", żeby mix Normal+Foil nie wyglądał jak zepsuty licznik.
local function onMergeClick(totemId: string)
	if _busyMerge then
		return
	end
	_busyMerge = true
	task.spawn(function()
		local ok, res = NetController.Invoke("MergeTotem", totemId)
		if ok and type(res) == "table" and res.ok then
			RollRevealController.PlayReveal({
				totemId = res.resultTotemId,
				tier = res.resultTier,
				variant = res.resultVariant,
				isNewDiscovery = res.isNewDiscovery,
				pityTriggered = false,
			})
			local conn
			conn = RollRevealController.RollCompleted:Connect(function()
				conn:Disconnect()
				refresh()
			end)
		end
		_busyMerge = false
	end)
end

local function onDisenchantClick(totemId: string, variant: string)
	if _busyMerge then
		return
	end
	_busyMerge = true
	task.spawn(function()
		NetController.Invoke("DisenchantTotem", totemId, variant)
		refresh()
		_busyMerge = false
	end)
end

local function renderGrid(entries: { any }, mergeById: { [string]: any }, disenchantById: { [string]: any })
	for _, child in _grid:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, e in ipairs(entries) do
		local cell = UIFactory.panel(_grid, {
			Size = UDim2.new(0, 80, 0, 130),
			BackgroundColor3 = e.discovered and UIFactory.tierColor(e.tier) or Color3.fromRGB(45, 45, 50),
			LayoutOrder = i,
		})
		if e.discovered then
			UIFactory.artImage(cell, CardArtConfig.get(e.id), {
				Size = UDim2.new(1, -8, 0, 52),
				Position = UDim2.new(0, 4, 0, 4),
			})
			UIFactory.label(cell, e.name, {
				Size = UDim2.new(1, -6, 0, 26),
				Position = UDim2.new(0, 3, 0, 58),
				TextSize = 12,
			})

			local merge = mergeById[e.id]
			local disenchant = disenchantById[e.id]
			if merge then
				UIFactory.label(cell, `Normal: {merge.count}/{MergeConfig.Threshold.Normal}`, {
					Size = UDim2.new(1, -6, 0, 16),
					Position = UDim2.new(0, 3, 0, 84),
					TextSize = 10,
					TextColor3 = Color3.fromRGB(200, 200, 205),
				})
				if merge.eligible then
					UIFactory.button(cell, "Połącz", {
						Size = UDim2.new(1, -8, 0, 24),
						Position = UDim2.new(0, 4, 1, -28),
						BackgroundColor3 = Color3.fromRGB(90, 170, 90),
						TextSize = 12,
					}, function()
						onMergeClick(e.id)
					end)
				end
			elseif disenchant then
				UIFactory.label(cell, `x{disenchant.count} dupl.`, {
					Size = UDim2.new(1, -6, 0, 16),
					Position = UDim2.new(0, 3, 0, 84),
					TextSize = 10,
					TextColor3 = Color3.fromRGB(200, 200, 205),
				})
				UIFactory.button(cell, `Rozłóż +{disenchant.value}`, {
					Size = UDim2.new(1, -8, 0, 24),
					Position = UDim2.new(0, 4, 1, -28),
					BackgroundColor3 = Color3.fromRGB(170, 130, 60),
					TextSize = 11,
				}, function()
					onDisenchantClick(e.id, disenchant.variant)
				end)
			end
		else
			UIFactory.label(cell, "?", {
				TextColor3 = Color3.fromRGB(85, 85, 90),
			})
		end
	end
end

local function renderThresholds(thresholds: { any })
	for _, child in _claimRow:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for i, t in ipairs(thresholds) do
		local color = Color3.fromRGB(60, 60, 68)
		local text = `{t.pct}%: locked`
		if t.claimed then
			color = Color3.fromRGB(55, 85, 60)
			text = `{t.pct}%: claimed`
		elseif t.reached then
			color = Color3.fromRGB(90, 200, 120)
			text = `ODBIERZ +{t.luck} ({t.pct}%)`
		end
		local btn = UIFactory.button(_claimRow, text, {
			Size = UDim2.new(0, 170, 0, 36),
			BackgroundColor3 = color,
			LayoutOrder = i,
			TextSize = 14,
		}, function()
			if t.reached and not t.claimed then
				local ok, res = NetController.Invoke("ClaimIndexLuck", t.pct)
				if ok and type(res) == "table" and res.ok then
					refresh()
				end
			end
		end)
		btn.Active = t.reached and not t.claimed
	end
end

refresh = function()
	local ok, state = NetController.Invoke("GetIndexState")
	if not (ok and type(state) == "table") then
		return
	end
	local mergeOk, mergeState = NetController.Invoke("GetMergeState")
	local mergeById, disenchantById = {}, {}
	if mergeOk and type(mergeState) == "table" then
		for _, m in mergeState.mergeable or {} do
			mergeById[m.id] = m
		end
		for _, d in mergeState.disenchantable or {} do
			disenchantById[d.id] = d -- v1: jeden wariant/id widoczny na kafelku, patrz MergeService.GetMergeState
		end
	end

	local overall = state.overall or { count = 0, total = 0, percent = 0 }
	_pctLabel.Text = `{overall.count}/{overall.total} · {math.floor(overall.percent)}%  (luck +{state.luckBonus or 0})`
	_barFill.Size = UDim2.new(math.clamp((overall.percent or 0) / 100, 0, 1), 0, 1, 0)
	renderGrid(state.entries or {}, mergeById, disenchantById)
	renderThresholds(state.thresholds or {})
end

local function openPanel()
	_modal.Visible = true
	refresh()
end

local function closePanel()
	_modal.Visible = false
end

function IndexController.Init() end

function IndexController.Start()
	_gui = UIRootController.Get("Index")

	_modal = UIFactory.panel(_gui, {
		Size = UDim2.new(1, -40, 0, 420),
		Position = UDim2.new(0, 20, 0.5, -210),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
		Visible = false,
	})

	UIFactory.label(_modal, "INDEX", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 6),
		TextColor3 = Color3.fromRGB(255, 196, 61),
	})
	UIFactory.button(_modal, "X", {
		Size = UDim2.new(0, 34, 0, 34),
		Position = UDim2.new(1, -42, 0, 4),
		BackgroundColor3 = Color3.fromRGB(160, 60, 60),
	}, closePanel)

	_pctLabel = UIFactory.label(_modal, "", {
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.new(0, 8, 0, 38),
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local barBg = UIFactory.panel(_modal, {
		Size = UDim2.new(1, -16, 0, 14),
		Position = UDim2.new(0, 8, 0, 62),
		BackgroundColor3 = Color3.fromRGB(20, 20, 24),
	})
	_barFill = UIFactory.panel(barBg, {
		Size = UDim2.new(0, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(90, 210, 120),
	})

	_grid = Instance.new("ScrollingFrame")
	_grid.Size = UDim2.new(1, -16, 0, 250)
	_grid.Position = UDim2.new(0, 8, 0, 82)
	_grid.BackgroundTransparency = 1
	_grid.BorderSizePixel = 0
	_grid.ScrollBarThickness = 6
	_grid.CanvasSize = UDim2.new(0, 0, 0, 0)
	_grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	_grid.Parent = _modal
	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0, 80, 0, 130) -- System 3: +30 dla wiersza akcji Połącz/Rozłóż
	gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = _grid

	_claimRow = UIFactory.row(_modal, {
		Size = UDim2.new(1, -16, 0, 40),
		Position = UDim2.new(0, 8, 1, -46),
		BackgroundTransparency = 1,
	})

	IndexController.Open = openPanel
	IndexController.Close = closePanel
end

return IndexController
