--!strict
-- Controllers/UnderwaterBubblesController.luau — bąbelki sprzedające "jesteśmy pod wodą".
--
-- UWAGA: ParticleEmitter nie renderowal sie WCALE w tej sesji Studio (zweryfikowane: nawet
-- ogromny czerwony 3-studowy Emit() 5 studow przed kamera byl niewidoczny, podczas gdy Fire
-- na tym samym Part renderowal sie normalnie) -- zamiast dalej gonic przyczyne (silnik/ustawienie
-- Studio poza nasza kontrola), bąbelki to zwykle klonowane Party (Shape=Ball), ktore na 100%
-- renderuja sie tak samo jak kazdy inny Part w grze. Ruch (dryf w gore + zanikanie) sterowany
-- reczna petla task.spawn zamiast wlasciwosci ParticleEmittera.
--
-- Zrodlo przy postaci: throttled Heartbeat, nie eventy -- Humanoid:GetState() sprawdzany co klatke
-- (chodzenie = MoveDirection>0 i nie w powietrzu, w locie = Jumping/Freefall), bo to jeden prosty
-- warunek zamiast zylowania StateChanged+Running osobno. CharacterAdded, bo HRP ginie z martwym
-- modelem przy respawnie.
--
-- Pole mapowe: te same bąbelki-Party, losowe punkty na PlazaFloor (raycast w dol, bo floor to
-- obrocony slab -- Position.Y+Size.Y/2 dawalby zla wysokosc, patrz komentarz w spawnMapBubbles).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local UnderwaterBubblesController = {}

local BUBBLE_COLOR = Color3.fromRGB(140, 220, 255)
local player = Players.LocalPlayer

local function spawnBubble(origin: Vector3, sizeMin: number, sizeMax: number, riseMin: number, riseMax: number, lifeMin: number, lifeMax: number)
	local b = Instance.new("Part")
	b.Name = "Bubble"
	b.Shape = Enum.PartType.Ball
	b.Material = Enum.Material.Neon
	b.Color = BUBBLE_COLOR
	local size = sizeMin + math.random() * (sizeMax - sizeMin)
	b.Size = Vector3.new(size, size, size)
	b.Transparency = 0.1
	b.CanCollide = false
	b.CanQuery = false
	b.CastShadow = false
	b.Anchored = true
	b.Position = origin + Vector3.new((math.random() * 2 - 1) * 0.6, 0, (math.random() * 2 - 1) * 0.6)
	b.Parent = Workspace

	task.spawn(function()
		local duration = lifeMin + math.random() * (lifeMax - lifeMin)
		local riseSpeed = riseMin + math.random() * (riseMax - riseMin)
		local driftX = (math.random() * 2 - 1) * 0.6
		local driftZ = (math.random() * 2 - 1) * 0.6
		local elapsed = 0
		while elapsed < duration and b.Parent do
			local dt = task.wait(0.05)
			elapsed += dt
			b.Position += Vector3.new(driftX * dt, riseSpeed * dt, driftZ * dt)
			b.Transparency = 0.1 + (elapsed / duration) * 0.9
		end
		b:Destroy()
	end)
end

local function attach(character: Model)
	local hrp = character:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hrp or not humanoid then
		return
	end

	local walkAccum = 0
	local airAccum = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		if not character.Parent or not hrp.Parent then
			conn:Disconnect()
			return
		end

		local feet = hrp.Position - Vector3.new(0, hrp.Size.Y / 2 + 1, 0)
		local state = humanoid:GetState()
		local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall

		if airborne then
			airAccum += dt
			if airAccum >= 0.07 then
				airAccum = 0
				spawnBubble(feet, 0.7, 1.4, 3, 5, 0.7, 1.2)
			end
		else
			airAccum = 0
			if humanoid.MoveDirection.Magnitude > 0.1 then
				walkAccum += dt
				if walkAccum >= 0.16 then
					walkAccum = 0
					spawnBubble(feet, 0.5, 1, 2, 3.2, 0.6, 1)
				end
			else
				walkAccum = 0
			end
		end
	end)
end

-- Pole ambientowych bąbelków na całej Plaza: losowe (x, z) w obrębie PlazaFloor, raz wyliczone
-- (raycast pod katem orientacji Partu), potem petla co ~0.4s stawia bąbelek na losowym punkcie.
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

	local half = math.max(floor.Size.X, floor.Size.Y, floor.Size.Z) / 2 - MAP_INSET

	local spots: { Vector3 } = {}
	for _ = 1, MAP_BUBBLE_SPOTS do
		local x = floor.Position.X + (math.random() * 2 - 1) * half
		local z = floor.Position.Z + (math.random() * 2 - 1) * half
		local origin = Vector3.new(x, floor.Position.Y + 200, z)
		local hit = Workspace:Raycast(origin, Vector3.new(0, -400, 0), rayParams)
		if hit then
			table.insert(spots, hit.Position + Vector3.new(0, 0.3, 0))
		end
	end

	if #spots == 0 then
		warn("[UnderwaterBubblesController] raycast nie trafil PlazaFloor ani razu — pomijam pole ambientowych bąbelków")
		return
	end

	while true do
		local spot = spots[math.random(1, #spots)]
		spawnBubble(spot, 0.7, 1.4, 2, 3.5, 4, 7)
		task.wait(0.3 + math.random() * 0.3)
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
