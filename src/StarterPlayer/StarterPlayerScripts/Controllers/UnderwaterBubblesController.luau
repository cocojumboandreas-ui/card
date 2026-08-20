--!strict
-- Controllers/UnderwaterBubblesController.luau — bąbelki sprzedające "jesteśmy pod wodą": ciągły
-- ambient z HumanoidRootPart (niski Rate, dryf w górę) + Emit() burst przy skoku (Humanoid.
-- StateChanged -> Jumping), żeby ruch gracza wizualnie "wzburzał" wodę. CharacterAdded, bo HRP
-- (i Attachment na nim) ginie razem z martwym modelem przy respawnie.

local Players = game:GetService("Players")

local UnderwaterBubblesController = {}

local BUBBLE_TEXTURE = "rbxassetid://117929489069196"
local player = Players.LocalPlayer

local function attach(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hrp or not humanoid then
		return
	end

	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -2, 0)
	attachment.Parent = hrp

	local ambient = Instance.new("ParticleEmitter")
	ambient.Texture = BUBBLE_TEXTURE
	ambient.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	ambient.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 0.35),
	})
	ambient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	ambient.Lifetime = NumberRange.new(1.2, 2)
	ambient.Speed = NumberRange.new(2, 3.5)
	ambient.SpreadAngle = Vector2.new(25, 25)
	ambient.Acceleration = Vector3.new(0, 4, 0)
	ambient.Rate = 6
	ambient.Parent = attachment

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = BUBBLE_TEXTURE
	burst.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	burst.Lifetime = NumberRange.new(0.6, 1)
	burst.Speed = NumberRange.new(6, 10)
	burst.SpreadAngle = Vector2.new(50, 50)
	burst.Acceleration = Vector3.new(0, 6, 0)
	burst.Rate = 0
	burst.Parent = attachment

	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			burst:Emit(18)
		end
	end)
end

function UnderwaterBubblesController.Init() end

function UnderwaterBubblesController.Start()
	if player.Character then
		attach(player.Character)
	end
	player.CharacterAdded:Connect(attach)
end

return UnderwaterBubblesController
