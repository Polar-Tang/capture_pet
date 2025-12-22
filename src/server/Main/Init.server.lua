--[[
this is my 5th submission to hidden devs, here are a list of improves
- Remove unnecessary calls of :WaitForChild (cause of rejection) 
- usage of Debris instead of task.delay + :Destroy()
- usage of well-known libraries:
	maid, divide responsability, clean connection usage
	use a version of my aniation handler, is not a well known library but is a Nevermore custom services
virtual_nautilus
]]
--------------- Services ---------------
local Debris = game:GetService("Debris")
local httpService: HttpService = game:GetService("HttpService")
local PLayers = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Sounds = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

--------------- REMOTE EVENTS ---------------
local Events = RepStore.Events
local clickEvent: RemoteEvent = Events.ClickTest
local PetNew = Events.PetNew
local PickPet = Events.PickPet

--------------- Sounds ---------------
local Crystal = Sounds.Crystal
local Throw = Sounds.Throw

--------------- Workspace model ---------------
local MagicBall = Workspace.MagicBall -- ball for capturing pet

--------------- Helpers ---------------
local Helpers = RepStore.Helpers
local IsToolEquipped = require(Helpers.IsToolEquipped)
local treasureVFX = require(Helpers.treasureVFX)
local Maid = require(Helpers.Maid)

-- Imternal registry
local registry = require(script.Registry)

--------------- Binders ---------------
--[[
	This is a tiny example of using binder but not through Nevermore, use a tiny registry pattern insteed, i will showcase it with a tiny example, a Binder for cooldowns
]]

-- Here's a very simple it's binder for cooldowns
local PlayerHeart = {}
PlayerHeart.__index = PlayerHeart

type PlayerHeart = { isAppease: boolean }

function PlayerHeart.new(player: Player): PlayerHeart
	local self = setmetatable({} :: PlayerHeart, PlayerHeart)
	self.isAppease = false
	self._maid = Maid.new()

	return self
end

function PlayerHeart:AddTask(signal: RBXScriptSignal, index: string?)
	local hitTask = signal
	hitTask.Destroy = hitTask.Disconnect

	self._maid:GiveTask(signal)
end

function PlayerHeart:Appease(num: number)
	self.isAppease = true
	task.delay(num, function()
		self.isAppease = false
	end)
end

-- Use this registry pattern
local PlayerHearthRegistry = {}

PlayerHearthRegistry.__index = PlayerHearthRegistry
PlayerHearthRegistry._players = {}

-- initialize a player handler
function PlayerHearthRegistry:InitPlayer(player)
	local handler = PlayerHeart.new(player)
	self._players[player.UserId] = handler
end

--[[ accept a player
-- Get the player handler
-- return the particular player handler
]]

function PlayerHearthRegistry:GetHandler(player)
	return self._players[player.UserId]
end

--[[ accept a player
-- remove the player instance
-- return nil
]]
function PlayerHearthRegistry:RemovePlayer(player)
	self._players[player.UserId] = nil
end

-- Now we can get/init/update the player handler by the player object
PLayers.PlayerAdded:Connect(function(player)
	PlayerHearthRegistry:InitPlayer(player)
end)
--------------- End of Binders ---------------

-- the function when pick the ball with the pet captured is global scope
local pickPet = function(player, pet, pokeClone)
	-- little security mesure
	if pet:GetAttribute("Captured") then
		return
	end

	pet:Destroy()
	Crystal:Play()

	pokeClone:Destroy()
	PetNew:FireClient(player, pet)
end

-- This is the remote event data
type clickEvenetData = {
	clickPosition: Vector3,
	stop: boolean,
}

