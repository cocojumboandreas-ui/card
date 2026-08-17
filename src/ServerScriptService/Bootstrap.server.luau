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
	"OfflineEarnService", -- Faza 3: zależy tylko od Profile/Stat/Economy, zero zależności od runu
	"IndexService",
	"RollService",
	"SeedService", -- Faza 3: czysta funkcja, zero zależności; PRZED RunSessionService (użyty w startRun)
	"RunSessionService",
	"PlayService",
	"RunShopService",
	"LeaderboardService", -- Faza 3: nasłuch RunSessionService.RunEnded, zależy tylko na odczyt (get)
	"StreakService", -- Faza 3: nasłuch ProfileService.ProfileLoaded, zależy tylko na odczyt (get)
	"QuestService", -- Faza 3: nasłuch PlayService/RunSessionService/RollService sygnałów, tylko odczyt (get)
	"AnnouncementService", -- Faza 3: nasłuch RollService.Rolled, tylko odczyt (get); MessagingService cross-server
}

for _, name in ipairs(ORDER) do
	local module = Services:WaitForChild(name)
	ServiceRegistry.register(name, require(module))
end

ServiceRegistry.initAll()
ServiceRegistry.startAll()
