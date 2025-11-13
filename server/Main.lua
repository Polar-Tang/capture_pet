--Services
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local httpService: HttpService = game:GetService("HttpService")
local PLayers = game:GetService("Players")

-- REMOTE EVENTS
local Events = game.ReplicatedStorage:WaitForChild("Events")
local clickEvent: RemoteEvent = Events:WaitForChild("ClickTest")
local PetNew = Events:WaitForChild("PetNew")

-- handler
local handlers = script.Parent:WaitForChild("Handlers")
local PlayerHeartHandler = require(handlers:WaitForChild("PlayerHeartHandler"))

PLayers.PlayerAdded:Connect(function(player)
	PlayerHeartHandler:InitPlayer(player)
end)

-- modules for the pet captured
local Helpers = game:GetService("ReplicatedStorage"):WaitForChild("Helpers")
local treasureVFX = require(Helpers.treasureVFX)
local Find = require(Helpers.FindArray)

-- player on pet captured
local pickPet = function(player, pet, pokeClone)

	-- little security mesure
	if pet:GetAttribute("Captured")  then
		return
	end

	pet:Destroy()
	pokeClone:Destroy()
	PetNew:FireClient(player, pet)
end

-- This is the remote event data
type clickEvenetData = {
	clickPosition: Vector3,
	stop: boolean
}

clickEvent.OnServerEvent:Connect(function(player: Player, data: clickEvenetData)

	if not data and not data.clickPosition  then
		return 
	end
	local humanoid = player.Character:WaitForChild("Humanoid")
	-- client can send stop thruty to cancel the operation
	if data.stop then
		humanoid:UnequipTools()
		return 
	end

	-- playerHeart is a class for cooldowns
	local PlayerHeart = PlayerHeartHandler:GetHandler(player)

	-- check isApeasse, avoid several tasks by several clicks
	if PlayerHeart.isAppease then
		return warn("Must wait")
	else
		PlayerHeart:Appease(2)
	end

	-- create a ball to trhow
	local pokeClone = game.Workspace:FindFirstChild("MagicBall"):Clone()
	pokeClone.Parent = workspace
	-- collection of the ball
	task.delay(15, function()
		pokeClone:Destroy()
	end)

	-- check if the ball is equipped
	local connection: RBXScriptSignal? = nil
	local CHAR = player.Character
	local HRP: BasePart = CHAR.PrimaryPart
	local equippedTool = CHAR:FindFirstChildOfClass("Tool")
	if not equippedTool or equippedTool.Name ~= "MagicBall" then
		return
	end

	-- play throw animation
	local Animator: Animator = humanoid:WaitForChild("Animator")
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://90384503768373"
	local animationTack = Animator:LoadAnimation(animation) 
	animationTack:Play()
	-- initialize the throw ball functionallity
	local markerConnection = animationTack:GetMarkerReachedSignal("throw"):Connect(function()
		humanoid:UnequipTools()

		-- calculate the ball trayectory
		local startPosition = HRP.Position

		-- constsants
		local GRAVITY = Vector3.new(0, -workspace.Gravity, 0)
		local T = 0.5 -- use a fixed time for the ball to reach the target
		local clickPosition = data.clickPosition

		--V1 = P1 - P0 - 0.5*G*T^2/T
		local initialVelocity = (clickPosition - startPosition - 0.5*GRAVITY*T^2) / T
		local t = 0

		-- use the connection for pivoting the ball
		connection = RunService.Heartbeat:Connect(function(deltaTime)
			t += deltaTime

			--// s = s0 + v0*t + 0.5*a*t^2
			local newPos = startPosition  + (initialVelocity * t) + 0.5 * GRAVITY * (t ^ 2)
		
			pokeClone:PivotTo(CFrame.new(newPos))

			-- the ball reached the target when current time is bigger than the fixed time
			if  t >= T then

				connection:Disconnect()

				-- detects parts in 10 radius
				local isPetFound = false
				local animDur = 2 -- dur for the pet captured
				local pet: Model? = nil -- the pet model that might get hit
				local petPrimaryPart = nil
				local parts = workspace:GetPartBoundsInRadius(newPos, 10)

				-- loop all over the parts and detetct if its parent (a model or worksapace) has the isAPet attribute
				for _, part in ipairs(parts) do
					if part.Parent:IsA("Model") then
						-- part child of a pet?
						if part.Parent:GetAttribute("isAPet") then
							pet = part.Parent
							petPrimaryPart = pet.PrimaryPart

							-- declare isPetFound once
							if not isPetFound  then
								isPetFound = true
							end
							
							-- animation for reducing all the pet parts hited
							local tween = TweenService:Create(
								part,
								TweenInfo.new(animDur),
								{ Size = part.Size - Vector3.new(1, 1, 1) }
							)
							tween:Play()
						end
					end
				end
				if isPetFound then

					-- emit a effect
					local brightPart: Part = treasureVFX(petPrimaryPart , animDur)

					
					local pickBallPrompt: ProximityPrompt = Instance.new("ProximityPrompt")
					pickBallPrompt.ActionText = "Pick Ball"
					pickBallPrompt.Name = "Pick Ball"
					pickBallPrompt.KeyboardKeyCode = Enum.KeyCode.Q
					pickBallPrompt.HoldDuration = 0
					pickBallPrompt.Style = Enum.ProximityPromptStyle.Default
					pickBallPrompt.RequiresLineOfSight = false
					pickBallPrompt.MaxActivationDistance = 8
					pickBallPrompt.ClickablePrompt = true
					pickBallPrompt.Parent = pokeClone

					pickBallPrompt.Triggered:Connect(function()
						pickPet(player, pet, pokeClone)
					end)
				

				end
			end
		end)
	end)
end)
