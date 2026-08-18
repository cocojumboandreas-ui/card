--!nonstrict
-- ServerScriptService/Services/ProfileService.luau
-- Odpowiedzialnosc: ProfileStore (session-locking), load/release, dostep do danych profilu.
-- NIKT inny nie dotyka ProfileStore. profile==nil -> Kick (nigdy gra bez danych).
-- Port 1:1 wzorca z D:/RobloxProjects/rng/.../ProfileService.luau (Architektura §2: "Port 1:1 z
-- WAR RNG, z lekcją Bug 2B: cleanup przez ProfileReleasing, nie PlayerRemoving") — PROFILE_TEMPLATE
-- podmieniony na schemat Roll a Rune (Architektura §6, dosłownie).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Signal = require(Framework:WaitForChild("Signal"))
local ProfileStore = require(
	ServerScriptService:WaitForChild("Server"):WaitForChild("Vendor"):WaitForChild("ProfileStore")
)

local STORE_NAME = "RollARuneProfile_v1"

-- Architektura §6 — DOKLADNIE ten schemat. spendableNote celowo NIE jest kluczem (przypis w doku:
-- rezerwacja nazwy na przyszla druga walute-zakrecenia, "spendable vs lifetime NIE mieszac" —
-- Reconcile() dopisze klucz gdy powstanie realna funkcja, nie wczesniej).
local PROFILE_TEMPLATE = {
	essence = 0,
	totems = {}, -- ["totemId#variant"] = count (Faza 2b: kolekcja, IndexService)
	activeDeck = {}, -- MAX-SLOT: lista totemId (max GameConfig.DeckSize) zasilająca RunShopService.availableTotemPool;
	-- pusta = "jeszcze nie wybrana", DeckService.EnsureDefaultDeck wypełnia domyślnie przy pierwszym użyciu
	-- (migracja istniejących graczy: Reconcile() dopisuje pusty {}, a "pusty -> uzupełnij domyślnym" jest
	-- trwałym niezmiennikiem, nie jednorazową flagą)
	indexClaims = {}, -- claimed luck thresholds (Faza 2b)
	guardiansSeen = {}, -- bestiariusz Strażników
	skills = {}, -- [skillId] = rank (Faza 2b: SkillTreeService)
	lifetimeRolls = 0,
	lifetimeMerges = 0, -- System 3 (Merge/Craft): telemetria engagement, patrz MergeService
	lifetimeDisenchants = 0,
	pity = { sinceEpic = 0 },
	bestScores = { daily = {}, allTime = 0 }, -- daily: [dateKey] = score (walidacja anti-resubmit)
	quests = { dateKey = "", list = {} },
	streak = { count = 0, lastDateKey = "", claimed = {} }, -- claimed: [days]=true, D7/D14/D30 (StreakConfig)
	offlineTs = 0,
	ftueDone = false,
	purchases = { receipts = {} }, -- idempotencja ProcessReceipt
	settings = { autoSuggest = true, fxQuality = 2 },
}

local ProfileService = {}

local _store = nil
local _profiles: { [Player]: any } = {} -- player -> ProfileStore profile object (Data w .Data)

function ProfileService.Init()
	ProfileService.ProfileLoaded = Signal.new() -- (player, Profile) po udanym StartSessionAsync
	ProfileService.ProfileReleasing = Signal.new() -- (player, Profile) przed release
	_store = ProfileStore.New(STORE_NAME, PROFILE_TEMPLATE)
end

local function onPlayerAdded(player: Player)
	local profile = _store:StartSessionAsync(tostring(player.UserId), {
		-- ForceLoad-owe zachowanie StartSessionAsync + anulowanie gdy gracz wyszedl
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		player:Kick("[roll-a-rune] Failed to load your profile. Please try again.")
		return
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()

	profile.OnSessionEnd:Connect(function()
		_profiles[player] = nil
		player:Kick("[roll-a-rune] Profile released (session taken over by another server or closed).")
	end)

	if player.Parent == Players then
		_profiles[player] = profile
		ProfileService.ProfileLoaded:Fire(player, profile.Data)
	else
		profile:EndSession()
	end
end

local function onPlayerRemoving(player: Player)
	local profile = _profiles[player]
	if profile == nil then
		return
	end
	-- ostatni moment na zapis (np. offlineTs, snapshot innych serwisow) — PRZED EndSession,
	-- lekcja Bug 2B: haczyk musi wisieć na ProfileReleasing, nie na osobnym PlayerRemoving.
	ProfileService.ProfileReleasing:Fire(player, profile.Data)
	profile.Data.offlineTs = os.time()
	_profiles[player] = nil
	profile:EndSession()
end

function ProfileService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	-- gracze obecni zanim serwis wystartowal (load async -> ProfileLoaded odpali po startAll)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

-- Dane profilu (mutowalne) lub nil jesli jeszcze nie zaladowany.
function ProfileService.GetProfile(player: Player)
	local profile = _profiles[player]
	return profile ~= nil and profile.Data or nil
end

function ProfileService.IsLoaded(player: Player): boolean
	return _profiles[player] ~= nil
end

-- Hook TYLKO do testow akceptacyjnych (odczyt ksztaltu template bez ladowania DataStore).
function ProfileService._TemplateForTest()
	return PROFILE_TEMPLATE
end

return ProfileService
