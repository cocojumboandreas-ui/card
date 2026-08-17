--!strict
-- Controllers/TotemBarController.luau (Architektura §3, kontroler #7) — rząd posiadanych Totemów
-- (Stworków), kolorowany wg tieru (UIFactory.TierColors — Totemy, w odróżnieniu od Run, MAJĄ tier).
-- Pusty pasek w 2a przy starcie runu (meta pick "1 z 3" odłożony, patrz RunSessionService) --
-- pasek zapełnia się wyłącznie zakupami w RunShopController.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local CardArtConfig = require(ReplicatedStorage.Shared.Configs.CardArtConfig)

local TotemBarController = {}

local _container: Frame
local _row: Frame
local _infoLabel: TextLabel

local function effectSummary(totem: { [string]: any }): string
	local parts = {}
	for k, v in totem.effect do
		table.insert(parts, `{k}={tostring(v)}`)
	end
	return table.concat(parts, ", ")
end

local function render(state: { [string]: any }?)
	if state == nil or state.status ~= "active" then
		_container.Visible = false
		return
	end
	_container.Visible = true

	for _, child in _row:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	_infoLabel.Text = ""

	for i, totem in state.totems do
		local slot = UIFactory.button(_row, totem.name, {
			Size = UDim2.new(0, 60, 0, 60),
			BackgroundColor3 = UIFactory.tierColor(totem.tier),
			TextSize = 11,
			LayoutOrder = i,
		}, function()
			_infoLabel.Text = `{totem.name} ({totem.tier}) — {effectSummary(totem)}`
		end)
		slot.TextWrapped = true

		if UIFactory.artImage(slot, CardArtConfig.get(totem.id)) then
			-- art niesie tożsamość Stworka -- nazwa i tak dostępna po tapie (_infoLabel);
			-- pełny podpis w 60px zasłoniłby ~88% artu.
			slot.Text = ""
		end
	end
end

function TotemBarController.Init() end

function TotemBarController.Start()
	local gui = UIRootController.Get("Hud")

	_container = UIFactory.panel(gui, {
		Size = UDim2.new(1, -24, 0, 100),
		Position = UDim2.new(0, 12, 0, 136),
		BackgroundTransparency = 1,
		Visible = false,
	})

	_row = UIFactory.row(_container, {
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 1,
	})

	_infoLabel = UIFactory.label(_container, "", {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.new(0, 0, 0, 66),
		TextSize = 13,
		Font = Enum.Font.Gotham,
		TextColor3 = Color3.fromRGB(200, 200, 205),
		TextWrapped = true,
	})

	NetController.StateChanged:Connect(render)
	render(NetController.state)
end

return TotemBarController
