--!strict
-- Controllers/ScoreFxController.luau (Architektura §3, kontroler #6) — "juice": popup na +score
-- i na wynik starcia. Architektura §5: RF return value to JEDYNE dopuszczalne miejsce na tego typu
-- detal (breakdown), RunStateSync nigdy go nie niesie -- dlatego ten kontroler NIE słucha
-- NetController.StateChanged, tylko dostaje PlayOutcome wprost od wołającego (HandController), zaraz
-- po udanym Invoke("PlayRunes"/"SwapRunes"/"EndEncounterVoluntary").

local TweenService = game:GetService("TweenService")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)

local ScoreFxController = {}

local _layer: ScreenGui

local function popup(text: string, color: Color3, yOffset: number)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0, 320, 0, 50)
	lbl.Position = UDim2.new(0.5, -160, 0.35, yOffset)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color
	lbl.Font = Enum.Font.GothamBlack
	lbl.TextScaled = true
	lbl.TextTransparency = 0
	lbl.Parent = _layer

	lbl.Size = UDim2.new(0, 40, 0, 10)
	local growTween = TweenService:Create(lbl, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 320, 0, 50),
	})
	growTween:Play()

	task.delay(0.6, function()
		local fadeTween = TweenService:Create(lbl, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
			TextTransparency = 1,
			Position = lbl.Position + UDim2.new(0, 0, 0, -30),
		})
		fadeTween:Play()
		fadeTween.Completed:Connect(function()
			lbl:Destroy()
		end)
	end)
end

-- Wołane przez HandController zaraz po udanym Invoke("PlayRunes"/"SwapRunes"/"EndEncounterVoluntary").
-- SwapRunes/EndEncounterVoluntary nie niosą scoreResult (nie liczą Zaklęcia) -- pomijamy tylko ten
-- popup, encounterResult (jeśli jest) i tak dostaje swój banner niżej.
function ScoreFxController.showPlayOutcome(outcome: { [string]: any }?)
	if not outcome or not outcome.ok then
		return
	end
	local scoreResult = outcome.scoreResult
	if scoreResult then
		local spellId = "?"
		for _, step in scoreResult.breakdown do
			if step.source == "spell" then
				spellId = step.id
				break
			end
		end
		popup(`{spellId}  +{math.floor(scoreResult.finalScore)}`, Color3.fromRGB(255, 220, 110), 0)
	end

	if outcome.encounterResult then
		task.delay(0.25, function()
			if outcome.encounterResult.won then
				popup(`ENCOUNTER CLEARED  +{outcome.encounterResult.baseGold + outcome.encounterResult.excessGold}g`, Color3.fromRGB(120, 230, 140), 40)
			else
				popup("ENCOUNTER FAILED", Color3.fromRGB(230, 90, 90), 40)
			end
		end)
	end
end

function ScoreFxController.Init() end

function ScoreFxController.Start()
	_layer = UIRootController.Get("ScoreFx")
end

return ScoreFxController
