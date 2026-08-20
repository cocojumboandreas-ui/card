--!strict
-- Controllers/ConveyorArrowsController.luau — strzałki-chevrony na pasach Hub.Walkways (Lane*_*_Walk).
--
-- UWAGA: Texture (Decal) na pasach NIE renderuje się w tej sesji Studio -- ten sam objaw co
-- ParticleEmitter w UnderwaterBubblesController (zweryfikowane: naprawiony asset ID, wciąż pusty
-- czarny pas na zrzucie). Zamiast gonić przyczynę (asset streaming poza naszą kontrolą), strzałki
-- to zwykłe geometryczne chevrony (2 cienkie Party na marker, kształt ">"), które renderują się
-- niezależnie od pobierania assetów. Ruch "taśmy" symulowany przesuwaniem markerów wzdłuż pasa
-- z zawijaniem (wrap) zamiast animacji OffsetStudsU tekstury.
--
-- Kierunek/prędkość: ta sama lokalna oś X pasa = kierunek jazdy (patrz ConveyorDriver +
-- dziewiętnasty przebieg), ten sam tag "ConveyorVisual" co dawny TapeAnimator (Walk-party).
-- Kierunek per-pas brany z odpowiadającego "*_Sensor" (atrybut ConveyorDir, już poprawnie
-- wyliczony z uwzględnieniem Out/Back) zamiast zgadywania znaku z samego CFrame Walk-a.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ConveyorArrowsController = {}

local CHEVRON_COLOR = Color3.fromRGB(255, 214, 64)
local MARKERS_PER_LANE = 4
local ARM_LEN = 2.4
local ARM_ANGLE = math.rad(28)
local EDGE_PAD = 2.5

type Lane = {
	center: Vector3,
	forward: Vector3,
	right: Vector3,
	up: Vector3,
	halfSpan: number,
	speed: number,
}

type Marker = {
	lane: Lane,
	s: number,
	armL: BasePart,
	armR: BasePart,
}

local function buildArm(length: number, cf: CFrame, parent: Instance): BasePart
	local arm = Instance.new("Part")
	arm.Name = "ChevronArm"
	arm.Size = Vector3.new(length, 0.18, 0.4)
	arm.CFrame = cf
	arm.Anchored = true
	arm.CanCollide = false
	arm.CanQuery = false
	arm.CastShadow = false
	arm.Material = Enum.Material.Neon
	arm.Color = CHEVRON_COLOR
	arm.Parent = parent
	return arm
end

local function armCFrame(tip: Vector3, dir: Vector3, up: Vector3, length: number): CFrame
	local rightVec = dir
	local upVec = (up - up:Dot(rightVec) * rightVec)
	if upVec.Magnitude < 0.001 then
		upVec = Vector3.new(0, 1, 0)
	else
		upVec = upVec.Unit
	end
	local lookVec = rightVec:Cross(upVec).Unit
	local mid = tip - rightVec * (length / 2)
	return CFrame.fromMatrix(mid, rightVec, upVec, lookVec)
end

local function spawnMarker(lane: Lane, s: number, folder: Instance): Marker
	local up = lane.up
	local cosA, sinA = math.cos(ARM_ANGLE), math.sin(ARM_ANGLE)
	local armDirL = (lane.forward * cosA + lane.right * sinA).Unit
	local armDirR = (lane.forward * cosA - lane.right * sinA).Unit
	local tip = lane.center + lane.forward * s

	local armL = buildArm(ARM_LEN, armCFrame(tip, armDirL, up, ARM_LEN), folder)
	local armR = buildArm(ARM_LEN, armCFrame(tip, armDirR, up, ARM_LEN), folder)

	return { lane = lane, s = s, armL = armL, armR = armR }
end

