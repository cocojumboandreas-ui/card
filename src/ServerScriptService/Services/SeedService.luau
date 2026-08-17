--!strict
-- SeedService (Faza 3, Architektura §2) — generacja seedow. Czysta funkcja + os.date, ZADNEGO
-- stanu. DailySeed jest identyczny dla WSZYSTKICH graczy w tej samej dobie UTC (dateKey
-- "YYYYMMDD") -- to jest fundament trybu ranked (zasada 12): Seed Dnia musi byc deterministyczny
-- i wspolny, nigdy losowy per gracz, inaczej leaderboard Seed Dnia nie ma sensu.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SeedUtil = require(ReplicatedStorage.Shared.SeedUtil)

local SeedService = {}

-- "YYYYMMDD" wg UTC -- ten sam klucz dla wszystkich stref czasowych, NIE lokalny czas gracza.
function SeedService.DailyKey(nowUtc: number?): string
	local t = os.date("!*t", nowUtc)
	return string.format("%04d%02d%02d", t.year, t.month, t.day)
end

-- Deterministyczny seed z dateKey -- SAM dateKey (nie zegar/nie gracz) jest jedynym wejsciem, wiec
-- dwoch graczy odpalajacych DailySeed() w tej samej dobie UTC dostaje IDENTYCZNY seed.
function SeedService.DailySeed(nowUtc: number?): number
	local key = SeedService.DailyKey(nowUtc)
	local hash = SeedUtil.hashString("dailyseed#" .. key)
	return (hash % 2147483646) + 1
end

-- Losowy seed runu swobodnego -- PORT 1:1 z inline'a, ktory wczesniej zyl w
-- RunSessionService.Start() (Random.new(), NIGDY SeedUtil -- to MetaRNG, zyje POZA jakimkolwiek
-- nazwanym strumieniem runu, jak roll totemow w RollService).
function SeedService.RandomSeed(): number
	return Random.new():NextInteger(1, 2147483646)
end

-- Passthrough -- seed przekazany np. przez link znajomego (feature na pozniej; hook gotowy teraz).
-- Walidacja typu/zakresu TYLKO (zero zaufania do wejscia od klienta), zadnej dodatkowej logiki --
-- nazwa "FriendSeed" opisuje SKAD pochodzi seed, nie CO z nim robimy.
function SeedService.FriendSeed(rawSeed: number): number?
	if type(rawSeed) ~= "number" or rawSeed ~= rawSeed or rawSeed == math.huge or rawSeed == -math.huge then
		return nil -- NaN/inf/zly typ
	end
	return math.floor(rawSeed) % 2147483647
end

function SeedService.Init() end
function SeedService.Start() end

return SeedService
