--[[
	HUD
	The always-on overlay: currencies, the tap loop, the action dock, and every
	piece of feedback the server can send (toasts, floats, reward popups, the
	hatch reveal, rebirth celebration, offline income).

	Design rule: money and power are read from player attributes, which the
	server pushes on every change, so the numbers on screen are always the
	server's numbers - no client-side optimistic math to desync.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Utils = require(ReplicatedStorage.Shared.Utils)

local Theme = require(script.Parent.Theme)

local HUD = {}
HUD.__index = HUD

local function trim(text: string): string
	return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

local KIND_COLORS = {
	info = Theme.Palette.accent,
	good = Theme.Palette.green,
	bad = Theme.Palette.red,
	gold = Theme.Palette.gold,
	luck = Theme.Palette.purple,
}

-- ----------------------------------------------------------------------------
-- Build
-- ----------------------------------------------------------------------------

--[[
	hub = {
		request(name, ...),   -- fire a remote
		openPanel(name),      -- assigned by init.client once Panels exist
		state(),              -- latest snapshot (may be nil early)
		getFollowers(),       -- the follower renderer, for the hide-pets toggle
	}
]]
function HUD.build(hub: any)
	local self = setmetatable({}, HUD)
	self.hub = hub
	self.attributeWiring = {}
	self.modal = nil

	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "SuperSim"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	self.gui = gui

	-- Vignette: keeps white parts of the world from washing out the UI.
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 0.22)
	vignette.BackgroundColor3 = Theme.Palette.backdrop
	vignette.BackgroundTransparency = 0.45
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 0
	vignette.Parent = gui
	Theme.gradient(vignette, Theme.Palette.backdrop, Theme.Palette.backdrop)
	vignette.BackgroundTransparency = 0.55

	self:buildTopBar(gui)
	self:buildDock(gui)
	self:buildTapZone(gui)
	self:buildToastStack(gui)
	self:buildFloaterLayer(gui)
	self:buildSettings(gui)
	self:buildLoading(gui)

	self:bindAttributes(player)
	return self
end

-- ----------------------------------------------------------------------------
-- Top bar
-- ----------------------------------------------------------------------------

function HUD:buildTopBar(gui: ScreenGui)
	local bar = Instance.new("Frame")
	bar.Name = "TopBar"
	bar.BackgroundTransparency = 1
	bar.Size = UDim2.fromOffset(640, 120)
	bar.Position = UDim2.fromOffset(18, 16)
	bar.Parent = gui

	local coins = Theme.chip({
		Parent = bar,
		Name = "Coins",
		Icon = "coin",
		Caption = "coins",
		Accent = Theme.Palette.gold,
		Size = UDim2.fromOffset(196, 52),
		Position = UDim2.fromOffset(0, 0),
		Gradient = { Theme.Palette.panelAlt, Theme.Palette.panel },
		Stroke = Theme.Palette.gold,
	})
	local power = Theme.chip({
		Parent = bar,
		Name = "Power",
		Icon = "power",
		Caption = "power stored",
		Accent = Theme.Palette.accent,
		Size = UDim2.fromOffset(196, 52),
		Position = UDim2.fromOffset(206, 0),
		Gradient = { Theme.Palette.panelAlt, Theme.Palette.panel },
		Stroke = Theme.Palette.accent,
	})

	self.coinsValue = coins:FindFirstChild("Value", true) :: TextLabel
	self.powerValue = power:FindFirstChild("Value", true) :: TextLabel

	-- Rates strip: everything else the player cares about, in small pills.
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundTransparency = 1
	strip.Size = UDim2.fromOffset(620, 32)
	strip.Position = UDim2.fromOffset(2, 60)
	strip.Parent = bar
	Theme.list(strip, 6, { Horizontal = true })

	self.rateValues = {}
	local function statPill(name: string, caption: string, color: Color3, order: number)
		local holder = Theme.card({
			Parent = strip,
			Size = UDim2.fromOffset(118, 30),
			Color = Theme.Palette.panel,
			Transparency = 0.2,
			Radius = Theme.Radius.pill,
			Stroke = color,
			StrokeTransparency = 0.6,
			LayoutOrder = order,
		})
		Theme.label({
			Parent = holder,
			Name = "Caption",
			Size = UDim2.fromOffset(46, 30),
			Position = UDim2.fromOffset(12, 0),
			Text = caption,
			TextSize = 11,
			TextColor = Theme.Palette.muted,
		})
		local value = Theme.label({
			Parent = holder,
			Name = "Value",
			Size = UDim2.new(1, -60, 1, 0),
			Position = UDim2.fromOffset(56, 0),
			Text = "-",
			Font = Theme.Font.bold,
			TextSize = 13,
			TextColor = color,
			XAlign = Enum.TextXAlignment.Right,
		})
		self.rateValues[name] = value
	end

	statPill("Rate", "PWR/s", Theme.Palette.green, 1)
	statPill("Income", "$/s", Theme.Palette.gold, 2)
	statPill("Luck", "luck", Theme.Palette.purple, 3)
	statPill("Slots", "slots", Theme.Palette.pink, 4)
	statPill("Rebirth", "rebirths", Theme.Palette.orange, 5)

	-- Studded backplate under the bar: the classic brick surface, in UI form.
	Theme.studBand(bar, {
		Size = UDim2.fromOffset(540, 24),
		Position = UDim2.fromOffset(2, 96),
		Columns = 16,
		Rows = 1,
		StudSize = 11,
		Spacing = 8,
		Inset = 8,
		Color = Theme.Palette.panel,
		Transparency = 0.72,
		Radius = Theme.Radius.pill,
	})
end

-- ----------------------------------------------------------------------------
-- Action dock
-- ----------------------------------------------------------------------------

function HUD:buildDock(gui: ScreenGui)
	local dock = Instance.new("Frame")
	dock.Name = "Dock"
	dock.BackgroundTransparency = 1
	dock.AnchorPoint = Vector2.new(0, 0.5)
	dock.Position = UDim2.fromScale(0, 0.5)
	dock.Size = UDim2.fromOffset(132, 0)
	dock.AutomaticSize = Enum.AutomaticSize.Y
	dock.Parent = gui
	Theme.list(dock, 7)

	local entries = {
		{ Panel = "Shop", Text = "Upgrades", Icon = "upgrade", Color = Theme.Palette.purple },
		{ Panel = "Eggs", Text = "Eggs", Icon = "egg", Color = Theme.Palette.green },
		{ Panel = "Pets", Text = "Pets", Icon = "pet", Color = Theme.Palette.pink },
		{ Panel = "Quests", Text = "Quests", Icon = "quest", Color = Theme.Palette.green },
		{ Panel = "Index", Text = "Index", Icon = "index", Color = Theme.Palette.accent },
		{ Panel = "Rebirth", Text = "Rebirth", Icon = "rebirth", Color = Theme.Palette.orange },
		{ Panel = "Daily", Text = "Daily", Icon = "daily", Color = Theme.Palette.gold },
		{ Panel = "Codes", Text = "Codes", Icon = "code", Color = Theme.Palette.pink },
		{ Panel = "Ranks", Text = "Ranks", Icon = "rank", Color = Theme.Palette.gold },
		{ Panel = "Store", Text = "Store", Icon = "store", Color = Theme.Palette.accent },
	}

	self.dockButtons = {}
	for index, entry in ipairs(entries) do
		local button = Theme.button({
			Parent = dock,
			Name = entry.Panel,
			Size = UDim2.fromOffset(132, 46),
			Text = entry.Text,
			Icon = entry.Icon,
			IconSize = 19,
			Font = Theme.Font.bold,
			TextSize = 14,
			Color = Theme.Palette.panel,
			Accent = entry.Color,
			LayoutOrder = index,
			Radius = Theme.Radius.pill,
			OnClick = function()
				if self.hub.openPanel then
					self.hub.openPanel(entry.Panel)
				end
			end,
		})
		local title = button:FindFirstChild("Title") :: TextLabel
		title.TextXAlignment = Enum.TextXAlignment.Left
		title.TextScaled = false
		title.TextSize = 14
		self.dockButtons[entry.Panel] = button
	end
end

-- ----------------------------------------------------------------------------
-- Tap / sell zone
-- ----------------------------------------------------------------------------

function HUD:buildTapZone(gui: ScreenGui)
	local holder = Instance.new("Frame")
	holder.Name = "ActionZone"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -24)
	holder.Size = UDim2.fromOffset(460, 210)
	holder.Parent = gui

	-- Combo meter
	local comboCard = Theme.card({
		Parent = holder,
		Name = "Combo",
		Size = UDim2.fromOffset(220, 44),
		Position = UDim2.new(0.5, 0, 0, 0),
		Color = Theme.Palette.panel,
		Transparency = 0.15,
		Gradient = { Theme.Palette.panelAlt, Theme.Palette.panel },
		Radius = Theme.Radius.medium,
		Stroke = Theme.Palette.accent,
		StrokeTransparency = 0.55,
	})
	comboCard.AnchorPoint = Vector2.new(0.5, 0)
	comboCard.Visible = false

	self.comboLabel = Theme.label({
		Parent = comboCard,
		Name = "ComboText",
		Size = UDim2.new(1, -20, 0, 22),
		Position = UDim2.fromOffset(10, 6),
		Text = "COMBO x1.0",
		Font = Theme.Font.black,
		TextSize = 16,
		TextColor = Theme.Palette.accent,
		XAlign = Enum.TextXAlignment.Center,
	})
	local _, setCombo = Theme.bar({
		Parent = comboCard,
		Size = UDim2.new(1, -20, 0, 6),
		Position = UDim2.fromOffset(10, 30),
		Color = Theme.Palette.accent,
	})
	self.setComboFill = setCombo
	self.comboCard = comboCard

	-- Tap button
	local tap = Theme.button({
		Parent = holder,
		Name = "TapButton",
		Size = UDim2.fromOffset(168, 168),
		Position = UDim2.new(0.5, -6, 1, 0),
		Color = Theme.Palette.panelSoft,
		Accent = Theme.Palette.accent,
		Text = "TAP",
		Font = Theme.Font.black,
		Radius = Theme.Radius.pill,
	})
	tap.AnchorPoint = Vector2.new(0.5, 1)
	tap:FindFirstChild("Title").TextSize = 30
	Theme.shine(tap)

	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.BackgroundTransparency = 1
	ring.Size = UDim2.fromScale(1, 1)
	ring.Parent = tap
	Theme.corner(ring, Theme.Radius.pill)
	Theme.stroke(ring, Theme.Palette.accent, 3, 0.7)

	self.tapSub = Theme.label({
		Parent = tap,
		Name = "Sub",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.new(0, 8, 1, -26),
		Text = "+1 power",
		TextSize = 13,
		TextColor = Theme.Palette.muted,
		XAlign = Enum.TextXAlignment.Center,
	})
	self.tapButton = tap

	-- Sell button
	local sell = Theme.button({
		Parent = holder,
		Name = "SellButton",
		Size = UDim2.fromOffset(150, 78),
		Position = UDim2.new(0.5, 214, 1, -10),
		Color = Theme.Palette.panel,
		Accent = Theme.Palette.gold,
		Text = "SELL",
		Sub = "0 power stored",
		Font = Theme.Font.black,
		Radius = Theme.Radius.medium,
		OnClick = function()
			self.hub.request("Sell")
		end,
	})
	sell.AnchorPoint = Vector2.new(0, 1)
	self.sellButton = sell
	self.sellSub = sell:FindFirstChild("Sub") :: TextLabel

	-- Tap behaviour: one tap per click, and holding repeats it for Turbo Tap owners.
	-- (Click fires after MouseButton1Down, so the repeat loop must never also tap
	-- on press, or every single click would count twice.)
	local holding = false
	local holdThread = nil

	local function tapOnce()
		self.hub.request("Click")
		self:comboOnTap()
	end

	tap.MouseButton1Click:Connect(tapOnce)

	local function stopHold()
		holding = false
		if holdThread then
			task.cancel(holdThread)
			holdThread = nil
		end
	end

	tap.MouseButton1Down:Connect(function()
		if not Players.LocalPlayer:GetAttribute("TurboClick") then
			return
		end
		holding = true
		if holdThread then
			return
		end
		holdThread = task.spawn(function()
			while holding do
				tapOnce()
				task.wait(0.09)
			end
			holdThread = nil
		end)
	end)
	tap.MouseButton1Up:Connect(stopHold)
	tap.MouseLeave:Connect(stopHold)

	-- Space bar as an alternative tap key, for people who dislike clicking.
	local UserInputService = game:GetService("UserInputService")
	UserInputService.InputBegan:Connect(function(input, processed)
		-- `processed` is true inside a TextBox, so typing a code never taps.
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space then
			tapOnce()
		end
	end)
