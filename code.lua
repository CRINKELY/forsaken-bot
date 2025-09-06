print("Forsaken bot ran.")

local PathfindingService = game:GetService("PathfindingService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot - v0.07",
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

function Pathfind(humanoid, target, opts)
	-- Cancel any previous pathing on this humanoid
	if activePaths[humanoid] then
		activePaths[humanoid]()
		activePaths[humanoid] = nil
	end

	opts = opts or {}
	local delay = opts.recomputeDelay or 0.5 -- recompute delay
	local agentParms = opts.agentParams or {
		AgentRadius   = 2.2,
		AgentHeight   = 5,
		AgentCanJump  = false,
		AgentMaxSlope = 45,
	}

	local alive = true

	local function SmoothMove(hrp, wpPos, speed)
		if not hrp then return end
		local startPos = hrp.Position
		local distance = (wpPos - startPos).Magnitude
		if distance == 0 then return end
		local direction = (wpPos - startPos).Unit
		local traveled = 0
		local conn
		conn = game:GetService("RunService").RenderStepped:Connect(function(dt)
			if not hrp.Parent or not alive then conn:Disconnect(); return end
			local moveStep = math.min(speed * dt, distance - traveled)
			hrp.CFrame = CFrame.new(hrp.Position + direction * moveStep, hrp.Position + direction * moveStep + hrp.CFrame.LookVector)
			traveled = traveled + moveStep
			if traveled >= distance then conn:Disconnect() end
		end)
	end

	local function computeAndFollow()
		if not alive or not humanoid.RootPart then return end
		local startPos = humanoid.RootPart.Position
		local endPos   = (typeof(target)=="Vector3" and target) or (target and target.Position)
		if not endPos then return end

		local path = PathfindingService:CreatePath(agentParms)
		path:ComputeAsync(startPos, endPos)
		if path.Status ~= Enum.PathStatus.Success then return end

		-- Follow waypoints smoothly
		for _, wp in ipairs(path:GetWaypoints()) do
			if not alive then return end

			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end

			-- Use WalkSpeed for smooth movement
			local speed = humanoid.WalkSpeed or 16
			SmoothMove(humanoid.RootPart, wp.Position, speed)

			-- Wait until close enough
			local timeout = tick() + 2
			repeat
				task.wait(0.01)
			until (humanoid.RootPart.Position - wp.Position).Magnitude < 1 or tick() > timeout
		end
	end

	task.spawn(function()
		while alive do
			computeAndFollow()
			task.wait(delay)
		end
	end)

	local function stop()
		alive = false
	end

	activePaths[humanoid] = stop
	return stop
end

-- local cache outside the function
local SprintCache = {}

function Sprint(enable)
	local cache = SprintCache

	-- refresh character/humanoid/animator if changed
	local char = player.Character
	if char ~= cache.lastCharacter then
		cache.lastCharacter = char
		cache.tracks = {}
		cache.animator = nil
		cache.humanoid = nil
		cache.baseWalkSpeed = 16
		if char then
			cache.humanoid = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 5)
			cache.animator = cache.humanoid and (cache.humanoid:FindFirstChildOfClass("Animator") or cache.humanoid:WaitForChild("Animator", 5))
			if cache.humanoid then
				local attrBase = cache.humanoid:GetAttribute("BaseSpeed")
				cache.baseWalkSpeed = (type(attrBase) == "number" and attrBase) or (cache.humanoid.WalkSpeed or 16)
				cache.humanoid:SetAttribute("BaseSpeed", cache.baseWalkSpeed)
			end
		end
	end

	local hum = cache.humanoid
	local animator = cache.animator
	if not hum or not animator then return end

	-- animations sets
	cache.normalAnims = cache.normalAnims or {
		Idle = "rbxassetid://131082534135875",
		Walk = "rbxassetid://108018357044094",
		Run  = "rbxassetid://136252471123500",
	}
	cache.injuredAnims = cache.injuredAnims or {
		Idle = "rbxassetid://132377038617766",
		Walk = "rbxassetid://134624270247120",
		Run  = "rbxassetid://115946474977409",
	}
	cache.sprintMultiplier = cache.sprintMultiplier or (26 / 16)
	cache.tracks = cache.tracks or {}

	-- choose animation set depending on health
	local animSet = hum.Health < (hum.MaxHealth * 0.5) and cache.injuredAnims or cache.normalAnims

	local function ensureTrack(id)
		if cache.tracks[id] then return cache.tracks[id] end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local ok, track = pcall(function() return animator:LoadAnimation(anim) end)
		if ok and track then
			cache.tracks[id] = track
			return track
		end
		return nil
	end

	local function playOnly(trackToPlay)
		for _, t in pairs(cache.tracks) do
			if t ~= trackToPlay and t.IsPlaying then
				pcall(function() t:Stop() end)
			end
		end
		if trackToPlay and not trackToPlay.IsPlaying then
			pcall(function() trackToPlay:Play() end)
		end
	end

	-- Remove previous enforcement loop
	if cache.enforceConnection then
		cache.enforceConnection:Disconnect()
		cache.enforceConnection = nil
	end

	if enable then
		local targetSpeed = cache.baseWalkSpeed * cache.sprintMultiplier
		hum.WalkSpeed = targetSpeed
		playOnly(ensureTrack(animSet.Run))

		-- Continuously enforce WalkSpeed to prevent overrides
		cache.enforceConnection = game:GetService("RunService").RenderStepped:Connect(function()
			if hum and hum.WalkSpeed ~= targetSpeed then
				hum.WalkSpeed = targetSpeed
			end
		end)
	else
		-- stop enforcement
		if cache.enforceConnection then
			cache.enforceConnection:Disconnect()
			cache.enforceConnection = nil
		end

		hum.WalkSpeed = cache.baseWalkSpeed
		local moveMag = hum.MoveDirection and hum.MoveDirection.Magnitude * hum.WalkSpeed or 0
		if moveMag == 0 then
			playOnly(ensureTrack(animSet.Idle))
		elseif moveMag > 0 and moveMag < 17 then
			playOnly(ensureTrack(animSet.Walk))
		else
			playOnly(ensureTrack(animSet.Run))
		end
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

