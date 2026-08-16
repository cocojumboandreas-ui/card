--!strict
-- Framework/ServiceRegistry.luau
-- Generyczny service-locator (wzorzec z RNG/Brainrot Fighters, bez configure()).
-- Kontrakt: register() -> initAll() -> startAll(). get() wolno dopiero w Start().
-- Framework NIE importuje z Content/Shared. ZERO zaleznosci w dol.
--
-- RÓŻNICA vs port źródłowy (RNG Framework/ServiceRegistry.luau): initAll/startAll owijają KAŻDE
-- Init()/Start() w pcall (Architektura §1: "bootstrap ServiceRegistry Z PCALL — lekcja z audytu
-- RNG!"). W RNG błąd w jednym serwisie potrafił ubić initAll/startAll bez jasnej atrybucji, co
-- utrudniało debugging. Tu: błąd jednego serwisu jest logowany z nazwą+fazą i NIE zatrzymuje
-- pozostałych — symetria z klientem (init.client: pcall per kontroler, patrz Architektura §3).

export type Service = {
	Name: string?,
	Init: (() -> ())?,
	Start: (() -> ())?,
	[any]: any,
}

local ServiceRegistry = {}

local _services: { [string]: Service } = {}
local _order: { string } = {}
local _initDone = false
local _startDone = false

-- Rejestracja. Kolejnosc rejestracji = deterministyczna kolejnosc Init/Start.
function ServiceRegistry.register(name: string, service: Service): Service
	assert(type(name) == "string" and name ~= "", "service name must be a non-empty string")
	assert(_services[name] == nil, "duplicate service: " .. name)
	assert(type(service) == "table", "service '" .. name .. "' must be a table")
	_services[name] = service
	table.insert(_order, name)
	if service.Name == nil then
		service.Name = name
	end
	return service
end

-- Pobranie zarejestrowanego serwisu. Blad jesli brak. Wolac w Start(), nigdy w Init().
function ServiceRegistry.get(name: string): Service
	local s = _services[name]
	assert(s ~= nil, "service not registered: " .. tostring(name))
	return s
end

function ServiceRegistry.has(name: string): boolean
	return _services[name] ~= nil
end

-- Kolejnosc rejestracji (kopia) — do testow/diagnostyki.
function ServiceRegistry.getOrder(): { string }
	return table.clone(_order)
end

-- Init wszystkich w kolejnosci rejestracji. Init() NIE dotyka innych serwisow. Kazdy Init() w
-- osobnym pcall — blad jednego serwisu nie blokuje Init pozostalych (jasna atrybucja w output).
function ServiceRegistry.initAll()
	assert(not _initDone, "initAll already ran")
	_initDone = true
	for _, name in ipairs(_order) do
		local s = _services[name]
		if type(s.Init) == "function" then
			local ok, err = pcall(s.Init :: any)
			if ok then
				print("[ServiceRegistry] Init " .. name)
			else
				warn("[ServiceRegistry] Init FAILED for " .. name .. ": " .. tostring(err))
			end
		end
	end
end

-- Start wszystkich po Init. Tu wolno ServiceRegistry.get() innych serwisow. Kazdy Start() w
-- osobnym pcall — ta sama izolacja co Init (jeden zepsuty serwis nie ubija reszty bootstrapu).
function ServiceRegistry.startAll()
	assert(_initDone, "startAll called before initAll")
	assert(not _startDone, "startAll already ran")
	_startDone = true
	for _, name in ipairs(_order) do
		local s = _services[name]
		if type(s.Start) == "function" then
			local ok, err = pcall(s.Start :: any)
			if ok then
				print("[ServiceRegistry] Start " .. name)
			else
				warn("[ServiceRegistry] Start FAILED for " .. name .. ": " .. tostring(err))
			end
		end
	end
end

return ServiceRegistry