end

-- Local combo readout. Mirrors Constants.CLICK so it can never lie.
function HUD:comboOnTap()
	local now = os.clock()
	if not self.comboCount or (now - (self.comboLast or 0)) > Constants.CLICK.COMBO_WINDOW then
		self.comboCount = 0
	end
	self.comboCount += 1
	self.comboLast = now

	local multiplier = math.min(1 + (self.comboCount - 1) * Constants.CLICK.COMBO_STEP, Constants.CLICK.COMBO_MAX)
	self.comboLabel.Text = string.format("COMBO x%.2f", multiplier)
	self.comboCard.Visible = true
	self.setComboFill((multiplier - 1) / (Constants.CLICK.COMBO_MAX - 1) + 0.06)

	if not self.comboThread then
		self.comboThread = task.spawn(function()
			while true do
				task.wait(0.1)
				local idle = os.clock() - (self.comboLast or 0)
				if idle > Constants.CLICK.COMBO_WINDOW then
					self.comboCount = 0
					self.comboCard.Visible = false
					self.comboThread = nil
					break
				end
				self.setComboFill(1 - idle / Constants.CLICK.COMBO_WINDOW)
			end
		end)
	end
end

-- ----------------------------------------------------------------------------
-- Toasts, floaters, modals
-- ----------------------------------------------------------------------------

