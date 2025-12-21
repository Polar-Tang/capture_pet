--[[
this is my 5th submission to hidden devs, here are a list of improves
- Remove unnecessary calls of :WaitForChild (cause of rejection) 
- usage of well-known libraries:
	maid, divide responsability, clean connection usage
virtual_nautilus
]]

--------------- Services ---------------
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local httpService: HttpService = game:GetService("HttpService")
local PLayers = game:GetService("Players")
local RepStore = game:GetService("ReplicatedStorage")
local Sounds = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

--------------- Workspace model ---------------
local MagicBall = Workspace.MagicBall -- ball for capturing pet

--------------- Sounds ---------------
local Throw = Sounds.Throw
local Crystal = Sounds.Crystal

--------------- REMOTE EVENTS ---------------
local Events = RepStore.Events
local clickEvent: RemoteEvent = Events.ClickTest
local PetNew = Events.PetNew
local PickPet = Events.PickPet
-- player handler
--[[
	This is a tiny example of a multiple player system handlers,
	it start with a tiny class for cooldown
]]

-- a simple handler for cooldowns
local _PlayerHeart = {}
_PlayerHeart.__index = _PlayerHeart

type _PlayerHeart = { isAppease: boolean }

-- but we don't use it directly, we access to its registry instead
function _PlayerHeart.new(player: Player): _PlayerHeart
	local self = setmetatable({} :: _PlayerHeart, _PlayerHeart)
	self.isAppease = false

	return self
end

function _PlayerHeart:Appease(num: number): nil
	self.isAppease = true
	task.delay(num, function()
		self.isAppease = false
	end)
end

-- modules for the pet captured
local Helpers = RepStore.Helpers
local IsToolEquipped = require(Helpers.IsToolEquipped)
local treasureVFX = require(Helpers.treasureVFX)

-- Imternal registry
local registry = require(script.Registry)

-- This handler is listed utilizing a registry pattern
local PlayerHearthRegistry = {}

PlayerHearthRegistry.__index = PlayerHearthRegistry

PlayerHearthRegistry._players = {}

-- initialize a player handler
function PlayerHearthRegistry:InitPlayer(player)
	local handler = _PlayerHeart.new(player)
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

-- the function when pick the ball with the pet captured is shared between to functions of global scope
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

