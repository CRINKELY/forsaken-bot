print("Forsaken bot ran.")

local PathfindingService = game:GetService("PathfindingService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot - v0.04",
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

	if enable then
		hum.WalkSpeed = cache.baseWalkSpeed * cache.sprintMultiplier
		playOnly(ensureTrack(animSet.Run))
	else
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

	local STAMINA_MAX, STAMINA_DRAIN, STAMINA_GAIN = 100, 10, 20
	local RESERVE, STOP_THRESHOLD, START_THRESHOLD = 2, 15, 60
	local stamina = STAMINA_MAX
	local sprinting = false

	local orderedTargets = {}
	local currentIndex, currentTarget, currentPathStop = 1, nil, nil
	local lastTargetSwitch, lastRootPos, lastMoveTime = 0, nil, tick()
	local lastHealth = player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health or nil
	local lastRushUse, lastDepletedTime = 0, nil
	local lastChatTimes = {Throwing = 0, Hurt = 0, Scared = 0}

	local ElliotMessages = {
		Throwing = {
			"GET THE PIZZA",
			"GRAB THE PIZZA",
			"PLEASE GET THIS",
			"istg if you dont get this",
			"HURRY UP WITH IT",
			"DON'T DROP IT",
			"HERE COMES THE PIZZA",
			"CATCH IT!",
			"TAKE THE PIZZA QUICK",
			"I NEED THAT PIZZA NOW"
		},
		Hurt = {
			"ow :((",
			"OWWW",
			"oww",
			"HEY >:(",
			"MY ARM!",
			"OUCH!",
			"I'M HURT",
			"NOT COOL!",
			"I CAN'T TAKE THIS",
			"YOWCH!"
		},
		Scared = {
			"okay im getting outta here",
			"OKAY BYEBYE",
			"NOT DEALING WITH THIS GUY",
			"time to not do my job :D",
			"RUNNING AWAY!",
			"I'M OUT!",
			"NOPE NOT TODAY",
			"CAN'T FIGHT THIS",
			"SEE YA!",
			"BETTER GET SOME DISTANCE"
		}
	}

	local function ChatRandomMessage(messageType)
		local now = tick()
		if now - (lastChatTimes[messageType] or 0) >= 15 then
			local channel = TextService.TextChannels:FindFirstChild("RBXGeneral")
			if channel then
				local msgTable = ElliotMessages[messageType]
				if msgTable and #msgTable > 0 then
					pcall(function()
						channel:SendAsync(msgTable[math.random(1,#msgTable)])
					end)
					lastChatTimes[messageType] = now
				end
			end
		end
	end

	local SRV, KLR = workspace.Players.Survivors, workspace.Players.Killers

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
		if currentPathStop then pcall(currentPathStop); currentPathStop = nil end
		currentTarget = newTarget
		lastTargetSwitch = tick()
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			local success, stopFunc = pcall(function()
				-- Pathfind regardless of sprinting; always try to follow target
				return Pathfind(player.Character.Humanoid, currentTarget.HumanoidRootPart, {recomputeDelay = 0.1, closeEnough = 2})
			end)
			if success and type(stopFunc) == "function" then currentPathStop = stopFunc end
		end
	end

	local function pickFarthestTarget()
		local farthest, farD = nil, nil
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local pos = player.Character.HumanoidRootPart.Position
			for _, s in ipairs(orderedTargets) do
				if s and s:FindFirstChild("HumanoidRootPart") then
					local d = (s.HumanoidRootPart.Position - pos).Magnitude
					if not farthest or d > farD then farthest, farD = s, d end
				end
			end
		end
		return farthest
	end

	local function forceWalkSpeed(speed)
		local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = speed
		end
	end

	-- Rush Hour on damage
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

	-- Main loop
	while GameState == "Ingame" and BotToggle.CurrentValue == true do
		rebuildOrderedTargets()

		if #SRV:GetChildren() == 1 then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if hum then hum.Health = 0 end
		end

		-- Ensure target exists
		if not currentTarget and #orderedTargets > 0 then
			currentIndex = 1
			switchToTarget(orderedTargets[currentIndex])
		end

		-- Stamina logic
		local moving = currentPathStop ~= nil
		if sprinting and moving then
			stamina = math.max(RESERVE, stamina - STAMINA_DRAIN*checkInterval)
			if stamina <= RESERVE then
				sprinting = false
				Sprint(false)
				lastDepletedTime = tick()
				if currentPathStop then pcall(currentPathStop); currentPathStop = nil end
			end
		else
			if not lastDepletedTime or tick() > lastDepletedTime + 0.8 then
				stamina = math.min(STAMINA_MAX, stamina + STAMINA_GAIN*checkInterval)
			end
		end

		-- Always enforce state WalkSpeed regardless of other effects
		if sprinting then
			forceWalkSpeed(26)
		else
			forceWalkSpeed(16)
		end

		if not sprinting and stamina >= START_THRESHOLD and currentTarget then
			sprinting = true
			Sprint(true)
			if not currentPathStop then switchToTarget(currentTarget) end
		end

		-- Cycle targets if proximity
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

		-- Scared behavior
		local scared = isKillerClose() or (tick() - lastHitTime <= 10)
		if scared then
			ChatRandomMessage("Scared")
			local farTarget = pickFarthestTarget()
			if farTarget and farTarget ~= currentTarget then
				switchToTarget(farTarget)
				sprinting = true
				Sprint(true)
				forceWalkSpeed(26)
				task.wait(math.random(1,3)) -- briefly move away
				sprinting = false
				Sprint(false)
				forceWalkSpeed(16)
				-- return to normal target after fleeing
				if #orderedTargets > 0 then
					currentIndex = 1
					switchToTarget(orderedTargets[currentIndex])
				end
			end
		end

		-- Pizza throw logic
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") and currentTarget:FindFirstChild("Humanoid") then
			local pr = player.Character and player.Character:FindFirstChild("HumanoidRootPart") and player.Character.HumanoidRootPart.Position
			if pr then
				local d = (currentTarget.HumanoidRootPart.Position - pr).Magnitude
				local hum = currentTarget.Humanoid
				if d >= pizzaRangeMin and d <= pizzaRangeMax and hum.Health <= (hum.MaxHealth - pizzaHeal) and tick() >= pizzaCD then
					Network.RemoteEvent:FireServer("UseActorAbility","ThrowPizza")
					ChatRandomMessage("Throwing")
					pizzaCD = tick() + pizzaCooldown
				end
			end
		end

		-- Stuck detection
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local rp = player.Character.HumanoidRootPart.Position
			if lastRootPos then
				if (rp - lastRootPos).Magnitude >= stuckMoveThreshold then lastMoveTime = tick() end
			else lastMoveTime = tick() end
			lastRootPos = rp
			if currentPathStop and (tick() - lastMoveTime) >= stuckTimeout then
				pcall(function() currentPathStop() end)
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
