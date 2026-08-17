--!strict
-- StarterPlayerScripts/init.client.luau — bootstrap kontrolerów, symetria z ServerScriptService/
-- Bootstrap.server.luau (ta sama ServiceRegistry, ten sam register->initAll->startAll kontrakt;
-- moduł jest per-VM, więc klient i serwer mają NIEZALEŻNE instancje jego wewnętrznego stanu).
-- Kolejność = Architektura §3 (kontrolery #1-8, Faza 2a — #9-17 czekają na Fazę 2b+ serwisy).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))

local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"NetController",
	"UIRootController",
	"HudController",
	"RunFlowController",
	"HandController",
	"ScoreFxController",
	"TotemBarController",
	"RunShopController",
}

for _, name in ipairs(ORDER) do
	local module = Controllers:WaitForChild(name)
	ServiceRegistry.register(name, require(module))
end

ServiceRegistry.initAll()
ServiceRegistry.startAll()
