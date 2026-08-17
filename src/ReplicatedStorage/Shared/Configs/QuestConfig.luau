--!strict
-- QuestConfig — Faza 3 krok #7, QuestService. Pula questów dziennych (Architektura §2 linia 69,
-- GDD linia 90 "3 questy dzienne"). eventType łączy się z sygnałami już istniejącymi w Fazie 3
-- (PlayService.SpellPlayed / RunSessionService.GuardianDefeated+RunEnded / RollService.Rolled) —
-- ŻADNEGO nowego sygnału, celowo (patrz komentarz w RollService.Rolled: "nie duplikować").
-- Nagrody PLACEHOLDER jak StreakConfig/ShopConfig — skala wobec EssenceConfig.RunGoldToEssenceRate.

local QuestConfig = {}

-- Ile z Pool losujemy każdego dnia (bez powtórzeń typu). VIP gamepass (+1 quest dzienny, GDD
-- §monetyzacja) to Faza 4 — hook na przyszłość, nie liczone tu dziś.
QuestConfig.DailyQuestCount = 3

QuestConfig.Pool = {
	{
		id = "playNawalnica",
		desc = "Zagraj Nawałnicę x3",
		eventType = "spellPlayed",
		spellId = "Nawalnica",
		targetCount = 3,
		rewardEssence = 40,
	},
	{
		id = "defeatGuardians",
		desc = "Pokonaj 2 Strażników",
		eventType = "guardianDefeated",
		targetCount = 2,
		rewardEssence = 60,
	},
	{
		id = "winRuns",
		desc = "Wygraj 1 run",
		eventType = "runWon",
		targetCount = 1,
		rewardEssence = 80,
	},
	{
		id = "rollTotems",
		desc = "Zakręć Totemem x3",
		eventType = "totemRolled",
		targetCount = 3,
		rewardEssence = 25,
	},
}

return QuestConfig
