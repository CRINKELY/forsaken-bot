print("Forsaken bot ran.")

local PathfindingService = game:GetService("PathfindingService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot [v0]",
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
	local lastHitTime, pizzaCD, scareRadius = 0, 0, 5
	local staminaDrain = 10  -- per second
	local pizzaHeal = 35
	local CycleOrder = {"Supports", "Sentinels", "Survivalists"}

	-- Tweakable distances / timings
	local proximitySwitchRange = 7            -- immediate switch if close to a survivor (6-8 suggested)
	local pizzaRangeMin, pizzaRangeMax = 10, 12
	local rushRange = 7                       -- killer distance to trigger RushHour on hit (6-8 suggested)
	local pizzaCooldown = 45
	local rushCooldown = 20
	local targetHoldTime = 3                  -- seconds to stay on a target before cycling to next
	local checkInterval = 0.15                -- main loop tick
	local stuckMoveThreshold = 0.5            -- studs considered "moved"
	local stuckTimeout = 2                    -- seconds not moving => consider stuck

	local SRV = workspace.Players.Survivors
	local KLR = workspace.Players.Killers

	-- State
	local orderedTargets = {}     -- list of survivor Instances in priority order this iteration
	local currentIndex = 1
	local currentTarget = nil
	local currentPathStop = nil
	local lastTargetSwitch = 0
	local lastRootPos = nil
	local lastMoveTime = tick()
	local lastHealth = player.Character and player.Character.Humanoid and player.Character.Humanoid.Health or nil
	local lastHitByKillerAt = 0
	local lastRushUse = 0

	-- read stamina (unchanged)
	local function parseStamina()
		local txt = player.PlayerGui.TemporaryUI:WaitForChild("PlayerInfo"):WaitForChild("Bars"):WaitForChild("Stamina"):WaitForChild("Amount").Text
		local cur, mx = txt:match("^(%d+)%s*/%s*(%d+)$")
		return tonumber(cur), tonumber(mx)
	end

	-- detect if any killer within scare radius (unchanged)
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

	-- nearest killer (for RushHour logic)
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

	-- rebuild orderedTargets from CycleOrder (most -> least priority)
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
		-- ensure currentIndex in bounds
		if #orderedTargets == 0 then
			currentIndex = 1
		else
			if currentIndex > #orderedTargets then currentIndex = 1 end
		end
	end

	-- move Pathfind to new target (handles stopping previous Pathfind)
	local function switchToTarget(newTarget)
		if currentTarget == newTarget then return end
		-- stop old path
		if currentPathStop then
			pcall(currentPathStop)
			currentPathStop = nil
		end
		currentTarget = newTarget
		lastTargetSwitch = tick()
		-- start new path if valid
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") then
			-- Pathfind returns stop function; store it
			local success, stopFunc = pcall(function()
				return Pathfind(player.Character.Humanoid, currentTarget.HumanoidRootPart, {recomputeDelay = 0.12})
			end)
			if success and type(stopFunc) == "function" then
				currentPathStop = stopFunc
			end
		end
	end

	-- HealthChanged: update lastHitTime and possibly use RushHour if killer close
	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid.HealthChanged:Connect(function(hp)
			if lastHealth and hp < lastHealth then
				lastHitTime = tick()
				-- find nearest killer and, if close enough, use RushHour
				local killer, kd = getNearestKiller()
				if killer and kd <= rushRange and tick() >= lastRushUse + rushCooldown then
					game:GetService("ReplicatedStorage").Modules.Network.RemoteEvent:FireServer("UseActorAbility", "RushHour")
					lastRushUse = tick()
				end
			end
			lastHealth = hp
		end)
	end

	-- main loop
	while GameState == "Ingame" do
		-- stamina drain (if desired)
		local curS, maxS = parseStamina()
		if curS then
			curS = math.max(0, curS - staminaDrain * checkInterval)
			-- Optionally implement behaviour if stamina == 0 (slow, stop, etc)
		end

		-- rebuild targets every loop (keeps up with spawns / deaths)
		rebuildOrderedTargets()

		-- nothing to do if no survivors
		if #orderedTargets == 0 then
			-- stop any path and wait
			if currentPathStop then
				pcall(currentPathStop)
				currentPathStop = nil
				currentTarget = nil
			end
			task.wait(checkInterval)
			continue
		end

		-- proximity-based immediate switch:
		if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local pr = player.Character.HumanoidRootPart.Position
			for i, s in ipairs(orderedTargets) do
				if s and s:FindFirstChild("HumanoidRootPart") then
					local d = (s.HumanoidRootPart.Position - pr).Magnitude
					-- if close enough to some survivor, switch immediately to them
					if d <= proximitySwitchRange and s ~= currentTarget then
						currentIndex = i
						switchToTarget(s)
						break
					end
				end
			end
		end

		-- cycle target if we held this one long enough or currentTarget is missing/dead
		local shouldAdvance = false
		if not currentTarget or not currentTarget.Parent or (currentTarget.Humanoid and currentTarget.Humanoid.Health <= 0) then
			shouldAdvance = true
		elseif tick() - lastTargetSwitch >= targetHoldTime then
			shouldAdvance = true
		end
		if shouldAdvance then
			-- advance index
			if #orderedTargets > 0 then
				currentIndex = currentIndex + 1
				if currentIndex > #orderedTargets then currentIndex = 1 end
				switchToTarget(orderedTargets[currentIndex])
			end
		end

		-- ensure we have a current target (first pass)
		if not currentTarget then
			currentIndex = 1
			switchToTarget(orderedTargets[currentIndex])
		end

		-- stuck detection: if we have an active path and haven't moved enough recently, cancel path to force recompute
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
				-- cancelled stuck path, will recompute next loop
				pcall(function() currentPathStop() end)
				currentPathStop = nil
				-- small nudge so MoveToFinished isn't stuck on old target
				pcall(function() player.Character.Humanoid:MoveTo(rp) end)
			end
		end

		-- ability usage decisions (pizza)
		if currentTarget and currentTarget:FindFirstChild("HumanoidRootPart") and currentTarget:FindFirstChild("Humanoid") then
			if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
				local d = (currentTarget.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
				local hum = currentTarget.Humanoid
				-- Throw pizza when in distance window, target missing health, and cd ready
				if d >= pizzaRangeMin and d <= pizzaRangeMax and hum.Health <= (hum.MaxHealth - pizzaHeal) and tick() >= pizzaCD then
					game:GetService("ReplicatedStorage").Modules.Network.RemoteEvent:FireServer("UseActorAbility", "ThrowPizza")
					pizzaCD = tick() + pizzaCooldown
				end
			end
		end

		-- If we were recently scared/attacked, optionally prefer farthest target (existing behaviour)
		local scared = isKillerClose() or (tick() - lastHitTime <= 10)
		if scared then
			-- find farthest survivor according to CycleOrder priority
			local farthest, farD
			for _, s in ipairs(orderedTargets) do
				if s and s:FindFirstChild("HumanoidRootPart") then
					local d = (s.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
					if not farthest or d > farD then farthest, farD = s, d end
				end
			end
			if farthest and farthest ~= currentTarget then
				-- switch immediately to farthest
				switchToTarget(farthest)
				-- set index to that one if it's in orderedTargets
				for i, s in ipairs(orderedTargets) do if s == farthest then currentIndex = i break end end
			end
		end

		task.wait(checkInterval)
	end

	-- cleanup on exit
	if currentPathStop then
		pcall(currentPathStop)
		currentPathStop = nil
	end
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
