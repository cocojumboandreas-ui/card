--!strict
-- RuneConfig — deck definition (Content, no logic). 40 Runes = 5 elements × values 1-8, exactly
-- one copy of each element+value pair (RUNE_RNG_GDD.md §1.2).

export type Rune = { element: string, value: number }

local RuneConfig = {}

RuneConfig.Elements = { "Fire", "Water", "Nature", "Lightning", "Shadow" }
RuneConfig.MinValue = 1
RuneConfig.MaxValue = 8
RuneConfig.PowerPerValue = 5 -- Moc bazowa runy = wartość × 5

function RuneConfig.power(rune: Rune): number
	return rune.value * RuneConfig.PowerPerValue
end

-- Canonical unshuffled 40-Rune deck (one of each element+value pair).
function RuneConfig.buildDeck(): { Rune }
	local deck = {}
	for _, element in RuneConfig.Elements do
		for value = RuneConfig.MinValue, RuneConfig.MaxValue do
			table.insert(deck, { element = element, value = value })
		end
	end
	return deck
end

return RuneConfig
