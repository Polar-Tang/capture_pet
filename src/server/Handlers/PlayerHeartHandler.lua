-- a simple handler for cooldowns
-- but we don't use this class directly, we access to its registry instead

local _PlayerHeart = {}
_PlayerHeart.__index = _PlayerHeart

function _PlayerHeart.new(player)

	local self = setmetatable({}, _PlayerHeart)
	self.isAppease = false
	
	return self
end


function _PlayerHeart:Appease(num)
	self.isAppease = true
	task.delay(num, function()
		self.isAppease = false
	end)
end
-- Utilize the registry pattern for the player handler
local PlayerHearthRegistry = {}

PlayerHearthRegistry.__index = PlayerHearthRegistry

PlayerHearthRegistry._players = {}
-- initialize a player handler
function PlayerHearthRegistry:InitPlayer(player)
	local handler = _PlayerHeart.new(player)
	self._players[player.UserId] = handler
end

-- accept a player
-- Get the player handler
-- return the particular player handler
function PlayerHearthRegistry:GetHandler(player)
	local thePlayer = self._players[player.UserId]
	return self._players[player.UserId]
end

-- accept a player
-- remove the player instance
-- return nil
function PlayerHearthRegistry:RemovePlayer(player)
	self._players[player.UserId] = nil
end

return PlayerHearthRegistry
