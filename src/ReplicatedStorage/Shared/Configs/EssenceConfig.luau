--!strict
-- EssenceConfig — konwersja ulotnego złota runowego -> persystentnej Esencji, na koniec runu
-- (RunSessionService.endEncounter, gdy run.status przechodzi w "won"/"lost"). Zero-magic-numbers
-- rule: ta stawka NIE jest częścią zamrożonego balansu run-wewnętrznego (Totemy/progi/ceny sklepu,
-- patrz GuardianConfig/GameConfig/ShopConfig) — to nowy, osobny gałka meta-progresji, dodana w
-- Fazie 2a. Wartość PLACEHOLDER, do stuningowania po pierwszym playteście z prawdziwą pętlą.

local EssenceConfig = {}

EssenceConfig.RunGoldToEssenceRate = 0.5 -- 1 essence za każde 2 złoto runowe skumulowane w runie

return EssenceConfig