function HUD:buildToastStack(gui: ScreenGui)
	local stack = Instance.new("Frame")
	stack.Name = "Toasts"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(0.5, 0)
	stack.Position = UDim2.new(0.5, 0, 0, 118)
	stack.Size = UDim2.fromOffset(420, 400)
	stack.Parent = gui
	Theme.list(stack, 6, { HAlign = Enum.HorizontalAlignment.Center })

	self.toastStack = stack
	self.toastCount = 0
end

function HUD:toast(payload: any)
	local text = trim(tostring(payload and payload.Text or ""))
	if text == "" then
		return
	end

	local kind = (payload and payload.Kind) or "info"
	local color = KIND_COLORS[kind] or Theme.Palette.accent

	local card = Theme.card({
		Parent = self.toastStack,
		Size = UDim2.fromOffset(400, 46),
		Color = Theme.Palette.panel,
		Transparency = 0.05,
		Gradient = { Theme.Palette.panelAlt, Theme.Palette.panel },
		Radius = Theme.Radius.medium,
		Stroke = color,
		StrokeTransparency = 0.4,
	})

	local accentBar = Instance.new("Frame")
	accentBar.Size = UDim2.fromOffset(5, 30)
	accentBar.Position = UDim2.fromOffset(10, 8)
	accentBar.BackgroundColor3 = color
	accentBar.BorderSizePixel = 0
	accentBar.Parent = card
	Theme.corner(accentBar, Theme.Radius.pill)

	local iconName = payload and payload.Icon
	if type(iconName) == "string" and iconName ~= "" then
		Theme.icon(card, iconName, {
			Size = 21,
			Position = UDim2.fromOffset(38, 23),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Tint = color,
			ZIndex = 2,
		})
	end

	Theme.label({
		Parent = card,
		Name = "Text",
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(58, 0),
		Text = text,
		Font = Theme.Font.medium,
		TextSize = 14,
		TextWrapped = false,
		TextColor = Theme.Palette.text,
	})

	card.BackgroundTransparency = 1
	TweenService:Create(card, TweenInfo.new(0.18), { BackgroundTransparency = 0.05 }):Play()

	self.toastCount += 1
	local order = self.toastCount

	task.delay(4.5, function()
		if not card.Parent then
			return
		end
		TweenService:Create(card, TweenInfo.new(0.25), { BackgroundTransparency = 1 }):Play()
		task.wait(0.25)
		card:Destroy()
	end)
