--!strict
-- Controllers/UIRootController.luau (Architektura §3, kontroler #2) — tworzy ScreenGui-rooty raz,
-- z jawnie ROSNĄCYM DisplayOrder (mina WAR RNG: domyślny/niski DisplayOrder ginie pod innymi UI).
-- Faza 2a: placeholdery są kolorowymi blokami budowanymi w kodzie (UIFactory), więc "klonowanie
-- UITemplates" z Architektury §3 tu nie występuje -- patrz komentarz na górze UIFactory.luau.
-- Wszystkie kontenery w kontrolerach niżej używają UDim2.fromScale, więc skalują się do ekranu
-- telefonu (portrait-first) bez dodatkowego UIAspectRatioConstraint na tym etapie placeholderów.

local UIRootController = {}

-- Kolejność = kolejność Z (rosnący DisplayOrder = bliżej wierzchu).
local ROOTS = {
	{ name = "Hud", order = 10 },
	{ name = "Hand", order = 15 },
	{ name = "RunFlow", order = 20 },
	{ name = "Roll", order = 25 }, -- Faza 2b: reveal rolla, nad RunFlow, pod Shop
	{ name = "Shop", order = 30 },
	{ name = "StartPick", order = 32 }, -- Faza 4 Krok 0: modal picku startowego, nad Shop (pierwsza decyzja runu)
	{ name = "ScoreFx", order = 40 },
	{ name = "Index", order = 45 }, -- Faza 2b: panel kolekcji, nad ScoreFx
	{ name = "Toast", order = 50 }, -- Faza 3: krótkie popupy (offline earn, streak, questy...), zawsze na wierzchu
}

local _guis: { [string]: ScreenGui } = {}

function UIRootController.Get(name: string): ScreenGui
	local gui = _guis[name]
	assert(gui ~= nil, "UIRootController: unknown root '" .. tostring(name) .. "'")
	return gui
end

function UIRootController.Init() end

function UIRootController.Start()
	local UIFactory = require(script.Parent.UIFactory)
	for _, root in ROOTS do
		_guis[root.name] = UIFactory.screenGui("Rune_" .. root.name, root.order)
	end
end

return UIRootController
