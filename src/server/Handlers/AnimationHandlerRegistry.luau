local AnimationHandler = require(RepStore.Handlers.AnimationHandler)

-- Use this registry pattern
local AnimationHandlerRegistry = {}

AnimationHandlerRegistry.__index = AnimationHandlerRegistry
AnimationHandlerRegistry._players = {}

-- initialize a player handler
function AnimationHandlerRegistry:InitPlayer(player)
	local handler = AnimationHandler.new(player)
	self._players[player.UserId] = handler
end

--[[ accept a player
-- Get the player handler
-- return the particular player handler
]]

function AnimationHandlerRegistry:GetHandler(player)
	return self._players[player.UserId]
end

--[[ accept a player
-- remove the player instance
-- return nil
]]
function AnimationHandlerRegistry:RemovePlayer(player)
	self._players[player.UserId] = nil
end
