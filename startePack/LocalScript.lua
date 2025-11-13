local Tool: Tool = script.Parent
-- the script responsible for "printing the trajectory" in the client
local peephole = require(script.Parent.Peephole)

Tool.Equipped:Connect(function(mouse)
	peephole.init()
end)
