local neutralSpawns = {}
local teamSpawns = {}
local connections = {}

settings = require ('settings', true)
if settings then
	settings:Add('CharacterAutoLoads','bool',true)
	settings:Add('RespawnCooldown','number',5)
else
	settings = {
		CharacterAutoLoads = true;
		RespawnCooldown = 5;
	}
end

local function getHumanoid(character)
	local children = character:GetChildren()
	for i = 1,#children do
		if children[i]:IsA'Humanoid' then
			return children[i]
		end
	end
	return nil
end

local addedPlayers = {}

local function remove(player)
	if addedPlayers[player] then
		addedPlayers[player]:disconnect()
		addedPlayers[player] = nil
	end
end

local function add(player)
	local function respawn()
		if not settings.CharacterAutoLoads then return end
		wait(settings.RespawnCooldown)
		if not settings.CharacterAutoLoads then return end
		return player:LoadCharacter()
	end

	addedPlayers[player] = player.CharacterAdded:connect(function(character)
		local humanoid = getHumanoid(character)
		if humanoid then
			humanoid.Died:connect(respawn)
		end
	end)

	if settings.CharacterAutoLoads then
		player:LoadCharacter()
	end
end

return {
	add = add;
	remove = remove;
}
