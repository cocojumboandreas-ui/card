--!strict
-- Controllers/CardDisplayController.luau — POLISH displayów kart (2026-08-20): powolny obrót wokół
-- Y + delikatna lewitacja góra-dół dla każdego CardFrame na plocie (własnym i cudzych, Workspace.Plots
-- to zwykły globalny Folder, replikuje się bez remote'u -- ten sam "za darmo" wzorzec co reszta T2).
--
-- Wzorzec 1:1 z ConveyorArrowsController: tag CollectionService ("CardDisplay", dołożony do
-- CardFrame w PlotTemplate) + kilka prób WaitForChild/zbierania z odstępem (replikacja tagów to
-- osobny kanał niż replikacja instancji -- pierwsza próba potrafi zobaczyć 0 kart mimo że
-- Workspace.Plots już istnieje). CardFrame ma PrimaryPart=Frame, więc PivotTo() rusza kartę (Frame,
-- oba SurfaceGui) -- AuraLight/AuraMount/AuraParticles/AuraRays są dziećmi Frame, więc aura jedzie
-- z kartą za darmo, bez osobnego animowania. AuraBeam/AuraGroundGlow (v2) są rodzeństwem CardFrame
-- pod Slot{i}, NIE Frame, więc świadomie NIE animują się tym kontrolerem -- zostają zakotwiczone w
-- podłodze.
--
-- Nowe plot-klony (Workspace.Plots.ChildAdded) są dogrywane na bieżąco -- gracze dołączają długo po
-- Start(), a każdy ma własnych 10 slotów do podpięcia.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CardDisplayController = {}

local SPIN_SPEED = math.rad(12) -- rad/s, pełny obrót ~30s
local BOB_AMPLITUDE = 0.35
local BOB_PERIOD = 4.2 -- sekundy na pełny cykl góra-dół

type Card = {
	model: Model,
	basePos: Vector3,
	baseLook: Vector3,
	phase: number,
}

local _cards: { Card } = {}
local _known: { [Model]: boolean } = {}
local _t = 0

local function trackCardFrame(cardFrame: Instance)
	if not cardFrame:IsA("Model") then
		return
	end
	local model = cardFrame :: Model
	if _known[model] then
		return
	end
	local frame = model:FindFirstChild("Frame")
	if not (frame and frame:IsA("BasePart")) then
		return
	end
	_known[model] = true
	local basePivot = model:GetPivot()
	table.insert(_cards, {
		model = model,
		basePos = basePivot.Position,
		baseLook = basePivot.LookVector,
		phase = (basePivot.Position.X + basePivot.Position.Z) * 0.37, -- rozjazd fazy bob między kartami
	})
end

local function collectExisting()
	for _, inst in ipairs(CollectionService:GetTagged("CardDisplay")) do
		trackCardFrame(inst)
	end
end

function CardDisplayController.Init() end

function CardDisplayController.Start()
	task.spawn(function()
		local plots = Workspace:WaitForChild("Plots", 30)
		if not plots then
			warn("[CardDisplayController] Workspace.Plots brak po 30s -- pomijam animację kart")
			return
		end

		for attempt = 1, 10 do
			collectExisting()
			if #_cards > 0 then
				break
			end
			task.wait(0.5)
		end
		if #_cards == 0 then
			warn("[CardDisplayController] 0 kart z tagiem CardDisplay po 10 próbach -- pomijam animację")
		end

		CollectionService:GetInstanceAddedSignal("CardDisplay"):Connect(trackCardFrame)

		RunService.Heartbeat:Connect(function(dt: number)
			_t += dt
			for _, card in ipairs(_cards) do
				local spinAngle = _t * SPIN_SPEED
				local bob = math.sin((_t / BOB_PERIOD) * math.pi * 2 + card.phase) * BOB_AMPLITUDE
				local rotatedLook = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), spinAngle) * card.baseLook)
				local pos = card.basePos + Vector3.new(0, bob, 0)
				card.model:PivotTo(CFrame.lookAt(pos, pos + rotatedLook, Vector3.new(0, 1, 0)))
			end
		end)
	end)
end

return CardDisplayController
