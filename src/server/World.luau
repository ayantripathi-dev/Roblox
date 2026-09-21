--[[
	World
	Builds the whole play space from code, so the game is playable in a blank
	Baseplate with nothing but `rojo serve` + Play. Nothing here decides gameplay:
	every interaction forwards to the same rate-limited handlers the UI uses, so
	tapping the cube and tapping the on-screen button are literally the same call.

	Layout (looking from the spawn at +Z toward the center):
		- the Power Cube floats over the plaza   (ClickDetector  -> tap)
		- the Sell Pad is the neon circle in front of it (Touched -> sell)
		- egg pedestals stand in an arc          (ProximityPrompt -> Eggs panel)
		- kiosks around the rim open the other panels
		- a physical leaderboard board shows the global top 10
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Icons = require(ReplicatedStorage.Shared.Icons)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Utils = require(ReplicatedStorage.Shared.Utils)

local GameService = require(script.Parent.GameService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local Notifier = require(script.Parent.Notifier)
local RateLimiter = require(script.Parent.RateLimiter)

local World = {}

local ACCENT = Color3.fromRGB(96, 196, 255)
local GOLD = Color3.fromRGB(255, 199, 82)
local DARK = Color3.fromRGB(22, 26, 38)
local FLOOR = Color3.fromRGB(38, 44, 62)

-- Only ever one tap/sell forwarded per player per this window. Touched fires
-- constantly while standing on the pad and we never want that to look like spam.
local sellTouched = setmetatable({}, { __mode = "k" }) :: { [Player]: number }

-- ----------------------------------------------------------------------------
-- Building blocks
-- ----------------------------------------------------------------------------

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makeNeon(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = makePart(name, size, position, color, parent)
	part.Material = Enum.Material.Neon
	part.CanCollide = false
	part.CastShadow = false
	return part
end

local function addLight(part: Part, color: Color3, brightness: number, range: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

--[[
	World signs show your Creator Store icons as soon as shared/Icons.luau has an
	id for the icon name. Until then they stay text-only - there are no emoji
	placeholders anywhere in the build, so nothing looks unfinished.
]]
local function addBillboardIcon(holder: Frame, iconName: string?): number
	if not iconName then
		return 0
	end
	local id = Icons.id(iconName)
	if id <= 0 then
		return 0
	end

	local image = Instance.new("ImageLabel")
	image.Name = `Icon_{iconName}`
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromOffset(34, 34)
	image.Position = UDim2.new(0.5, -70, 0, 4)
	image.Image = `rbxassetid://{id}`
	image.ImageColor3 = Icons.tint(iconName)
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = holder
	return 40
end

local function addBillboard(part: Part, title: string, subtitle: string?, accent: Color3?, iconName: string?): ()
	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompter"
	gui.Size = UDim2.fromOffset(320, 88)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 180
	gui.Parent = part

	local holder = Instance.new("Frame")
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = gui

	local iconGutter = addBillboardIcon(holder, iconName)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -iconGutter, 0.6, 0)
	titleLabel.Position = UDim2.fromOffset(iconGutter, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBlack
	titleLabel.TextScaled = true
	titleLabel.TextColor3 = accent or ACCENT
	titleLabel.TextStrokeTransparency = 0.55
	titleLabel.Text = title
	titleLabel.Parent = holder

	local subtitleLabel = Instance.new("TextLabel")
	subtitleLabel.Position = UDim2.new(0, iconGutter, 0.58, 0)
	subtitleLabel.Size = UDim2.new(1, -iconGutter, 0.42, 0)
	subtitleLabel.BackgroundTransparency = 1
	subtitleLabel.Font = Enum.Font.GothamMedium
	subtitleLabel.TextScaled = true
	subtitleLabel.TextColor3 = Color3.fromRGB(226, 232, 240)
	subtitleLabel.TextTransparency = if subtitle then 0 else 1
	subtitleLabel.Text = subtitle or ""
	subtitleLabel.Parent = holder
end

--[[
	A kiosk: a pedestal, a glowing screen with a title, and a ProximityPrompt that
	tells the client which panel to open. Every panel in the game is one of these.
]]
local function makeKiosk(parent: Instance, options: any): Part
	-- Kiosks always face the middle of the plaza, so every screen is readable
	-- from the spawn no matter which side of the ring it stands on.
	local rotation = if options.Rotation then options.Rotation else math.deg(math.atan2(-options.Position.X, -options.Position.Z))

	local base = makePart(options.Name .. "Base", Vector3.new(9, 1, 9), options.Position, DARK, parent)
	local pillar = makePart(options.Name .. "Pillar", Vector3.new(6, 7, 1.2), options.Position + Vector3.new(0, 4, 0), DARK, parent)
	pillar.Material = Enum.Material.Metal
	pillar.Orientation = Vector3.new(0, rotation, 0)
	local screen = makeNeon(options.Name .. "Screen", Vector3.new(7.4, 3.6, 0.4), options.Position + Vector3.new(0, 8, 0), options.Color, parent)
	screen.CanCollide = true
	screen.Orientation = Vector3.new(0, rotation, 0)

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Screen"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(740, 360)
	surface.LightInfluence = 0
	surface.Parent = screen

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(14, 17, 27)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = surface

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.06, 0)
	padding.PaddingBottom = UDim.new(0.06, 0)
	padding.PaddingLeft = UDim.new(0.05, 0)
	padding.PaddingRight = UDim.new(0.05, 0)
	padding.Parent = frame

	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = frame

	local heading = Instance.new("TextLabel")
	heading.LayoutOrder = 1
	heading.Size = UDim2.new(1, 0, 0.42, 0)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBlack
	heading.TextScaled = true
	heading.TextColor3 = options.Color
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.Text = options.Heading or options.Name
	heading.Parent = frame

	local body = Instance.new("TextLabel")
	body.LayoutOrder = 2
	body.Size = UDim2.new(1, 0, 0.5, 0)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.GothamMedium
	body.TextScaled = true
	body.TextWrapped = true
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextColor3 = Color3.fromRGB(214, 222, 236)
	body.Text = options.Body or ""
	body.Parent = frame

	-- A studded strip along the bottom keeps the in-world screens matching the
	-- studded UI theme. Same look as Theme.studs on the client.
	local studRow = Instance.new("Frame")
	studRow.Name = "Studs"
	studRow.BackgroundTransparency = 1
	studRow.Size = UDim2.new(1, -36, 0, 16)
	studRow.Position = UDim2.new(0, 18, 1, -30)
	studRow.Parent = surface

	local studLayout = Instance.new("UIGridLayout")
	studLayout.CellSize = UDim2.fromOffset(14, 14)
	studLayout.CellPadding = UDim2.fromOffset(8, 0)
	studLayout.SortOrder = Enum.SortOrder.LayoutOrder
	studLayout.Parent = studRow

	for index = 1, 14 do
		local stud = Instance.new("Frame")
		stud.Name = "Stud"
		stud.Size = UDim2.fromOffset(14, 14)
		stud.BackgroundColor3 = options.Color
		stud.BackgroundTransparency = 0.6
		stud.BorderSizePixel = 0
		stud.LayoutOrder = index
		stud.Parent = studRow

		local studCorner = Instance.new("UICorner")
		studCorner.CornerRadius = UDim.new(1, 0)
		studCorner.Parent = stud

		local studLit = Instance.new("UIGradient")
		studLit.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(80, 86, 110))
		studLit.Rotation = 90
		studLit.Parent = stud
	end

	if options.ScreenUpdate then
		options.ScreenUpdate(frame, heading, body)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = options.ActionText or "Open"
	prompt.ObjectText = options.PromptName or options.Name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = base

	prompt.Triggered:Connect(function(player: Player)
		Notifier.panel(player, options.Panel)
	end)

	if options.Light then
		addLight(screen, options.Color, 2, 22)
	end

	return base
end

-- ----------------------------------------------------------------------------
-- Interactive pieces
-- ----------------------------------------------------------------------------

local function buildCube(parent: Instance): Part
	local cube = makeNeon("PowerCube", Vector3.new(16, 16, 16), Vector3.new(0, 12, 0), ACCENT, parent)
	cube.Material = Enum.Material.Neon
	cube.CanCollide = false

	-- The shell is see-through so the spinning core inside it actually reads.
	cube.Transparency = 0.22

	local inner = makeNeon("Core", Vector3.new(9, 9, 9), cube.Position, Color3.fromRGB(255, 255, 255), parent)
	inner.Transparency = 0.1
	inner.Parent = cube
	inner.Position = cube.Position

	local ring = makeNeon("Ring", Vector3.new(30, 0.6, 30), Vector3.new(0, 1, 0), Color3.fromRGB(56, 122, 200), parent)
	ring.Transparency = 0.35

	addLight(cube, ACCENT, 4, 40)
	addBillboard(cube, "POWER CUBE", "Click to tap - chain taps for a combo", Color3.fromRGB(150, 214, 255), "tap")

	local detector = Instance.new("ClickDetector")
	detector.Name = "Tap"
	detector.MaxActivationDistance = 60
	detector.Parent = cube

	detector.MouseClick:Connect(function(player: Player)
		RateLimiter.guard(player, "Click", Constants.CLICK.RATE, Constants.CLICK.BURST, function()
			GameService.handleClick(player, "world")
		end)
	end)

	local detectorInner = Instance.new("ClickDetector")
	detectorInner.Name = "TapCore"
	detectorInner.MaxActivationDistance = 60
	detectorInner.Parent = inner
	detectorInner.MouseClick:Connect(function(player: Player)
		RateLimiter.guard(player, "Click", Constants.CLICK.RATE, Constants.CLICK.BURST, function()
			GameService.handleClick(player, "world")
		end)
	end)

	-- Slow spin + bob so the plaza never looks static. Cheap: one Heartbeat hook.
	local basePosition = cube.Position
	local innerOffset = inner.Position - basePosition
	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta: number)
		if not cube.Parent then
			return
		end
		elapsed += delta
		cube.CFrame = CFrame.new(basePosition + Vector3.new(0, math.sin(elapsed * 1.4) * 1.6, 0))
			* CFrame.Angles(0, elapsed * 0.35, math.rad(12))
		inner.CFrame = cube.CFrame * CFrame.new(innerOffset) * CFrame.Angles(0, -elapsed * 0.8, math.rad(45))
	end)

	return cube
end

local function buildSellPad(parent: Instance): Part
	local pad = makeNeon("SellPad", Vector3.new(26, 1, 26), Vector3.new(0, 0.6, 34), GOLD, parent)
	pad.CanCollide = true
	pad.Transparency = 0.15

	local trim = makeNeon("SellPadTrim", Vector3.new(30, 0.4, 30), Vector3.new(0, 0.35, 34), Color3.fromRGB(255, 240, 170), parent)
	trim.Transparency = 0.5
	addLight(pad, GOLD, 3, 34)
	addBillboard(pad, "SELL PAD", "Walk on it to turn power into coins", GOLD, "sell")

	pad.Touched:Connect(function(hit: BasePart)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local now = os.clock()
		if (sellTouched[player] or 0) > now then
			return
		end
		sellTouched[player] = now + Constants.SELL.COOLDOWN
		RateLimiter.guard(player, "Sell", 2, 4, function()
			GameService.handleSell(player)
		end)
	end)

	return pad
end

local function buildEggRing(parent: Instance): ()
	local count = #Pets.Eggs
	for index, egg in ipairs(Pets.Eggs) do
		local angle = (index - 1) / count * math.pi * 2 - math.pi / 2
		local position = Vector3.new(math.cos(angle) * 92, 0.5, math.sin(angle) * 92 - 12)
		local eggColor = if typeof(egg.Color) == "Color3" then egg.Color else ACCENT

		local pedestal = makePart(`{egg.Name}Pedestal`, Vector3.new(14, 3, 14), position, DARK, parent)
		pedestal.Material = Enum.Material.Slate
		local dome = makeNeon(`{egg.Name}Dome`, Vector3.new(8, 8, 8), position + Vector3.new(0, 6, 0), eggColor, parent)
		dome.Shape = Enum.PartType.Ball
		dome.CanCollide = false
		addLight(dome, eggColor, 2.5, 20)

		local unlocked = egg.RebirthRequired == 0
		addBillboard(
			pedestal,
			egg.Name,
			if unlocked then `{Utils.formatNumber(egg.Cost)} coins per hatch` else `{egg.RebirthRequired} rebirths required`,
			eggColor,
			egg.Icon
		)

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Hatch"
		prompt.ObjectText = egg.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 16
		prompt.RequiresLineOfSight = false
		prompt.Parent = pedestal
		prompt.Triggered:Connect(function(player: Player)
			Notifier.panel(player, "Eggs")
		end)
	end
end

local function buildRanksBoard(parent: Instance): ()
	local base = makePart("RanksBoardBase", Vector3.new(26, 1, 8), Vector3.new(0, 0.5, -78), DARK, parent)
	local screen = makeNeon("RanksBoardScreen", Vector3.new(24, 14, 0.6), Vector3.new(0, 8.5, -78), Color3.fromRGB(120, 214, 255), parent)
	screen.CanCollide = true

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Screen"
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(1200, 700)
	surface.LightInfluence = 0
	surface.Parent = screen

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(12, 15, 24)
	background.BorderSizePixel = 0
	background.Parent = surface

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, 0, 0.14, 0)
	heading.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	heading.BorderSizePixel = 0
	heading.Font = Enum.Font.GothamBlack
	heading.TextScaled = true
	heading.TextColor3 = GOLD
	heading.Text = "TOP EARNERS - LIFETIME COINS"
	heading.Parent = background

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0.008, 0)
	layout.Parent = background

	local rows = {}
	for index = 1, 10 do
		local row = Instance.new("TextLabel")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0.078, 0)
		row.BackgroundTransparency = 1
		row.Font = Enum.Font.GothamMedium
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = Color3.fromRGB(206, 214, 228)
		row.Text = `#{index}   -`
		row.Parent = background
		table.insert(rows, row)
	end

	local function refresh()
		local snapshot = LeaderboardService.query()
		for index, row in ipairs(rows) do
			local entry = snapshot.Rows[index]
			if entry then
				row.Text = `#{entry.Rank}   {entry.Name}   -   {Utils.formatNumber(entry.Score)}`
			else
				row.Text = `#{index}   -`
			end
		end
		background.BackgroundColor3 = if snapshot.Live then Color3.fromRGB(12, 15, 24) else Color3.fromRGB(14, 18, 28)
	end

	refresh()
	task.spawn(function()
		while screen.Parent do
			task.wait(Constants.LEADERBOARD.CACHE_SECONDS)
			refresh()
		end
	end)
