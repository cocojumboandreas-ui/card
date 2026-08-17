--!strict
-- IndexConfig — Faza 2b: progi %ukończenia kolekcji (15 MVP Stworków, discovery = jakikolwiek
-- wariant) -> permanentny, KLAIMOWALNY bonus luck (IndexService.ClaimLuck). Wartości PLACEHOLDER,
-- porcja z WAR RNG jako punkt startowy — tuning po graniu, nie blokada.
local IndexConfig = {}

IndexConfig.luckThresholds = {
	{ pct = 25, luck = 0.5 },
	{ pct = 50, luck = 1.0 },
	{ pct = 100, luck = 2.0 },
}

return IndexConfig