end

function HUD:buildFloaterLayer(gui: ScreenGui)
	local layer = Instance.new("Frame")
	layer.Name = "Floaters"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 20
	layer.Parent = gui
	self.floaterLayer = layer
end

-- Power gained from a tap, floating up from the tap button.
function HUD:floatPower(text: string, color: Color3?)
	local button = self.tapButton
	local x = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	local y = button.AbsolutePosition.Y

	local floater = Theme.label({
		Parent = self.floaterLayer,
		Name = "Floater",
		Size = UDim2.fromOffset(200, 30),
		Position = UDim2.fromOffset(x - 100, y - 20),
		Text = text,
		Font = Theme.Font.black,
		TextSize = 20,
		TextColor = color or Theme.Palette.accent,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 21,
	})
	floater.TextStrokeTransparency = 0.3

	local drift = math.random(-28, 28)
	TweenService:Create(floater, TweenInfo.new(0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(x - 100 + drift, y - 120),
		TextTransparency = 1,
	}):Play()
	task.delay(0.9, function()
		floater:Destroy()
	end)
end

-- Coins flying up from the sell button.
function HUD:floatCoins(text: string)
	local button = self.sellButton
	local x = button.AbsolutePosition.X + button.AbsoluteSize.X / 2
	local y = button.AbsolutePosition.Y

	local floater = Theme.label({
		Parent = self.floaterLayer,
		Size = UDim2.fromOffset(260, 34),
		Position = UDim2.fromOffset(x - 130, y - 20),
		Text = text,
		Font = Theme.Font.black,
		TextSize = 22,
		TextColor = Theme.Palette.gold,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 21,
	})
	floater.TextStrokeTransparency = 0.25

	TweenService:Create(floater, TweenInfo.new(1, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.fromOffset(x - 130, y - 130),
		TextTransparency = 1,
	}):Play()
	task.delay(1.1, function()
		floater:Destroy()
	end)
