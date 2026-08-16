--!strict
-- Sanity tests for GameConfig/RuneConfig/SpellConfig/TotemConfig/GuardianConfig data — catches
-- transcription typos against RUNE_RNG_GDD.md / RUNE_RNG_STWORKI.md. No Studio required.
--   luau tests/Configs.test.luau

local RuneConfig = require("../src/ReplicatedStorage/Shared/Configs/RuneConfig")
local SpellConfig = require("../src/ReplicatedStorage/Shared/Configs/SpellConfig")
local TotemConfig = require("../src/ReplicatedStorage/Shared/Configs/TotemConfig")
local GuardianConfig = require("../src/ReplicatedStorage/Shared/Configs/GuardianConfig")
local GameConfig = require("../src/ReplicatedStorage/Shared/Configs/GameConfig")

local failures = 0
local function check(label: string, cond: boolean)
	if cond then
		print("ok    " .. label)
	else
		failures += 1
		print("FAIL  " .. label)
	end
end

-- RuneConfig: 40 Run = 5 żywiołów × wartości 1-8 (GDD §1.2).
local deck = RuneConfig.buildDeck()
check("deck has 40 runes", #deck == 40)
local seen = {}
local duplicates = 0
for _, rune in deck do
	local key = rune.element .. "#" .. rune.value
	if seen[key] then
		duplicates += 1
	end
	seen[key] = true
end
check("deck has no duplicate element+value pairs", duplicates == 0)
check("power(value=8) == 40", RuneConfig.power({ element = "Fire", value = 8 }) == 40)
check("power(value=1) == 5", RuneConfig.power({ element = "Fire", value = 1 }) == 5)

-- SpellConfig: 7 Zaklęć, wartości bazowe z GDD §1.3.
check("7 spells defined", #SpellConfig.Spells == 7)
local bySpellId = {}
for _, spell in SpellConfig.Spells do
	bySpellId[spell.id] = spell
end
check(
	"Iskra baseMoc=10 baseRez=1 size=1",
	bySpellId.Iskra.baseMoc == 10 and bySpellId.Iskra.baseRez == 1 and bySpellId.Iskra.size == 1
)
check(
	"Echo baseMoc=20 baseRez=2 size=2",
	bySpellId.Echo.baseMoc == 20 and bySpellId.Echo.baseRez == 2 and bySpellId.Echo.size == 2
)
check(
	"Triada baseMoc=40 baseRez=3 size=3",
	bySpellId.Triada.baseMoc == 40 and bySpellId.Triada.baseRez == 3 and bySpellId.Triada.size == 3
)
check(
	"Zywiol baseMoc=35 baseRez=3 size=3",
	bySpellId.Zywiol.baseMoc == 35 and bySpellId.Zywiol.baseRez == 3 and bySpellId.Zywiol.size == 3
)
check(
	"Kaskada baseMoc=60 baseRez=4 size=4",
	bySpellId.Kaskada.baseMoc == 60 and bySpellId.Kaskada.baseRez == 4 and bySpellId.Kaskada.size == 4
)
check(
	"Nawalnica baseMoc=100 baseRez=6 size=5",
	bySpellId.Nawalnica.baseMoc == 100 and bySpellId.Nawalnica.baseRez == 6 and bySpellId.Nawalnica.size == 5
)
check(
	"Konwergencja baseMoc=160 baseRez=10 size=5",
	bySpellId.Konwergencja.baseMoc == 160 and bySpellId.Konwergencja.baseRez == 10 and bySpellId.Konwergencja.size == 5
)

-- TotemConfig: 15 ★ Stworków (Faza 1); STWORKI.md jest kanoniczny.
local totemCount = 0
for _ in TotemConfig.Totems do
	totemCount += 1
end
check("15 MVP totems in TotemConfig", totemCount == 15)
check("kingosaur is Legendary tier", TotemConfig.Totems.kingosaur.tier == "Legendary")
check("coinpurr fires onPlay (economy), not onScore", TotemConfig.Totems.coinpurr.phase == "onPlay")

-- GuardianConfig: 3 typy.
local guardianCount = 0
for _ in GuardianConfig.Guardians do
	guardianCount += 1
end
check("3 guardian types", guardianCount == 3)
check(
	"thresholdWarden covers levels 5-6",
	GuardianConfig.Guardians.thresholdWarden.appliesToLevels[1] == 5
		and GuardianConfig.Guardians.thresholdWarden.appliesToLevels[2] == 6
)

-- GameConfig: 12 progów (GDD §1.4).
check("12 thresholds", #GameConfig.Thresholds == 12)
check("last threshold is 21000 (ZMIANA 3, Faza 3: spłaszczony wykładnik starć 9-12)", GameConfig.Thresholds[12] == 21000)

if failures > 0 then
	error(`{failures} Config test(s) failed`)
end
print("All Config tests passed.")
