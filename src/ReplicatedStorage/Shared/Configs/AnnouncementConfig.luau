--!strict
-- AnnouncementConfig — Faza 3 krok #8, AnnouncementService. Próg "rzadki drop" (Architektura §2
-- linia 74: "próg z GameConfig, np. 1/10k"). Świadomie NOWY plik zamiast dopisania do GameConfig —
-- ten sam wzorzec co reszta Fazy 3 (LeaderboardConfig/StreakConfig/QuestConfig), zero-magic-numbers
-- per-feature, nie jedna rosnąca kupa w GameConfig.
--
-- Próg zdefiniowany STRUKTURALNIE (odczyt RarityConfig/VariantConfig), nie jako twarda liczba %,
-- bo cascade tieru w RollService jest sekwencyjny divide-by-N (nie proste udziały wagowe) — patrz
-- komentarz w RarityConfig. Math checkpoint (Faza 2b, n=200000) zmierzył Legendary ~1.1%;
-- VariantConfig.ladder ma Galaxy=1% (dokładne z definicji, compliance table). Iloczyn niezależnych
-- rolli (tier i wariant są rollowane osobno w RollService): 1.1% * 1% ≈ 0.011% ≈ 1 na 9090 —
-- rząd wielkości dokładnie zgodny z "np. 1/10k" z architektury. Rainbow (0.1%) jest rzadszy jeszcze
-- o rząd wielkości (~1/90900) i też się kwalifikuje (MaxVariantPct=1 obejmuje oba).
local AnnouncementConfig = {}

AnnouncementConfig.MinTier = "Legendary" -- najrzadszy tier w RarityConfig.TierWeight
AnnouncementConfig.MaxVariantPct = 1 -- VariantConfig.ladder wpisy z pct <= to się kwalifikują (dziś: Galaxy=1, Rainbow=0.1)

-- Nazwa topicu MessagingService (cross-server pub/sub). Wersjonowana jak nazwy OrderedDataStore
-- w LeaderboardConfig — zmiana kształtu payloadu = nowa nazwa, stare wiadomości nigdy nie mieszają
-- się ze starym formatem.
AnnouncementConfig.Topic = "RollARune_RareDrop_v1"

return AnnouncementConfig
