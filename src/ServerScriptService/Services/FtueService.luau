--!strict
-- ServerScriptService/Services/FtueService.luau (Faza 4 Krok 5) — cienki most flagi ftueDone
-- (PROFILE_TEMPLATE, ProfileService.luau:36). Serwer zostaje jedynym autorytetem stanu -- push
-- raz po ProfileLoaded, przyjmuje MarkFtueDone gdy klient (FTUEController) uzna sekwencje
-- onboardingu za skonczona. Zero logiki sekwencji/beatow tutaj -- to wylacznie odczyt/zapis flagi.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))

local FtueService = {}

local _profile = nil

function FtueService.Init() end

function FtueService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	local ftueSync = Net.get("FtueSync") :: RemoteEvent
	local markDone = Net.get("MarkFtueDone") :: RemoteEvent

	_profile.ProfileLoaded:Connect(function(player: Player, data: { [string]: any })
		ftueSync:FireClient(player, { ftueDone = data.ftueDone == true })
	end)

	markDone.OnServerEvent:Connect(function(player: Player)
		local data = _profile.GetProfile(player)
		if data then
			data.ftueDone = true
		end
	end)
end

-- Hook TYLKO do testow.
function FtueService._InjectForTest(deps: { profile: any })
	_profile = deps.profile
end

return FtueService
