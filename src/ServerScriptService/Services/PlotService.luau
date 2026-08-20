--!strict
-- ServerScriptService/Services/PlotService.luau (T2, pivot tycoon) — przydział plotów w siatce
-- (join -> wolny plot, leave -> zwolniony) + wypełnianie 10 slotów wystawowych z profile.plotSlots.
-- Wzorzec walidacji identyczny jak DeckService.SetDeck (odrzuć w całości, jawny reason) --
-- IsDiscovered z IndexService jest jedynym źródłem prawdy o posiadaniu, tak jak w DeckService.
--
-- Replikacja "za darmo" (Architektura-style): CardArt.Image / Frame.Color / atrybut
-- Frame.TotemId to zwykłe property/attribute-replication Roblox na instancjach pod Workspace --
-- inni gracze widzą wystawione karty bez osobnego eventu, klient odczytuje bieżący stan slotu
-- (atrybut) lokalnie zamiast dobijać się remotem.
--
-- PlotTemplate żyje w ServerStorage (T2: przeniesiony z ReplicatedStorage T1) -- klient nigdy nie
-- potrzebuje surowego template'u, tylko żywych klonów w Workspace.Plots, które i tak replikują.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))
local CardArtConfig = require(Shared:WaitForChild("CardArtConfig"))
local TierColorConfig = require(Shared:WaitForChild("TierColorConfig"))
local EssenceRateConfig = require(Shared:WaitForChild("EssenceRateConfig"))
local TierAuraConfig = require(Shared:WaitForChild("TierAuraConfig"))

local PlotService = {}

local SLOT_COUNT = 10
local GRID_COLS = 4
local GRID_SPACING = 100 -- footprint 64 + zapas
local GRID_BASE_X = -150
local GRID_BASE_Z = 250 -- offset od SpawnLocation(0,0.5,0), zero kolizji z domyślnym Baseplate
local PLOT_COUNT = 8 -- start N (Andreas: "start np. 6-12"), 4x2 siatka -- TYLKO fallback, patrz buildAnchorSlots

-- Gracz spawnuje NA swoim plocie (nie na domyslnym SpawnLocation w Hubie) -- lokalny offset od
-- PlotOrigin, kawalek za EntranceArch (Z=30, patrz PlotTemplate), patrzac w -Z czyli w glab plotu
-- (identyczna orientacja co CFrame.new() -- LookVector (0,0,-1) bez dodatkowej rotacji).
local SPAWN_LOCAL_OFFSET = CFrame.new(0, 3, 25)

type PlotSlot = { cframe: CFrame, showcase: Model?, showcaseHome: Instance? }

local _profileService = nil
local _indexService = nil
local _seedService = nil
local _template: Model? = nil
local _plotsFolder: Folder? = nil
local _hiddenShowcaseHolder: Folder? = nil

local _freeSlots: { PlotSlot } = {}
local _playerPlot: { [Player]: Model } = {}
local _playerSlot: { [Player]: PlotSlot } = {}

-- T5 (odwiedziny) — wypełnia Nameplate.SurfaceGui.PlayerName żywym stanem gracza. Property
-- replication "za darmo", ten sam wzorzec co CardArt.Image/Frame.Color w renderSlot.
local function renderNameplate(plotModel: Model, player: Player, likes: number)
	local nameplate = plotModel:FindFirstChild("Nameplate")
	local surfaceGui = nameplate and nameplate:FindFirstChild("SurfaceGui")
	local label = surfaceGui and surfaceGui:FindFirstChild("PlayerName")
	if label and label:IsA("TextLabel") then
		label.Text = `{player.DisplayName} \u{2764} {likes}`
	end
end

local function buildGridCFrames(): { CFrame }
	local list = {}
	for i = 1, PLOT_COUNT do
		local col = (i - 1) % GRID_COLS
		local row = math.floor((i - 1) / GRID_COLS)
		local x = GRID_BASE_X + col * GRID_SPACING
		local z = GRID_BASE_Z + row * GRID_SPACING
		table.insert(list, CFrame.new(x, 0, z))
	end
	return list
end

