--!strict
-- ServerScriptService/Bootstrap.server.luau — bootstrap ServiceRegistry (Architektura §1: "Z
-- PCALL — lekcja z audytu RNG!" — patrz Framework/ServiceRegistry.luau dla mechanizmu izolacji).
-- Kolejność rejestracji = kolejność Init/Start (Architektura §2 tabela serwisów).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Services = ServerScriptService:WaitForChild("Services")

-- ProfileService -> StatProfileService -> EconomyService -> RunSessionService -> PlayService ->
-- RunShopService (Faza 2a). Wszystkie sześć mają teraz Init/Start (krok 5: PlayService/
-- RunShopService.Start() wiążą swoje remote'y z Net.luau -- patrz te pliki).
local ORDER = {
	"ProfileService",
	"StatProfileService",
	"EconomyService",
	"RunSessionService",
	"PlayService",
	"RunShopService",
}

for _, name in ipairs(ORDER) do
	local module = Services:WaitForChild(name)
	ServiceRegistry.register(name, require(module))
end

ServiceRegistry.initAll()
ServiceRegistry.startAll()