end

local function buildPillars(parent: Instance): ()
	local count = 12
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 132, 0, math.sin(angle) * 132)
		local pillar = makePart("Pillar", Vector3.new(4, 26, 4), position + Vector3.new(0, 12, 0), Color3.fromRGB(30, 36, 52), parent)
		pillar.Material = Enum.Material.Metal
		local cap = makeNeon("PillarCap", Vector3.new(5, 1, 5), position + Vector3.new(0, 26, 0), ACCENT, parent)
		cap.Transparency = 0.15
		addLight(cap, ACCENT, 1.2, 30)
	end
end

-- ----------------------------------------------------------------------------
-- Entry point
-- ----------------------------------------------------------------------------

local function tuneLighting()
	Lighting.ClockTime = 17.4
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(58, 62, 82)
	Lighting.OutdoorAmbient = Color3.fromRGB(74, 78, 104)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4

	if not Lighting:FindFirstChild("PlazaAtmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Name = "PlazaAtmosphere"
		atmosphere.Density = 0.32
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(190, 200, 230)
		atmosphere.Decay = Color3.fromRGB(96, 118, 168)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.4
		atmosphere.Parent = Lighting
	end
end

function World.build(): Folder
	tuneLighting()

	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		baseplate.Size = Vector3.new(512, 2, 512)
		baseplate.Position = Vector3.new(0, -1, 0)
		baseplate.Anchored = true
		baseplate.Color = FLOOR
		baseplate.Material = Enum.Material.Slate
	else
		makePart("Baseplate", Vector3.new(512, 2, 512), Vector3.new(0, -1, 0), FLOOR, Workspace)
	end

	world.Parent = Workspace

	local plaza = makeNeon("PlazaRing", Vector3.new(210, 0.4, 210), Vector3.new(0, 0.2, 0), Color3.fromRGB(52, 96, 160), world)
	plaza.Shape = Enum.PartType.Cylinder
	plaza.Orientation = Vector3.new(0, 0, 90)
	plaza.Transparency = 0.62

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(0, 0.6, 70)
	spawn.Anchored = true
	spawn.Color = ACCENT
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.25
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	buildCube(world)
	buildSellPad(world)
	buildEggRing(world)
	buildPillars(world)
	buildRanksBoard(world)

	makeKiosk(world, {
		Name = "Upgrades",
		Heading = "UPGRADE LAB",
		Body = "Spend coins on Tap Power, Sell Value, Auto-Farm and Luck.",
		Position = Vector3.new(-62, 0.5, 46),
		Color = Color3.fromRGB(178, 112, 255),
		Panel = "Shop",
		ActionText = "Upgrade",
		Light = true,
	})

	makeKiosk(world, {
		Name = "Quests",
		Heading = "QUEST BOARD",
		Body = "Three new quests every day. Finish them, claim the coins.",
		Position = Vector3.new(62, 0.5, 46),
		Color = Color3.fromRGB(124, 231, 158),
		Panel = "Quests",
		ActionText = "Read",
		Light = true,
	})

	makeKiosk(world, {
		Name = "Rebirth",
		Heading = "REBIRTH ALTAR",
		Body = "Trade everything for a permanent multiplier and new eggs.",
		Position = Vector3.new(-96, 0.5, -46),
		Color = Color3.fromRGB(255, 140, 90),
		Panel = "Rebirth",
		ActionText = "Rebirth",
		Light = true,
	})

	makeKiosk(world, {
		Name = "Codes",
		Heading = "CODE MACHINE",
		Body = "Type a code, get coins, luck and maybe a free pet.",
		Position = Vector3.new(96, 0.5, -46),
		Color = Color3.fromRGB(255, 118, 196),
		Panel = "Codes",
		ActionText = "Redeem",
		Light = true,
	})

	makeKiosk(world, {
		Name = "Daily",
		Heading = "DAILY CHEST",
		Body = "One reward per day. Seven in a row earns a free pet.",
		Position = Vector3.new(0, 0.5, 96),
		Color = Color3.fromRGB(255, 199, 82),
		Panel = "Daily",
		ActionText = "Claim",
		Light = true,
	})

	print("[World] plaza built")
	return world
end

return World