-- Reconciliacja z hub-buildem (STATUS.md "HUB/Swiat"): 8 autorskich kotwic w
-- Workspace.Hub.PlotAnchors.PlotAnchor1..8 (realne Party, zbudowane w edit-mode) niosą docelowy
-- CFrame (AnchorMarker, +Z już skierowane do centrum placu -- konwencja Nameplate z T1) i
-- opcjonalnie ShowcasePlot -- pomalowaną, statyczną geometrię plotu widoczną dopóki kotwica jest
-- wolna. Fallback na starą siatkę TYLKO gdy hub jeszcze nie istnieje w tym miejscu (np. świeże
-- Studio przed Ctrl+S hub-buildu) -- bez tego serwer wywaliłby się na starcie zamiast po prostu
-- degradować do starego zachowania.
local function buildAnchorSlots(): { PlotSlot }
	local hub = Workspace:FindFirstChild("Hub")
	local anchorsFolder = hub and hub:FindFirstChild("PlotAnchors")
	if not anchorsFolder then
		warn("[PlotService] Workspace.Hub.PlotAnchors brak -- fallback na starą siatkę 4x2")
		local list = {}
		for _, cf in buildGridCFrames() do
			table.insert(list, { cframe = cf, showcase = nil, showcaseHome = nil })
		end
		return list
	end

	local anchors = {}
	for _, child in anchorsFolder:GetChildren() do
		if child:IsA("Model") then
			table.insert(anchors, child)
		end
	end
	table.sort(anchors, function(a, b)
		return (a:GetAttribute("Index") or 0) < (b:GetAttribute("Index") or 0)
	end)

	local list = {}
	for _, anchorModel in anchors do
		local marker = anchorModel:FindFirstChild("AnchorMarker")
		if marker and marker:IsA("BasePart") then
			local showcase = anchorModel:FindFirstChild("ShowcasePlot")
			table.insert(list, { cframe = marker.CFrame, showcase = showcase, showcaseHome = anchorModel })
		end
	end
	return list
end

