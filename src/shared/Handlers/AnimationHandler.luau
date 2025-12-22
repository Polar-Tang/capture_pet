--[[
Animation handler @v_02
	The .new accepts an object as a parameter, it tolerates the model player or the player object
	Check the animation priority before stop it
	Got bindable events for animations
Animation handler @v_03
	implements Lazy load by prealoading the registered animation on demand

]]
local RepStore = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
-- local require = require(script.Parent.loader).load(script)

local Maid = require(RepStore.Helpers.Maid)
--local NeverMore = require(RS.Packages.neverMore.loader).load(script.Parent.Parent.Parent.Packages.neverMore)
--local Binder = NeverMore("Binder")
--print("binder ", Binder)
local AnimationHandler = {}
AnimationHandler.__index = AnimationHandler
type MaidType = typeof(Maid.new(...))

export type AnimationsData = {
	animationId: string,
	AnimationTrack: AnimationTrack,
	--AnimationPriorityNumber: number -- i'm not sure if this is useful
}

export type AnimationMap = {
	[string]: { Animation },
}

export type Options = {
	player: Player?,
	char: Model?,
	animations: AnimationMap?,
	armName: string?,
}

--[[
local PRIORITY_LIST = {
	Enum.AnimationPriority.Core,
	Enum.AnimationPriority.Idle,
	Enum.AnimationPriority.Movement,
	Enum.AnimationPriority.Action,
	Enum.AnimationPriority.Action2,
	Enum.AnimationPriority.Action3,
	Enum.AnimationPriority.Action4,
}
]]
type AnimationDescriptor = {
	Animation: Animation,
	AnimationTrack: AnimationTrack,
	Maid: MaidType,
	preloaded: boolean,
}

type AnimationDescriptors = {
	[string]: AnimationDescriptor,
}

function AnimationHandler.new(char: Instance | Player, serviceBag): Options
	local self = setmetatable({}, AnimationHandler)

	if char:IsA("Player") then
		self.Char = char.Character or char.CharacterAdded:Wait()
	else
		self.Char = char
	end

	self.animations = {}
	self.animationDescriptors = {}
	self.armName = ""
	self._maid = Maid.new()
	return self
end

--[[
If takes state false does nothing, returns nil
If takes state false and animation name, stop it, returns nil
If takes state true and animation name, play it, returns AnimationTrack
If takes state true and animation name and preload true, playr and stop it inmediatly, returns nil
]]
function AnimationHandler:LoadAnimation(state: boolean, animaName: string, isPreload: boolean)
	---- START ANIM ----
	--print("self.animationDescriptors ", self.animationDescriptors)
	if isPreload then
		warn("Do you meant to use Preload() " .. debug.traceback())
	end
	local current_desc = self:_getDescriptor(animaName)
	self:_ensurePreload(animaName)
	local animaTionTrack: AnimationTrack = current_desc.AnimationTrack

	if state and not animaTionTrack then
		local animaTionTrack: AnimationTrack =
			self.animator:LoadAnimation(self.animationDescriptors[animaName].Animation)
		animaTionTrack:Play()
		self.animationDescriptors[animaName].AnimationTracker = animaTionTrack
		return animaTionTrack
	elseif state and animaTionTrack then
		animaTionTrack:Play()
		return animaTionTrack
	end
	--------------------------------------

	---- STOP ANIM ----
	if not state and animaTionTrack then
		animaTionTrack:Stop()
		return nil
	elseif not state then
		return nil
	end
	return nil
	---- STOP ANIM ----
end

-- Check if there's an animator in case the user is ragdolled
function AnimationHandler:_Check()
	if not self.animator then
		return
	end
end

function AnimationHandler:_initDescriptior(animaName: string)
	local desc = self:_getDescriptor(animaName)
	local animId = self.animations[animaName]

	if desc.AnimationTrack then
		warn("This descriptor were intialized " .. debug.traceback())
	end
	local descriptor: AnimationDescriptor = {} :: AnimationDescriptor
	local newAnimation = Instance.new("Animation")
	newAnimation.AnimationId = animId
	descriptor.Animation = newAnimation
	descriptor.Maid = Maid.new()
	self.animationDescriptors[animaName] = descriptor
end

