--[[
this is my 5th submission to hidden devs, here are a list of improves
- Remove unnecessary calls of :WaitForChild (cause of rejection) 
- usage of Debris instead of task.delay + :Destroy()
- elegantly avoid memmory leackage by the usage of well-known libraries:
	maid
	quenty's promises (Nevermore)
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
local getTool = require(Helpers.getTool)
local Promise = require(Helpers.Promises.Promise)
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

type PlayerHeart = {
	isAppease: boolean,
	_scopes: { [string]: InteractionScope },
}

type InteractionScope = {
	maid: typeof(Maid.new(...)),
	resolve: (any) -> (),
	reject: (any) -> (),
	promise: typeof(Promise.new(...)),
}

function PlayerHeart.new(player: Player): PlayerHeart
	local self = setmetatable({} :: PlayerHeart, PlayerHeart)
	self.isAppease = false
	self._maid = Maid.new()
	self._scopes = {}

	return self
end

function PlayerHeart:GiveTask(connection: RBXScriptConnection, index: string?)
	assert(typeof(connection) == "RBXScriptConnection", "First argument must be an RBXScriptConnection type")
	self._maid:GiveTask(connection)
end

-- Create a promise that represents the remote event connections scope
function PlayerHeart:CreateInteractionScope(timeoutSeconds: number, timeStamp: number)
	local index = tostring(timeStamp)
	local scopeMaid = Maid.new()

	local storedResolve, storedReject

	local PromiseTask = Promise.new(function(resolve, reject)
		storedResolve = resolve
		storedReject = reject

		-- expiration
		local timeoutTask = task.delay(timeoutSeconds, function()
			resolve()
		end)
		scopeMaid:GiveTask(timeoutTask)
	end):Finally(function()
		-- always clean, on resolve, reject, or by expiring
		scopeMaid:DoCleaning()
		self._scopes[index] = nil
	end)

	self._scopes[index] = {
		maid = scopeMaid,
		resolve = storedResolve,
		reject = storedReject,
		promise = PromiseTask,
	}

	return PromiseTask, scopeMaid
end

-- Do clean the connections
function PlayerHeart:ResolveScope(timeStamp: number, result: any)
	local index = tostring(timeStamp)
	local scope = self._scopes[index]
	if not scope then
		warn("No scope found for timestamp:", timeStamp)
		return
	end

	scope.resolve(result)
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
	-- GET THE PLAYER HEART FOR CLEANING THE CONNS
	local timeStamp = pokeClone:GetAttribute("Stamp")

	local PlayerHeart = PlayerHearthRegistry:GetHandler(player)
	PlayerHeart:ResolveScope(timeStamp)
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

	-- player must have a character with humanoid
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	-- client can send stop thruty to cancel the operation
	if data.stop then
		humanoid:UnequipTools()
		return
	end

	-- check if the ball is equipped
	local equippedTool = getTool(player)
	if not equippedTool or equippedTool.Name ~= "MagicBall" then
		return
	end

	local HRP: BasePart = character.PrimaryPart
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
	local pokeClone: Model = MagicBall:Clone()
	pokeClone.Parent = Workspace

	-- create a scoped Maid using time stamps as a keys
	local timeStamp = tick()
	pokeClone:SetAttribute("Stamp", timeStamp)
	local _, scopeMaid = PlayerHeart:CreateInteractionScope(15, timeStamp)

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

		-- CALCULATE DIRECTION AND HOW FAST THE OBJECT MOVES
		--V1 = (P1 - P0 - 0.5*G*T^2)/ T
		local initialVelocity = (clickPosition - startPosition - 0.5 * GRAVITY * T ^ 2) / T
		local t = 0

		-- This function is ccall if a pet is caputred, it plays effects and creates a prompt connection
		local function capturePet(pet: Model, animDur: number?)
			--------------- variables ---------------
			local Dur = animDur or 2
			local petPrimaryPart = pet.PrimaryPart
			--------------- shine vfx ---------------
			local brightPart: Part = treasureVFX(petPrimaryPart, Dur)
			Debris:AddItem(brightPart, Dur)

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

			local prompCOnn = function()
				pickPet(player, pet, pokeClone)
			end
			scopeMaid:GiveTask(pickBallPrompt.Triggered:Connect(prompCOnn))

			--------------- shake animation ---------------
			do
				local primary = pokeClone.PrimaryPart

				-- original orientation
				local originalCFrame = primary.CFrame

				-- how far it tilts left/right (in radians)
				local angle = math.rad(10)
				local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

				local goal = { CFrame = originalCFrame * CFrame.Angles(0, 0, angle) }
				local tween = TweenService:Create(primary, tweenInfo, goal)
				tween:Play()
			end
		end

		--call after T, uses A BuoyancySensor to call capturePet if a model is hit
		local function lastHit(pos: Vector3)
			-- clean the projectile trayectory
			scopeMaid:__index("trajectoryConnection"):Disconnect()
			-- detects parts in 10 radius
			local animDur = 2 -- dur for the pet captured
			local pet: Model -- the pet model that might get hit
			local parts = workspace:GetPartBoundsInRadius(pos, 10)

			-- loop all over the parts and detetct if its parent (a model or worksapace) has the isAPet attribute
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

				capturePet(pet, animDur)
			end
		end

		-- use the connection for pivoting the ball, with kinematic equation, while t < T
		scopeMaid:__newindex(
			"trajectoryConnection",
			RunService.Heartbeat:Connect(function(deltaTime)
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
					local bounceVelY = -impactVelocity.Y * BOUNCINESS

					if math.abs(bounceVelY) < 15 then
						lastHit(newPos)
						return
					end
					-- Keep on bouncing
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
		)
	end)

	-- Add the marker connection to the maid for cleanup
	scopeMaid:GiveTask(markerConn)
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
