--!strict
-- Controllers/AnnouncementController.luau (Faza 3) — toast "gracz X wyrollował rzadki Stworek".
-- Ten sam wzorzec co OfflineEarnController: jeden panel w rootcie "Toast", auto-dismiss. Serwer
-- wysyła AnnouncementSync TYLKO dla dropów spełniających AnnouncementConfig (patrz
-- AnnouncementService), więc kontroler nie filtruje progu sam.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)

local Net = require(ReplicatedStorage.Framework.Net)

local AnnouncementController = {}

local AUTO_DISMISS_SECONDS = 6

local function showToast(gui: ScreenGui, payload)
	local panel = UIFactory.panel(gui, {
		Size = UDim2.new(0, 360, 0, 90),
		Position = UDim2.new(0.5, -180, 0, 24),
		BackgroundColor3 = Color3.fromRGB(40, 22, 50),
	})
	UIFactory.label(panel, `{payload.name} wyrollował {payload.variant} {payload.totemId} ({payload.tier})!`, {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		TextColor3 = Color3.fromRGB(255, 120, 240),
	})
	task.delay(AUTO_DISMISS_SECONDS, function()
		if panel.Parent then
			panel:Destroy()
		end
	end)
end

function AnnouncementController.Init() end

function AnnouncementController.Start()
	local gui = UIRootController.Get("Toast")
	local remote = Net.get("AnnouncementSync")
	remote.OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.name) == "string" then
			showToast(gui, payload)
		end
	end)
end

return AnnouncementController
