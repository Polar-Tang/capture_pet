local Event = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local PickPet = Event:WaitForChild("PickPet")
local ProximityPormp = game:GetService("ProximityPromptService")
local Players = game:GetService("Players")

local PlayerGui = Players.LocalPlayer.PlayerGui

ProximityPormp.PromptShown:Connect(function(prompt)
	local pet = prompt.Parent

	local Billboard = Instance.new("BillboardGui")
	Billboard.Size = UDim2.new(3, 0, 3, 0)
	Billboard.Active = true
	Billboard.AlwaysOnTop = true
	Billboard.Parent = PlayerGui
	Billboard.Adornee = pet
	Billboard.StudsOffset = Vector3.new(0, 2, 0)

	local image = Instance.new("ImageButton")
	image.Size = UDim2.new(1, 0, 1, 0)
	image.BackgroundTransparency = 1
	image.ZIndex = 2
	image.Image = "rbxassetid://95971433898404"
	image.Activated:Connect(function()
		PickPet:FireServer(prompt)
	end)
	image.Parent = Billboard
end)