-- let's try to not spaghetti in this signals russian doll
clickEvent.OnServerEvent:Connect(function(player: Player, data: clickEvenetData)
	if not data or not data.clickPosition then
		return
	end

	if not IsToolEquipped(player) then
		warn("No tool equipped")
		return
	end

	-- player must have a character with humanoid
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	-- client can send stop thruty to cancel the operation
	if data.stop then
		humanoid:UnequipTools()
		return
	end

	-- This is like a plain binder
	local PlayerHeart = PlayerHearthRegistry:GetHandler(player)

	-- check isApeasse, avoid several tasks by several clicks
	if PlayerHeart.isAppease then
		warn("Must wait")
		return
	else
		PlayerHeart:Appease(2)
	end

	-- create a ball to trhow
	local pokeClone = MagicBall:Clone()
	pokeClone.Parent = Workspace

	-- the backend sign the ball
	local ballId = httpService:GenerateGUID()
	registry[ballId] = {
		ball = pokeClone,
		id = ballId,
	}
	-- collection of the ball
	Debris:AddItem(pokeClone, 15)
	task.delay(15, function()
		registry[ballId] = nil
	end)

	-- check if the ball is equipped
	local HRP: BasePart = character.PrimaryPart
	local equippedTool = character:FindFirstChildOflCass("Tool")
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
	-- Create a Maid to manage all connections/tasks for this throw

	local markerConn
	markerConn = animationTack:GetMarkerReachedSignal("throw"):Connect(function()
		humanoid:UnequipTools()
		Throw:Play()

		--------------- variables ---------------
		local startPosition = HRP.Position
		local lastY = 0

		--------------- constants ---------------
		local T = 0.5 -- a fixed amount of time for the ball to hit the ground
		local BOUNCINESS = 0.4 -- elasticity of a collision
		local clickPosition = data.clickPosition -- P1 or position goal
		local GRAVITY = Vector3.new(0, -workspace.Gravity, 0)

		local initialVelocity = (clickPosition - startPosition - 0.5 * GRAVITY * T ^ 2) / T
		local t = 0

		local trajectoryConnection

		-- This function plays an effect and reduce the pet size until make it invisible.
		local function capturePet(pet: Model, animDur: number?)
			local Dur = animDur or 2
			local petPrimaryPart = pet.PrimaryPart
			local brightPart: Part = treasureVFX(petPrimaryPart, Dur)
			Debris:AddItem(brightPart, Dur)

			local pickBallPrompt: ProximityPrompt = Instance.new("ProximityPrompt")
			pickBallPrompt.ActionText = "Pick Ball"
			pickBallPrompt.Name = "Pick Ball"
			pickBallPrompt.KeyboardKeyCode = Enum.KeyCode.Q
			pickBallPrompt.HoldDuration = 0
			pickBallPrompt.Style = Enum.ProximityPromptStyle.Custom
			pickBallPrompt.RequiresLineOfSight = false
			pickBallPrompt.MaxActivationDistance = 8
			pickBallPrompt.ClickablePrompt = true
			pickBallPrompt.ObjectText = ballId
			pickBallPrompt.Parent = pokeClone
			-- Add the prompt connection to the maid for cleanup
			PlayerHeart:AddTask(pickBallPrompt.Triggered:Connect(function()
				pickPet(player, pet, pokeClone)
			end))

			do
				local primary = pokeClone.PrimaryPart
				local originalCFrame = primary.CFrame
				local angle = math.rad(10)
				local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				local goal = { CFrame = originalCFrame * CFrame.Angles(0, 0, angle) }
				local tween = TweenService:Create(primary, tweenInfo, goal)
				tween:Play()
				PlayerHeart:AddTask(function()
					tween:Cancel()
				end)
			end
		end

		local function lastHit(pos: Vector3)
			if trajectoryConnection then
				trajectoryConnection:Disconnect()
			end

			local animDur = 2
			local pet: Model = nil
			local parts = workspace:GetPartBoundsInRadius(pos, 10)

			for _, part in ipairs(parts) do
				if not part.Parent:IsA("Model") then
					continue
				end
				if not part.Parent:GetAttribute("isAPet") then
					continue
				end
				pet = part.Parent

				local tween =
					TweenService:Create(part, TweenInfo.new(animDur), { Size = part.Size - Vector3.new(1, 1, 1) })
				tween:Play()
				PlayerHeart:AddTask(function()
					tween:Cancel()
				end)

				capturePet(pet, animDur)
			end
		end

		trajectoryConnection = RunService.Heartbeat:Connect(function(deltaTime)
			t += deltaTime
			local newPos = startPosition + (initialVelocity * t) + 0.5 * GRAVITY * (t ^ 2)

			if lastY > 0 and newPos.Y <= 0 then
				local impactVelocity = initialVelocity + GRAVITY * t
				local bounceVelY = -impactVelocity.Y * BOUNCINESS
				if math.abs(bounceVelY) < 15 then
					lastHit(newPos)
					return
				end
				startPosition = Vector3.new(newPos.X, 0, newPos.Z)
				initialVelocity = Vector3.new(impactVelocity.X, bounceVelY, impactVelocity.Z)
				t = 0
				lastY = 0
				return
			end

			pokeClone:PivotTo(CFrame.new(newPos))
			lastY = newPos.Y
		end)
		PlayerHeart:AddTask(trajectoryConnection)
	end)

	-- Add the marker connection to the maid for cleanup
	PlayerHeart:AddTask(markerConn)
end)

PickPet.OnServerEvent:Connect(function(player, prompt: ProximityPrompt)
	local pet = prompt.Parent

	local ballId = prompt.ObjectText
	local balLRegistry = registry[ballId]
	if not balLRegistry then
		return
	end
	pickPet(player, pet, balLRegistry.ball)
end)
