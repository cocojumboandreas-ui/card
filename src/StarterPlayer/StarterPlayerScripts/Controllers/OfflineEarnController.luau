--!strict
-- Controllers/OfflineEarnController.luau (Faza 3) — popup "+N Esencji za czas offline". Brzydko-ale-
-- działająco: jeden panel w root "Toast" (UIRootController), auto-znika po kilku sekundach albo na
-- klik. Serwer wysyła OfflineEarnings TYLKO gdy essence>0 (patrz OfflineEarnService.Start), więc
-- kontroler nie musi sam filtrować zera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)

local Net = require(ReplicatedStorage.Framework.Net)

local OfflineEarnController = {}

local AUTO_DISMISS_SECONDS = 6

local function showToast(gui: ScreenGui, essence: number)
	local panel = UIFactory.panel(gui, {
		Size = UDim2.new(0, 320, 0, 90),
		Position = UDim2.new(0.5, -160, 0, 24),
		BackgroundColor3 = Color3.fromRGB(24, 24, 30),
	})
	UIFactory.label(panel, `Offline: +{essence} Esencji`, {
		Size = UDim2.new(1, -16, 1, -16),
		Position = UDim2.new(0, 8, 0, 8),
		TextColor3 = Color3.fromRGB(255, 196, 61),
	})
	local btn = UIFactory.button(panel, "X", {
		Size = UDim2.new(0, 28, 0, 28),
		Position = UDim2.new(1, -34, 0, 4),
		BackgroundColor3 = Color3.fromRGB(60, 60, 68),
	}, function()
		panel:Destroy()
	end)
	btn.ZIndex = 2
	task.delay(AUTO_DISMISS_SECONDS, function()
		if panel.Parent then
			panel:Destroy()
		end
	end)
end

function OfflineEarnController.Init() end

function OfflineEarnController.Start()
	local gui = UIRootController.Get("Toast")
	local remote = Net.get("OfflineEarnings")
	remote.OnClientEvent:Connect(function(result)
		if type(result) == "table" and type(result.essence) == "number" and result.essence > 0 then
			showToast(gui, result.essence)
		end
	end)
end

return OfflineEarnController