-- Ustawia wygląd JEDNEGO slotu na żywej instancji plotu. totemId=nil/"" -> stan pusty.
-- Karta jest wolnostojąca i DWUSTRONNA (POLISH kart v2, 2026-08-20: bez złotych ramek, bez ściany
-- za plecami) -- obraz ustawiany na obu SurfaceGui (Back=przód od strony gracza, Front=tył), aura
-- to PointLight+ParticleEmitter jadące z kartą (dzieci Frame) + AuraBeam/AuraGroundGlow zakotwiczone
-- w podłodze pod kartą (rodzeństwo CardFrame pod Slot{i}, NIE animują się razem z obrotem/lewitacją
-- -- światło-kolumna i świecący okrąg mają zostać na miejscu). CardArt/TotemId NIE zmienione co do
-- nazwy/ścieżki (poza dodatkiem SurfaceGuiFront), więc PlotController/EssenceTickController dalej
-- działają bez modyfikacji.
local function renderSlot(plotModel: Model, slotIndex: number, totemId: string?)
	local slotModel = plotModel:FindFirstChild("Slot" .. slotIndex)
	local cardFrame = slotModel and slotModel:FindFirstChild("CardFrame")
	local frame = cardFrame and cardFrame:FindFirstChild("Frame")
	local surfaceGuiBack = frame and frame:FindFirstChild("SurfaceGui")
	local cardArtBack = surfaceGuiBack and surfaceGuiBack:FindFirstChild("CardArt")
	local surfaceGuiFront = frame and frame:FindFirstChild("SurfaceGuiFront")
	local cardArtFront = surfaceGuiFront and surfaceGuiFront:FindFirstChild("CardArt")
	local light = frame and frame:FindFirstChild("AuraLight")
	local mount = frame and frame:FindFirstChild("AuraMount")
	local particles = mount and mount:FindFirstChild("AuraParticles")
	local rays = mount and mount:FindFirstChild("AuraRays")
	local beamAnchor = slotModel and slotModel:FindFirstChild("AuraBeamAnchor")
	local beam = beamAnchor and beamAnchor:FindFirstChild("AuraBeam")
	local beamTopAtt = beamAnchor and beamAnchor:FindFirstChild("BeamTop")
	local ground = slotModel and slotModel:FindFirstChild("AuraGroundGlow")
	if not (frame and cardArtBack) then
		return
	end

	-- Casty raz do lokalnych zmiennych: linia zaczynająca się od "(" po wyrażeniu kończącym się
	-- wywołaniem funkcji (np. TierColorConfig.tierColor(...)) to w Lua "ambiguous syntax" -- parser
	-- czyta to jako kontynuację tego samego wywołania, nie nową instrukcję.
	local frameInst = frame :: BasePart
	local cardArtBackLabel = cardArtBack :: ImageLabel
	local cardArtFrontLabel = cardArtFront :: ImageLabel?
	local lightInst = light :: PointLight?
	local particlesInst = particles :: ParticleEmitter?
	local raysInst = rays :: ParticleEmitter?
	local beamInst = beam :: Beam?
	local beamTopAttInst = beamTopAtt :: Attachment?
	local groundPart = ground :: BasePart?

	local totem = totemId and totemId ~= "" and TotemConfig.Totems[totemId] or nil
	if totem then
		local image = CardArtConfig.Images[totemId :: string] or ""
		cardArtBackLabel.Image = image
		if cardArtFrontLabel then
			cardArtFrontLabel.Image = image
		end
		local color = TierColorConfig.tierColor(totem.tier)
		frameInst.Color = color
		frameInst:SetAttribute("TotemId", totemId)

		local aura = TierAuraConfig.get(totem.tier)
		if aura then
			if lightInst then
				lightInst.Color = color
				lightInst.Brightness = aura.lightBrightness
				lightInst.Range = aura.lightRange
				lightInst.Enabled = true
			end
			if particlesInst then
				particlesInst.Color = ColorSequence.new(color)
				particlesInst.Rate = aura.particleRate
				particlesInst.Size = NumberSequence.new(aura.particleSize.Min, aura.particleSize.Max)
				particlesInst.Lifetime = aura.particleLifetime
				particlesInst.Speed = aura.particleSpeed
				particlesInst.SpreadAngle = aura.spreadAngle
				particlesInst.Enabled = aura.particleRate > 0
			end
			if raysInst then
				raysInst.Color = ColorSequence.new(color)
				raysInst.Enabled = aura.rays
			end
			if beamInst and beamTopAttInst then
				beamTopAttInst.Position = Vector3.new(0, math.max(aura.beamHeight, 0.05), 0)
				beamInst.Color = ColorSequence.new(color)
				beamInst.Width0 = aura.beamThickness * 3
				beamInst.Width1 = aura.beamThickness * 1.2
				beamInst.Enabled = aura.beamHeight > 0
			end
			if groundPart then
				local pos = groundPart.Position
				local thin = 0.12
				groundPart.Color = color
				groundPart.Size = Vector3.new(thin, aura.groundRadius, aura.groundRadius)
				groundPart.CFrame = CFrame.new(pos.X, thin / 2, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
				groundPart.Transparency = aura.groundTransparency
			end
		end
	else
		cardArtBackLabel.Image = ""
		if cardArtFrontLabel then
			cardArtFrontLabel.Image = ""
		end
		frameInst.Color = Color3.new(1, 1, 1)
		frameInst:SetAttribute("TotemId", "")

		if lightInst then
			lightInst.Enabled = false
		end
		if particlesInst then
			particlesInst.Enabled = false
		end
		if raysInst then
			raysInst.Enabled = false
		end
		if beamInst then
			beamInst.Enabled = false
		end
		if groundPart then
			groundPart.Transparency = 1
		end
	end
end

local function renderAllSlots(player: Player, plotModel: Model)
	local data = _profileService and _profileService.GetProfile(player)
	local slots = (data and data.plotSlots) or {}
	for i = 1, SLOT_COUNT do
		renderSlot(plotModel, i, slots[i])
	end
end

-- Teleportuje AKTUALNA postac gracza (jesli juz istnieje) na jego wlasny plot. Wolane zarowno z
-- allocatePlot (gracz zwykle spawnuje na domyslnym SpawnLocation ZANIM profil zdazy sie zaladowac
-- z DataStore) jak i z CharacterAdded (respawn po smierci/upadku ma trafiac z powrotem na plot,
-- nie do Huba).
local function relocateToPlot(player: Player)
	local slot = _playerSlot[player]
	local character = player.Character
	if not slot or not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	character:PivotTo(slot.cframe * SPAWN_LOCAL_OFFSET)
end

local function allocatePlot(player: Player)
	if not _template or not _plotsFolder then
		return
	end
	if _playerPlot[player] then
		return -- już ma plot (np. podwójny ProfileLoaded) -- idempotencja
	end
	-- table.remove(t) bez indeksu zdejmuje z KONCA (LIFO) -- pierwszy gracz dostawalby plot 8
	-- zamiast 1. table.remove(t, 1) zdejmuje z POCZATKU (FIFO), wiec wolne poloty przydzielane sa
	-- w kolejnosci Index 1..8 -- "lepszy" (nizszy numer) plot zawsze pierwszy.
	local slot = table.remove(_freeSlots, 1)
	if not slot then
		warn("[PlotService] brak wolnych plotów, gracz " .. player.Name .. " bez plotu")
		return
	end

	local clone = (_template :: Model):Clone()
	clone.Name = "Plot_" .. player.UserId
	clone:PivotTo(slot.cframe)
	clone:SetAttribute("OwnerUserId", player.UserId)
	clone.Parent = _plotsFolder

	-- Chowamy statyczną (pomalowaną) geometrię pod tą kotwicą zamiast ją niszczyć -- klon gracza
	-- stoi DOKŁADNIE w tym samym CFrame, więc zero podwójnej geometrii; po releasePlot showcase
	-- wraca na miejsce, więc hub nie "pustoszeje" przy wylogowaniu gracza.
	if slot.showcase then
		slot.showcase.Parent = _hiddenShowcaseHolder
	end

	_playerPlot[player] = clone
	_playerSlot[player] = slot
	renderAllSlots(player, clone)

	local data = _profileService and _profileService.GetProfile(player)
	renderNameplate(clone, player, (data and data.plotLikes) or 0)

	relocateToPlot(player)
end

local function releasePlot(player: Player)
	local plot = _playerPlot[player]
	if not plot then
		return
	end
	local slot = _playerSlot[player]
	plot:Destroy()
	_playerPlot[player] = nil
	_playerSlot[player] = nil

	if slot then
		if slot.showcase and slot.showcaseHome then
			slot.showcase.Parent = slot.showcaseHome
		end
		table.insert(_freeSlots, slot)
	end
end

-- Zapis serwer-autorytatywny jednego slotu. totemId=nil/"" czyści slot (zawsze dozwolone).
-- reason: NoProfile|BadSlot|BadArg|UnknownTotem|NotOwned.
function PlotService.SetPlotSlot(player: Player, slotIndex: any, totemId: any): { ok: boolean, reason: string? }
	local data = _profileService and _profileService.GetProfile(player)
	if not data then
		return { ok = false, reason = "NoProfile" }
	end
	if type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > SLOT_COUNT then
		return { ok = false, reason = "BadSlot" }
	end

	local clean: string? = nil
	if totemId ~= nil and totemId ~= "" then
		if type(totemId) ~= "string" then
			return { ok = false, reason = "BadArg" }
		end
		if not TotemConfig.Totems[totemId] then
			return { ok = false, reason = "UnknownTotem" }
		end
		if not (_indexService and _indexService.IsDiscovered(player, totemId)) then
			return { ok = false, reason = "NotOwned" }
		end
		clean = totemId
	end

	data.plotSlots = data.plotSlots or {}
	data.plotSlots[slotIndex] = clean -- JEDYNY zapis profile.plotSlots

	local plotModel = _playerPlot[player]
	if plotModel then
		renderSlot(plotModel, slotIndex, clean)
	end
	return { ok = true }
end

-- T5 (odwiedziny) — jawna akcja gościa "polub plot". Wzorzec walidacji jak SetPlotSlot: odrzuć w
-- całości, jawny reason. Limit raz/dzień per (liker, ownerUserId) trzymany na profilu LAJKUJĄCEGO
-- (data.plotLikesGiven) -- klucz dnia z SeedService.DailyKey, ten sam zaufany zegar serwera co
-- StreakService.TouchLogin, żeby nie dało się zalać lajków wielokrotnym klikiem/rejoinem tego
-- samego dnia. Licznik `plotLikes` żyje na profilu WŁAŚCICIELA -- bezpieczne bo plot (a więc i ta
-- funkcja) istnieje TYLKO gdy właściciel jest online (allocatePlot/releasePlot na
-- ProfileLoaded/ProfileReleasing), więc GetProfile(ownerPlayer) zawsze trafia w załadowany profil.
-- reason: NoProfile|SelfLike|NoPlot|AlreadyLiked.
function PlotService.LikePlot(liker: Player, ownerUserId: any): { ok: boolean, likes: number?, reason: string? }
	local likerData = _profileService and _profileService.GetProfile(liker)
	if not likerData then
		return { ok = false, reason = "NoProfile" }
	end
	if type(ownerUserId) ~= "number" then
		return { ok = false, reason = "NoPlot" }
	end
	if ownerUserId == liker.UserId then
		return { ok = false, reason = "SelfLike" }
	end

	local ownerPlayer = Players:GetPlayerByUserId(ownerUserId)
	local ownerPlot = ownerPlayer and _playerPlot[ownerPlayer]
	local ownerData = ownerPlayer and _profileService and _profileService.GetProfile(ownerPlayer)
	if not (ownerPlayer and ownerPlot and ownerData) then
		return { ok = false, reason = "NoPlot" }
	end

	local todayKey = _seedService.DailyKey(os.time())
	likerData.plotLikesGiven = likerData.plotLikesGiven or {}
	local key = tostring(ownerUserId)
	if likerData.plotLikesGiven[key] == todayKey then
		return { ok = false, reason = "AlreadyLiked" }
	end
	likerData.plotLikesGiven[key] = todayKey -- JEDYNY zapis profile.plotLikesGiven

	ownerData.plotLikes = (ownerData.plotLikes or 0) + 1 -- JEDYNY zapis profile.plotLikes
	renderNameplate(ownerPlot, ownerPlayer, ownerData.plotLikes)

	return { ok = true, likes = ownerData.plotLikes }
end

-- T3 (pasywna esencja): suma stawek esencja/sek wszystkich wystawionych kart (pusty slot = brak
-- wpisu = 0). Pure, testowalna bez profilu/instancji -- czyta WYŁĄCZNIE TotemConfig +
-- EssenceRateConfig, żeby EssenceTickService (online) i OfflineEarnService (offline) liczyły
-- zawsze z tej samej stawki, nigdy dwóch rozjeżdżających się kopii.
function PlotService.RatePerSecond(plotSlots: { [number]: string? }): number
	local total = 0
	for _, totemId in pairs(plotSlots or {}) do
		local totem = totemId and totemId ~= "" and TotemConfig.Totems[totemId :: string]
		if totem then
			total += EssenceRateConfig.tierRatePerSecond(totem.tier)
		end
	end
	return total
end

-- Żywa instancja plotu gracza (Workspace.Plots.Plot_<id>) lub nil -- używane przez
-- EssenceTickService do ustawienia atrybutu juice na EssenceGenerator.
function PlotService.GetPlotModel(player: Player): Model?
	return _playerPlot[player]
end

function PlotService.Init() end

function PlotService.Start()
	_profileService = ServiceRegistry.get("ProfileService")
	_indexService = ServiceRegistry.get("IndexService")
	_seedService = ServiceRegistry.get("SeedService")

	_template = ServerStorage:WaitForChild("PlotTemplate") :: Model
	_plotsFolder = Workspace:FindFirstChild("Plots") :: Folder?
	if not _plotsFolder then
		local f = Instance.new("Folder")
		f.Name = "Plots"
		f.Parent = Workspace
		_plotsFolder = f
	end

	_hiddenShowcaseHolder = ServerStorage:FindFirstChild("HiddenShowcases") :: Folder?
	if not _hiddenShowcaseHolder then
		local f = Instance.new("Folder")
		f.Name = "HiddenShowcases"
		f.Parent = ServerStorage
		_hiddenShowcaseHolder = f
	end

	_freeSlots = buildAnchorSlots()

	_profileService.ProfileLoaded:Connect(function(player: Player)
		allocatePlot(player)
	end)
	_profileService.ProfileReleasing:Connect(function(player: Player)
		releasePlot(player)
	end)

	-- CharacterAdded pokrywa dwa przypadki ktorych allocatePlot->relocateToPlot nie zlapie:
	-- respawn po smierci/upadku (ma wracac na WLASNY plot, nie do domyslnego SpawnLocation w
	-- Hubie) oraz rzadki wyscig gdzie postac spawnuje sie PO przydziale plotu.
	local function hookCharacterAdded(player: Player)
		player.CharacterAdded:Connect(function()
			relocateToPlot(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		hookCharacterAdded(player)
	end
	Players.PlayerAdded:Connect(hookCharacterAdded)

	Net.get("GetMyPlot").OnServerInvoke = function(player: Player)
		local plot = _playerPlot[player]
		return { ok = plot ~= nil, plotModel = plot }
	end

	Net.get("SetPlotSlot").OnServerInvoke = function(player: Player, slotIndex: any, totemId: any)
		return PlotService.SetPlotSlot(player, slotIndex, totemId)
	end

	Net.get("LikePlot").OnServerInvoke = function(player: Player, ownerUserId: any)
		return PlotService.LikePlot(player, ownerUserId)
	end
end

-- Hooki TYLKO do testów (wzorzec DeckService._SetProfileServiceForTest).
function PlotService._SetProfileServiceForTest(fake)
	_profileService = fake
end

function PlotService._SetIndexServiceForTest(fake)
	_indexService = fake
end

function PlotService._SetSeedServiceForTest(fake)
	_seedService = fake
end

return PlotService
