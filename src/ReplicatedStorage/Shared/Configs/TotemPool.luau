--!strict
-- TotemPool — the ONE pool RollService.selectTotem draws from AND the ONE source PolicyService
-- reads to compute the odds table shown to the player. Extracted from RollService (was a private
-- `totemsSorted()` local) so display and roll can never independently drift out of sync again --
-- before this file existed, PolicyService.computeTierOdds modeled "1 totem per tier" while
-- RollService's real pool has ONE ENTRY PER TOTEM (10 Common/5 Uncommon/4 Rare/4 Epic/2 Legendary),
-- so the displayed table understated every non-Common tier 2-4x (see STATUS.md, odds-bug fix).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Configs")
local TotemConfig = require(Shared:WaitForChild("TotemConfig"))
local RarityConfig = require(Shared:WaitForChild("RarityConfig"))

export type PoolEntry = { id: string, tier: string, weight: number }

local TotemPool = {}

-- Sorted MALEJĄCO po tier-weight (najrzadsze pierwsze) -- identyczna kolejność, jakiej używa
-- RollService.selectTotem. Statyczny roster w runtime, więc liczony raz i cache'owany.
local _sorted: { PoolEntry }? = nil
function TotemPool.sorted(): { PoolEntry }
	if _sorted then
		return _sorted
	end
	local arr = {}
	for id, totem in TotemConfig.Totems do
		local weight = RarityConfig.TierWeight[totem.tier]
		assert(weight ~= nil, "TotemPool: TotemConfig tier '" .. tostring(totem.tier) .. "' has no RarityConfig.TierWeight entry")
		arr[#arr + 1] = { id = id, tier = totem.tier, weight = weight }
	end
	table.sort(arr, function(a, b)
		return a.weight > b.weight
	end)
	_sorted = arr
	return arr
end

return TotemPool
