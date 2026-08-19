--!strict
-- ServerScriptService/Services/PlotService.luau (T2, pivot tycoon) — przydział plotów w siatce
-- (join -> wolny plot, leave -> zwolniony) + wypełnianie 10 slotów wystawowych z profile.plotSlots.
-- Wzorzec walidacji identyczny jak DeckService.SetDeck (odrzuć w całości, jawny reason) --
-- IsDiscovered z IndexService jest jedynym źródłem prawdy o posiadaniu, tak jak w DeckService.
--
-- Replikacja "za darmo" (Architektura-style): CardArt.Image / RarityBorder.Color3 / atrybut
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

local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))
local CardArtConfig = require(Shared:WaitForChild("CardArtConfig"))
local TierColorConfig = require(Shared:WaitForChild("TierColorConfig"))
local EssenceRateConfig = require(Shared:WaitForChild("EssenceRateConfig"))

local PlotService = {}

local SLOT_COUNT = 10
local GRID_COLS = 4
local GRID_SPACING = 100 -- footprint 64 + zapas
local GRID_BASE_X = -150
local GRID_BASE_Z = 250 -- offset od SpawnLocation(0,0.5,0), zero kolizji z domyślnym Baseplate
local PLOT_COUNT = 8 -- start N (Andreas: "start np. 6-12"), 4x2 siatka

local EMPTY_BORDER_COLOR = Color3.fromRGB(120, 120, 125) -- przygaszony placeholder, pusty slot

local _profileService = nil
local _indexService = nil
local _template: Model? = nil
local _plotsFolder: Folder? = nil

local _freeCFrames: { CFrame } = {}
local _playerPlot: { [Player]: Model } = {}

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

-- Ustawia wygląd JEDNEGO slotu na żywej instancji plotu. totemId=nil/"" -> stan pusty.
local function renderSlot(plotModel: Model, slotIndex: number, totemId: string?)
	local slotModel = plotModel:FindFirstChild("Slot" .. slotIndex)
	local cardFrame = slotModel and slotModel:FindFirstChild("CardFrame")
	local frame = cardFrame and cardFrame:FindFirstChild("Frame")
	local border = cardFrame and cardFrame:FindFirstChild("RarityBorder")
	local surfaceGui = frame and frame:FindFirstChild("SurfaceGui")
	local cardArt = surfaceGui and surfaceGui:FindFirstChild("CardArt")
	if not (frame and border and cardArt) then
		return
	end

	-- Casty raz do lokalnych zmiennych: linia zaczynająca się od "(" po wyrażeniu kończącym się
	-- wywołaniem funkcji (np. TierColorConfig.tierColor(...)) to w Lua "ambiguous syntax" -- parser
	-- czyta to jako kontynuację tego samego wywołania, nie nową instrukcję.
	local frameInst = frame :: Instance
	local borderPart = border :: BasePart
	local cardArtLabel = cardArt :: ImageLabel

	local totem = totemId and totemId ~= "" and TotemConfig.Totems[totemId] or nil
	if totem then
		cardArtLabel.Image = CardArtConfig.Images[totemId :: string] or ""
		borderPart.Color = TierColorConfig.tierColor(totem.tier)
		frameInst:SetAttribute("TotemId", totemId)
	else
		cardArtLabel.Image = ""
		borderPart.Color = EMPTY_BORDER_COLOR
		frameInst:SetAttribute("TotemId", "")
	end
end

local function renderAllSlots(player: Player, plotModel: Model)
	local data = _profileService and _profileService.GetProfile(player)
	local slots = (data and data.plotSlots) or {}
	for i = 1, SLOT_COUNT do
		renderSlot(plotModel, i, slots[i])
	end
end

local function allocatePlot(player: Player)
	if not _template or not _plotsFolder then
		return
	end
	if _playerPlot[player] then
		return -- już ma plot (np. podwójny ProfileLoaded) -- idempotencja
	end
	local cf = table.remove(_freeCFrames)
	if not cf then
		warn("[PlotService] brak wolnych plotów (PLOT_COUNT=" .. PLOT_COUNT .. "), gracz " .. player.Name .. " bez plotu")
		return
	end

	local clone = (_template :: Model):Clone()
	clone.Name = "Plot_" .. player.UserId
	clone:PivotTo(cf)
	clone:SetAttribute("OwnerUserId", player.UserId)
	clone.Parent = _plotsFolder

	_playerPlot[player] = clone
	renderAllSlots(player, clone)
end

local function releasePlot(player: Player)
	local plot = _playerPlot[player]
	if not plot then
		return
	end
	table.insert(_freeCFrames, plot:GetPivot())
	plot:Destroy()
	_playerPlot[player] = nil
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

	_template = ServerStorage:WaitForChild("PlotTemplate") :: Model
	_plotsFolder = Workspace:FindFirstChild("Plots") :: Folder?
	if not _plotsFolder then
		local f = Instance.new("Folder")
		f.Name = "Plots"
		f.Parent = Workspace
		_plotsFolder = f
	end

	_freeCFrames = buildGridCFrames()

	_profileService.ProfileLoaded:Connect(function(player: Player)
		allocatePlot(player)
	end)
	_profileService.ProfileReleasing:Connect(function(player: Player)
		releasePlot(player)
	end)

	Net.get("GetMyPlot").OnServerInvoke = function(player: Player)
		local plot = _playerPlot[player]
		return { ok = plot ~= nil, plotModel = plot }
	end

	Net.get("SetPlotSlot").OnServerInvoke = function(player: Player, slotIndex: any, totemId: any)
		return PlotService.SetPlotSlot(player, slotIndex, totemId)
	end
end

-- Hooki TYLKO do testów (wzorzec DeckService._SetProfileServiceForTest).
function PlotService._SetProfileServiceForTest(fake)
	_profileService = fake
end

function PlotService._SetIndexServiceForTest(fake)
	_indexService = fake
end

return PlotService
