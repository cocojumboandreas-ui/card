--!strict
-- SeedUtil — splits one run seed into independent, deterministic named streams (Framework, no
-- Roblox deps). Headless-testable: Roblox's Random.new() is unavailable in the plain `luau` CLI
-- used for `tests/*.test.luau`, so this uses a pure Park-Miller LCG instead (same technique as
-- Drones' CommanderRollCore). Streams never perturb each other — re-rolling the shop must not
-- reshuffle the deck (odpowiedź: strumienie deck/shop/guardian/totemProc).

export type Stream = {
	nextFloat: () -> number, -- [0, 1)
	nextInt: (min: number, max: number) -> number, -- inclusive
	chance: (p: number) -> boolean,
}

local SeedUtil = {}

-- FNV-1a 32-bit over a string — derives an independent integer seed per stream name.
local function fnv1a32(s: string): number
	local hash = 0x811c9dc5
	for i = 1, #s do
		hash = bit32.bxor(hash, string.byte(s, i))
		hash = (hash * 0x01000193) % 0x100000000
	end
	return hash
end

-- Park-Miller minimal-standard LCG: deterministic [0,1) stream from an integer seed.
local function newRng(seed: number): () -> number
	local state = math.floor(seed) % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return function(): number
		state = (state * 16807) % 2147483647
		return (state - 1) / 2147483646
	end
end

-- Faza 3 (SeedService): exposes the same hash used internally for streams, so DailySeed can turn a
-- UTC date key into a deterministic integer without a second, divergent hash implementation.
SeedUtil.hashString = fnv1a32

-- One independent Stream: base seed + stream name are hashed together, so e.g. "shop" and "deck"
-- never share state even though both derive from the same run seed.
function SeedUtil.newStream(seed: number | string, name: string): Stream
	local combined = tostring(seed) .. "#" .. name
	local rng = newRng(fnv1a32(combined))
	rng() -- warm-up: avoids first-output correlation for small/adjacent seeds

	local stream = {} :: Stream

	stream.nextFloat = function(): number
		return rng()
	end

	stream.nextInt = function(min: number, max: number): number
		assert(max >= min, "SeedUtil: nextInt requires max >= min")
		return min + math.floor(rng() * (max - min + 1))
	end

	stream.chance = function(p: number): boolean
		return rng() < p
	end

	return stream
end

-- Canonical Phase-1 stream names (RunSessionService will read from this table).
SeedUtil.StreamNames = { "deck", "shop", "guardian", "totemProc" }

-- One Stream per canonical name, all derived from the same run seed.
function SeedUtil.streams(seed: number | string): { [string]: Stream }
	local result = {}
	for _, name in SeedUtil.StreamNames do
		result[name] = SeedUtil.newStream(seed, name)
	end
	return result
end

-- Fisher-Yates, pure (returns a NEW array; does not mutate `list`).
function SeedUtil.shuffle<T>(list: { T }, stream: Stream): { T }
	local out = table.clone(list)
	for i = #out, 2, -1 do
		local j = stream.nextInt(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

return SeedUtil