local function updateMarker(marker: Marker)
	local lane = marker.lane
	local up = lane.up
	local cosA, sinA = math.cos(ARM_ANGLE), math.sin(ARM_ANGLE)
	local armDirL = (lane.forward * cosA + lane.right * sinA).Unit
	local armDirR = (lane.forward * cosA - lane.right * sinA).Unit
	local tip = lane.center + lane.forward * marker.s

	marker.armL.CFrame = armCFrame(tip, armDirL, up, ARM_LEN)
	marker.armR.CFrame = armCFrame(tip, armDirR, up, ARM_LEN)
end

local function collectLanes(): { Lane }
	local wk = Workspace:WaitForChild("Hub", 30) and Workspace.Hub:WaitForChild("Walkways", 30)
	if not wk then
		warn("[ConveyorArrowsController] Workspace.Hub.Walkways nie znalezione po 30s — pomijam strzałki")
		return {}
	end

	local lanes: { Lane } = {}
	for _, walk in ipairs(wk:GetChildren()) do
		if walk:IsA("BasePart") and CollectionService:HasTag(walk, "ConveyorVisual") then
			local sensorName = (walk.Name:gsub("_Walk$", "_Sensor"))
			local sensor = wk:FindFirstChild(sensorName)
			local dirAttr = sensor and sensor:GetAttribute("ConveyorDir")
			local speedAttr = sensor and sensor:GetAttribute("ConveyorSpeed")
			local forward: Vector3
			if typeof(dirAttr) == "Vector3" and dirAttr.Magnitude > 0.01 then
				forward = dirAttr.Unit
			else
				forward = walk.CFrame.RightVector
			end
			local up = Vector3.new(0, 1, 0)
			local right = up:Cross(forward).Unit
			table.insert(lanes, {
				center = walk.Position,
				forward = forward,
				right = right,
				up = up,
				halfSpan = walk.Size.X / 2 - EDGE_PAD,
				speed = (typeof(speedAttr) == "number" and speedAttr) or 22,
			})
		end
	end
	return lanes
end

function ConveyorArrowsController.Init() end

function ConveyorArrowsController.Start()
	task.spawn(function()
		-- WaitForChild(Hub/Walkways) gwarantuje istnienie Partow, ale NIE gwarantuje ze tagi
		-- CollectionService juz zreplikowaly sie na klienta w tym samym momencie (osobny kanal
		-- replikacji) -- pierwsza probka potrafi zobaczyc 0 polaczonych lane'ow mimo ze Party i
		-- Walkways juz istnieja (zweryfikowane: hub=true walkways=true folder=false po 5s przy
		-- automatycznym boot Start(), a reczne ponowne wywolanie identycznego kodu zawsze dzialalo).
		-- Zamiast poddawac sie po jednej probie, dobijamy kilka razy z odstepem.
		local lanes: { Lane } = {}
		for attempt = 1, 10 do
			lanes = collectLanes()
			if #lanes > 0 then
				break
			end
			task.wait(0.5)
		end
		if #lanes == 0 then
			warn("[ConveyorArrowsController] 0 lane'ow z tagiem ConveyorVisual po 10 probach — pomijam strzałki")
			return
		end

		local folder = Instance.new("Folder")
		folder.Name = "ConveyorArrowsFX"
		folder.Parent = Workspace

		local markers: { Marker } = {}
		for _, lane in ipairs(lanes) do
			local span = lane.halfSpan * 2
			for i = 0, MARKERS_PER_LANE - 1 do
				local s = -lane.halfSpan + (span * i / MARKERS_PER_LANE)
				table.insert(markers, spawnMarker(lane, s, folder))
			end
		end

		local accum = 0
		RunService.Heartbeat:Connect(function(dt: number)
			accum += dt
			if accum < 0.03 then
				return
			end
			local step = accum
			accum = 0
			for _, marker in ipairs(markers) do
				marker.s += marker.lane.speed * step
				if marker.s > marker.lane.halfSpan then
					marker.s -= marker.lane.halfSpan * 2
				end
				updateMarker(marker)
			end
		end)
	end)
end

return ConveyorArrowsController
