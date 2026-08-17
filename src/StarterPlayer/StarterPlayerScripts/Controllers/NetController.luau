--!strict
-- Controllers/NetController.luau (Architektura §3, kontroler #1) — cache referencji remotes +
-- helpery subscribe. Trzyma też JEDYNE lustro RunState na kliencie: RunStateSync jest jedynym
-- źródłem prawdy (Net.luau: "klient renderuje z tego, nie z return value") -- wszystkie pozostałe
-- kontrolery czytają NetController.state / słuchają NetController.StateChanged, nigdy nie wołają
-- Net.get() same.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Framework = ReplicatedStorage:WaitForChild("Framework")
local Net = require(Framework:WaitForChild("Net"))
local Signal = require(Framework:WaitForChild("Signal"))

local NetController = {}

NetController.state = nil :: { [string]: any }? -- ostatni RunStateSync snapshot; nil = brak aktywnego runu
NetController.StateChanged = Signal.new() -- (state) po każdym RunStateSync
NetController.EssenceChanged = Signal.new() -- (balance: number)

local _remotes: { [string]: Instance } = {}
local function remote(name: string): Instance
	if not _remotes[name] then
		_remotes[name] = Net.get(name)
	end
	return _remotes[name]
end

-- RemoteFunction wrapper: ZAWSZE pcall (Architektura §5: "pcall po stronie klienta" dla RF) --
-- serwer może kicknąć/timeout, kontrolery nie mogą się na tym wywalić.
function NetController.Invoke(name: string, ...: any): (boolean, any)
	local args = { ... }
	local ok, result = pcall(function()
		return (remote(name) :: RemoteFunction):InvokeServer(table.unpack(args))
	end)
	return ok, result
end

function NetController.FireServer(name: string, ...: any)
	(remote(name) :: RemoteEvent):FireServer(...)
end

function NetController.Init() end

function NetController.Start()
	local runStateSync = remote("RunStateSync") :: RemoteEvent
	runStateSync.OnClientEvent:Connect(function(state: { [string]: any })
		NetController.state = state
		NetController.StateChanged:Fire(state)
	end)
	local essenceSync = remote("EssenceSync") :: RemoteEvent
	essenceSync.OnClientEvent:Connect(function(payload: { balance: number })
		NetController.EssenceChanged:Fire(payload.balance)
	end)
end

return NetController
