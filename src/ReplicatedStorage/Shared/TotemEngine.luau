--!strict
-- TotemEngine — pure, config-driven Totem effect resolution (Framework, no Roblox deps, no
-- mutation). Iterates totems in SLOT ORDER (order matters — see ScoreEngine, which applies each
-- totem's delta sequentially so slot order changes the final score), evaluates each one's
-- condition exactly once per call, and returns a delta + optional statePatch. Never mutates
-- `totems`/`ctx`/RunState — the caller (ScoreEngine / a future PlayService) is the sole authority
-- for applying deltas and persisting statePatch.

export type TotemDef = {
	id: string,
	name: string,
	tier: string,
	element: string?,
	phase: string, -- "onScore" | "onPlay" | "onSwap" | "onShop" | "onRoundStart" | "onFail"
	condition: string,
	conditionArg: any,
	effect: { [string]: any },
}

export type TotemCtx = {
	playedRunes: { any }?,
	spellId: string?,
	totemState: { [string]: any }?,
	rngStream: any?, -- SeedUtil Stream ("totemProc"); required only for procChance totems
}

export type TotemDelta = { [string]: any }

export type TotemApplyResult = {
	totemId: string,
	applies: boolean,
	delta: TotemDelta,
	statePatch: { [string]: any }?,
}

local TotemEngine = {}

local Conditions: { [string]: (ctx: TotemCtx, arg: any, totemId: string) -> boolean } = {}

Conditions.always = function(_ctx, _arg, _totemId)
	return true
end

Conditions.playContainsElement = function(ctx, arg, _totemId)
	for _, rune in ctx.playedRunes or {} do
		if rune.element == arg then
			return true
		end
	end
	return false
end

Conditions.exactPlayedCount = function(ctx, arg, _totemId)
	return #(ctx.playedRunes or {}) == arg
end

Conditions.playedCountAtLeast = function(ctx, arg, _totemId)
	return #(ctx.playedRunes or {}) >= arg
end

Conditions.spellIs = function(ctx, arg, _totemId)
	return ctx.spellId == arg
end

-- "Raz na starcie" gate (np. Dawn Phoenix) — czyta ctx.totemState[totemId].used, nie mutuje.
Conditions.notYetTriggeredThisEncounter = function(ctx, _arg, totemId)
	local state = ctx.totemState and ctx.totemState[totemId]
	return not (state and state.used)
end

TotemEngine.Conditions = Conditions

local function resolveCondition(totem: TotemDef, ctx: TotemCtx): boolean
	local fn = Conditions[totem.condition]
	assert(fn ~= nil, `TotemEngine: unknown condition '{totem.condition}' on totem '{totem.id}'`)
	return fn(ctx, totem.conditionArg, totem.id)
end

-- Applies all `phase`-matching totems, in slot order, exactly once each. Returns one
-- TotemApplyResult per matching totem (even when its condition didn't hold), so the caller can
-- render "why did/didn't this totem fire" in the UI breakdown.
function TotemEngine.apply(totems: { TotemDef }, phase: string, ctx: TotemCtx): { TotemApplyResult }
	local results = {}

	for _, totem in totems do
		if totem.phase ~= phase then
			continue
		end

		local applies = resolveCondition(totem, ctx)
		local delta: TotemDelta = {}
		local statePatch: { [string]: any }? = nil

		if applies then
			local effect = totem.effect

			if effect.mocFlat then
				delta.mocFlat = effect.mocFlat
			end
			if effect.rezFlat then
				delta.rezFlat = effect.rezFlat
			end
			if effect.rezMult then
				delta.rezMult = effect.rezMult
			end
			if effect.mocMult then
				delta.mocMult = effect.mocMult
			end
			if effect.mocMultElement then
				delta.mocMultElement = effect.mocMultElement
			end
			if effect.elementWildcard then
				delta.elementWildcard = true
			end
			if effect.mocPerRune then
				delta.mocFlat = (delta.mocFlat or 0) + effect.mocPerRune * #(ctx.playedRunes or {})
			end
			if effect.goldFlat then
				delta.goldFlat = effect.goldFlat
			end
			if effect.extraPlay then
				delta.extraPlay = effect.extraPlay
			end
			if effect.extraSwap then
				delta.extraSwap = effect.extraSwap
			end

			-- Generyczny "rośnie w runie" (Faza 2 balance pass): stacks++ za KAŻDĄ aplikację (condition
			-- już decyduje KIEDY totem się liczy — np. spellIs/always/exactPlayedCount), amount = perTrigger
			-- * stacks. To geometryczne źródło mocy: jeden totem, rosnąca kontrybucja co starcie/zagranie.
			if effect.scalingFlat then
				local cfg = effect.scalingFlat
				local state = (ctx.totemState and ctx.totemState[totem.id]) or { stacks = 0 }
				local stacks = (state.stacks or 0) + 1
				local amount = cfg.perTrigger * stacks
				if cfg.stat == "moc" then
					delta.mocFlat = (delta.mocFlat or 0) + amount
				else
					delta.rezFlat = (delta.rezFlat or 0) + amount
				end
				statePatch = statePatch or {}
				statePatch.stacks = stacks
			end

			if effect.scalingGold then
				local cfg = effect.scalingGold
				local state = (ctx.totemState and ctx.totemState[totem.id]) or { stacks = 0 }
				local stacks = (state.stacks or 0) + 1
				delta.goldFlat = (delta.goldFlat or 0) + cfg.perTrigger * stacks
				statePatch = statePatch or {}
				statePatch.stacks = stacks
			end

			if effect.procChance then
				local roll = ctx.rngStream
				assert(roll ~= nil, `TotemEngine: totem '{totem.id}' needs ctx.rngStream for procChance`)
				if roll.chance(effect.procChance.chance) then
					for key, value in effect.procChance.onSuccess do
						delta[key] = value
					end
				end
			end

			if effect.revive then
				delta.revive = true
				delta.extraPlay = (delta.extraPlay or 0) + (effect.reviveExtraPlay or 0)
				statePatch = statePatch or {}
				statePatch.used = true
			end
		end

		table.insert(results, {
			totemId = totem.id,
			applies = applies,
			delta = delta,
			statePatch = statePatch,
		})
	end

	return results
end

return TotemEngine
