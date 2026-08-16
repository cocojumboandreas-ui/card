--!strict
-- Headless tests for SeedUtil: same-seed determinism, stream independence (re-rolling shop must
-- NOT reshuffle the deck), shuffle correctness. No Studio required (Roblox's Random.new() is
-- unavailable in the plain `luau` CLI, hence the hand-rolled Park-Miller LCG).
--   luau tests/SeedUtil.test.luau

local SeedUtil = require("../src/ReplicatedStorage/Shared/SeedUtil")
local RuneConfig = require("../src/ReplicatedStorage/Shared/Configs/RuneConfig")

local failures = 0
local function check(label: string, cond: boolean)
	if cond then
		print("ok    " .. label)
	else
		failures += 1
		print("FAIL  " .. label)
	end
end

local function deepEqualRunes(a: { RuneConfig.Rune }, b: { RuneConfig.Rune }): boolean
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i].element ~= b[i].element or a[i].value ~= b[i].value then
			return false
		end
	end
	return true
end

-- Ten sam seed + ta sama nazwa strumienia -> identyczna sekwencja.
do
	local s1 = SeedUtil.newStream(777, "deck")
	local s2 = SeedUtil.newStream(777, "deck")
	local same = true
	for _ = 1, 20 do
		if s1.nextFloat() ~= s2.nextFloat() then
			same = false
		end
	end
	check("same seed+name -> identical float sequence", same)
end

-- Różny seed -> (praktycznie na pewno) inna sekwencja.
do
	local s1 = SeedUtil.newStream(1, "deck")
	local s2 = SeedUtil.newStream(2, "deck")
	check("different seed -> different first float", s1.nextFloat() ~= s2.nextFloat())
end

-- Różna nazwa strumienia z tego samego seeda -> niezależne (inne) sekwencje.
do
	local sDeck = SeedUtil.newStream(555, "deck")
	local sShop = SeedUtil.newStream(555, "shop")
	check("same seed, different stream name -> different first float", sDeck.nextFloat() ~= sShop.nextFloat())
end

-- Kluczowa reguła: konsumpcja strumienia "shop" NIE zmienia sekwencji strumienia "deck".
do
	local seed = 12345

	local s1 = SeedUtil.streams(seed)
	local deckOrder1 = SeedUtil.shuffle(RuneConfig.buildDeck(), s1.deck)
	for _ = 1, 25 do
		s1.shop.nextFloat() -- symuluj wiele re-rolli sklepu PO stasowaniu talii
	end

	local s2 = SeedUtil.streams(seed)
	-- s2.shop celowo nietknięty
	local deckOrder2 = SeedUtil.shuffle(RuneConfig.buildDeck(), s2.deck)

	check("deck shuffle unaffected by shop stream consumption", deepEqualRunes(deckOrder1, deckOrder2))
end

-- Symetrycznie: konsumpcja "deck" (tasowanie) nie zmienia sekwencji "shop".
do
	local seed = 999

	local s1 = SeedUtil.streams(seed)
	SeedUtil.shuffle(RuneConfig.buildDeck(), s1.deck) -- konsumuj deck
	local shopRolls1 = { s1.shop.nextInt(1, 100), s1.shop.nextInt(1, 100), s1.shop.nextInt(1, 100) }

	local s2 = SeedUtil.streams(seed)
	-- s2.deck celowo nietknięty
	local shopRolls2 = { s2.shop.nextInt(1, 100), s2.shop.nextInt(1, 100), s2.shop.nextInt(1, 100) }

	check(
		"shop rolls unaffected by deck stream consumption",
		shopRolls1[1] == shopRolls2[1] and shopRolls1[2] == shopRolls2[2] and shopRolls1[3] == shopRolls2[3]
	)
end

-- streams() zwraca dokładnie 4 nazwane strumienie Fazy 1.
do
	local s = SeedUtil.streams(1)
	check("streams() has deck/shop/guardian/totemProc", s.deck ~= nil and s.shop ~= nil and s.guardian ~= nil and s.totemProc ~= nil)
end

-- shuffle: permutacja tej samej talii (ta sama długość, ten sam multiset, oryginał niemutowany).
do
	local original = RuneConfig.buildDeck()
	local originalLen = #original
	local stream = SeedUtil.newStream(42, "deck")
	local shuffled = SeedUtil.shuffle(original, stream)

	check("shuffle preserves length", #shuffled == originalLen)
	check("shuffle does not mutate the input list", #original == originalLen and original[1].value == 1 and original[1].element == "Fire")

	local counts = {}
	for _, rune in shuffled do
		local key = rune.element .. "#" .. rune.value
		counts[key] = (counts[key] or 0) + 1
	end
	local allUnique = true
	for _, count in counts do
		if count ~= 1 then
			allUnique = false
		end
	end
	check("shuffle is a permutation (same multiset)", allUnique)
end

-- nextInt respektuje granice (inclusive).
do
	local stream = SeedUtil.newStream(7, "guardian")
	local inBounds = true
	for _ = 1, 200 do
		local v = stream.nextInt(3, 7)
		if v < 3 or v > 7 then
			inBounds = false
		end
	end
	check("nextInt(3,7) stays within [3,7] over 200 draws", inBounds)
end

if failures > 0 then
	error(`{failures} SeedUtil test(s) failed`)
end
print("All SeedUtil tests passed.")
