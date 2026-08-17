--!strict
-- Controllers/FTUEController.luau (Faza 4 Krok 5) — sekwencja onboardingu GDD §2.7 (4 beaty),
-- WYLACZNIE dla swiezego profilu (ftueDone==false, push z FtueService przez FtueSync). Zero nowej
-- mechaniki -- kazdy beat juz istnieje jako zwykla mechanika gry (reka+auto-suggest+PLAY z
-- HandController, totem-pick z Krok 0/StartPickController -- automatyczny na starcie kazdego runu,
-- sklep z RunShopController, meta-roll z RollRevealController) -- ten kontroler WYLACZNIE dokleja
-- lekkie podpowiedzi/toasty dla pierwszorazowego gracza i oznacza ftueDone=true po pierwszym udanym
-- meta-rollu (ostatni z 4 beatow, GDD "pierwszy mini-roll Stworka z pelnym revealem").
-- "brzydko-ale-dzialajaco" (Faza 4 brief): tekstowe callouty + prosty pulsujacy tween, zero grafik.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local RollRevealController = require(script.Parent.RollRevealController)
local Net = require(ReplicatedStorage.Framework.Net)

local FTUEController = {}

local _gui: ScreenGui
local _playHint: Frame
local _rollHint: Frame
local _levelToast: TextLabel? = nil

local _ftueDone = true -- bezpieczny default dopoki FtueSync nie przyjdzie -- brak migotania dla starych graczy
local _synced = false

local _startEncounterIndex: number? = nil -- encounterIndex na wejsciu do biezacego runu (beat 2 trigger)
local _prevBudget: number? = nil -- playsRemaining+swapsRemaining z poprzedniego stanu (beat 1 hide trigger)
local _beat1Shown = false
local _beat2Shown = false
local _shopHintShown = false

local function pulse(inst: GuiObject)
	TweenService:Create(
		inst,
		TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ BackgroundTransparency = 0.55 }
	):Play()
end

local function levelToast(text: string)
	if _levelToast then
		_levelToast:Destroy()
	end
	local lbl = UIFactory.label(_gui, text, {
		Size = UDim2.new(0, 300, 0, 60),
		Position = UDim2.new(0.5, -150, 0.28, 0),
		TextColor3 = Color3.fromRGB(120, 230, 140),
		TextSize = 30,
		TextStrokeTransparency = 0,
	})
	_levelToast = lbl
	task.delay(2.2, function()
		if lbl.Parent then
			lbl:Destroy()
		end
		if _levelToast == lbl then
			_levelToast = nil
		end
	end)
end

local function markDone()
	if _ftueDone then
		return
	end
	_ftueDone = true
	_playHint.Visible = false
	_rollHint.Visible = false
	NetController.FireServer("MarkFtueDone")
end

local function render(state: { [string]: any }?)
	if _ftueDone then
		return
	end

	if state == nil or state.status ~= "active" then
		_playHint.Visible = false
		_startEncounterIndex = nil
		_prevBudget = nil
		return
	end

	if _startEncounterIndex == nil then
		_startEncounterIndex = state.encounterIndex
		_beat1Shown = false
		_beat2Shown = false
	end

	-- Beat 1 (0-10s): pierwsza reka tego starcia, jeszcze zadnej akcji -- podpowiedz PLAY.
	local budget = state.playsRemaining + state.swapsRemaining
	if not _beat1Shown and #state.hand > 0 then
		_beat1Shown = true
		_playHint.Visible = true
		pulse(_playHint)
	end
	if _prevBudget ~= nil and budget < _prevBudget then
		_playHint.Visible = false
	end
	_prevBudget = budget

	-- Beat 2 (10-30s power-spike): pierwsze starcie tego runu zaliczone.
	if not _beat2Shown and state.encounterIndex > _startEncounterIndex then
		_beat2Shown = true
		levelToast(`LEVEL {state.level} ✓`)
	end

	-- Beat 4 (60-120s, czesc "sklep"): lekka podpowiedz przy pierwszej ofercie sklepu tego runu.
	if not _shopHintShown and state.shopOffers ~= nil then
		_shopHintShown = true
		levelToast("Shop unlocked — spend your gold!")
	end

	-- Beat 4 (60-120s, czesc "roll"): po pierwszym zdobytym zlocie pokaz podpowiedz Roll.
	if state.gold and state.gold > 0 then
		_rollHint.Visible = true
	end
end

function FTUEController.Init() end

function FTUEController.Start()
	_gui = UIRootController.Get("Ftue")

	_playHint = UIFactory.panel(_gui, {
		Size = UDim2.new(0, 280, 0, 40),
		Position = UDim2.new(0.5, -140, 1, -260),
		BackgroundColor3 = Color3.fromRGB(90, 200, 120),
		Visible = false,
	})
	UIFactory.label(_playHint, "▲ TAP PLAY", { TextColor3 = Color3.fromRGB(15, 40, 20) })

	_rollHint = UIFactory.panel(_gui, {
		Size = UDim2.new(0, 100, 0, 32),
		Position = UDim2.new(1, -165, 0, 66),
		BackgroundColor3 = Color3.fromRGB(200, 160, 60),
		Visible = false,
	})
	UIFactory.label(_rollHint, "▲ TRY ROLL", { TextSize = 14, TextColor3 = Color3.fromRGB(40, 30, 0) })
	pulse(_rollHint)

	local ftueSyncRemote = Net.get("FtueSync") :: RemoteEvent
	ftueSyncRemote.OnClientEvent:Connect(function(payload: { ftueDone: boolean }?)
		_synced = true
		_ftueDone = (payload ~= nil and payload.ftueDone == true)
		if _ftueDone then
			_playHint.Visible = false
			_rollHint.Visible = false
		end
	end)

	RollRevealController.RollCompleted:Connect(function()
		if not _ftueDone then
			_rollHint.Visible = false
			markDone()
		end
	end)

	NetController.StateChanged:Connect(render)
	render(NetController.state)
end

-- Hooki TYLKO do testow.
function FTUEController._StateForTest(): { [string]: any }
	return {
		ftueDone = _ftueDone,
		synced = _synced,
		playHintVisible = _playHint.Visible,
		rollHintVisible = _rollHint.Visible,
	}
end
function FTUEController._SetFtueDoneForTest(done: boolean)
	_ftueDone = done
end
function FTUEController._RenderForTest(state: { [string]: any }?)
	render(state)
end
function FTUEController._MarkDoneForTest()
	markDone()
end

return FTUEController
