print("Forsaken bot ran.")

local PathfindingService = game:GetService("PathfindingService")
local RunService = game:GetService("RunService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot - v0.09",
	LoadingSubtitle = "Made by @g_rd#0",
	ShowText = "Rayfield", -- for mobile users to unhide rayfield, change if you'd like
	Theme = "DarkBlue", -- Check https://docs.sirius.menu/rayfield/configuration/themes

	ToggleUIKeybind = "K", -- The keybind to toggle the UI visibility (string like "K" or Enum.KeyCode)

	DisableRayfieldPrompts = false,
	DisableBuildWarnings = false, -- Prevents Rayfield from warning when the script has a version mismatch with the interface

	ConfigurationSaving = {
		Enabled = false,
		FolderName = nil, -- Create a custom folder for your hub/game
		FileName = "Big Hub"
	},

	Discord = {
		Enabled = false, -- Prompt the user to join your Discord server if their executor supports it
		Invite = "noinvitelink", -- The Discord invite code, do not include discord.gg/. E.g. discord.gg/ ABCD would be ABCD
		RememberJoins = true -- Set this to false to make them join the discord every time they load it up
	},

	KeySystem = false, -- Set this to true to use our key system
	KeySettings = {
		Title = "Untitled",
		Subtitle = "Key System",
		Note = "No method of obtaining the key is provided", -- Use this to tell the user how to get a key
		FileName = "Key", -- It is recommended to use something unique as other scripts using Rayfield may overwrite your key file
		SaveKey = true, -- The user's key will be saved, but if you change the key, they will be unable to use your script
		GrabKeyFromSite = false, -- If this is true, set Key below to the RAW site you would like Rayfield to get the key from
		Key = {"Hello"} -- List of keys that will be accepted by the system, can be RAW file links (pastebin, github etc) or simple strings ("hello","key22")
	}
})

local BotControlTab = Window:CreateTab("Bot", "bot")

local BotTypes = BotControlTab:CreateDropdown({
	Name = "Bot Types - Survivors",
	Options = {"Elliot"},
	CurrentOption = {"Elliot"},
	MultipleOptions = false,
	Flag = "Dropdown1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	Callback = function(Options)
		
	end,
})

local BotToggle = BotControlTab:CreateToggle({
	Name = "Toggle Bot",
	CurrentValue = true,
	Flag = "Toggle1", -- A flag is the identifier for the configuration file, make sure every element has a different flag if you're using configuration saving to ensure no overlaps
	Callback = function(Value)
		-- The function that takes place when the toggle is pressed
		-- The variable (Value) is a boolean on whether the toggle is true or false
	end,
})

Rayfield:Notify({
	Title = "Notification",
	Content = "Forsaken Bot has loaded!",
	Duration = 2,
	Image = "bell",
})

-- HELPERS --

-- Variables used frequently throughout the script
local player = game.Players.LocalPlayer
local Character = player.Character
local humanoid = Character:WaitForChild("Humanoid")
local animator = humanoid:WaitForChild("Animator")

-- Sets the game state
local GameState = "Dead"

-- Survivor types sorted by priority
local SurvivorTypes = {
	["Supports"] = {"Elliot", "Dusekkar", "Taph", "Builderman"},
	["Sentinels"] = {"#SWATOfficer", "Shedletsky", "TwoTime", "Guest1337", "Chance"},
	["Survivalists"] = {"007n7", "Noob"}
}

-- Movement animations
local Animations = {
	Normal = {
		Idle = "rbxassetid://131082534135875",
		Walk = "rbxassetid://108018357044094",
		Run  = "rbxassetid://136252471123500",
	},
	Injured = {
		Idle = "rbxassetid://132377038617766",
		Walk = "rbxassetid://134624270247120",
		Run  = "rbxassetid://115946474977409",
	}
}

-- Table to cache AnimationTracks
local Tracks = {
	Normal = {},
	Injured = {}
}

-- Preload all animations
for state, set in pairs(Animations) do
	for name, id in pairs(set) do
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		
		if ok and track then
			Tracks[state][name] = track
			track.Priority = Enum.AnimationPriority.Action -- or appropriate priority
		end
	end
end