end

-- --- modal helpers ---------------------------------------------------------

function HUD:closeModal()
	if self.modal then
		local old = self.modal
		self.modal = nil
		TweenService:Create(old, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
		for _, descendant in ipairs(old:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				TweenService:Create(descendant, TweenInfo.new(0.16), { TextTransparency = 1 }):Play()
			elseif descendant:IsA("Frame") or descendant:IsA("TextButton") then
				TweenService:Create(descendant, TweenInfo.new(0.16), { BackgroundTransparency = 1 }):Play()
			end
		end
		task.delay(0.2, function()
			if old.Parent then
				old:Destroy()
			end
		end)
	end
end

-- Shared modal chrome: dimmer + centered card + close button.
function HUD:newModal(size: UDim2, accent: Color3, title: string, subtitle: string?)
	self:closeModal()

	local dimmer = Instance.new("Frame")
	dimmer.Name = "Modal"
	dimmer.BackgroundColor3 = Theme.Palette.backdrop
	dimmer.BackgroundTransparency = 0.45
	dimmer.BorderSizePixel = 0
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.ZIndex = 40
	dimmer.Parent = self.gui

	local card = Theme.card({
		Parent = dimmer,
		Name = "ModalCard",
		Size = size,
		Position = UDim2.fromScale(0.5, 0.5),
		Color = Theme.Palette.panel,
		Transparency = 0,
		Gradient = { Theme.Palette.panelAlt, Theme.Palette.panel },
		Radius = Theme.Radius.large,
		Stroke = accent,
		StrokeThickness = 2,
		StrokeTransparency = 0.25,
	})
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ZIndex = 41
	Theme.shine(card)

	Theme.label({
		Parent = card,
		Name = "Title",
		Size = UDim2.new(1, -100, 0, 34),
		Position = UDim2.fromOffset(24, 20),
		Text = title,
		Font = Theme.Font.black,
		TextSize = 24,
		TextColor = accent,
		ZIndex = 42,
	})

	if subtitle and subtitle ~= "" then
		Theme.label({
			Parent = card,
			Name = "Subtitle",
			Size = UDim2.new(1, -48, 0, 24),
			Position = UDim2.fromOffset(24, 54),
			Text = subtitle,
			TextSize = 14,
			TextColor = Theme.Palette.muted,
			ZIndex = 42,
		})
	end

	local close = Theme.button({
		Parent = card,
		Name = "Close",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(1, -48, 0, 16),
		IconOnly = true,
		Icon = "close",
		IconSize = 18,
		Color = Theme.Palette.panelSoft,
		Accent = Theme.Palette.muted,
		Radius = Theme.Radius.pill,
		OnClick = function()
			self:closeModal()
		end,
	})
	close.ZIndex = 43

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -48, 1, -110)
	body.Position = UDim2.fromOffset(24, 86)
	body.ZIndex = 42
	body.Parent = card

	self.modal = dimmer
	return dimmer, card, body
end

-- --- reward popup ----------------------------------------------------------

function HUD:reward(payload: any)
	payload = payload or {}
	local iconName = if payload.Pet then "star" else (payload.Icon or "daily")
	local title = payload.Title or "Reward"
	local subtitle = payload.Subtitle or ""

	local _, _, body = self:newModal(UDim2.fromOffset(440, 300), Theme.Palette.gold, title, subtitle)
	Theme.corner(body, Theme.Radius.small)

	Theme.icon(body, iconName, {
		Size = 64,
		Position = UDim2.fromOffset(14, 12),
		Tint = Theme.Palette.gold,
		ZIndex = 43,
	})

	local rows = Instance.new("Frame")
	rows.BackgroundTransparency = 1
	rows.Size = UDim2.new(1, -100, 1, 0)
	rows.Position = UDim2.fromOffset(92, 4)
	rows.Parent = body
	Theme.list(rows, 6)

	local function addRow(text: string, color: Color3)
		Theme.label({
			Parent = rows,
			Size = UDim2.new(1, 0, 0, 22),
			Text = text,
			Font = Theme.Font.bold,
			TextSize = 15,
			TextColor = color,
			ZIndex = 43,
		})
	end

	if (payload.Coins or 0) > 0 then
		addRow(`+{Utils.comma(payload.Coins)} coins`, Theme.Palette.gold)
	end
	if (payload.Power or 0) > 0 then
		addRow(`+{Utils.comma(payload.Power)} power`, Theme.Palette.accent)
	end
	if (payload.Luck or 0) > 0 then
		addRow(`+{payload.Luck} luck for {payload.LuckMinutes or 0}m`, Theme.Palette.purple)
	end
	if payload.Pet then
		local rarity = payload.Pet.Rarity or "Common"
		addRow(`{payload.Pet.Name} ({rarity}, {Utils.formatMultiplier(payload.Pet.Mult)})`, Pets.color(rarity))
	end

	Theme.button({
		Parent = body,
		Name = "Claim",
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 1, -44),
		Text = "NICE!",
		Font = Theme.Font.black,
		Color = Theme.Palette.panelSoft,
		Accent = Theme.Palette.gold,
		OnClick = function()
			self:closeModal()
		end,
	})

	task.delay(9, function()
		if self.modal then
			self:closeModal()
		end
	end)
