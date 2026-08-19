--!strict
-- Controllers/EssenceTickController.luau (T3, pasywna esencja) — JUICE na fontannie własnego plotu:
-- popup "+N" (BillboardGui + tween, wzorzec ScoreFxController -- tu 3D-zaczepiony na Part zamiast
-- ScreenGui, bo fontanna to konkretny punkt w świecie, nie globalny HUD) + krótki rozbłysk
-- ParticleEmitter. Zero remote'ów: EssenceGenerator.LastTickAmount/LastTickSeq to zwykłe atrybuty
-- ustawiane serwerowo przez EssenceTickService (replikacja "za darmo", ten sam wzorzec co karty na
-- slotach w PlotService) -- LastTickSeq istnieje WYŁĄCZNIE po to, żeby AttributeChangedSignal
-- odpalił nawet gdy dwa kolejne tyki dają identyczną kwotę (Roblox nie fire'uje sygnału zmiany, gdy
-- wartość atrybutu się nie zmienia).
--
-- Scoping: WŁASNY plot gracza (jak PlotController) -- podgląd fontann cudzych plotów to
-- rozszerzenie na później, nie w zakresie T3.

local TweenService = game:GetService("TweenService")

local NetController = require(script.Parent.NetController)

local EssenceTickController = {}

local function spawnPopup(gen: BasePart, amount: number)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 40)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = gen

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.fromScale(1, 1)
	lbl.BackgroundTransparency = 1
	lbl.Text = `+{amount}`
	lbl.TextColor3 = Color3.fromRGB(255, 196, 61)
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextTransparency = 0
	lbl.Parent = billboard

	local moveTween = TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
		StudsOffset = Vector3.new(0, 8, 0),
	})
	local fadeTween = TweenService:Create(lbl, TweenInfo.new(1.1, Enum.EasingStyle.Quad), {
		TextTransparency = 1,
	})
	moveTween:Play()
	fadeTween:Play()
	fadeTween.Completed:Connect(function()
		billboard:Destroy()
	end)
end

local function spawnSparkle(gen: BasePart)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, gen.Size.Y / 2, 0)
	attachment.Parent = gen

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 221, 120))
	emitter.Lifetime = NumRange.new(0.4, 0.7)
	emitter.Speed = NumRange.new(3, 6)
	emitter.SpreadAngle = Vector2.new(45, 45)
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(14)

	task.delay(1, function()
		attachment:Destroy()
	end)
end

local function onTick(gen: BasePart)
	local amount = gen:GetAttribute("LastTickAmount")
	if type(amount) == "number" and amount > 0 then
		spawnPopup(gen, amount)
		spawnSparkle(gen)
	end
end

local function waitForOwnGenerator()
	task.spawn(function()
		for _ = 1, 30 do
			local ok, res = NetController.Invoke("GetMyPlot")
			if ok and type(res) == "table" and res.ok and res.plotModel then
				local plotModel = res.plotModel :: Model
				local gen = plotModel:FindFirstChild("EssenceGenerator")
				if gen and gen:IsA("BasePart") then
					local part = gen :: BasePart
					part:GetAttributeChangedSignal("LastTickSeq"):Connect(function()
						onTick(part)
					end)
				end
				return
			end
			task.wait(1)
		end
		warn("[EssenceTickController] GetMyPlot: brak plotu po 30 próbach")
	end)
end

function EssenceTickController.Init() end

function EssenceTickController.Start()
	waitForOwnGenerator()
end

return EssenceTickController
