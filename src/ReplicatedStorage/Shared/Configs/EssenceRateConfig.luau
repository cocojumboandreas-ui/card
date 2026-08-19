--!strict
-- Shared/Configs/EssenceRateConfig.luau (T3, pasywna esencja) — JEDYNE źródło stawki esencja/sek
-- na wystawioną kartę wg tieru, rodzeństwo TierColorConfig. Czytane i online (EssenceTickService)
-- i offline (OfflineEarnService) przez wspólny PlotService.RatePerSecond -- ta sama dyscyplina co
-- TierColorConfig/TotemPool: jedno źródło, nie dwie kopie liczby.
--
-- TUNING-PENDING: stawki to hipotezy startowe (jak MergeConfig 50/150/30, OfflineConfig.CapHours),
-- NIE zwalidowane bramką balansu -- bramka mierzy % ukończeń runu, nie przepływ esencji. Skala:
-- pełny plot 10x Common (minimalne zaangażowanie) = 20 esencji/h, w okolicy starego flat
-- offline-bonusu (teraz zastąpionego). Pełny plot 10x Legendary (ekstremalny endgame) = 750/h,
-- ~15 rolli/h przy RollCostEssence=50 -- hojne nagrodzenie kolekcji, ale nie zeruje sensu
-- aktywnego rollowania. Strojenie na danych z playtestu, nie teraz.
local EssenceRateConfig = {}

EssenceRateConfig.TierRatePerHour = {
	Common = 2,
	Uncommon = 5,
	Rare = 12,
	Epic = 30,
	Legendary = 75,
}

EssenceRateConfig.TickIntervalSeconds = 5 -- online: co ile sek EssenceTickService nalicza + odpala juice na fontannie

function EssenceRateConfig.tierRatePerSecond(tier: string?): number
	local perHour = tier and EssenceRateConfig.TierRatePerHour[tier]
	return (perHour or 0) / 3600
end

return EssenceRateConfig
