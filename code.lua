print("Forsaken bot ran.")

local PathfindingService = game:GetService("PathfindingService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot - v0.08",
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
		EquipCharacter("Survivor", Options[1])
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

local GameState = "Dead"
local SurvivorTypes = {
	["Supports"] = {"Elliot", "Dusekkar", "Taph", "Builderman"},
	["Sentinels"] = {"#SWATOfficer", "Shedletsky", "TwoTime", "Guest1337", "Chance"},
	["Survivalists"] = {"007n7", "Noob"}
}

local player = game.Players.LocalPlayer

function SetGameState()
	coroutine.wrap(function()
		while task.wait(0.1) do
			GameState = (if workspace.Players.Spectating:FindFirstChild(player.Name) ~= nil then "Dead" else "Ingame")
		end
	end)()
end

SetGameState()

-- Keeps the functions for each pathfind function to stop them on the next iteration
local activePaths = {}

-- Speed Controller system
local SpeedControllers = {}

local function GetSpeedController(character)
	if not SpeedControllers[character] then
		SpeedControllers[character] = {
			BaseSpeed = 16,
			SprintMultiplier = 26/16,
			IsSprinting = false,
			CurrentSpeed = 16
		}
	end
	return SpeedControllers[character]
end

-- Pathfind function using CurrentSpeed
function Pathfind(humanoid, target, opts)
	if activePaths[humanoid] then
		activePaths[humanoid]()
		activePaths[humanoid] = nil
	end

	opts = opts or {}
	local delay = opts.recomputeDelay or 0.5
	local agentParms = opts.agentParams or {
		AgentRadius   = 2.2,
		AgentHeight   = 5,
		AgentCanJump  = true,
		AgentMaxSlope = 45,
	}

	local alive = true
	local hrp = humanoid.RootPart
	local speedCtrl = GetSpeedController(humanoid.Parent)

	local function SmoothMove(destination)
		if not hrp then return end
		local conn
		conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
			if not hrp.Parent or not alive then conn:Disconnect(); return end
			local dir = destination - hrp.Position
			local dist = dir.Magnitude
			if dist < 0.1 then conn:Disconnect(); return end
			dir = dir.Unit

			local moveVector = dir * speedCtrl.CurrentSpeed * dt

			-- obstacle adjustment
			local ray = Ray.new(hrp.Position, moveVector)
			if workspace:FindPartOnRayWithIgnoreList(ray, {humanoid.Parent}) then
				local sideDir = Vector3.new(-dir.Z,0,dir.X)
				local altRay = Ray.new(hrp.Position, sideDir * speedCtrl.CurrentSpeed * dt)
				if not workspace:FindPartOnRayWithIgnoreList(altRay, {humanoid.Parent}) then
					moveVector = sideDir * speedCtrl.CurrentSpeed * dt
				else
					moveVector = Vector3.new(0,0,0)
				end
			end

			hrp.CFrame = CFrame.new(hrp.Position + moveVector, hrp.Position + moveVector + hrp.CFrame.LookVector)
		end)
	end

	local function computeAndFollow()
		if not alive or not hrp then return end
		local startPos = hrp.Position
		local endPos = (typeof(target)=="Vector3" and target) or (target and target.Position)
		if not endPos then return end

		local path = PathfindingService:CreatePath(agentParms)
		path:ComputeAsync(startPos, endPos)
		if path.Status ~= Enum.PathStatus.Success then return end

		for _, wp in ipairs(path:GetWaypoints()) do
			if not alive then return end
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end

			SmoothMove(wp.Position)

			local timeout = tick() + 3
			repeat task.wait(0.01)
			until (hrp.Position - wp.Position).Magnitude < 1 or tick() > timeout
		end
	end

	task.spawn(function()
		while alive do
			computeAndFollow()
			task.wait(delay)
		end
	end)

	local function stop() alive = false end
	activePaths[humanoid] = stop
	return stop
end

-- Sprint system without modifying WalkSpeed
function Sprint(enable)
	local char = player.Character
	if not char then return end

	local speedCtrl = GetSpeedController(char)
	speedCtrl.IsSprinting = enable
	speedCtrl.CurrentSpeed = speedCtrl.BaseSpeed * (enable and speedCtrl.SprintMultiplier or 1)

	-- handle animations
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not animator then return end

	local normalAnims = {
		Idle = "rbxassetid://131082534135875",
		Walk = "rbxassetid://108018357044094",
		Run  = "rbxassetid://136252471123500",
	}
	local injuredAnims = {
		Idle = "rbxassetid://132377038617766",
		Walk = "rbxassetid://134624270247120",
		Run  = "rbxassetid://115946474977409",
	}
	local animSet = hum.Health < (hum.MaxHealth*0.5) and injuredAnims or normalAnims

	local function playAnimation(id)
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track:Play()
	end

	if enable then
		playAnimation(animSet.Run)
	else
		local speed = speedCtrl.CurrentSpeed
		if speed < 17 then
			playAnimation(animSet.Walk)
		else
			playAnimation(animSet.Run)
		end
	end
end

-- Smooth manual movement
local RunService = game:GetService("RunService")
local function SmoothMove(hrp, targetPos, speed)
	if not hrp then return end
	local startPos = hrp.Position
	local distance = (targetPos - startPos).Magnitude
	if distance == 0 then return end

	local direction = (targetPos - startPos).Unit
	local traveled = 0

	local conn
	conn = RunService.RenderStepped:Connect(function(dt)
		if not hrp.Parent then conn:Disconnect(); return end
		local moveStep = math.min(speed * dt, distance - traveled)
		hrp.CFrame = CFrame.new(hrp.Position + direction * moveStep, hrp.Position + direction * moveStep + hrp.CFrame.LookVector)
		traveled = traveled + moveStep
		if traveled >= distance then conn:Disconnect() end
	end)
