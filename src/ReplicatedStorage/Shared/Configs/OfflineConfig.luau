--!strict
-- OfflineConfig — Faza 3, OfflineEarnService. Cap na godziny offline, port wzorca z D:/RobloxProjects/rng
-- EconomyService.ComputeOfflineEarnings (3 guardy: first-login, clock-skew, cap).
--
-- T3 (2026-08-19, pasywna esencja z tycoon-plotu): stawka przestała być flat -- teraz to
-- PlotService.RatePerSecond(profile.plotSlots), esencja z WYSTAWIONYCH KART, nie darmowy
-- AFK-bonus. EssencePerHour USUNIĘTE (martwy config po tej zmianie, patrz EssenceRateConfig).

local OfflineConfig = {}

OfflineConfig.CapHours = 10 -- w paśmie 8-12h sugerowanym przy T3, bez zmian

return OfflineConfig