function PerformElliotAI()
	local Network = game:GetService("ReplicatedStorage").Modules.Network
	local TextService = game:GetService("TextChatService")
	local SRV, KLR = workspace.Players.Survivors, workspace.Players.Killers
	local RunService = game:GetService("RunService")

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
	local RESERVE, START_THRESHOLD = 3, 60
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

	local function getNearestKiller()
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return nil, math.huge end
		local closest, minDist = nil, math.huge
		local pos = player.Character.HumanoidRootPart.Position
		for _, killer in pairs(KLR:GetChildren()) do
			if killer:FindFirstChild("HumanoidRootPart") then
				local d = (killer.HumanoidRootPart.Position - pos).Magnitude
				if d < minDist then
					closest = killer
					minDist = d
				end
			end
		end
		return closest, minDist
	end

	local function isKillerClose(range)
		range = range or scareRadius
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return false end
		local pos = player.Character.HumanoidRootPart.Position
		for _, killer in pairs(KLR:GetChildren()) do
			if killer:FindFirstChild("HumanoidRootPart") then
				for _, s in pairs(SRV:GetChildren()) do
					if s:FindFirstChild("HumanoidRootPart") and s:FindFirstChild("Humanoid") and s.Humanoid.Health < s.Humanoid.MaxHealth then
						if currentTarget == s and (killer.HumanoidRootPart.Position - pos).Magnitude <= range then
							return false
						end
					end
				end
				if (killer.HumanoidRootPart.Position - pos).Magnitude <= range then
					return true
				end
			end
		end
		return false
	end

	local function rebuildOrderedTargets()
		orderedTargets = {}
		for _, category in ipairs(CycleOrder) do
			local list = SurvivorTypes[category]
			if list then
				for _, name in ipairs(list) do
					local s = SRV:FindFirstChild(name)
					if s and s:FindFirstChild("HumanoidRootPart") and s:FindFirstChild("Humanoid") and s.Humanoid.Health > 0 then
						table.insert(orderedTargets, s)
					end
				end
			end
		end
		if #orderedTargets == 0 then currentIndex = 1
		elseif currentIndex > #orderedTargets then currentIndex = 1 end
	end

	local function switchToTarget(newTarget)
		if currentTarget == newTarget then return end
		if currentPathStop then pcall(currentPathStop); currentPathStop = nil end
		currentTarget = newTarget
		lastTargetSwitch = tick()
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local success, stopFunc = pcall(function()
				return Pathfind(player.Character.Humanoid, currentTarget.HumanoidRootPart, {recomputeDelay = 0.1, closeEnough = 2})
			end)
			if success and type(stopFunc) == "function" then currentPathStop = stopFunc end
		end
	end

	local function pickFarthestTarget(ignoreInjured)
		local farthest, farD = nil, nil
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return nil end
		local pos = player.Character.HumanoidRootPart.Position
		for _, s in ipairs(orderedTargets) do
			if s and s:FindFirstChild("HumanoidRootPart") and s:FindFirstChild("Humanoid") then
				if ignoreInjured and s.Humanoid.Health < s.Humanoid.MaxHealth then continue end
				local d = (s.HumanoidRootPart.Position - pos).Magnitude
				if not farthest or d > farD then farthest, farD = s, d end
			end
		end
		return farthest
	end

	local function pickClosestInjured()
		local closest, minDist = nil, math.huge
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return nil end
		local pos = player.Character.HumanoidRootPart.Position
		for _, s in ipairs(SRV:GetChildren()) do
			if s:FindFirstChild("HumanoidRootPart") and s:FindFirstChild("Humanoid") then
				local hum = s.Humanoid
				if hum.Health < hum.MaxHealth then
					local d = (s.HumanoidRootPart.Position - pos).Magnitude
					if d < minDist then
						closest = s
						minDist = d
					end
				end
			end
		end
		return closest
	end

	local function SmoothMove(hrp, targetPos, speed)
		if not hrp then return end
		local startPos = hrp.Position
		local distance = (targetPos - startPos).Magnitude
		if distance == 0 then return end

		local direction = (targetPos - startPos).Unit
		local traveled = 0

		local conn
		conn = RunService.RenderStepped:Connect(function(dt)
			if not hrp.Parent then
				conn:Disconnect()
				return
			end
			local moveStep = math.min(speed * dt, distance - traveled)
			hrp.CFrame = CFrame.new(hrp.Position + direction * moveStep, hrp.Position + direction * moveStep + hrp.CFrame.LookVector)
			traveled = traveled + moveStep
			if traveled >= distance then
				conn:Disconnect()
			end
		end)
	end

	local function forceMoveTo(targetPos, speed)
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			SmoothMove(player.Character.HumanoidRootPart, targetPos, speed)
		end
	end

	-- Rush on damage
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.HealthChanged:Connect(function(hp)
			if lastHealth and hp < lastHealth then
				lastHitTime = tick()
				local killer, kd = getNearestKiller()
				if killer and kd <= rushRange and tick() >= lastRushUse + rushCooldown then
					Network.RemoteEvent:FireServer("UseActorAbility","RushHour")
					lastRushUse = tick()
				end
				ChatRandomMessage("Hurt")
			end
			lastHealth = hp
		end)
	end

	-- Main AI loop
	while GameState == "Ingame" and BotToggle.CurrentValue do
		rebuildOrderedTargets()

		-- Heal injured first
		local injured = pickClosestInjured()
		if injured then
			switchToTarget(injured)
			if not sprinting then
				sprinting = true
				Sprint(true)
			end
		else
			if not currentTarget and #orderedTargets > 0 then
				currentIndex = 1
				switchToTarget(orderedTargets[currentIndex])
			end
		end

		-- Scared flee
		if isKillerClose() then
			local farTarget = pickFarthestTarget(true)
			if farTarget then
				switchToTarget(farTarget)
				if not sprinting then
					sprinting = true
					Sprint(true)
				end
				ChatRandomMessage("Scared")
			end
		end

		-- Pizza throw
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") and currentTarget:FindFirstChild("Humanoid") then
			local pr = player.Character.HumanoidRootPart.Position
			local hum = currentTarget.Humanoid
			local dist = (currentTarget.HumanoidRootPart.Position - pr).Magnitude
			if dist >= pizzaRangeMin and dist <= pizzaRangeMax and hum.Health <= (hum.MaxHealth - pizzaHeal) and tick() >= pizzaCD then
				local vel = currentTarget.HumanoidRootPart.AssemblyLinearVelocity
				local predPos = currentTarget.HumanoidRootPart.Position + vel * 0.6
				Network.RemoteEvent:FireServer("UseActorAbility","ThrowPizza")
				ChatRandomMessage("Throwing")
				pizzaCD = tick() + pizzaCooldown
			end
		end

		-- Stamina management
		if sprinting then
			stamina = math.max(RESERVE, stamina - STAMINA_DRAIN*checkInterval)
			if stamina <= RESERVE then
				sprinting = false
				Sprint(false)
			end
		else
			stamina = math.min(STAMINA_MAX, stamina + STAMINA_GAIN*checkInterval)
		end

		-- Move manually towards current target
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local speed = sprinting and 26 or 16
			forceMoveTo(currentTarget.HumanoidRootPart.Position, speed)
		end

		-- Stuck detection
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rp = player.Character.HumanoidRootPart.Position
			if lastRootPos then
				if (rp - lastRootPos).Magnitude >= 0.5 then lastMoveTime = tick() end
			else lastMoveTime = tick() end
			lastRootPos = rp
			if currentPathStop and (tick() - lastMoveTime) >= 0.5 then
				pcall(currentPathStop)
				currentPathStop = nil
				pcall(function() player.Character.Humanoid:MoveTo(rp) end)
			end
		end

		task.wait(checkInterval)
	end

	if currentPathStop then pcall(currentPathStop); currentPathStop = nil end
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
