--!strict
-- Controllers/UnderwaterBubblesController.luau — bąbelki sprzedające "jesteśmy pod wodą": ciągły
-- ambient z HumanoidRootPart (niski Rate, dryf w górę) + Emit() burst przy skoku (Humanoid.
-- StateChanged -> Jumping), żeby ruch gracza wizualnie "wzburzał" wodę. CharacterAdded, bo HRP
-- (i Attachment na nim) ginie razem z martwym modelem przy respawnie. Dodatkowo: pole ambientowych
-- bąbelków rozsianych po całej Plaza (niezależnych od gracza), losowe punkty na PlazaFloor, wolno
-- unoszą się w górę i znikają — czyste tło sprzedające "jesteśmy pod wodą" nawet gdy gracz stoi.
--
-- Tekstura: pusty Texture = "" -> domyślna wbudowana okrągła cząsteczka Robloxa (NIE Creator Store
-- rbxassetid -- Decal ID z search_assets to ID KATALOGOWE, nie to samo co realny content ID
-- obrazka; NIE smoke_main.dds -- działał, ale wygląda jak niewyraźna chmurka, nie bańka; pusty
-- Texture daje czysty okrągły kształt bez zależności od CDN).
-- Size 0.6-1.5 + nasycony cyan (140,220,255), NIE pastelowy blekit -- zweryfikowane zrzutami ekranu
-- z klienta: mała/jasna wersja TECHNICZNIE działała (particle się tworzył), ale zlewała się z
-- białymi butami postaci i jasną podłogą, więc potrzeba większego rozmiaru + kontrastowego koloru
-- niż "realistyczna" bańka, by faktycznie było widać podczas gry z normalnego dystansu kamery.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local UnderwaterBubblesController = {}

local BUBBLE_COLOR = Color3.fromRGB(140, 220, 255)
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
	ambient.Texture = ""
	ambient.Color = ColorSequence.new(BUBBLE_COLOR)
	ambient.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1.3),
	})
	ambient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	ambient.Lifetime = NumberRange.new(1.2, 2)
	ambient.Speed = NumberRange.new(2, 3.5)
	ambient.SpreadAngle = Vector2.new(25, 25)
	ambient.Acceleration = Vector3.new(0, 4, 0)
	ambient.Rate = 10
	ambient.Parent = attachment

	local burst = Instance.new("ParticleEmitter")
	burst.Texture = ""
	burst.Color = ColorSequence.new(BUBBLE_COLOR)
	burst.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 1.5),
	})
	burst.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
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

-- Pole ambientowych bąbelków na całej Plaza: losowe (x, z) w obrębie PlazaFloor, każdy punkt to
-- osobny niski Rate (rzadkie, niesynchronizowane pęcherzyki) + długi Lifetime (dryf daleko w górę
-- zanim spadnie Transparency=1), żeby czuć skalę mapy, nie tylko okolicę gracza.
local MAP_BUBBLE_SPOTS = 18
local MAP_INSET = 6 -- studów od krawędzi PlazaFloor, żeby nie wystawać poza platformę

local function spawnMapBubbles()
	local hub = Workspace:WaitForChild("Hub", 30)
	local plaza = hub and hub:WaitForChild("Plaza", 30)
	local floor = plaza and (plaza:WaitForChild("PlazaFloor", 30) :: BasePart?)
	if not floor then
		warn("[UnderwaterBubblesController] Workspace.Hub.Plaza.PlazaFloor nie znalezione po 30s — pomijam pole ambientowych bąbelków")
		return
	end

	-- PlazaFloor to obrócony slab (Size np. 8x96x96, cienki wymiar NIE jest na lokalnej osi Y) --
	-- Position.Y + Size.Y/2 daje złą wysokość. Raycast w dół z wysoka jest odporny na orientację.
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { floor }

	local halfX = math.max(floor.Size.X, floor.Size.Y, floor.Size.Z) / 2 - MAP_INSET
	local halfZ = halfX

	for i = 1, MAP_BUBBLE_SPOTS do
		local x = floor.Position.X + (math.random() * 2 - 1) * halfX
		local z = floor.Position.Z + (math.random() * 2 - 1) * halfZ

		local origin = Vector3.new(x, floor.Position.Y + 200, z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), rayParams)
		if not hit then
			continue
		end

		local carrier = Instance.new("Part")
		carrier.Name = "MapBubbleSpot"
		carrier.Anchored = true
		carrier.CanCollide = false
		carrier.CanQuery = false
		carrier.Transparency = 1
		carrier.Size = Vector3.new(1, 1, 1)
		carrier.Position = hit.Position + Vector3.new(0, 0.3, 0)
		carrier.Parent = Workspace

		local attachment = Instance.new("Attachment")
		attachment.Parent = carrier

		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = ""
		emitter.Color = ColorSequence.new(BUBBLE_COLOR)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 1.1),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Lifetime = NumberRange.new(4, 7)
		emitter.Speed = NumberRange.new(2, 4)
		emitter.SpreadAngle = Vector2.new(8, 8)
		emitter.Acceleration = Vector3.new(0, 2.5, 0)
		emitter.Rate = 0.15 + math.random() * 0.35
		emitter.Parent = attachment
	end
end

function UnderwaterBubblesController.Init() end

function UnderwaterBubblesController.Start()
	if player.Character then
		attach(player.Character)
	end
	player.CharacterAdded:Connect(attach)

	task.spawn(spawnMapBubbles)
end

return UnderwaterBubblesController
