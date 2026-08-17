--!strict
-- RankedConfig (Faza 3 krok #4, zasada 12) — neutralna, stała pula Totemów dla trybu ranked.
-- Skład potwierdzony przez Andreasa (Wariant A, 2026-08-17): pokrywa wszystkie 3 rodziny
-- (flat/multiplikatywny/skalujący), tiery Common->Legendary, zero totemów zależnych od
-- konkretnego spellId. Używane WYŁĄCZNIE przez RunShopService.availableTotemPool gdy
-- run.mode=="ranked" -- zastępuje normalną pulę (starter Common UNION posiadane przez gracza),
-- która zależy od kolekcji i złamałaby determinizm ranked (dwaj gracze, ten sam Seed Dnia, różna
-- kolekcja, MUSZĄ dostać identyczną ofertę).

local RankedConfig = {}

-- Kolejność ma znaczenie: to jest STAŁY porządek indeksowania w run.streams.shop.nextInt, więc
-- musi zostać niezmieniony między sesjami serwera (inaczej ten sam seed dałby inną ofertę po
-- restarcie/deployu -- pairs() na TotemConfig.Totems nie gwarantuje kolejności, ta lista tak).
RankedConfig.TotemIds = { "emberpup", "frostfawn", "blobby", "coinpurr", "kingosaur" }

return RankedConfig