-- Declare the firast animation track and set ptreload to true in the descriptor
function AnimationHandler:_ensurePreload(animaName)
	if self.animationDescriptors[animaName].preloaded then
		return
	end
	self:_initDescriptior(animaName)

	if not self.animator then
		self.animator = self.Char:WaitForChild("Humanoid").Animator
		self:_Check()
	end

	-- Load the animation and declare it
	do
		local animaTionTrack: AnimationTrack =
			self.animator:LoadAnimation(self.animationDescriptors[animaName].Animation)
		animaTionTrack:Play(0)
		self.animationDescriptors[animaName].AnimationTrack = animaTionTrack
	end

	self.animationDescriptors[animaName].preloaded = true
end

-- Just a helper to getting the animation tracker by its animation name
function AnimationHandler:_getDescriptor(animaName): AnimationDescriptor
	assert(self.animations[animaName], "animation name does not exists")
	return self.animationDescriptors[animaName]
end

function AnimationHandler:AddAnimations(newAnims)
	for k, v in pairs(newAnims) do
		self.animations[k] = v
	end
end

function AnimationHandler:Destroy()
	self._maid:DoCleaning()
	self:ClearAllTheAnims()
	setmetatable(self, nil)
end

function AnimationHandler:registryAnims(anims: AnimationMap)
	self.animations = anims
	self:_declarDescriptors()
end

function AnimationHandler:_declarDescriptors()
	local newDescs = {}
	for k, _ in pairs(self.animations) do
		local descriptor = {}

		descriptor.Animation = nil
		descriptor.AnimationTrack = nil
		descriptor.Maid = nil
		descriptor.preloaded = false
		newDescs[k] = descriptor
	end
	self.animationDescriptors = newDescs
end

-- Preaload all the animation at once, better don't use it on long animations list
function AnimationHandler:preloadAll()
	warn(debug.traceback())
	local anims = self.animations
	-- local descriptors = {} :: { AnimationDescriptors }

	for k, v in pairs(anims) do
		local descriptor: AnimationDescriptor = {} :: AnimationDescriptor
		local newAnimation = Instance.new("Animation")
		newAnimation.AnimationId = v
		descriptor.Animation = newAnimation
		descriptor.Maid = Maid.new()
		descriptor.preloaded = true
		self.animationDescriptors[k] = descriptor
		self:LoadAnimation(true, k, true)
	end

	--self.animationDescriptors = descriptors
end

local animationsData = require(RS.Animations.WeaponsAnims)

function AnimationHandler:Init(binder) end

function AnimationHandler:Start(binder)
	if self.Char.Name == "Blocking" then
		self:registryAnims(animationsData["Fist-r6"])
		self:LoadAnimation(true, "Blocking")
	end
end

type connArgs = {
	callback: (Track: AnimationTrack, params: any) -> (),
	animationName: string,
	animationEventName: string,
}
function AnimationHandler:OnSignal(info: connArgs)
	local animName = info.animationName
	local animationEventName = info.animationEventName
	local descriptor: AnimationDescriptor = self.animationDescriptors[animName]
	if descriptor.Maid and descriptor.Maid[animationEventName] then
		return
	end

	local animationTracker = descriptor.AnimationTrack
	local signal: RBXScriptSignal
	if descriptor.Maid[animationEventName] then
		return
	end

	if animationEventName == "EndedCon" then
		signal = animationTracker.Ended
	else
		signal = animationTracker:GetMarkerReachedSignal(animationEventName)
	end

	local conn = signal:Connect(function(param)
		info.callback(animationTracker, param)
	end)
	descriptor.Maid:__newindex(animationEventName, conn)
end

function AnimationHandler:_ClearAnimation(animName)
	local desc = self.animationDescriptors[animName]
	if desc and desc.Maid then
		desc.Maid:DoCleaning() -- disconnects ALL marker/ended/start connections
		if desc.AnimationTrack then
			desc.AnimationTrack:Destroy()
		end
	end
end
function AnimationHandler:ClearAllTheAnims()
	for k, v in pairs(self.animations) do
		self:_ClearAnimation(k)
	end
end
export type AnimationHandler = typeof(AnimationHandler.new({} :: Options))

return AnimationHandler
