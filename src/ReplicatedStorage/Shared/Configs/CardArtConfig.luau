--!strict
-- CardArtConfig — jedyne źródło prawdy id Stworka -> rbxassetid obrazu karty (cardsw/, processed
-- 2026-08-17: RGBA, tło usunięte, 1024x1024, spójna skala). Kontrolery NIE hardcodują assetId --
-- czytają stąd. Brakujący/nil wpis (i asset w moderacji "pending", który jeszcze się nie renderuje)
-- to NORMALNY stan: UIFactory rysuje art jako WARSTWĘ NAD kolorowym blokiem tieru, nie zamiast --
-- jeśli obraz nie załaduje się, kolorowy blok zostaje widoczny, więc nie trzeba nic wykrywać ręcznie.

local CardArtConfig = {}

-- 2026-08-17b: re-upload przez Open Cloud (grupa 175176483, właściciel placu "karta") --
-- pierwszy upload (MCP upload_image) poszedł na indywidualne konto Studio, nie grupę,
-- więc Roblox traktował je jak cudzy asset i klient nigdy ich nie widział (0 błędów w
-- konsoli, po prostu cichy fail). Skrypt: cards/scripts/upload_card_art.py + D:\RobloxProjects\oc_upload.py.
-- Open Cloud assetType="Decal" NIE daje id gotowego do ImageLabel.Image wprost -- Decal
-- opakowuje osobny wewnętrzny asset Image; id niżej to TEKSTURA (Decal.Texture), nie id
-- Decala, wyciągnięta przez cards/scripts/resolve_decal_textures.luau (execute_luau w Studio).
CardArtConfig.Images = {
	capybop = "rbxassetid://121950090652174",
	lotti = "rbxassetid://94161079978337",
	emberpup = "rbxassetid://118458523871140",
	voltmouse = "rbxassetid://83714223015272",
	shadowkit = "rbxassetid://106828973013192",
	quackers = "rbxassetid://85812573625878",
	blobby = "rbxassetid://131511372837064",
	coinpurr = "rbxassetid://105040957119866",
	drakelet = "rbxassetid://134586552951845",
	pixiespark = "rbxassetid://94842827888182",
	merlynx = "rbxassetid://117231232735901",
	frostfawn = "rbxassetid://89519332969476",
	lavacat = "rbxassetid://92304430965455",
	thunderwolf = "rbxassetid://107189263202851",
	kingosaur = "rbxassetid://77927691164146",
	-- astrodrake celowo pominięty -- poza MVP-15 (RUNE_RNG_STWORKI.md §A6), art w cardsw/_not_mvp/.

	-- System 2 (nowe Stworki, 2026-08-18) -- upload przez cards/scripts/upload_card_art.py
	-- (filtr nazw jako argv[1], żeby nie re-uploadować pozostałych 15) + resolve_decal_textures.luau.
	boltpup = "rbxassetid://98074471382346",
	emberwing = "rbxassetid://86498311121284",
	frostnib = "rbxassetid://138585842561232",
	galaxeon = "rbxassetid://125382479572362",
	pebblit = "rbxassetid://81369847695082",
	puffcap = "rbxassetid://131643779083438",
	shardmaw = "rbxassetid://139209865672360",
	sparkfly = "rbxassetid://94874022611678",
	tidalox = "rbxassetid://138273537574496",
	vinelet = "rbxassetid://90264794542654",
} :: { [string]: string }

function CardArtConfig.get(totemId: string): string?
	return CardArtConfig.Images[totemId]
end

return CardArtConfig
