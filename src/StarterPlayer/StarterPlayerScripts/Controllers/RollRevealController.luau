--!strict
-- Controllers/RollRevealController.luau (Faza 2b, kontroler #9) — UI ujawnienia meta-rolla Stworka
-- (Net.RollTotem). PORTUJEMY TYLKO PACING z WAR RNG RevealConfig (tier -> spin/hold w sekundach,
-- Common szybko / Epic+Legendary dłuższa suspensja = "sedno dopaminy"), NIE ich styl (brak
-- koniczyn/kaskad/gradientów/cząsteczek — zgodnie z briefem, to idzie do finałowego redesignu).
-- Karty = UIFactory.panel w kolorze tieru + art z CardArtConfig (nasz styl, nie ich). Wariant
-- (Foil/Gold/Galaxy/Rainbow) = zwykły TextLabel, zero animacji.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIFactory = require(script.Parent.UIFactory)
local UIRootController = require(script.Parent.UIRootController)
local NetController = require(script.Parent.NetController)
local TotemConfig = require(ReplicatedStorage.Shared.Configs.TotemConfig)
local CardArtConfig = require(ReplicatedStorage.Shared.Configs.CardArtConfig)

local RollRevealController = {}

-- Pacing port (WAR RNG RevealConfig.tiers §): Common szybki spin, Legendary dłuższy/suspensyjny.
-- Wartości własne (5 nazwanych tierów zamiast ich 1/3/5 numerycznych), ta sama rosnąca krzywa.
local REVEAL_PACING = {
	Common = { spinSec = 1.0, holdSec = 0.6 },
	Uncommon = { spinSec = 1.5, holdSec = 0.8 },
	Rare = { spinSec = 2.2, holdSec = 1.1 },
	Epic = { spinSec = 3.2, holdSec = 1.8 },
	Legendary = { spinSec = 4.5, holdSec = 2.5 },
}

local VARIANT_LABEL = {
	Foil = { text = "★ FOIL", color = Color3.fromRGB(200, 220, 255) },
	Gold = { text = "★ GOLD", color = Color3.fromRGB(255, 210, 80) },
	Galaxy = { text = "★ GALAXY", color = Color3.fromRGB(180, 130, 255) },
	Rainbow = { text = "★ RAINBOW", color = Color3.fromRGB(255, 120, 200) },
}

local _gui: ScreenGui
local _dim: Frame
local _card: Frame
local _art: ImageLabel?
local _nameLabel: TextLabel
local _tierLabel: TextLabel
local _variantLabel: TextLabel
local _badgeLabel: TextLabel
local _statusLabel: TextLabel
local _busy = false

local function totemIds(): { string }
	local ids = {}
	for id in TotemConfig.Totems do
		table.insert(ids, id)
	end
	return ids
end
local _allIds = totemIds()

local function randomDecoyId(excludeId: string): string
	if #_allIds <= 1 then
		return excludeId
	end
	local id = _allIds[math.random(1, #_allIds)]
	while id == excludeId do
		id = _allIds[math.random(1, #_allIds)]
	end
	return id
end

local function renderCard(totemId: string, tier: string)
	local totem = TotemConfig.Totems[totemId]
	_card.BackgroundColor3 = UIFactory.tierColor(tier)
	if _art then
		_art:Destroy()
		_art = nil
	end
	_art = UIFactory.artImage(_card, CardArtConfig.get(totemId), {
		Size = UDim2.new(1, -12, 0, 140),
		Position = UDim2.new(0, 6, 0, 6),
	})
	_nameLabel.Text = totem and totem.name or totemId
	_tierLabel.Text = tier
end

-- Spin: cykluje losowe Stworki w slocie, interwał rośnie (ease-out slowdown) -> ląduje na wyniku
-- dokładnie po `spinSec`. YIELDS w wątku wołającym (task.spawn po stronie RequestRoll).
local function spin(winnerId: string, winnerTier: string, spinSec: number)
	local startT = os.clock()
	while os.clock() - startT < spinSec do
		local t = (os.clock() - startT) / spinSec
		renderCard(randomDecoyId(winnerId), winnerTier)
		task.wait(0.04 + t * t * 0.30)
	end
	renderCard(winnerId, winnerTier)
end

local function playReveal(result: { [string]: any })
	_statusLabel.Text = ""
	_badgeLabel.Text = ""
	_variantLabel.Text = ""
	_dim.Visible = true

	local pacing = REVEAL_PACING[result.tier] or REVEAL_PACING.Common
	spin(result.totemId, result.tier, pacing.spinSec)

	local badges = {}
	if result.isNewDiscovery then
		table.insert(badges, "NEW!")
	end
	if result.pityTriggered then
		table.insert(badges, "PITY")
	end
	_badgeLabel.Text = table.concat(badges, "  ")

	local variantInfo = VARIANT_LABEL[result.variant]
	if variantInfo then
		_variantLabel.Text = variantInfo.text
		_variantLabel.TextColor3 = variantInfo.color
	end

	task.wait(pacing.holdSec)
	_dim.Visible = false
end

function RollRevealController.RequestRoll()
	if _busy then
		return
	end
	_busy = true
	task.spawn(function()
		local ok, result = NetController.Invoke("RollTotem")
		if ok and type(result) == "table" and result.ok then
			playReveal(result)
		else
			local reason = (ok and type(result) == "table" and result.reason) or "error"
			_statusLabel.Text = `Roll failed: {reason}`
			task.delay(1.5, function()
				_statusLabel.Text = ""
			end)
		end
		_busy = false
	end)
end

function RollRevealController.Init() end

function RollRevealController.Start()
	_gui = UIRootController.Get("Roll")

	_dim = UIFactory.panel(_gui, {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.4,
		Visible = false,
	})

	_card = UIFactory.panel(_dim, {
		Size = UDim2.new(0, 220, 0, 260),
		Position = UDim2.new(0.5, -110, 0.5, -170),
	})

	_nameLabel = UIFactory.label(_card, "", {
		Size = UDim2.new(1, -8, 0, 30),
		Position = UDim2.new(0, 4, 0, 150),
	})
	_tierLabel = UIFactory.label(_card, "", {
		Size = UDim2.new(1, -8, 0, 22),
		Position = UDim2.new(0, 4, 0, 180),
		TextSize = 14,
	})
	_variantLabel = UIFactory.label(_card, "", {
		Size = UDim2.new(1, -8, 0, 22),
		Position = UDim2.new(0, 4, 0, 202),
		TextSize = 14,
	})
	_badgeLabel = UIFactory.label(_card, "", {
		Size = UDim2.new(1, -8, 0, 24),
		Position = UDim2.new(0, 4, 0, 224),
		TextColor3 = Color3.fromRGB(255, 210, 90),
		TextSize = 16,
	})

	_statusLabel = UIFactory.label(_gui, "", {
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.new(0, 20, 0.5, 140),
		TextColor3 = Color3.fromRGB(255, 120, 120),
	})
end

return RollRevealController
