--!strict
-- ShopConfig — sklep W RUNIE (RUNE_RNG_GDD.md §1.5, RUNE_RNG_ARCHITEKTURA.md §1 repo layout names
-- this file explicitly). 3 STAŁE sloty co wizytę: Totem / Ulepszenie Zaklęcia / Zwój — nie losowe
-- typy slotów. Zwój = zawsze manipulacja talią (zmień żywioł / usuń runę / duplikuj runę), więc
-- gwarancja "min. 1 Zwój manipulacji talią na wizytę" (GDD §1.5) jest spełniona strukturalnie przez
-- sam fakt istnienia slotu 3, nie osobną logiką.
--
-- Wszystkie liczby poniżej to PLACEHOLDER — nie pochodzą z GDD/Architektury (żaden dokument nie
-- podaje cen sklepowych), do stuningowania w trakcie 20-run walidacji krzywej. Zero-magic-numbers:
-- żywią tu, nie w RunShopService.

local ShopConfig = {}

ShopConfig.TotemPriceByTier = {
	Common = 10,
	Uncommon = 20,
	Rare = 35,
	Epic = 60,
	Legendary = 120,
}

-- ZMIANA 2 (Faza 3 balance pass): ulepszenie jest MULTIPLIKATYWNE na Rezonansie bazowym Zaklęcia
-- (nie płaski dodatek) — druga geometryczna dźwignia obok Totemów, kupowalna za nadwyżkowe złoto
-- z Wariantu B. Compounding: kolejny zakup na TYM SAMYM Zaklęciu mnoży rezMult *= factor (nie sumuje).
ShopConfig.SpellUpgradePrice = 25
ShopConfig.SpellUpgradeRezMultPerPurchase = 1.8

ShopConfig.ScrollPrice = 15
-- Wszystkie 3 kinds to manipulacja talią (GDD §1.5) — gwarancja jest więc automatyczna.
ShopConfig.ScrollKinds = { "changeElement", "removeRune", "duplicateRune" }

ShopConfig.RerollBaseCost = 5
ShopConfig.RerollCostStep = 5 -- rośnie o tyle za każdy reroll w TEJ wizycie sklepu

return ShopConfig
