-- Odpal w Roblox Studio (execute_luau, datamodel_type="Client", w trakcie Play) PO
-- upload_card_art.py. Open Cloud assetType="Decal" zwraca ID Decala -- opakowuje osobny
-- wewnętrzny asset Image i NIE nadaje się wprost do ImageLabel.Image. Prawdziwe ID do
-- CardArtConfig.Images to Decal.Texture, wyciągnięte przez game:GetObjects().
--
-- Wklej decalIds z oc_manifest_cards.json (assetId per Stworek) i uruchom.

local decalIds = {
	-- capybop = "...",
}

local result = {}
for name, id in pairs(decalIds) do
	local ok, objs = pcall(function()
		return game:GetObjects("rbxassetid://" .. id)
	end)
	if ok and objs[1] and objs[1]:IsA("Decal") then
		result[name] = objs[1].Texture
	else
		result[name] = "ERR:" .. tostring(objs)
	end
end
return result
