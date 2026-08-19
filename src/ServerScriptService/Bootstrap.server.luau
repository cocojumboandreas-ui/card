--!strict
-- ServerScriptService/Bootstrap.server.luau — bootstrap ServiceRegistry (Architektura §1: "Z
-- PCALL — lekcja z audytu RNG!" — patrz Framework/ServiceRegistry.luau dla mechanizmu izolacji).
-- Kolejność rejestracji = kolejność Init/Start (Architektura §2 tabela serwisów).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Services = ServerScriptService:WaitForChild("Services")

-- ProfileService -> StatProfileService -> EconomyService -> IndexService -> RollService ->
-- RunSessionService -> PlayService -> RunShopService (Faza 2a + 2b). IndexService/RollService
-- wstawione PRZED RunSessionService (Architektura §2: RollService/IndexService żyją POZA runem,
-- nic z runu ich nie potrzebuje przy starcie) -- kolejność register() nie wpływa na
-- ServiceRegistry.get() (wszystkie zarejestrowane PRZED initAll/startAll), ale trzymamy ją zgodną z
-- grafem zależności dla czytelności.
local ORDER = {
	"ProfileService",
	"StatProfileService",
	"EconomyService",
	"PurchaseService", -- Faza 4 Krok 2: ProcessReceipt + gamepass cache, zależy od Profile/Economy/Stat
	"PolicyService", -- Faza 4 Krok 4: tabela szans (compliance), zero zależności, cienki config-reader
	"FtueService", -- Faza 4 Krok 5: push/odbior flagi ftueDone, zależy tylko od Profile
	"OfflineEarnService", -- Faza 3: zależy tylko od Profile/Stat/Economy, zero zależności od runu
	"IndexService",
	"PlotService", -- T2 (pivot tycoon): przydział plotów + wypełnianie slotów, zależy tylko na odczyt (get) ProfileService/IndexService, poza-runowa meta jak Deck
	"EssenceTickService", -- T3 (pasywna esencja): online tyk z PlotService.RatePerSecond, zależy tylko na odczyt (get) Profile/Economy/Plot
	"DeckService", -- MAX-SLOT: GetDeck/SetDeck, zależy tylko na odczyt (get) ProfileService/IndexService, wymagany PRZED RunShopService
	"RollService",
	"MergeService", -- System 3: merge/disenchant kolekcji, zależy na odczyt (get) Profile/Economy/Index, poza-runowa meta jak Roll
	"PackService", -- T4: paczki Mega/Super/Legend, zależy na odczyt (get) Profile/Economy/Index/Purchase/Roll, poza-runowa meta jak Merge
	"SeedService", -- Faza 3: czysta funkcja, zero zależności; PRZED RunSessionService (użyty w startRun)
	"RunSessionService",
	"PlayService",
	"RunShopService",
	"LeaderboardService", -- Faza 3: nasłuch RunSessionService.RunEnded, zależy tylko na odczyt (get)
	"StreakService", -- Faza 3: nasłuch ProfileService.ProfileLoaded, zależy tylko na odczyt (get)
	"QuestService", -- Faza 3: nasłuch PlayService/RunSessionService/RollService sygnałów, tylko odczyt (get)
	"AnnouncementService", -- Faza 3: nasłuch RollService.Rolled, tylko odczyt (get); MessagingService cross-server
}

-- Straznik: ORDER musi zgadzac sie 1:1 z modulami faktycznie obecnymi w Services, w obie strony.
-- Bez tego serwis moze cicho wypasc z ORDER (jak DeckService przy MAX-SLOT, patrz STATUS.md) i po
-- prostu nie wystartowac -- zero bledu, tylko ciche NoProfile/puste dane w produkcji.
do
	local orderSet: { [string]: boolean } = {}
	for _, name in ipairs(ORDER) do
		orderSet[name] = true
	end

	local missingFromOrder: { string } = {}
	for _, child in ipairs(Services:GetChildren()) do
		if child:IsA("ModuleScript") and not orderSet[child.Name] then
			table.insert(missingFromOrder, child.Name)
		end
	end

	local missingOnDisk: { string } = {}
	for _, name in ipairs(ORDER) do
		if not Services:FindFirstChild(name) then
			table.insert(missingOnDisk, name)
		end
	end

	if #missingFromOrder > 0 or #missingOnDisk > 0 then
		error(
			string.format(
				"[Bootstrap] ORDER desync! W Services ale NIE w ORDER: [%s]. W ORDER ale brak w Services: [%s].",
				table.concat(missingFromOrder, ", "),
				table.concat(missingOnDisk, ", ")
			),
			0
		)
	end
end

for _, name in ipairs(ORDER) do
	local module = Services:WaitForChild(name)
	ServiceRegistry.register(name, require(module))
end

ServiceRegistry.initAll()
ServiceRegistry.startAll()
