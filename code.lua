local PathfindingService = game:GetService("PathfindingService")

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
	Name = "Forsaken Bot",
	Icon = "square-dashed-bottom-code", -- Icon in Topbar. Can use Lucide Icons (string) or Roblox Image (number). 0 to use no icon (default).
	LoadingTitle = "Forsaken Bot",
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
	local delay      = opts.recomputeDelay or 0.05
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
			return
		end

		for _, wp in ipairs(path:GetWaypoints()) do
			if not alive then return end
			if wp.Action == Enum.PathWaypointAction.Jump then
				humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
			humanoid:MoveTo(wp.Position)
			local reached = humanoid.MoveToFinished:Wait()
			if not reached then break end
		end
	end

	-- start the loop
	spawn(function()
		while alive do
			computeAndFollow()
			task.wait(delay)
		end
	end)

	-- the stop function
	local function stop()
		alive = false
		-- nudge MoveTo to cancel any pending MoveToFinished wait
		if humanoid.RootPart then
			humanoid:MoveTo(humanoid.RootPart.Position)
		end
	end

	-- store it so next call can cancel this one
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
	
	local SRV = workspace.Players.Survivors
	local KLR = workspace.Players.Killers
	local PizzaHeal = 35   -- approximate healing from Pizza
	
	local CycleOrder = {"Supports", "Sentinels", "Survivalists"}

	local function parseStamina()
		local txt = player.PlayerGui.TemporaryUI.PlayerInfo.Bars.Stamina.Amount.Text
		local cur, mx = txt:match("^(%d+)%s*/%s*(%d+)$")
		return tonumber(cur), tonumber(mx)
	end

	local function isKillerClose()
		for _, killer in pairs(KLR:GetChildren()) do
			if killer.HumanoidRootPart then
				local d = (killer.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
				if d <= scareRadius then return true end
			end
		end
		return false
	end

	local function getFarthestTarget()
		for _, category in ipairs(CycleOrder) do
			local bestT, maxDist = nil, -math.huge
			for _, name in ipairs(SurvivorTypes[category]) do
				local s = SRV:FindFirstChild(name)
				if s and s.HumanoidRootPart and s.Humanoid then
					local d = (s.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
					if d > maxDist then bestT, maxDist = s, d end
				end
			end
			if bestT then return bestT end
		end
	end

	local function getNextTarget()
		for _, category in ipairs(CycleOrder) do
			for _, name in ipairs(SurvivorTypes[category]) do
				local s = SRV:FindFirstChild(name)
				if s and s.HumanoidRootPart and s.Humanoid then
					return s
				end
			end
		end
	end

	player.Character.Humanoid.HealthChanged:Connect(function(hp)
		if hp < player.Character.Humanoid.MaxHealth then
			lastHitTime = tick()
		end
	end)

	while GameState == "Ingame" do
		-- Drain stamina
		local curS, maxS = parseStamina()
		if curS then
			curS = math.max(0, curS - staminaDrain * 0.2)
			-- Optionally, stop movement when 0
			if curS <= 0 then
				-- Could halt Pathfind or slow down
			end
		end

		local scared = isKillerClose() or (tick() - lastHitTime <= 10)
		local target = scared and getFarthestTarget() or getNextTarget()

		if target and target.HumanoidRootPart then
			Pathfind(player.Character.Humanoid, target.HumanoidRootPart, {recomputeDelay = 0.1})

			-- Heal if target needs it (within Pizza heal range)
			local hum = target.Humanoid
			if hum.Health <= hum.MaxHealth - PizzaHeal and tick() >= pizzaCD then
				game:GetService("ReplicatedStorage").Modules.Network.RemoteEvent:FireServer("UseActorAbility", "ThrowPizza")
				pizzaCD = tick() + 45
			end
		end

		task.wait(0.2)
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