end

local function forceMoveTo(targetPos, speed)
	if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
		SmoothMove(player.Character.HumanoidRootPart, targetPos, speed)
	end
end

function EquipCharacter(Type: string, Name: string)
	-- Attempts to equip the character specified with the type

	local args = {
		[1] = "EquipState",
		[2] = game:GetService("ReplicatedStorage").Assets:FindFirstChild(Type .. "s"):FindFirstChild(Name)
	}

	game:GetService("ReplicatedStorage").Modules.Network.RemoteEvent:FireServer(unpack(args))

	task.wait()

	return (player.PlayerData.Equipped:FindFirstChild(Type).Value == Name)
end

-- PerformElliotAI
function PerformElliotAI()
	local Network = game:GetService("ReplicatedStorage").Modules.Network
	local TextService = game:GetService("TextChatService")
	local SRV, KLR = workspace.Players.Survivors, workspace.Players.Killers

	local lastHitTime, pizzaCD, scareRadius = 0, 0, 45
	local pizzaHeal = 35
	local CycleOrder = {"Supports", "Sentinels", "Survivalists"}
	local proximitySwitchRange = 4
	local pizzaRangeMin, pizzaRangeMax = 12, 14
	local rushRange = 7
	local pizzaCooldown = 45
	local rushCooldown = 0
	local checkInterval = 0.15
	local STAMINA_MAX, STAMINA_DRAIN, STAMINA_GAIN = 100, 10, 20
	local RESERVE = 3
	local stamina = STAMINA_MAX
	local sprinting = false

	local orderedTargets = {}
	local currentIndex, currentTarget, currentPathStop = 1, nil, nil
	local lastTargetSwitch, lastRootPos, lastMoveTime = 0, nil, tick()
	local lastHealth = player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health or nil
	local lastRushUse = 0
	local lastChatTimes = {Throwing = 0, Hurt = 0, Scared = 0}

	local ElliotMessages = {
		Throwing = {"GET THE PIZZA","GRAB THE PIZZA","PLEASE GET THIS","istg if you dont get this","HURRY UP WITH IT","DON'T DROP IT","HERE COMES THE PIZZA","CATCH IT!","TAKE THE PIZZA QUICK","I NEED THAT PIZZA NOW"},
		Hurt = {"ow :((","OWWW","oww","HEY >:(","MY ARM!","OUCH!","I'M HURT","NOT COOL!","I CAN'T TAKE THIS","YOWCH!"},
		Scared = {"okay im getting outta here","OKAY BYEBYE","NOT DEALING WITH THIS GUY","time to not do my job :D","RUNNING AWAY!","I'M OUT!","NOPE NOT TODAY","CAN'T FIGHT THIS","SEE YA!","BETTER GET SOME DISTANCE"}
	}

	local function ChatRandomMessage(messageType)
		local now = tick()
		if now - (lastChatTimes[messageType] or 0) >= 20 then
			local channel = TextService.TextChannels:FindFirstChild("RBXGeneral")
			if channel then
				local msgTable = ElliotMessages[messageType]
				if msgTable and #msgTable > 0 then
					pcall(function() channel:SendAsync(msgTable[math.random(1,#msgTable)]) end)
					lastChatTimes[messageType] = now
				end
			end
		end
	end

	task.spawn(function()
		while task.wait(checkInterval) do
			if GameState ~= "Ingame" then task.wait(1) continue end
			local char = player.Character
			if not char then continue end
			local hum = char:FindFirstChild("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hum or not hrp then continue end

			-- Determine targets
			orderedTargets = {}
			for _, typeName in ipairs(CycleOrder) do
				for _, survivorName in ipairs(SurvivorTypes[typeName]) do
					local target = SRV:FindFirstChild(survivorName)
					if target and target:FindFirstChild("HumanoidRootPart") then
						table.insert(orderedTargets, target)
					end
				end
			end

			currentTarget = orderedTargets[currentIndex] or orderedTargets[1]
			if not currentTarget then continue end

			local dist = (currentTarget.HumanoidRootPart.Position - hrp.Position).Magnitude
			if dist < proximitySwitchRange then
				currentIndex = currentIndex + 1
				if currentIndex > #orderedTargets then currentIndex = 1 end
				currentTarget = orderedTargets[currentIndex]
			end

			-- Pathfind to target using speed controller
			local speed = GetSpeedController(player.Character).CurrentSpeed
			if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
				forceMoveTo(currentTarget.HumanoidRootPart.Position, speed)
			end

			-- Handle sprint stamina
			if stamina < STAMINA_MAX and not sprinting then
				stamina = math.min(stamina + STAMINA_GAIN * checkInterval, STAMINA_MAX)
			elseif sprinting then
				stamina = math.max(stamina - STAMINA_DRAIN * checkInterval, 0)
				if stamina <= 0 then
					Sprint(false)
					sprinting = false
				end
			end

			-- Throw pizza if conditions met
			if pizzaCD <= 0 and hum.Health < 24 then
				pcall(function()
					game:GetService("ReplicatedStorage").Modules.Network.RemoteEvent:FireServer("UseActorAbility","ThrowPizza")
					ChatRandomMessage("Throwing")
				end)
				pizzaCD = pizzaCooldown
			end

			pizzaCD = math.max(0, pizzaCD - checkInterval)
		end
	end)
end

-- CODE --

while task.wait() do
	repeat task.wait() until GameState == "Ingame"
	
	if BotToggle.CurrentValue == true then
		local Survivor = player.PlayerData.Equipped.Survivor.Value
		
		if Survivor == "Elliot" then
			PerformElliotAI()
		end
	end
end
