return function(player): Tool?
	for _, child in pairs(player.Character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end
