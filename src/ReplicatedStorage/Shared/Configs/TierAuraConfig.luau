--!strict
-- Shared/Configs/TierAuraConfig.luau — jedyne źródło intensywności aury per tier (POLISH displayów
-- kart v2, 2026-08-20: usuniete zlote ramki, karty wolnostojace dwustronne). Kolor ZAWSZE z
-- TierColorConfig (jeden import) -- ten config trzyma TYLKO intensywnosc: czastki (swirl wokol
-- karty), swiatlo, promienisty emiter "rays" (tylko Legendary), oraz DWA nowe elementy zakotwiczone
-- w podlodze (nie ruszaja sie z animacja karty): pionowy "AuraBeam" (kolumna swiatla, jak w
-- referencyjnym anime-card-tycoon) i plaski "AuraGroundGlow" (swiecacy okrag pod karta). Im wyzszy
-- tier, tym wieksza/intensywniejsza kazda z tych czesci -- to jest GLOWNY nosnik rarity, nie ramka.
-- Czytany przez PlotService.renderSlot (serwer, przy kazdym fill/clear slotu) -- NIE przez klienta,
-- bo wszystko to zwykle property/attribute na instancjach pod Workspace.Plots, wiec replikuja sie
-- "za darmo" tym samym mechanizmem co CardArt.Image.

local TierAuraConfig = {}

export type AuraSpec = {
	particleRate: number,
	particleSize: NumberRange,
	particleLifetime: NumberRange,
	particleSpeed: NumberRange,
	spreadAngle: Vector2,
	lightBrightness: number,
	lightRange: number,
	rays: boolean, -- dodatkowy promienisty emiter -- tylko Legendary
	beamHeight: number, -- 0 = brak kolumny swiatla (Common); wysokosc gornego Attachment Beama
	beamThickness: number, -- Beam.Width0/1 skaluja sie od tego (stozek gruby->cienki)
	groundRadius: number, -- srednica swiecacego okregu pod karta
	groundTransparency: number,
}

TierAuraConfig.Tiers = {
	Common = {
		particleRate = 2,
		particleSize = NumberRange.new(0.08, 0.15),
		particleLifetime = NumberRange.new(0.8, 1.1),
		particleSpeed = NumberRange.new(0.4, 0.8),
		spreadAngle = Vector2.new(10, 10),
		lightBrightness = 1.5,
		lightRange = 6,
		rays = false,
		beamHeight = 0,
		beamThickness = 0.3,
		groundRadius = 1.6,
		groundTransparency = 0.7,
	},
	Uncommon = {
		particleRate = 6,
		particleSize = NumberRange.new(0.15, 0.25),
		particleLifetime = NumberRange.new(1.1, 1.5),
		particleSpeed = NumberRange.new(1, 2),
		spreadAngle = Vector2.new(18, 18),
		lightBrightness = 3,
		lightRange = 9,
		rays = false,
		beamHeight = 4,
		beamThickness = 0.35,
		groundRadius = 2.6,
		groundTransparency = 0.5,
	},
	Rare = {
		particleRate = 14,
		particleSize = NumberRange.new(0.22, 0.35),
		particleLifetime = NumberRange.new(1.3, 1.7),
		particleSpeed = NumberRange.new(1.8, 3),
		spreadAngle = Vector2.new(26, 26),
		lightBrightness = 5,
		lightRange = 13,
		rays = false,
		beamHeight = 8,
		beamThickness = 0.5,
		groundRadius = 3.6,
		groundTransparency = 0.35,
	},
	Epic = {
		particleRate = 26,
		particleSize = NumberRange.new(0.3, 0.5),
		particleLifetime = NumberRange.new(1.5, 2.0),
		particleSpeed = NumberRange.new(2.5, 4.5),
		spreadAngle = Vector2.new(36, 36),
		lightBrightness = 8,
		lightRange = 18,
		rays = false,
		beamHeight = 13,
		beamThickness = 0.7,
		groundRadius = 4.6,
		groundTransparency = 0.2,
	},
	Legendary = {
		particleRate = 48,
		particleSize = NumberRange.new(0.4, 0.75),
		particleLifetime = NumberRange.new(1.7, 2.4),
		particleSpeed = NumberRange.new(3.5, 6),
		spreadAngle = Vector2.new(55, 55),
		lightBrightness = 13,
		lightRange = 26,
		rays = true, -- intensywna promienista aura -- must-have
		beamHeight = 20,
		beamThickness = 1.0,
		groundRadius = 6.0,
		groundTransparency = 0.05,
	},
} :: { [string]: AuraSpec }

function TierAuraConfig.get(tier: string?): AuraSpec?
	return tier and TierAuraConfig.Tiers[tier]
end

return TierAuraConfig