end

-- --- hatch reveal ----------------------------------------------------------

function HUD:hatch(payload: any)
	local results = (payload and payload.Results) or {}
	if #results == 0 then
		return
	end

	local best = (payload and payload.Best) or results[1]
	local accent = Pets.color(best.Rarity)

	local _, _, body = self:newModal(
		UDim2.fromOffset(640, 340),
		accent,
		`{payload.Egg or "Egg"} opened`,
		if payload.IsNew then "New pets discovered!" else `Spent {Utils.comma(payload.Spent or 0)} coins`
	)

	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(1, 0, 1, -8)
	grid.CanvasSize = UDim2.new()
	grid.ScrollBarThickness = 3
	grid.ScrollBarImageColor3 = accent
	grid.Parent = body

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(112, 76)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local size = Instance.new("AutomaticCanvasSize")
	size.SizingMode = Enum.AutomaticSize.Y
	size.Parent = grid

	table.sort(results, function(a, b)
		return Pets.rank(a.Rarity) > Pets.rank(b.Rarity)
	end)

	for index, pet in ipairs(results) do
		local color = Pets.color(pet.Rarity)
		local card = Theme.card({
			Parent = grid,
			Name = pet.Name,
			Size = UDim2.fromOffset(112, 76),
			Color = color,
			Transparency = 0.84,
			Radius = Theme.Radius.small,
			Stroke = color,
			StrokeTransparency = 0.3,
			LayoutOrder = index,
		})

		if pet.IsNew then
			Theme.label({
				Parent = card,
				Name = "New",
				Size = UDim2.fromOffset(38, 18),
				Position = UDim2.new(1, -42, 0, 6),
				Text = "NEW",
				Font = Theme.Font.black,
				TextSize = 10,
				TextColor = Theme.Palette.gold,
				XAlign = Enum.TextXAlignment.Center,
			})
		end

		Theme.label({
			Parent = card,
			Name = "Name",
			Size = UDim2.new(1, -12, 0, 20),
			Position = UDim2.fromOffset(6, 10),
			Text = pet.Name,
			Font = Theme.Font.bold,
			TextSize = 13,
			TextColor = Theme.Palette.text,
			XAlign = Enum.TextXAlignment.Center,
		})
		Theme.label({
			Parent = card,
			Name = "Rarity",
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.fromOffset(6, 32),
			Text = pet.Rarity,
			Font = Theme.Font.medium,
			TextSize = 11,
			TextColor = color,
			XAlign = Enum.TextXAlignment.Center,
		})
		Theme.label({
			Parent = card,
			Name = "Mult",
			Size = UDim2.new(1, -12, 0, 16),
			Position = UDim2.fromOffset(6, 50),
			Text = Utils.formatMultiplier(pet.Mult),
			Font = Theme.Font.black,
			TextSize = 12,
			TextColor = Theme.Palette.muted,
			XAlign = Enum.TextXAlignment.Center,
		})
	end

	task.delay(7, function()
		if self.modal then
			self:closeModal()
		end
	end)
end

-- --- sale / rebirth / offline ---------------------------------------------

