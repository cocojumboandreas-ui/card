--!strict
-- Shared/Configs/TierColorConfig.luau — JEDYNE źródło tier->kolor. Wyciągnięte z UIFactory.TierColors
-- (T2, pivot tycoon): serwer (PlotService, kolorowanie Frame/aury na plotach) i klient (UIFactory)
-- muszą czytać JEDEN wspólny config, nie dwie kopie tej samej tabeli — ta sama dyscyplina co
-- odds-bug fix (PolicyService/RollService dzielą TotemPool zamiast duplikować %).

local TierColorConfig = {}

TierColorConfig.TierColors = {
	Common = Color3.fromRGB(158, 158, 163), -- szary
	Uncommon = Color3.fromRGB(74, 144, 255), -- niebieski
	Rare = Color3.fromRGB(50, 110, 230), -- niebieski (świadomie ten sam bucket co Uncommon -- 4 kolory na 5 tierów, wg brief)
	Epic = Color3.fromRGB(170, 90, 255), -- fioletowy
	Legendary = Color3.fromRGB(255, 196, 61), -- złoty
}

function TierColorConfig.tierColor(tier: string?): Color3
	return (tier and TierColorConfig.TierColors[tier]) or Color3.fromRGB(120, 120, 125)
end

return TierColorConfig
