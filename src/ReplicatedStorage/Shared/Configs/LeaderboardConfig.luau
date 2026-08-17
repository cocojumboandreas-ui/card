--!strict
-- LeaderboardConfig — stałe LeaderboardService (Faza 3 krok #5, Architektura §2 linia 73).
-- Zero magic numbers w serwisie (GDD §"stałe w configu").

local LeaderboardConfig = {}

-- Kompozytowy rankScore = encounterIndex * GoldWeight + clamp(gold, 0, GoldWeight-1).
-- encounterIndex zawsze dominuje (dalszy postęp > więcej złota na płytszym runie); gold tylko
-- rozstrzyga remis na tym samym encounterIndex. GoldWeight musi być > max możliwe gold w jednym
-- runie (ExcessGoldCap=50/starcie * 12 starć + baza << 1_000_000, mnóstwo zapasu).
LeaderboardConfig.GoldWeight = 1_000_000

-- Mediana-z-N najlepszych runów gracza danego dnia (anti-skrypt, żelazna zasada — Andreas,
-- 2026-08-17). N=3: sortujemy malejąco top-3 zebrane w ciągu dnia, publikujemy środkowy.
LeaderboardConfig.DailyTopCount = 3

-- Throttle zapisów + cache odświeżania (Architektura §2: "top100 cache odświeżany co 60s").
-- Zapisy do OrderedDataStore i odczyt GetSortedAsync dzieją się WYŁĄCZNIE w tym rytmie (batch),
-- nigdy bezpośrednio z RunEnded — respektuje limity DataStore niezależnie od liczby/częstości runów.
LeaderboardConfig.RefreshIntervalSeconds = 60
LeaderboardConfig.TopN = 100

LeaderboardConfig.DailyStoreName = "RollARune_LB_Daily_v1"
LeaderboardConfig.AllTimeStoreName = "RollARune_LB_AllTime_v1"

return LeaderboardConfig