function HUD:sale(payload: any)
	if not payload then
		return
	end
	self:floatCoins(`+{Utils.comma(payload.Coins)} coins`)
end

function HUD:celebrate(payload: any)
	payload = payload or {}
	local flash = Instance.new("Frame")
	flash.BackgroundColor3 = Theme.Palette.orange
	flash.BackgroundTransparency = 0.55
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 30
	flash.Parent = self.gui

	local crown = Theme.icon(flash, "crown", {
		Size = 76,
		Position = UDim2.new(0.5, -38, 0.32, -104),
		Tint = Theme.Palette.gold,
		ZIndex = 31,
	})
	for _, part in ipairs(crown:GetChildren()) do
		if part:IsA("GuiObject") then
			TweenService:Create(part, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
		end
	end

	local banner = Theme.label({
		Parent = flash,
		Size = UDim2.new(1, 0, 0, 120),
		Position = UDim2.fromScale(0, 0.32),
		Text = `REBIRTH {payload.Rebirths or "?"}!`,
		Font = Theme.Font.black,
		TextSize = 64,
		TextColor = Theme.Palette.text,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 31,
	})

	local detail = Theme.label({
		Parent = flash,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromScale(0, 0.32),
		Text = string.format("Everything now earns x%.2f", payload.Multiplier or 1),
		Font = Theme.Font.bold,
		TextSize = 22,
		TextColor = Theme.Palette.panel,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 31,
	})
	detail.Position = UDim2.new(0, 0, 0.32, 96)

	TweenService:Create(flash, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(banner, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	TweenService:Create(detail, TweenInfo.new(1.2), { TextTransparency = 1 }):Play()
	task.delay(1.3, function()
		flash:Destroy()
	end)

	if payload.NewEggs and #payload.NewEggs > 0 then
		self:toast({ Text = `New egg unlocked: {payload.NewEggs[1]}`, Kind = "gold", Icon = "egg" })
	end
	if (payload.NewSlots or 0) > 0 then
		self:toast({ Text = `+{payload.NewSlots} pet slot(s) unlocked`, Kind = "good", Icon = "pet" })
	end
end

function HUD:offline(payload: any)
	payload = payload or {}
	self:reward({
		Title = "Welcome back!",
		Subtitle = `You were away for {Utils.formatTime(payload.Seconds)}`,
		Icon = "clock",
		Coins = payload.Coins,
	})
end

-- ----------------------------------------------------------------------------
-- Settings + loading
-- ----------------------------------------------------------------------------

function HUD:buildSettings(gui: ScreenGui)
	local holder = Theme.card({
		Parent = gui,
		Name = "Settings",
		Size = UDim2.fromOffset(196, 42),
		Position = UDim2.new(1, -214, 1, -60),
		Color = Theme.Palette.panel,
		Transparency = 0.1,
		Radius = Theme.Radius.pill,
		Stroke = Theme.Palette.strokeSoft,
		StrokeTransparency = 0.4,
	})
	holder.AnchorPoint = Vector2.new(0, 1)

	local petsVisible = true

	local toggle = Theme.button({
		Parent = holder,
		Name = "TogglePets",
		Size = UDim2.fromOffset(90, 32),
		Position = UDim2.fromOffset(6, 5),
		Text = "HIDE PETS",
		TextSize = 12,
		Font = Theme.Font.bold,
		Icon = "pet",
		IconSize = 15,
		Color = Theme.Palette.panelSoft,
		Accent = Theme.Palette.pink,
		Radius = Theme.Radius.pill,
		OnClick = function()
			petsVisible = not petsVisible
			local title = toggle:FindFirstChild("Title") :: TextLabel
			title.Text = if petsVisible then "HIDE PETS" else "SHOW PETS"
			if self.hub.getFollowers then
				self.hub.getFollowers():setEnabled(petsVisible)
			end
		end,
	})
	toggle:FindFirstChild("Title").TextScaled = false

	Theme.button({
		Parent = holder,
		Name = "Store",
		Size = UDim2.fromOffset(90, 32),
		Position = UDim2.fromOffset(100, 5),
		Text = "STORE",
		TextSize = 12,
		Font = Theme.Font.bold,
		Icon = "store",
		IconSize = 15,
		Color = Theme.Palette.panelSoft,
		Accent = Theme.Palette.accent,
		Radius = Theme.Radius.pill,
		OnClick = function()
			if self.hub.openPanel then
				self.hub.openPanel("Store")
			end
		end,
	})
end

function HUD:buildLoading(gui: ScreenGui)
	local overlay = Instance.new("Frame")
	overlay.Name = "Loading"
	overlay.BackgroundColor3 = Theme.Palette.backdrop
	overlay.BackgroundTransparency = 0.1
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.ZIndex = 50
	overlay.Parent = gui

	Theme.label({
		Parent = overlay,
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromScale(0, 0.46),
		Text = "LOADING YOUR SAVE",
		Font = Theme.Font.black,
		TextSize = 28,
		TextColor = Theme.Palette.accent,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 51,
	})

	Theme.label({
		Parent = overlay,
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromScale(0, 0.46),
		Text = "grabbing your coins, pets and quests...",
		TextSize = 15,
		TextColor = Theme.Palette.muted,
		XAlign = Enum.TextXAlignment.Center,
		ZIndex = 51,
	}).Position = UDim2.new(0, 0, 0.46, 44)

	Theme.icon(overlay, "star", {
		Size = 54,
		Position = UDim2.new(0.5, 0, 0.46, -86),
		AnchorPoint = Vector2.new(0.5, 0),
		Tint = Theme.Palette.accent,
		ZIndex = 51,
	})

	Theme.studBand(overlay, {
		Size = UDim2.new(0, 420, 0, 26),
		Position = UDim2.new(0.5, -210, 0.46, 80),
		Columns = 14,
		Rows = 1,
		StudSize = 12,
		Spacing = 8,
		Inset = 10,
		Transparency = 0.55,
		Radius = Theme.Radius.pill,
		ZIndex = 51,
	})

	self.loadingOverlay = overlay
end

function HUD:setLoading(loading: boolean)
	if not self.loadingOverlay then
		return
	end
	if loading then
		self.loadingOverlay.Visible = true
		TweenService:Create(self.loadingOverlay, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()
	elseif self.loadingOverlay.Visible then
		TweenService:Create(self.loadingOverlay, TweenInfo.new(0.3), { BackgroundTransparency = 1 }):Play()
		task.delay(0.32, function()
			if self.loadingOverlay then
				self.loadingOverlay.Visible = false
			end
		end)
	end
end

-- ----------------------------------------------------------------------------
-- Live attribute wiring
-- ----------------------------------------------------------------------------

function HUD:bindAttributes(player: Player)
	local function refresh()
		local coins = player:GetAttribute("Coins") or 0
		local power = player:GetAttribute("Power") or 0
		self.coinsValue.Text = Utils.comma(coins)
		self.powerValue.Text = Utils.formatNumber(power)

		local perClick = player:GetAttribute("PowerPerClick") or 1
		self.tapSub.Text = `+{Utils.formatNumber(perClick)} power per tap`
		self.sellSub.Text = `{Utils.formatNumber(power)} power stored`

		-- Only ding the sell button when it is actually worth pressing.
		local affordable = power >= 1
		Theme.paintButton(self.sellButton, Theme.Palette.gold, affordable)

		local rates = self.rateValues
		rates.Rate.Text = Utils.formatNumber(player:GetAttribute("PowerPerSecond") or 0)
		rates.Income.Text = Utils.formatNumber(player:GetAttribute("CoinsPerSecond") or 0)
		rates.Luck.Text = Utils.formatMultiplier(1 + (player:GetAttribute("Luck") or 0))
		rates.Slots.Text = `{player:GetAttribute("PetSlotsUsed") or 0}/{player:GetAttribute("PetSlots") or 3}`
		rates.Rebirth.Text = `{player:GetAttribute("Rebirths") or 0} (x{Utils.formatMultiplier(player:GetAttribute("RebirthMultiplier") or 1)})`
	end

	refresh()
	for _, attribute in ipairs({
		"Coins",
		"Power",
		"PowerPerClick",
		"PowerPerSecond",
		"CoinsPerSecond",
		"Luck",
		"PetSlots",
		"PetSlotsUsed",
		"Rebirths",
		"RebirthMultiplier",
		"TurboClick",
	}) do
		table.insert(self.attributeWiring, player:GetAttributeChangedSignal(attribute):Connect(refresh))
	end

	-- Tap floaters: locally predicted, so tapping feels instant.
	local lastPower = player:GetAttribute("Power") or 0
	table.insert(self.attributeWiring, player:GetAttributeChangedSignal("Power"):Connect(function()
		local now = player:GetAttribute("Power") or 0
		local delta = now - lastPower
		lastPower = now
		if delta > 0 and delta < 1e12 then
			self:floatPower(`+{Utils.formatNumber(delta)}`)
		end
	end))
end

return HUD
