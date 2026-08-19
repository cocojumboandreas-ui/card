--!strict
-- Shared/Configs/MarketplaceConfig.luau (Faza 4 Krok 2)
-- JEDNO zrodlo ID-kow gamepassow/dev productow (katalog cen: RUNE_RNG_GDD.md §3). PurchaseService
-- i MonetizationController (Faza 4 Krok 4) czytaja WYLACZNIE stad, zero hardkodowanych ID gdzie
-- indziej. id=0 = PLACEHOLDER dopoki asset nie istnieje w Creator Dashboard -- bezpieczny domyslnie
-- (UserOwnsGamePassAsync z id=0 zawsze zwraca false, wiec brak grantu, nie cichy bug). Kwoty
-- essence/tempBuff sa PLACEHOLDER (GDD daje tylko ceny Robux, nie balans) -- do przejscia w
-- osobnym balance-passie, nie w zakresie Kroku 2 (infrastruktura zakupow).

local MarketplaceConfig = {}

-- Permanentne. stat/mult = pole ktore Faza 4 Krok 3 dopisze do StatProfileService.compute().
MarketplaceConfig.GamePasses = {
	EssenceX2 = { id = 0, priceRobux = 99, stat = "essenceMult", mult = 2 },
	LuckX2 = { id = 0, priceRobux = 149, stat = "luck", mult = 2 },
	FastRolls = { id = 0, priceRobux = 79 }, -- brak stat pola: czysto kliencki flag (skip reveal), czytany bezposrednio przez kontroler (Krok 3 GDD notatka)
	StartPickBonus = { id = 0, priceRobux = 199, stat = "startPickSize", add = 2 }, -- 3 -> 5
	VIP = { id = 0, priceRobux = 449, stat = "essenceMult", mult = 1.25 }, -- +1 quest dzienny / tag / VIP-lobby: POST Faza 4 (patrz StatProfileService.luau:383)
}

-- Konsumowalne. essence = natychmiastowy grant przez EconomyService.AwardEssence. tempBuff/
-- rerollCredits = zapisane w profile.purchases, KONSUMOWANE przez inny system pozniej (RollService/
-- RunShopService) -- Krok 2 tylko GRANTUJE i PAMIETA idempotentnie, podlaczenie czytania to osobna
-- robota poza zakresem tego kroku. serverBuff/guaranteedEpicTotem: swiadomie NIE zaimplementowane
-- w Kroku 2 (brak systemu server-wide buffow / gwarantowanego dropu) -- flaga zapisana w profile
-- jako TODO-marker, zero grantu efektu dopoki nie powstanie konsument.
MarketplaceConfig.DevProducts = {
	EssencePackSmall = { id = 0, priceRobux = 49, essence = 500 },
	EssencePackMedium = { id = 0, priceRobux = 99, essence = 1200 }, -- "BEST VALUE" w UI (Krok 4)
	EssencePackLarge = { id = 0, priceRobux = 249, essence = 3500 },
	EssencePackHuge = { id = 0, priceRobux = 499, essence = 8000 },
	PotionLuckX2 = { id = 0, priceRobux = 29, tempBuff = { stat = "luck", mult = 2, durationSec = 900 } },
	PotionEssenceX2 = { id = 0, priceRobux = 29, tempBuff = { stat = "essenceMult", mult = 2, durationSec = 900 } },
	RerollPackX5 = { id = 0, priceRobux = 29, rerollCredits = 5 },
	ServerLuckX2 = { id = 0, priceRobux = 79, serverBuff = { stat = "luck", mult = 2, durationSec = 1800 } }, -- TODO: brak konsumenta (Faza 4 Krok 2 zakres)
	StarterPack = { id = 0, priceRobux = 199, essence = 1000, guaranteedEpicTotem = true }, -- TODO: guaranteedEpicTotem brak konsumenta

	-- T4: paczki Mega/Super/Legend. packCredit = klucz w PackConfig.Packs ORAZ klucz zapisu w
	-- data.purchases.packCredits (grantDevProduct powyżej) -- konsumowany atomowo przez
	-- PurchaseService.ConsumePackCredit w PackService.OpenPack(method="robux").
	PackMega = { id = 0, priceRobux = 149, packCredit = "Mega" },
	PackSuper = { id = 0, priceRobux = 299, packCredit = "Super" },
	PackLegend = { id = 0, priceRobux = 599, packCredit = "Legend" },
}

return MarketplaceConfig
