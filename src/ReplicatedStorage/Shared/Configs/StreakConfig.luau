--!strict
-- StreakConfig — Faza 3 krok #6, StreakService. Kamienie milowe D7/D14/D30 (Architektura §2 linia
-- 70, GDD linia 90 "nagrody eskalujące D7/D14/D30"). Wartości PLACEHOLDER (jak ShopConfig/
-- OfflineConfig) — skalowane wobec EssenceConfig.RunGoldToEssenceRate: mediana runu daje ~135-145
-- esencji, OfflineConfig cap 10h daje 200 — D7 warte mniej niż 1 run, D30 warte ~1 tydzień offline.

local StreakConfig = {}

StreakConfig.Milestones = {
	{ days = 7, essence = 100 },
	{ days = 14, essence = 250 },
	{ days = 30, essence = 600 },
}

return StreakConfig
