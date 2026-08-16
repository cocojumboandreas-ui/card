--!strict
-- GameConfig — global run-structure constants (RUNE_RNG_GDD.md §1.4). Zero-magic-numbers rule:
-- everything tunable lives here, nowhere in engine code.

local GameConfig = {}

GameConfig.HandSize = 7
GameConfig.MaxPlaySize = 5
GameConfig.PlaysPerEncounter = 4
GameConfig.SwapsPerEncounter = 3
GameConfig.TotemSlots = 5
GameConfig.ScrollSlots = 2 -- konsumowalne Zwoje w ekwipunku (Architektura odpowiedź #6)
GameConfig.Levels = 6
GameConfig.EncountersPerLevel = 2 -- zwykłe + Strażnik

-- 12 progów do zbicia sumą zagrań w starciu. Starcia 1-8: ~×1.7/starcie (zaciskanie, NIE ruszać —
-- Faza 3 walidacja potwierdziła, że działa). Starcia 9-12 (ZMIANA 3, Faza 3 balance pass): spłaszczone
-- do ~×1.45-1.5/starcie — poprzednie ×1.67-1.85 rosło szybciej niż jakiekolwiek osiągalne źródło mocy.
GameConfig.Thresholds = {
	100,
	180,
	320,
	550,
	950,
	1600,
	2700,
	4500,
	6800,
	10000,
	14500,
	21000,
}

-- Nadwyżka (Wynik − próg) → bonusowe złoto, z twardym capem (odpowiedź #14, Wariant B).
-- Wartości PLACEHOLDER — tuning po playtestach, nie blokuje Fazy 1.
GameConfig.ExcessToGoldRate = 10 -- 1 złoto za każde 10 punktów nadwyżki
GameConfig.ExcessGoldCap = 50 -- max złota z nadwyżki na jedno starcie

-- Bazowa nagroda złota za zbicie progu (PLACEHOLDER, nowe w Fazie 2 — nie było w GDD/Architekturze
-- pod tą nazwą; mnożone przez Strażnikowe rewardMult, np. thresholdWarden x2).
GameConfig.EncounterGoldReward = 20

return GameConfig
