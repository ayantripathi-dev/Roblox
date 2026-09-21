--[[
	Followers
	Renders every player's equipped pets from the PetFollowers attribute the
	server publishes (a JSON list of { Name, Rarity, Mult }).

	Pets are pure decoration and are owned by the character they orbit, so when
	the character is destroyed they go with it - no leaks, no bookkeeping.
	Multiplayer comes for free: everyone sees everyone's pets.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Pets = require(ReplicatedStorage.Shared.Pets)

local Followers = {}
Followers.__index = Followers

local ORBIT_RADIUS = 4.6
local ORBIT_HEIGHT = 4.2
local MAX_PER_PLAYER = 10

function Followers.new()
	local self = setmetatable({}, Followers)
	self.enabled = true
	self.visuals = {} -- { part, phase, offset, owner }
	self.elapsed = 0
	self.distanceTimer = 0

	self.connection = RunService.Heartbeat:Connect(function(delta)
		self:step(delta)
	end)

	self.characterConnections = {}
	self:watchPlayer(Players.LocalPlayer)

	Players.PlayerAdded:Connect(function(player)
		self:watchPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:dropOwned(player)
		local connections = self.characterConnections[player]
		if connections then
			for _, connection in ipairs(connections) do
				connection:Disconnect()
			end
			self.characterConnections[player] = nil
		end
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= Players.LocalPlayer then
			self:watchPlayer(player)
		end
	end

	return self
end

function Followers:setEnabled(enabled: boolean)
	self.enabled = enabled
	for _, visual in ipairs(self.visuals) do
		visual.part.Transparency = if enabled then visual.transparency else 1
		local gui = visual.part:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = enabled
		end
	end
end


-- ----------------------------------------------------------------------------
-- Watching players
-- ----------------------------------------------------------------------------

function Followers:watchPlayer(player: Player)
	if not self.characterConnections[player] then
		self.characterConnections[player] = {
			player:GetAttributeChangedSignal("PetFollowers"):Connect(function()
				self:rebuild(player)
			end),
			player.CharacterAdded:Connect(function()
				task.wait(0.2)
				self:rebuild(player)
			end),
			player.CharacterRemoving:Connect(function()
				self:dropOwned(player)
			end),
		}
	end
	self:rebuild(player)
end

function Followers:dropOwned(player: Player)
	local kept = {}
	for _, visual in ipairs(self.visuals) do
		if visual.owner == player then
			visual.part:Destroy()
		else
			table.insert(kept, visual)
		end
	end
	self.visuals = kept
end

function Followers:rootOf(player: Player): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- ----------------------------------------------------------------------------
-- Building the pets
-- ----------------------------------------------------------------------------

function Followers:rebuild(player: Player)
	self:dropOwned(player)

	if not self.enabled then
		return
	end

	local root = self:rootOf(player)
	if not root then
		return
	end

	local raw = player:GetAttribute("PetFollowers")
	local list = {}
	if type(raw) == "string" and #raw > 2 then
		local ok, decoded = pcall(function()
			return HttpService:JSONDecode(raw)
		end)
		if ok and type(decoded) == "table" then
			list = decoded
		end
	end

	local holder = Instance.new("Folder")
	holder.Name = "Pets"
	holder.Parent = root

	local count = math.min(#list, MAX_PER_PLAYER)
	for index = 1, count do
		local pet = list[index]
		local color = Pets.color(pet.Rarity)
		local angle = (index - 1) / math.max(1, count) * math.pi * 2

		local part = Instance.new("Part")
		part.Name = pet.Name or "Pet"
		part.Shape = Enum.PartType.Ball
		part.Size = Vector3.new(2.4, 2.4, 2.4)
		part.Color = color
		part.Material = if pet.Rarity == "Secret" then Enum.Material.Neon else Enum.Material.SmoothPlastic
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		-- Anchored on purpose: the orbit is driven by this module, and an
		-- unanchored part welded into the character would shove the player around.
		part.Anchored = true
		part.Transparency = 0.05
		part.CFrame = root.CFrame * CFrame.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
		part.Parent = holder

		local gui = Instance.new("BillboardGui")
		gui.Name = "Tag"
		gui.Size = UDim2.fromOffset(120, 34)
		gui.StudsOffset = Vector3.new(0, 2, 0)
		gui.AlwaysOnTop = false
		gui.MaxDistance = 90
		gui.Parent = part

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.4
		label.Text = `{pet.Name}  x{string.format("%.1f", pet.Mult or 1)}`
		label.Parent = gui

		table.insert(self.visuals, {
			part = part,
			owner = player,
			phase = angle,
			transparency = 0.05,
		})
	end
end

-- ----------------------------------------------------------------------------
-- Animation + visibility budget
-- ----------------------------------------------------------------------------

function Followers:step(delta: number)
	self.elapsed += delta
	self.distanceTimer += delta
	local checkDistance = self.distanceTimer > 0.35
	if checkDistance then
		self.distanceTimer = 0
	end

	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else nil

	for _, visual in ipairs(self.visuals) do
		local part = visual.part
		local holder = part.Parent
		local root = holder and holder.Parent
		if not holder or not root or not root:IsA("BasePart") then
			continue
		end

		-- Distance is checked before any CFrame work, so pets you cannot see
		-- cost nothing to keep in the world.
		if checkDistance and cameraPosition then
			local distance = (root.Position - cameraPosition).Magnitude
			local visible = self.enabled and distance < 220
			part.Transparency = if visible then visual.transparency else 1
			local gui = part:FindFirstChildOfClass("BillboardGui")
			if gui then
				gui.Enabled = visible and distance < 90
			end
			if not visible then
				visual.hidden = true
				continue
			end
			visual.hidden = false
		elseif visual.hidden or not self.enabled then
			continue
		end

		local angle = visual.phase + self.elapsed * 0.9
		local bob = math.sin(self.elapsed * 2.4 + visual.phase) * 0.6
		part.CFrame = root.CFrame * CFrame.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT + bob, math.sin(angle) * ORBIT_RADIUS)
	end
end

function Followers:destroy()
	if self.connection then
		self.connection:Disconnect()
	end
	for player, connections in pairs(self.characterConnections) do
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
		self.characterConnections[player] = nil
	end
	for _, visual in ipairs(self.visuals) do
		visual.part:Destroy()
	end
	self.visuals = {}
end

return Followers
