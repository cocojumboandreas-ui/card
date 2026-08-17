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
	"RollRevealController", -- Faza 2b: przed HudController (przycisk Roll go woła), po UIRootController (root "Roll")
	"IndexController", -- Faza 2b: przed HudController (przycisk Indeks go woła), po UIRootController (root "Index")
	"OfflineEarnController", -- Faza 3: po UIRootController (root "Toast"), niezależny od HUD-u
	"AnnouncementController", -- Faza 3: po UIRootController (root "Toast"), niezależny od HUD-u
	"HudController",
	"RunFlowController",
	"StartPickController", -- Faza 4 Krok 0: modal picku startowego, po RunFlowController, niezależny od HUD-u
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
