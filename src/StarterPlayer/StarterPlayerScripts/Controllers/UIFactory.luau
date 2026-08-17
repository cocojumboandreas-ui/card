--!strict
-- Controllers/UIFactory.luau — placeholder UI budowane W KODZIE, nie klonowane z Studio (świadome
-- odejście od Architektura §3's "klient klonuje szablony z ReplicatedStorage.UITemplates": Faza 2a
-- placeholdery to KOLOROWE BLOKI wg tieru + tekst, zero artu, więc Studio-authored templates nie
-- dają nic ponad Instance.new -- ta decyzja NIE zamyka drogi do prawdziwych UITemplates później,
-- kontrolery wołają tylko te fabryczne funkcje, nie budują Instance.new wprost).
--
-- Miny z WAR RNG (przypomniane w briefie): wysoki DisplayOrder na każdym ScreenGui (inaczej domyślne
-- Roblox UI/inne ScreenGuiy przykrywają), i KAŻDA pozioma grupa przycisków owinięta we własny "Row"
-- Frame z UIListLayout (nie UIListLayout wrzucony luzem do panelu z mieszaną zawartością -- wtedy
-- layout żre też nie-przyciskowe dzieci i się rozjeżdża).

local Players = game:GetService("Players")

local UIFactory = {}

UIFactory.TierColors = {
	Common = Color3.fromRGB(158, 158, 163), -- szary
	Uncommon = Color3.fromRGB(74, 144, 255), -- niebieski
	Rare = Color3.fromRGB(50, 110, 230), -- niebieski (świadomie ten sam bucket co Uncommon -- 4 kolory na 5 tierów, wg brief)
	Epic = Color3.fromRGB(170, 90, 255), -- fioletowy
	Legendary = Color3.fromRGB(255, 196, 61), -- złoty
}

UIFactory.ElementColors = {
	Fire = Color3.fromRGB(235, 90, 64),
	Water = Color3.fromRGB(64, 170, 235),
	Nature = Color3.fromRGB(101, 201, 96),
	Lightning = Color3.fromRGB(240, 214, 64),
	Shadow = Color3.fromRGB(120, 90, 160),
}

function UIFactory.tierColor(tier: string?): Color3
	return (tier and UIFactory.TierColors[tier]) or Color3.fromRGB(120, 120, 125)
end

function UIFactory.elementColor(element: string?): Color3
	return (element and UIFactory.ElementColors[element]) or Color3.fromRGB(150, 150, 150)
end

local function applyProps(inst: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	for k, v in props do
		(inst :: any)[k] = v
	end
end

-- Root ScreenGui, DisplayOrder wysoki i JAWNY (mina WAR RNG) -- kolejne wywołania z rosnącym
-- displayOrder, żeby overlaye (shop, win/lose) zawsze na wierzchu HUD-u.
function UIFactory.screenGui(name: string, displayOrder: number): ScreenGui
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.DisplayOrder = displayOrder
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Parent = playerGui
	return gui
end

function UIFactory.panel(parent: Instance, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	applyProps(frame, props)
	frame.Parent = parent
	return frame
end

function UIFactory.label(parent: Instance, text: string, props: { [string]: any }?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = Color3.fromRGB(240, 240, 245)
	lbl.Font = Enum.Font.GothamBold
	lbl.TextScaled = true
	applyProps(lbl, props)
	lbl.Parent = parent
	return lbl
end

function UIFactory.button(parent: Instance, text: string, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 120, 0, 44)
	btn.BackgroundColor3 = Color3.fromRGB(70, 90, 200)
	btn.Text = text
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Font = Enum.Font.GothamBold
	btn.TextScaled = true
	btn.AutoButtonColor = true
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = btn
	applyProps(btn, props)
	btn.Parent = parent
	if onClick then
		-- Activated = zunifikowany tap+click, poprawny wybór pod dotyk (nie MouseButton1Click).
		btn.Activated:Connect(onClick)
	end
	return btn
end

-- Dedykowany kontener na poziomy rządek przycisków/kart -- WŁASNY Frame, nie UIListLayout wrzucony
-- do istniejącego panelu (mina WAR RNG, patrz komentarz na górze pliku).
function UIFactory.row(parent: Instance, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 0, 60)
	frame.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	applyProps(frame, props)
	frame.Parent = parent
	return frame
end

function UIFactory.column(parent: Instance, props: { [string]: any }?): Frame
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundTransparency = 1
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame
	applyProps(frame, props)
	frame.Parent = parent
	return frame
end

return UIFactory
