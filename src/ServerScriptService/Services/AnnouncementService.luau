--!strict
-- AnnouncementService (Faza 3 krok #8, Architektura §2 linia 74) — globalne ogłoszenia rzadkich
-- dropów. Nasłuchuje TEGO SAMEGO RollService.Rolled co QuestService/IndexService (zero nowego
-- sygnału, patrz komentarz w RollService.Rolled).
--
-- Cross-server: MessagingService (Roblox pub/sub między instancjami serwera tej samej gry).
-- Kluczowa decyzja architektoniczna: klient dostaje ogłoszenie WYŁĄCZNIE z callbacku
-- SubscribeAsync, NIGDY bezpośrednim FireAllClients zaraz po rollu. Powód: serwer, który publikuje
-- na topic, JEST TEŻ subskrybentem własnego topicu (udokumentowane zachowanie MessagingService) —
-- gdyby ogłaszać od razu PLUS w callbacku, gracze na serwerze-źródle dostaliby duplikat. Jeden
-- kod-path, jednolity dla wszystkich serwerów (w tym tego, na którym drop się wydarzył).
--
-- `AnnouncementService.Announced` (Signal lokalny) odpala się NATYCHMIAST na serwerze-źródle,
-- PRZED rundtripem MessagingService — hook na przyszłość dla server-side logiki (np. analytics),
-- świadomie NIE napędza UI klienta (to robi SubscribeAsync, patrz wyżej).
--
-- PublishAsync/SubscribeAsync to wywołania sieciowe zewnętrzne -> Z PCALL (Architektura §1),
-- warn zamiast crasha przy limicie/awarii MessagingService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService = game:GetService("MessagingService")

local Framework = ReplicatedStorage:WaitForChild("Framework")
local ServiceRegistry = require(Framework:WaitForChild("ServiceRegistry"))
local Net = require(Framework:WaitForChild("Net"))
local Signal = require(Framework:WaitForChild("Signal"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnnouncementConfig = require(Shared.Configs.AnnouncementConfig)
local VariantConfig = require(Shared.Configs.VariantConfig)

local AnnouncementService = {}

local function variantPct(variantId: string): number?
	for _, v in VariantConfig.ladder do
		if v.id == variantId then
			return v.pct
		end
	end
	return nil
end

local function qualifies(tier: string, variantId: string): boolean
	local pct = variantPct(variantId)
	if pct == nil then
		return false -- np. Void: poza paid ladder, nie powinno tu w ogóle dotrzeć, ale defensywnie
	end
	return tier == AnnouncementConfig.MinTier and pct <= AnnouncementConfig.MaxVariantPct
end

function AnnouncementService.Init()
	AnnouncementService.Announced = Signal.new() -- (payload) lokalny, patrz komentarz u góry pliku
end

function AnnouncementService.Start()
	local RollService = ServiceRegistry.get("RollService")
	local sync = Net.get("AnnouncementSync")

	local ok, subscription = pcall(function()
		return MessagingService:SubscribeAsync(AnnouncementConfig.Topic, function(message)
			sync:FireAllClients(message.Data)
		end)
	end)
	if not ok then
		warn("[AnnouncementService] SubscribeAsync failed: " .. tostring(subscription))
	end

	RollService.Rolled:Connect(function(player: Player, result)
		if not qualifies(result.tier, result.variant) then
			return
		end
		local payload = {
			name = player.DisplayName,
			totemId = result.totemId,
			tier = result.tier,
			variant = result.variant,
		}
		AnnouncementService.Announced:Fire(payload)
		local pubOk, pubErr = pcall(function()
			MessagingService:PublishAsync(AnnouncementConfig.Topic, payload)
		end)
		if not pubOk then
			warn("[AnnouncementService] PublishAsync failed: " .. tostring(pubErr))
		end
	end)
end

-- Hook TYLKO do testów.
function AnnouncementService._QualifiesForTest(tier: string, variantId: string): boolean
	return qualifies(tier, variantId)
end

return AnnouncementService