clickEvent.OnServerEvent:Connect(function(player: Player, data: clickEvenetData)
	if not data or not data.clickPosition then
		return
	end

	if not IsToolEquipped(player) then
		return warn("No tool equipped")
	end

	-- player must have a character with humanoid
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	-- client can send stop thruty to cancel the operation
	if data.stop then
		humanoid:UnequipTools()
		return
	end

	local PlayerHeart = PlayerHearthRegistry:GetHandler(player)

	-- check isApeasse, avoid several tasks by several clicks
	if PlayerHeart.isAppease then
		return warn("Must wait")
	else
		PlayerHeart:Appease(2)
	end

	-- create a ball to trhow
	local pokeClone = MagicBall:Clone()
	pokeClone.Parent = workspace

	-- equipped tool sound

	-- the backend sign the ball
	local ballId = httpService:GenerateGUID()
	registry[ballId] = {
		ball = pokeClone,
		id = ballId,
	}
	-- collection of the ball
	task.delay(15, function()
		pokeClone:Destroy()
		registry[ballId] = nil
	end)

	-- check if the ball is equipped
	local CHAR = player.Character
	local HRP: BasePart = CHAR.PrimaryPart
	local equippedTool = CHAR:FindFirstChildOfClass("Tool")
	if not equippedTool or equippedTool.Name ~= "MagicBall" then
		return
	end

	-- set the heartbeat conn variable
	local trajectoryConnection: RBXScriptSignal? = nil

	-- play throw animation
	local Animator: Animator = humanoid:WaitForChild("Animator")
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://90384503768373"
	local animationTack = Animator:LoadAnimation(animation)
	animationTack:Play()
	-- initialize the throw ball functionallity
	animationTack:GetMarkerReachedSignal("throw"):Connect(function()
		do
			humanoid:UnequipTools()
			Throw:Play()
		end
		--------------- variables ---------------
		local startPosition = HRP.Position
		local lastY = 0

		--------------- constants ---------------
		local T = 0.5 -- a fixed amount of time for the ball to hit the ground
		local BOUNCINESS = 0.4 -- elasticity of a collision
		local clickPosition = data.clickPosition -- P1 or position goal
		-- All the projectile formula comes from V1, P0 and P1, under Gravity over time
		local GRAVITY = Vector3.new(0, -workspace.Gravity, 0)

		-- CALCULATE DIRECTION AND HOW FAST THE OBJECT MOVES
		--V1 = (P1 - P0 - 0.5*G*T^2)/ T
		local initialVelocity = (clickPosition - startPosition - 0.5 * GRAVITY * T ^ 2) / T
		local t = 0

		-- This function plays an effect and reduce the pet size until make it invisible.
		-- Also generates a prompt for the poke clone model, in the real project, when its triggered, list the pet in the player bestiary
		local function capturePet(pet: Model, animDur: number?): nil
			--------------- variables ---------------
			local animDur = animDur or 2 -- dur for the pet captured
			local petPrimaryPart = pet.PrimaryPart
			--------------- shine vfx ---------------
			local brightPart: Part = treasureVFX(petPrimaryPart, animDur)

			--------------- ball prompt ---------------
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

			--------------- here's a pickPet ---------------
			pickBallPrompt.Triggered:Connect(function()
				pickPet(player, pet, pokeClone)
			end)

			--------------- shake animation ---------------
			do
				local primary = pokeClone.PrimaryPart

				-- original orientation
				local originalCFrame = primary.CFrame

				-- how far it tilts left/right (in radians)
				local angle = math.rad(10)

				local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

				local goal = {
					CFrame = originalCFrame * CFrame.Angles(0, 0, angle),
				}

				local tween = TweenService:Create(primary, tweenInfo, goal)
				tween:Play()
			end
		end

		--THE POKECLONE HAS A BuoyancySensor, DETECTS IF ANY PART HITED BELONGS TO A PET CALL capturePet
		local function lastHit(pos: Vector3)
			trajectoryConnection:Disconnect()

			-- detects parts in 10 radius
			local isPetFound = false
			local animDur = 2 -- dur for the pet captured
			local pet: Model? = nil -- the pet model that might get hit
			local petPrimaryPart = nil
			local parts = workspace:GetPartBoundsInRadius(pos, 10)

			-- loop all over the parts and detetct if its parent (a model or worksapace) has the isAPet attribute
			for _, part in ipairs(parts) do
				if part.Parent:IsA("Model") then
					-- The pet has isAPet attribute
					if part.Parent:GetAttribute("isAPet") then
						pet = part.Parent
						petPrimaryPart = pet.PrimaryPart

						-- declare isPetFound once
						if not isPetFound then
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
				capturePet(pet, animDur)
			end
		end

		-- use the connection for pivoting the ball
		trajectoryConnection = RunService.Heartbeat:Connect(function(deltaTime)
			t += deltaTime

			-- calculate the current position based in the cinematic function, this trajectory is also predicted by the client in a StarterPack.MagicBall.localScript
			--// s = s0 + v0*t + 0.5*a*t^2
			local newPos = startPosition + (initialVelocity * t) + 0.5 * GRAVITY * (t ^ 2)

			--Bouncing
			if lastY > 0 and newPos.Y <= 0 then
				-- This is the current velocity at the moment of impact
				-- The v0 (last initial velocity) at current time * gravity
				-- ImpactV = v0 + a*t
				local impactVelocity = initialVelocity + GRAVITY * t
				--print("new throw backend", newPos)
				--print("t backend", t)
				--print("initialVelocity backend", initialVelocity)
				--print("impactVelocity backend", impactVelocity)
				-- impactVelocity.Y is literally the falling aceleration, we use its opposite
				-- Bouciness has the enrgy loss
				local bounceVelY = -impactVelocity.Y * BOUNCINESS

				-- bounceVelY too weak to bounce
				if math.abs(bounceVelY) < 15 then
					lastHit(newPos)
					return
				end

				-- redefines de variable for newPos calculation, so newPosition changes
				-- Every bounce is creating a new Throw event

				-- impact point, from the ground
				startPosition = Vector3.new(newPos.X, 0, newPos.Z)
				-- bounce direction + bounce strength
				initialVelocity = Vector3.new(impactVelocity.X, bounceVelY, impactVelocity.Z)
				t = 0
				lastY = 0
				return
			end

			pokeClone:PivotTo(CFrame.new(newPos))
			lastY = newPos.Y
		end)
	end)
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
