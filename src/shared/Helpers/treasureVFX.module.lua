local TweenService = game:GetService("TweenService")
local rp = game:GetService("ReplicatedStorage")
local reward = rp:WaitForChild("Effects"):WaitForChild("treasure")

-- recursivelly emit all particles descendants
local function emitParticles(effect)
	local function emitAllParticles(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child:Emit(50)
			elseif child:IsA("Attachment") or child:IsA("Model") then
				emitAllParticles(child)
			end
		end
	end
	emitAllParticles(effect)
end

-- Utilize the vfx
return function( hrp: BasePart, animDur: number?)
	local animDur = animDur or 4

	-- Increase the vfx size
	local bright = reward:Clone()
	bright.Size = Vector3.new(1,1,1)
	local goal = bright.Size + Vector3.new(2,2,2)

	bright.Transparency = 1
	bright.Position = hrp.Position
	bright.Parent = workspace
	emitParticles(bright)
	local tween = TweenService:Create(bright, TweenInfo.new(animDur), { Size = bright.Size + Vector3.new(2,2,2) })
	tween:Play()

	-- delete the effect after the animation duration has reached
	task.delay(animDur, function()

		for _, child: ParticleEmitter in ipairs(bright:GetChildren()) do
			if child:IsA("ParticleEmitter") then
				child:Clear()
				child:Destroy()
			end
		end
		bright:Destroy()
	end)

	return bright
	--for _, scale in ipairs(scaleValues) do
	--      local tween = TweenService:Create(scale, TweenInfo.new(2), { Value = 0.5 })
	--      tween:Play()
	--end
end
