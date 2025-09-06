print("Forsaken bot ran.")

local PathfindingService = game:GetService("PathfindingService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot - v0.02",
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
	local delay      = opts.recomputeDelay or 0.5 -- a bit higher to avoid spamming
	local agentParms = opts.agentParams or {
		AgentRadius   = 2.2,
		AgentHeight   = 5,
		AgentCanJump  = false,
		AgentMaxSlope = 45,
	}

	local alive = true

	local function computeAndFollow()
		if not alive or not humanoid.RootPart then return end
		local startPos = humanoid.RootPart.Position
		local endPos   = (typeof(target)=="Vector3" and target)
			or (target and target.Position)
		if not endPos then return end

		local path = PathfindingService:CreatePath(agentParms)
		path:ComputeAsync(startPos, endPos)

		if path.Status ~= Enum.PathStatus.Success then
			return -- just retry next loop
		end

		for _, wp in ipairs(path:GetWaypoints()) do
			if not alive then return end

			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end

			humanoid:MoveTo(wp.Position)

			-- wait with timeout so it doesn’t hang forever
			local reached = humanoid.MoveToFinished:Wait(2) -- wait up to 2 seconds

			if not reached then
				-- If it failed, just stop this path early and recompute
				return
			end
		end
	end

	-- start the loop
	task.spawn(function()
		while alive do
			computeAndFollow()
			task.wait(delay)
		end
	end)

	-- the stop function
	local function stop()
		alive = false
		if humanoid.RootPart then
			humanoid:MoveTo(humanoid.RootPart.Position)
		end
	end

	activePaths[humanoid] = stop
	return stop
end

-- local cache outside the function
local SprintCache = {}

function Sprint(enable)
	-- use the cache
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

	-- animations
	cache.anims = cache.anims or {
		Idle = "rbxassetid://134624270247120",
		Walk = "rbxassetid://132377038617766",
		Run  = "rbxassetid://115946474977409",
	}
	cache.sprintMultiplier = cache.sprintMultiplier or (26 / 16)
	cache.tracks = cache.tracks or {}

	local function ensureTrack(id)
		if not animator then return nil end
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
		for k, t in pairs(cache.tracks) do
			if t ~= trackToPlay and t.IsPlaying then
				pcall(function() t:Stop() end)
			end
		end
		if trackToPlay and not trackToPlay.IsPlaying then
			pcall(function() trackToPlay:Play() end)
		end
	end

	if not hum then return end

	if enable then
		hum.WalkSpeed = cache.baseWalkSpeed * cache.sprintMultiplier
		local runTrack = ensureTrack(cache.anims.Run)
		playOnly(runTrack)
	else
		hum.WalkSpeed = cache.baseWalkSpeed
		local moveMag = 0
		if hum.RootPart and hum.MoveDirection then
			moveMag = hum.MoveDirection.Magnitude * hum.WalkSpeed
		end
		if moveMag == 0 then
			local idleTrack = ensureTrack(cache.anims.Idle)
			playOnly(idleTrack)
		elseif moveMag > 0 and moveMag < 17 then
			local walkTrack = ensureTrack(cache.anims.Walk)
			playOnly(walkTrack)
		else
			local runTrack = ensureTrack(cache.anims.Run)
			playOnly(runTrack)
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

	local lastHitTime, pizzaCD, scareRadius = 0, 0, 7
	local pizzaHeal = 35
	local CycleOrder = {"Supports", "Sentinels", "Survivalists"}

	local proximitySwitchRange = 4
	local pizzaRangeMin, pizzaRangeMax = 12, 14
	local rushRange = 7
	local pizzaCooldown = 45
	local rushCooldown = 0
	local targetHoldTime = 3
	local checkInterval = 0.15
	local stuckMoveThreshold = 0.5
	local stuckTimeout = 0.5

	local SRV = workspace.Players.Survivors
	local KLR = workspace.Players.Killers

	-- stamina config + thresholds
	local STAMINA_MAX = 100
	local STAMINA_DRAIN = 10   -- per second while sprinting (matches your variable)
	local STAMINA_GAIN = 20    -- per second when not sprinting
	local RESERVE = 2          -- never drop below this
	local STOP_THRESHOLD = 15  -- when to stop sprinting and regen
	local START_THRESHOLD = 60 -- when to resume sprinting

	local stamina = STAMINA_MAX
	local sprinting = false

	-- State (copied from your AI)
	local orderedTargets = {}
	local currentIndex = 1
	local currentTarget = nil
	local currentPathStop = nil
	local lastTargetSwitch = 0
	local lastRootPos = nil
	local lastMoveTime = tick()
	local lastHealth = player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health or nil
	local lastRushUse = 0
	local lastDepletedTime = nil
	
	local ElliotMessages = {
		["Throwing"] = {"GET THE PIZZA", "GRAB THE PIZZA", "PLEASE GET THIS", "istg if you dont get this"},
		["Hurt"] = {"ow :((", "OWWW", "oww", "HEY >:("},
		["Scared"] = {"okay im getting outta here", "OKAY BYEBYE", "NOT DEALING WITH THIS GUY", "time to not do my job :D"}
	}
	
	local function ChatRandomMessage(messageType)
		game:GetService("TextChatService").TextChannels:WaitForChild("RBXGeneral"):SendAsync(ElliotMessages[messageType][math.random(1, #ElliotMessages[messageType])])
	end

	local function isKillerClose(range)
		range = range or scareRadius
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return false end
		for _, killer in pairs(KLR:GetChildren()) do
			if killer:FindFirstChild("HumanoidRootPart") then
				local d = (killer.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
				if d <= range then return true end
			end
		end
		return false
	end

	local function getNearestKiller()
		if not player.Character or not player.Character:FindFirstChild("HumanoidRootPart") then return nil, math.huge end
		local pr = player.Character.HumanoidRootPart.Position
		local best, bestD = nil, math.huge
		for _, k in pairs(KLR:GetChildren()) do
			if k:FindFirstChild("HumanoidRootPart") and k:FindFirstChild("Humanoid") and k.Humanoid.Health > 0 then
				local d = (k.HumanoidRootPart.Position - pr).Magnitude
				if d < bestD then best, bestD = k, d end
			end
		end
		return best, bestD
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
		if #orderedTargets == 0 then
			currentIndex = 1
		else
			if currentIndex > #orderedTargets then currentIndex = 1 end
		end
	end

	local function switchToTarget(newTarget)
		if currentTarget == newTarget then return end
		if currentPathStop then
			pcall(currentPathStop)
			currentPathStop = nil
		end
		currentTarget = newTarget
		lastTargetSwitch = tick()
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local success, stopFunc = pcall(function()
				return Pathfind(player.Character.Humanoid, currentTarget.HumanoidRootPart, {recomputeDelay = 0.12})
			end)
			if success and type(stopFunc) == "function" then
				currentPathStop = stopFunc
			end
		end
	end

	-- Rush Hour trigger on damage
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.HealthChanged:Connect(function(hp)
			if lastHealth and hp < lastHealth then
				lastHitTime = tick()
				
				local killer, kd = getNearestKiller()
				if killer and kd <= rushRange and tick() >= lastRushUse + rushCooldown then
					Network.RemoteEvent:FireServer("UseActorAbility", "RushHour")
					lastRushUse = tick()
				end
				
				ChatRandomMessage("Chasing")
			end
			lastHealth = hp
		end)
	end

	-- heartbeat updater to manage stamina & animation loop
	local accum = 0
	while GameState == "Ingame" and BotToggle.CurrentValue == true do
		-- main tick
		-- compute if currently moving (very simple check: path active)
		local moving = currentPathStop ~= nil

		-- stamina update (drain while sprinting, regen otherwise). ensure reserve.
		if sprinting and moving then
			stamina = stamina - (STAMINA_DRAIN * checkInterval)
			if stamina <= RESERVE then
				stamina = RESERVE
				-- stop sprint to regen
				sprinting = false
				Sprint(false)
				lastDepletedTime = tick()
				-- cancel path so pathfind doesn't try to run while regen
				if currentPathStop then
					pcall(currentPathStop); currentPathStop = nil
				end
			end
		else
			-- regeneration: if we recently hit reserve, add a small delay before regen
			if lastDepletedTime and tick() < lastDepletedTime + 0.8 then
				-- short pause
			else
				stamina = math.min(STAMINA_MAX, stamina + (STAMINA_GAIN * checkInterval))
			end
		end

		-- If stamina recovered above start threshold and we have target, resume sprinting
		if not sprinting and stamina >= START_THRESHOLD and currentTarget then
			sprinting = true
			Sprint(true)
			-- ensure we have a path (restart)
			if not currentPathStop then
				switchToTarget(currentTarget)
			end
		end

		-- If we have no target, pick one
		rebuildOrderedTargets()
		if #orderedTargets == 0 then
			if currentPathStop then
				pcall(currentPathStop)
				currentPathStop = nil
				currentTarget = nil
			end
			task.wait(checkInterval)
			continue
		end

		-- proximity immediate switch
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local pr = player.Character.HumanoidRootPart.Position
			for i, s in ipairs(orderedTargets) do
				if s and s:FindFirstChild("HumanoidRootPart") then
					local d = (s.HumanoidRootPart.Position - pr).Magnitude
					if d <= proximitySwitchRange and s ~= currentTarget then
						currentIndex = i
						switchToTarget(s)
						break
					end
				end
			end
		end

		-- cycle target based on hold time or death
		local shouldAdvance = false
		if not currentTarget or not currentTarget.Parent or (currentTarget.Humanoid and currentTarget.Humanoid.Health <= 0) then
			shouldAdvance = true
		elseif tick() - lastTargetSwitch >= targetHoldTime then
			shouldAdvance = true
		end
		if shouldAdvance and #orderedTargets > 0 then
			currentIndex = currentIndex + 1
			if currentIndex > #orderedTargets then currentIndex = 1 end
			switchToTarget(orderedTargets[currentIndex])
		end

		if not currentTarget then
			currentIndex = 1
			switchToTarget(orderedTargets[currentIndex])
		end

		-- stuck detection
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rp = player.Character.HumanoidRootPart.Position
			if lastRootPos then
				if (rp - lastRootPos).Magnitude >= stuckMoveThreshold then
					lastMoveTime = tick()
				end
			else
				lastMoveTime = tick()
			end
			lastRootPos = rp

			if currentPathStop and (tick() - lastMoveTime) >= stuckTimeout then
				pcall(function() currentPathStop() end)
				currentPathStop = nil
				pcall(function() player.Character.Humanoid:MoveTo(rp) end)
			end
		end

		-- pizza throw logic
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") and currentTarget:FindFirstChild("Humanoid") then
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local d = (currentTarget.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
				local hum = currentTarget.Humanoid
				if d >= pizzaRangeMin and d <= pizzaRangeMax and hum.Health <= (hum.MaxHealth - pizzaHeal) and tick() >= pizzaCD then
					Network.RemoteEvent:FireServer("UseActorAbility", "ThrowPizza")
					ChatRandomMessage("Hurt")
					pizzaCD = tick() + pizzaCooldown
				end
			end
		end

		-- scared behaviour: prefer farthest survivor
		local scared = isKillerClose() or (tick() - lastHitTime <= 10)
		if scared then
			ChatRandomMessage("Scared")
			
			local farthest, farD
			
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				for _, s in ipairs(orderedTargets) do
					if s and s:FindFirstChild("HumanoidRootPart") then
						local d = (s.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
						if not farthest or d > farD then farthest, farD = s, d end
					end
				end
				if farthest and farthest ~= currentTarget then
					switchToTarget(farthest)
					for i, s in ipairs(orderedTargets) do if s == farthest then currentIndex = i break end end
				end
			end
		end

		-- If we have a target and enough stamina, ensure sprinting is toggled on so AI moves faster.
		if currentTarget and currentPathStop then
			if not sprinting and stamina >= START_THRESHOLD then
				sprinting = true
				Sprint(true)
			elseif sprinting and stamina <= STOP_THRESHOLD then
				sprinting = false
				Sprint(false)
				-- cancel path to allow regen before resuming
				if currentPathStop then pcall(currentPathStop); currentPathStop = nil end
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
