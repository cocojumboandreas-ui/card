--!strict
-- Shared/Configs/TierAuraConfig.luau — jedyne źródło intensywności aury per tier (POLISH displayów
-- kart, 2026-08-20). Kolor ZAWSZE z TierColorConfig (jeden import) -- ten config trzyma TYLKO
-- intensywność: cząstki (rate/size/lifetime/speed/spread), światło (brightness/range), halo
-- (RarityGlow transparency/sizeMult), opcjonalny drugi emiter "rays" (tylko Legendary).
-- Czytany przez PlotService.renderSlot (serwer, przy każdym fill/clear slotu) -- NIE przez klienta,
-- bo AuraLight/AuraParticles/RarityGlow to zwykłe property/attribute na instancjach pod
-- Workspace.Plots, więc replikują się "za darmo" tym samym mechanizmem co CardArt.Image.

local TierAuraConfig = {}

export type AuraSpec = {
	particleRate: number,
	particleSize: NumberRange,
	particleLifetime: NumberRange,
	particleSpeed: NumberRange,
	spreadAngle: Vector2,
	lightBrightness: number,
	lightRange: number,
	glowTransparency: number, -- 1 = niewidoczne (halo "off"), niżej = mocniejsze halo
	glowSizeMult: number, -- mnożnik względem GLOW_BASE_SIZE
	rays: boolean, -- dodatkowy promienisty emiter -- tylko Legendary
}

TierAuraConfig.Tiers = {
	Common = {
		particleRate = 0, -- "zero/minimum cząstek" wg brief
		particleSize = NumberRange.new(0.1, 0.1),
		particleLifetime = NumberRange.new(1, 1),
		particleSpeed = NumberRange.new(0, 0),
		spreadAngle = Vector2.new(0, 0),
		lightBrightness = 1.2,
		lightRange = 8,
		glowTransparency = 0.92, -- praktycznie niewidoczne
		glowSizeMult = 1.0,
		rays = false,
	},
	Uncommon = {
		particleRate = 3,
		particleSize = NumberRange.new(0.15, 0.25),
		particleLifetime = NumberRange.new(1.2, 1.6),
		particleSpeed = NumberRange.new(1, 2),
		spreadAngle = Vector2.new(20, 20),
		lightBrightness = 2.5,
		lightRange = 10,
		glowTransparency = 0.75,
		glowSizeMult = 1.05,
		rays = false,
	},
	Rare = {
		particleRate = 8,
		particleSize = NumberRange.new(0.2, 0.35),
		particleLifetime = NumberRange.new(1.3, 1.8),
		particleSpeed = NumberRange.new(1.5, 2.5),
		spreadAngle = Vector2.new(28, 28),
		lightBrightness = 4.0,
		lightRange = 13,
		glowTransparency = 0.55,
		glowSizeMult = 1.10,
		rays = false,
	},
	Epic = {
		particleRate = 16,
		particleSize = NumberRange.new(0.28, 0.45),
		particleLifetime = NumberRange.new(1.5, 2.0),
		particleSpeed = NumberRange.new(2, 3.5),
		spreadAngle = Vector2.new(36, 36),
		lightBrightness = 6.0,
		lightRange = 17,
		glowTransparency = 0.35,
		glowSizeMult = 1.18,
		rays = false,
	},
	Legendary = {
		particleRate = 30,
		particleSize = NumberRange.new(0.35, 0.6),
		particleLifetime = NumberRange.new(1.7, 2.4),
		particleSpeed = NumberRange.new(3, 5),
		spreadAngle = Vector2.new(50, 50),
		lightBrightness = 9.0,
		lightRange = 24,
		glowTransparency = 0.12, -- najmocniejsze halo
		glowSizeMult = 1.30,
		rays = true, -- "intensywna promienista aura...halo/promienie = must-have"
	},
} :: { [string]: AuraSpec }

function TierAuraConfig.get(tier: string?): AuraSpec?
	return tier and TierAuraConfig.Tiers[tier]
end

return TierAuraConfig