coroutine.wrap(function()
	while task.wait(0.1) do
		if workspace.Players.Spectating:FindFirstChild(player.Name) ~= nil then
			GameState = "Ingame"
		else
			GameState = "Dead"
		end
	end
end)()

local PathfindingInstances = {}

function Pathfind(humanoid: humanoid, start: Vector3, _end: Vector3, walkspeed: number)
	local function LerpToAtWalkspeed(_humanoid: Humanoid, _walkspeed: number, _start: Vector3, __end: Vector3)
		if not _humanoid or not _humanoid.Parent then return end
		local hrp = _humanoid.Parent:FindFirstChild("HumanoidRootPart")
		hrp.Anchored = true
		if not hrp then return end

		local startPos = _start
		local endPos = __end
		local direction = (endPos - startPos)
		local distance = direction.Magnitude
		if distance == 0 then return end
		direction = direction.Unit

		local traveled = 0
		local finished = false
		local conn
		
		conn = RunService.RenderStepped:Connect(function(dt)
			if not hrp.Parent then
				conn:Disconnect()
				return
			end

			local moveStep = math.min(_walkspeed * dt, distance - traveled)
			hrp.CFrame = CFrame.new(hrp.Position + direction * moveStep, hrp.Position + direction * moveStep + hrp.CFrame.LookVector)
			traveled = traveled + moveStep

			if traveled >= distance then
				conn:Disconnect()
				finished = true
			end
		end)
		
		repeat task.wait() until finished
		
		hrp.Anchored = false
	end
	
	local function ClearAnimations()
		for s, set in pairs(Tracks) do
			for n, track in pairs(set) do
				if track.IsPlaying then
					track:Stop(0)  -- stop immediately
				end
			end
		end
	end
	
	local function PlayAnimation(state: string, name: string)
		ClearAnimations()

		local track = Tracks[state] and Tracks[state][name]
		
		if track then
			track:Play(0.1) -- optional fadeTime = 0.1 for smooth transition
		end
	end
	
	-- Plays the corresponding movement animation
	PlayAnimation(
		(if humanoid.Health > 50 then "Normal" else "Injured"), 
		(if walkspeed > 16 then "Run" elseif walkspeed > 0 then "Walk" else "Idle")
	)
	
	-- Create a path with optional agent parameters
	local path = PathfindingService:CreatePath({
		AgentRadius = 2.1,      -- how wide the agent is
		AgentHeight = 5,      -- how tall the agent is
		AgentCanJump = false,  -- can the agent jump over obstacles
		AgentMaxSlope = 45    -- maximum slope angle in degrees
	})

	-- Compute path from start to goal
	path:ComputeAsync(start, _end)
	
	local hrp = humanoid.Parent:WaitForChild("HumanoidRootPart")

	-- Check if path was successful
	if path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		
		for i, wp in ipairs(waypoints) do
			LerpToAtWalkspeed(humanoid, walkspeed, hrp.Position, wp)
		end
	end
	
	ClearAnimations()
end

function FindGeneratorsInMap()
	if #workspace.Map.Ingame > 0 then
		local Generators = {}
		
		for i, potentialGenerator in pairs(workspace.Map.Ingame.Map:GetChildren()) do
			if potentialGenerator:IsA("Model") and potentialGenerator.Name == "Generator" then
				table.insert(Generators, potentialGenerator)
			end
		end
		
		return Generators
	else
		return nil
	end
end

function ElliotPathfinding()
	while GameState == "Ingame" and BotToggle.CurrentValue == true do
		local Generators = FindGeneratorsInMap()
		
		for i, generator in pairs(Generators)  do
			local pos = generator.Positions:GetChildren()[math.random(1, #generator.Positions:GetChildren())]
			Pathfind(humanoid, humanoid.Parent:WaitForChild("HumanoidRootPart").Position, pos, 24)
			
			task.wait(1)
		end
	end
end

-- CODE --

while task.wait() do
	repeat task.wait() until GameState == "Ingame"
	
	if BotToggle.CurrentValue == true then
		local Survivor = player.PlayerData.Equipped.Survivor.Value
		
		if Survivor == "Elliot" then
			ElliotPathfinding()
		end
	end
end
