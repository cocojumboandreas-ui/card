--!nonstrict
-- ServerScriptService/Services/PurchaseService.luau (Faza 4 Krok 2)
-- Real ProcessReceipt + gamepass ownership cache. JEDYNY writer profile.purchases (receipts,
-- rerollCredits, tempBuffs) -- inne serwisy czytaja stad (Krok 3+) przez PurchaseService.HasGamePass/
-- GetRerollCredits, nigdy nie doytkaja profile.purchases wprost.
-- Idempotencja: receiptInfo.PurchaseId zapisany w profile.purchases.receipts PRZED zwroceniem
-- PurchaseGranted -- powtorny ProcessReceipt tego samego PurchaseId (Roblox retry po utracie
-- odpowiedzi) trafia na klucz juz w tabeli i nie granatuje drugi raz.
-- deps: ProfileService, EconomyService, StatProfileService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local Signal = require(Framework:WaitForChild("Signal"))
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local MarketplaceConfig = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs"):WaitForChild("MarketplaceConfig")
)

local PurchaseService = {}

local _profile, _economy, _stat = nil, nil, nil
local _ownedPasses: { [Player]: { [number]: boolean } } = {} -- gamePassId -> owned

local function productKeyFromId(productId: number): string?
	for key, cfg in pairs(MarketplaceConfig.DevProducts) do
		if cfg.id == productId then
			return key
		end
	end
	return nil
end

-- Grant efektow ktore mozna zastosowac NATYCHMIAST (essence/rerollCredits/tempBuff-zapis).
-- serverBuff/guaranteedEpicTotem: brak konsumenta w Kroku 2, celowo pominiete (patrz MarketplaceConfig).
local function grantDevProduct(player: Player, data, productKey: string)
	local cfg = MarketplaceConfig.DevProducts[productKey]
	if cfg.essence and _economy then
		_economy.AwardEssence(player, cfg.essence, "purchase:" .. productKey)
	end
	if cfg.rerollCredits then
		data.purchases.rerollCredits = (data.purchases.rerollCredits or 0) + cfg.rerollCredits
	end
	if cfg.packCredit then
		data.purchases.packCredits = data.purchases.packCredits or {}
		data.purchases.packCredits[cfg.packCredit] = (data.purchases.packCredits[cfg.packCredit] or 0) + 1
	end
	if cfg.tempBuff then
		data.purchases.tempBuffs = data.purchases.tempBuffs or {}
		data.purchases.tempBuffs[cfg.tempBuff.stat] = {
			mult = cfg.tempBuff.mult,
			expiresAt = os.time() + cfg.tempBuff.durationSec,
		}
	end
	PurchaseService.ProductGranted:Fire(player, productKey)
end

local function processReceipt(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = _profile and _profile.GetProfile(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if data.purchases.receipts[receiptInfo.PurchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productKey = productKeyFromId(receiptInfo.ProductId)
	if productKey then
		grantDevProduct(player, data, productKey)
	end

	data.purchases.receipts[receiptInfo.PurchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function refreshGamePasses(player: Player)
	local owned = _ownedPasses[player] or {}
	for _, cfg in pairs(MarketplaceConfig.GamePasses) do
		local ok, result = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, cfg.id)
		owned[cfg.id] = ok and result == true
	end
	_ownedPasses[player] = owned
	if _stat then
		_stat.Recompute(player)
	end
	PurchaseService.GamePassesRefreshed:Fire(player)
end

function PurchaseService.HasGamePass(player: Player, key: string): boolean
	local cfg = MarketplaceConfig.GamePasses[key]
	if not cfg then
		return false
	end
	local owned = _ownedPasses[player]
	return owned ~= nil and owned[cfg.id] == true
end

function PurchaseService.GetRerollCredits(player: Player): number
	local data = _profile and _profile.GetProfile(player)
	return (data and data.purchases.rerollCredits) or 0
end

-- T4 (paczki): odczyt kredytów Robux-paczek (granted idempotentnie w grantDevProduct powyżej).
function PurchaseService.GetPackCredits(player: Player, packKey: string): number
	local data = _profile and _profile.GetProfile(player)
	local credits = data and data.purchases.packCredits
	return (credits and credits[packKey]) or 0
end

-- Atomowy check-and-decrement -- PurchaseService zostaje JEDYNYM writerem profile.purchases nawet
-- dla konsumpcji (PackService woła TO, nie dotyka profile.purchases.packCredits bezpośrednio).
function PurchaseService.ConsumePackCredit(player: Player, packKey: string): boolean
	local data = _profile and _profile.GetProfile(player)
	local credits = data and data.purchases.packCredits
	local n = (credits and credits[packKey]) or 0
	if n < 1 then
		return false
	end
	credits[packKey] = n - 1
	return true
end

function PurchaseService.Init()
	PurchaseService.ProductGranted = Signal.new() -- (player, productKey)
	PurchaseService.GamePassesRefreshed = Signal.new() -- (player)
end

function PurchaseService.Start()
	_profile = ServiceRegistry.get("ProfileService")
	_economy = ServiceRegistry.get("EconomyService")
	_stat = ServiceRegistry.get("StatProfileService")

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _gamePassId, wasPurchased)
		if wasPurchased then
			refreshGamePasses(player)
		end
	end)

	_profile.ProfileLoaded:Connect(function(player)
		refreshGamePasses(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		_ownedPasses[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if _profile.IsLoaded(player) then
			refreshGamePasses(player)
		end
	end
end

-- Hooki TYLKO do testow.
function PurchaseService._InjectForTest(deps)
	_profile, _economy, _stat = deps.profile, deps.economy, deps.stat
end
function PurchaseService._ProcessReceiptForTest(receiptInfo)
	return processReceipt(receiptInfo)
end
function PurchaseService._SetOwnedForTest(player: Player, gamePassId: number, owned: boolean)
	local o = _ownedPasses[player] or {}
	o[gamePassId] = owned
	_ownedPasses[player] = o
end

return PurchaseService
