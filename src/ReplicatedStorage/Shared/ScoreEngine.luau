--!strict
-- ScoreEngine — pure scoring math (Framework, no Roblox deps, no mutation). Given the runes a
-- player played, the Zaklęcie HandEvaluator picked, and RunState-derived context, computes the
-- final score plus an ordered breakdown for client-side juice. Deterministic: identical input →
-- identical output and identical breakdown.
--
-- Order of operations (confirmed with the designer, mirrors Balatro's Chip×Mult resolution):
--   1) spell base Moc/Rezonans (+ per-spell RunState upgrades, applied upstream in HandEvaluator)
--   2) rune loop, left→right: each rune's own Moc, scaled by any onScore totem's elemental
--      multiplier/wildcard (Frostfawn-style effects), zeroed if its element is nullified
--      (np. Strażnik "Pożeracz Żywiołów")
--   3) totems, left→right (slot order): EACH totem applies its own flat delta then its own mult
--      delta to the running Moc/Rezonans before the next totem runs — this is what makes totem
--      ORDER change the final score (a flat totem before a mult totem compounds differently than
--      after it; see ScoreEngine.test.luau for the numeric proof).
--   4) finalScore = Moc × Rezonans

local RuneConfig = require("./Configs/RuneConfig")
local TotemEngine = require("./TotemEngine")

type Rune = RuneConfig.Rune
type TotemDef = TotemEngine.TotemDef
type TotemApplyResult = TotemEngine.TotemApplyResult

export type SpellResult = {
	spellId: string,
	baseMoc: number,
	baseRezonans: number,
	matchedRunes: { number }?,
}

export type RunState = {
	totems: { TotemDef }?,
	totemState: { [string]: any }?,
	elementNullifiers: { [string]: boolean }?, -- np. Strażnik "Pożeracz Żywiołów" (RunSessionService rozstrzyga KTÓRY żywioł)
}

export type ScoreCtx = {
	rngStream: any?, -- SeedUtil Stream "totemProc"; tylko dla totemów z procChance
}

export type BreakdownStep = {
	source: string, -- "spell" | "rune" | "totem"
	id: string,
	mocDelta: number?,
	rezDelta: number?,
	mult: number?,
}

export type PlayResult = {
	finalScore: number,
	moc: number,
	rezonans: number,
	breakdown: { BreakdownStep },
	totemResults: { TotemApplyResult }, -- surowe wyniki onScore, do aplikacji statePatch/gold przez PlayService
}

local ScoreEngine = {}

function ScoreEngine.score(playedRunes: { Rune }, spellResult: SpellResult, runState: RunState?, ctx: ScoreCtx?): PlayResult
	local rs: RunState = runState or {}
	local sctx: ScoreCtx = ctx or {}
	local totems = rs.totems or {}
	local totemState = rs.totemState or {}
	local nullified = rs.elementNullifiers or {}

	local totemCtx = {
		playedRunes = playedRunes,
		spellId = spellResult.spellId,
		totemState = totemState,
		rngStream = sctx.rngStream,
	}
	local totemResults = TotemEngine.apply(totems, "onScore", totemCtx)

	-- Pre-pass: elemental rune modifiers (Frostfawn-style) + wildcard flag (Rainbowfin-style),
	-- resolved BEFORE the rune loop so the loop can read them per rune.
	local elementMult: { [string]: number } = {}
	local wildcard = false
	for _, res in totemResults do
		if res.applies then
			if res.delta.mocMultElement then
				local em = res.delta.mocMultElement
				elementMult[em.element] = (elementMult[em.element] or 1) * em.factor
			end
			if res.delta.elementWildcard then
				wildcard = true
			end
		end
	end

	local breakdown: { BreakdownStep } = {}
	table.insert(breakdown, {
		source = "spell",
		id = spellResult.spellId,
		mocDelta = spellResult.baseMoc,
		rezDelta = spellResult.baseRezonans,
	})

	local moc = spellResult.baseMoc
	local rez = spellResult.baseRezonans

	for i, rune in playedRunes do
		local basePower = RuneConfig.power(rune)
		local mult = 1
		if wildcard then
			for _, factor in elementMult do
				mult *= factor
			end
		else
			mult = elementMult[rune.element] or 1
		end
		if nullified[rune.element] and not wildcard then
			mult = 0
		end
		local runeMoc = basePower * mult
		moc += runeMoc
		table.insert(breakdown, { source = "rune", id = `#{i}:{rune.element}{rune.value}`, mocDelta = runeMoc })
	end

	-- Totemy w kolejności slotów: KAŻDY totem aplikuje swoją deltę do bieżącego stanu przed
	-- kolejnym — to sprawia, że kolejność totemów zmienia wynik.
	for _, res in totemResults do
		if res.applies then
			if res.delta.mocFlat then
				moc += res.delta.mocFlat
				table.insert(breakdown, { source = "totem", id = res.totemId, mocDelta = res.delta.mocFlat })
			end
			if res.delta.mocMult then
				moc *= res.delta.mocMult
				table.insert(breakdown, { source = "totem", id = res.totemId, mult = res.delta.mocMult })
			end
			if res.delta.rezFlat then
				rez += res.delta.rezFlat
				table.insert(breakdown, { source = "totem", id = res.totemId, rezDelta = res.delta.rezFlat })
			end
			if res.delta.rezMult then
				rez *= res.delta.rezMult
				table.insert(breakdown, { source = "totem", id = res.totemId, mult = res.delta.rezMult })
			end
		end
	end

	return {
		finalScore = moc * rez,
		moc = moc,
		rezonans = rez,
		breakdown = breakdown,
		totemResults = totemResults,
	}
end

return ScoreEngine
