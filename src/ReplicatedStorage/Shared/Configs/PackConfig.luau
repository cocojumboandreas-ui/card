--!strict
-- Shared/Configs/PackConfig.luau (T4) — trzy płatne paczki (Mega/Super/Legend), KAŻDA z WŁASNĄ
-- niezależną tierTable (nie global RarityConfig/TotemPool kaskada jak RollService.selectTotem --
-- paczki mają eskalujące, jawnie disclosed tabele, wzorzec compliance VariantConfig.ladder).
--
-- PackService.OddsTable zwraca tierTable BEZ ŻADNEJ transformacji (bezpośrednia referencja do tej
-- samej tabeli, którą czyta selectPackTier) -- silniejsza gwarancja single-source-of-truth niż nawet
-- PolicyService.computeTierOdds (tam jest domknięta matematyka kaskady, tu zero kroku pośredniego).
--
-- Legend: guaranteeLegendaryLast=true -- karta #cards ZAWSZE Legendary (deterministycznie, PackService
-- pomija tierTable na tym slocie). tierTable Legend opisuje TYLKO karty 1..cards-1 (9 niezależnych
-- losowań) -- ujawniane graczowi LITERALNIE jako osobna linia "Karta 10: gwarantowany Legendary", NIE
-- zblendowane w jeden %, decyzja Andreasa (T4 plan).
--
-- Ceny/liczności = TUNING-PENDING (startowe wartości z zatwierdzonego planu T4, do balansu później).
-- Esencja-ceny kotwiczone o GameConfig.RollCostEssence=50: Mega 600(=12 rolli), Super 1400(=28),
-- Legend 3200(=64) -- świadomie znacznie droższe niż seria pojedynczych rolli, bo gwarantują WIĘCEJ
-- kart NARAZ + (Legend) gwarancję Legendary, którą pojedynczy roll nigdy nie daje.
--
-- Paczki NIE dotykają data.pity/data.lifetimeRolls (decyzja Andreasa, T4 plan) -- osobny tor od
-- RollService.RollTotem, żeby zakup paczki nie resetował/karmił pity gracza rollującego esencją.

local PackConfig = {}

export type TierEntry = { tier: string, pct: number }
export type PackDef = {
	cards: number,
	guaranteeLegendaryLast: boolean,
	priceRobux: number,
	priceEssence: number,
	tierTable: { TierEntry },
}

PackConfig.Packs = {
	Mega = {
		cards = 5,
		guaranteeLegendaryLast = false,
		priceRobux = 149,
		priceEssence = 600,
		tierTable = {
			{ tier = "Common", pct = 50 },
			{ tier = "Uncommon", pct = 30 },
			{ tier = "Rare", pct = 13 },
			{ tier = "Epic", pct = 4 },
			{ tier = "Legendary", pct = 3 },
		},
	},
	Super = {
		cards = 8,
		guaranteeLegendaryLast = false,
		priceRobux = 299,
		priceEssence = 1400,
		tierTable = {
			{ tier = "Common", pct = 40 },
			{ tier = "Uncommon", pct = 30 },
			{ tier = "Rare", pct = 17 },
			{ tier = "Epic", pct = 7 },
			{ tier = "Legendary", pct = 6 },
		},
	},
	Legend = {
		cards = 10,
		guaranteeLegendaryLast = true,
		priceRobux = 599,
		priceEssence = 3200,
		tierTable = {
			{ tier = "Common", pct = 25 },
			{ tier = "Uncommon", pct = 30 },
			{ tier = "Rare", pct = 20 },
			{ tier = "Epic", pct = 10 },
			{ tier = "Legendary", pct = 15 },
		},
	},
} :: { [string]: PackDef }

-- COMPLIANCE: każda tierTable musi sumować się do DOKŁADNIE 100 -- to co widzi gracz w "?" MUSI być
-- kompletnym rozkładem prawdopodobieństwa. Assert przy load-time (nie runtime check gdzieś głęboko),
-- błąd w tabeli zatrzymuje serwer od razu, nie po pierwszym zakupie.
for packKey, def in PackConfig.Packs do
	local sum = 0
	for _, entry in def.tierTable do
		sum += entry.pct
	end
	assert(math.abs(sum - 100) < 0.0001, ("PackConfig: %s.tierTable sums to %.4f, expected 100"):format(packKey, sum))
end

return PackConfig
