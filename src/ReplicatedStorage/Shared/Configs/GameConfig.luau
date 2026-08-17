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
-- Faza 3 walidacja potwierdziła, że działa).
-- Starcia 9-12 (ZMIANA 5, Faza 3, po naprawie harnessu + dodaniu pełnego smart-bota z wymianami i
-- zwojami jako proxy człowieka): ZMIANA 3 spłaszczyła krok do ~×1.45-1.5, co dawało naive-bota w
-- widełkach (44-52%), ALE pełny smart-bot (proxy myślącego człowieka, z wymianami+zwojami) robił
-- 72% -- za łatwo. Krok podniesiony z powrotem do ~×1.575/starcie (cel człowieka 30-55%, nie bota).
GameConfig.Thresholds = {
	100,
	180,
	320,
	550,
	950,
	1600,
	2700,
	4500,
	7100,
	11200,
	17600,
	27700,
}

-- Nadwyżka (Wynik − próg) → bonusowe złoto, z twardym capem (odpowiedź #14, Wariant B).
-- Wartości PLACEHOLDER — tuning po playtestach, nie blokuje Fazy 1.
GameConfig.ExcessToGoldRate = 10 -- 1 złoto za każde 10 punktów nadwyżki
GameConfig.ExcessGoldCap = 50 -- max złota z nadwyżki na jedno starcie

-- Bazowa nagroda złota za zbicie progu (PLACEHOLDER, nowe w Fazie 2 — nie było w GDD/Architekturze
-- pod tą nazwą; mnożone przez Strażnikowe rewardMult, np. thresholdWarden x2).
GameConfig.EncounterGoldReward = 20

-- Koszt jednego rolla Stworka w Esencji (Faza 2b, RollService). PLACEHOLDER — tuning po graniu.
GameConfig.RollCostEssence = 50

-- Bazowe Staty v1 (Architektura §2, tabela StatProfileService) — neutralne wartości PRZED deltami
-- skilli/kolekcji. Faza 2a czyta tylko luck/essenceMult/extraPlays/extraSwaps/startPickSize
-- (skille dopiero w Fazie 2b); offlineRate/fastRoll czekają na OfflineEarnService/RollService, ale
-- żyją tu już teraz, żeby dołożenie tamtych serwisów nie wymagało zmiany kształtu Stats.
GameConfig.StatBase = {
	luck = 1,
	essenceMult = 1,
	extraPlays = 0,
	extraSwaps = 0,
	startPickSize = 1,
	offlineRate = 0,
	fastRoll = false,
}

return GameConfig
