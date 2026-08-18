--!strict
-- MergeConfig — zero-magic-numbers dane dla System 3 (Merge/Craft), wzorzec GameConfig/RarityConfig.
-- Zatwierdzone przez Andreasa (MERGE_PLAN_PROPOSAL.md sekcja 7+8, 2026-08-18): rdzeń Common->Uncommon
-- ->Rare, próg 5 (Normal-only — Foil-merge odłożony), essence 50/150, disenchant Rare @30 wszystkie
-- warianty. Liczby to HIPOTEZY STARTOWE (nie zwalidowane bramką ekonomii, patrz STATUS.md) — bramka
-- balansu (runDeckGate) mierzy % ukończeń runu, NIE przepływ essence; strojenie 50/150/30 zostaje na
-- dane z playtestu, nie na "na oko".

local MergeConfig = {}

-- Ile kopii wariantu Normal potrzeba do merge. Foil/Gold/Galaxy/Rainbow/Void NIE są mergowalne w V1
-- (Foil-merge odłożony po-launch, patrz MERGE_PLAN_PROPOSAL.md punkt 6) — tylko disenchantowalne
-- (Rare, patrz DisenchantTier niżej).
MergeConfig.Threshold = {
	Normal = 5,
}

-- Essence do zapłacenia PONAD 5 kart, indeksowane tierem WEJŚCIOWYM (co się merguje, nie co wychodzi).
MergeConfig.EssenceCost = {
	Common = 50,
	Uncommon = 150,
}

-- tier wejściowy -> tier wyjściowy. Brak klucza = tier NIE jest wejściem merge (naturalny cap na
-- Rare, decyzja Andreasa: Epic/Legendary wyłącznie z paczek/rolla, żeby merge nie psuł sensu premium
-- paczek).
MergeConfig.NextTier = {
	Common = "Uncommon",
	Uncommon = "Rare",
}

-- Disenchant: sink dla nadmiaru Rare (ślepy zaułek merge'a, patrz punkt E). Stratny kurs, wszystkie
-- warianty jednakowo (dotarcie do duplikatu Rare+Foil jest już samo w sobie ekstremalnie rzadkie —
-- nie trzeba osobno zabezpieczać). Zostawia zawsze co najmniej 1 kopię (nie da się disenchantować
-- jedynej posiadanej).
MergeConfig.DisenchantTier = "Rare"
MergeConfig.DisenchantValueEssence = 30

return MergeConfig
