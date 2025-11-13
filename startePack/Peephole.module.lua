-- THIS MODULE IS RENSPONSIBLE FOR RENDERING THE MARKERS TRAYECTORY 

-- Services
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local clickEvent = game.ReplicatedStorage:WaitForChild("Events"):WaitForChild("ClickTest")

-- Global variables
local P1
local markerCon: RBXScriptSignal | nil  
local peepHole = {}
local isPeepHoleActive = false
local folder: Folder? = nil

--constants
local PLAYER = game.Players.LocalPlayer
local MOUSE = PLAYER:GetMouse()

local DELTA_TIME = 0.05 -- THE MARKERS EVERY 0.05 SECONDS

-- FOR RENDER STEPS, WE NEED TO CALCULATE THE INITIAL VELOCITY, P0 initiaposition, P1 GOAL, GRAVITY, AND THE TOTAL TIME TO REACH THE GROUND
local GRAVITY = Vector3.new(0, -workspace.Gravity, 0)
-- THIS IS THE TOTAL TIME THAT THE BALL WILL LAST TO REACH THE GROUND
local T = 0.5


function peepHole.init()
	isPeepHoleActive = true
	MOUSE.Button1Down:Connect(function()
		print("P1 ", P1)
		clickEvent:FireServer({clickPosition= P1})
	end)
	MOUSE.Button2Down:Connect(function()
		clickEvent:FireServer({stop = true})
		peepHole.finish()
	end)

	-- Create the folder for the markers
	folder = Instance.new("Folder")
	folder.Name = "TrajectoryMarkers"
	folder.Parent = workspace

	local function createMarker(pos)
		local marker = Instance.new("Part")
		marker.Size = Vector3.new(0.4, 0.4, 0.4)
		marker.Shape = Enum.PartType.Ball

		marker.Color = Color3.fromRGB(255, 255, 255)
		marker.Material = Enum.Material.Neon
		marker.Anchored = true
		marker.CanCollide = false
		marker.Position = pos
		marker.Parent = folder
		return marker
	end


	local function createLandingMarker(pos)


		local SpotLight = Instance.new("SpotLight")
		SpotLight.Face = Enum.NormalId.Top
		SpotLight.Color = Color3.fromRGB(0, 170, 0)
		SpotLight.Angle = 30
		SpotLight.Brightness = 100

		local marker = createMarker(pos)
		marker.Size = Vector3.new(2, 2, 2)
		SpotLight.Parent = marker

	end

	local function drawTrajectory(startPos: Vector3, initialVelocity: Vector3, clickPos: Vector3)
		folder:ClearAllChildren()

		-- current time
		local t = 0

		-- CREATE A MARKER EVERY 0.05 SECONDS UNTI CURRENT TIME IS ALMOST T, 0.5
		while t < T do
			--// s = s0 + v0*t + 0.5*a*t^2
			local CURRENT_POS = startPos + (initialVelocity * t )+ 0.5 * GRAVITY * (t ^ 2)

			-- if current time is bigger than T it means is the last one
			if t + DELTA_TIME >= T then
				createLandingMarker(CURRENT_POS)
			else
				createMarker(CURRENT_POS)
			end

			t += DELTA_TIME
		end
	end

	local timer = 0
	local lastTime = nil
	markerCon = RunService.RenderStepped:Connect(function(deltaTime)
		local CHAR = PLAYER.Character
		if not CHAR then return end
		local HRP = CHAR.PrimaryPart

		if not HRP then return end
		local P0 = HRP.Position
		timer = timer +deltaTime

		-- render the markers every 0.05 seconds
		-- render when the cached p1 is different from the mouse hit position, avoid glitching
		if (not lastTime or timer - lastTime >= DELTA_TIME) and (not P1 or (P1 - MOUSE.Hit.Position).Magnitude > 2) then
			lastTime = timer
			--GOAL POSITION
			P1 = MOUSE.Hit.Position
			--THE TOTAL TIME TO REACH THE GROUND is a fixed value, the ball always last the same to reach the ground 
			local T = 0.5
			-- CALCULATE THE INITIAL POSITION
			--V1 = P1 - P0 - 0.5*G*T^2/T
			local initialVelocity = (P1 - P0 - 0.5*GRAVITY*T^2) / T

			drawTrajectory(P0, initialVelocity, P1)
		end

	end)
end

-- this is like a :Destroy()
function peepHole.finish()
	if markerCon then
		markerCon:Disconnect()
		markerCon=nil
	end
	folder:Destroy()
	isPeepHoleActive = false
end

return peepHole
