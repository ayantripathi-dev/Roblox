--[[
	Panels
	Every menu in the game: upgrades, eggs, pets, quests, index, rebirth, daily,
	codes, ranks and the store.

	One shell, ten builders. Each builder gets a scrolling body and draws itself
	from the latest StateSnapshot, so a panel can never show numbers the server
	did not send. Anything that costs something re-reads the cost from the shared
	config (Upgrades/Pets/Constants) - the same files the server uses - which is
	why the client's "you need 1,250 coins" always matches the server's answer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Codes = require(ReplicatedStorage.Shared.Codes)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Pets = require(ReplicatedStorage.Shared.Pets)
local Upgrades = require(ReplicatedStorage.Shared.Upgrades)
local Utils = require(ReplicatedStorage.Shared.Utils)

local Theme = require(script.Parent.Theme)

local Panels = {}
Panels.__index = Panels

local P = Theme.Palette

-- The icon shown in each panel's header (see shared/Icons.luau).
local PANEL_ICONS = {
	Shop = "upgrade",
	Eggs = "egg",
	Pets = "pet",
	Quests = "quest",
	Index = "index",
	Rebirth = "rebirth",
	Daily = "daily",
	Codes = "code",
	Ranks = "rank",
	Store = "store",
}

-- ----------------------------------------------------------------------------
-- Shell
-- ----------------------------------------------------------------------------

function Panels.build(gui: ScreenGui, hub: any)
	local self = setmetatable({}, Panels)
	self.gui = gui
	self.hub = hub
	self.state = nil
	self.quests = nil
	self.rerollsLeft = 0
	self.leaderboard = nil
	self.openName = nil
	self.builder = {}

	self:registerBuilders()

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape and self.openName then
			self:close()
		end
	end)

	return self
end

function Panels:open(name: string)
	local builder = self.builder[name]
	if not builder then
		return
	end

	self:close()
	self.openName = name

	-- The board is cached for a minute server side, so ask for a fresh copy when
	-- the player actually looks at it.
	if name == "Ranks" then
		self.hub.request("RequestLeaderboard")
	end

	local dimmer = Instance.new("Frame")
	dimmer.Name = `Panel_{name}`
	dimmer.BackgroundColor3 = P.backdrop
	dimmer.BackgroundTransparency = 0.4
	dimmer.BorderSizePixel = 0
	dimmer.Size = UDim2.fromScale(1, 1)
	dimmer.ZIndex = 25
	dimmer.Parent = self.gui

	local card = Theme.card({
		Parent = dimmer,
		Name = "Sheet",
		Size = UDim2.new(1, -70, 1, -150),
		Position = UDim2.fromScale(0.5, 0.5),
		Color = P.panel,
		Transparency = 0,
		Gradient = { P.panelAlt, P.panel },
		Radius = Theme.Radius.large,
		Stroke = P.stroke,
		StrokeThickness = 2,
		StrokeTransparency = 0.35,
	})
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.ZIndex = 26

	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(960, 640)
	sizeLimit.MinSize = Vector2.new(420, 320)
	sizeLimit.Parent = card

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = P.backdrop
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, -48, 0, 68)
	header.Position = UDim2.fromOffset(24, 18)
	header.ZIndex = 27
	header.Parent = card

	Theme.icon(header, PANEL_ICONS[name] or "star", {
		Size = 32,
		Position = UDim2.fromOffset(0, 6),
		Tint = P.accent,
		ZIndex = 28,
	})

	self.titleLabel = Theme.label({
		Parent = header,
		Name = "Title",
		Size = UDim2.new(1, -104, 0, 32),
		Position = UDim2.fromOffset(44, 0),
		Text = name,
		Font = Theme.Font.black,
		TextSize = 26,
		TextColor = P.text,
		ZIndex = 28,
	})

	self.subtitleLabel = Theme.label({
		Parent = header,
		Name = "Subtitle",
		Size = UDim2.new(1, -104, 0, 22),
		Position = UDim2.fromOffset(44, 34),
		Text = "",
		TextSize = 14,
		TextColor = P.muted,
		ZIndex = 28,
	})

	-- Studded strip along the bottom of the sheet, matching the HUD chrome.
	Theme.studBand(card, {
		Size = UDim2.new(1, -48, 0, 24),
		Position = UDim2.new(0, 24, 1, -36),
		Columns = 16,
		Rows = 1,
		StudSize = 12,
		Spacing = 8,
		Inset = 10,
		Transparency = 0.7,
		Radius = Theme.Radius.pill,
		Color = P.panelSoft,
		ZIndex = 25,
	})

	local close = Theme.button({
		Parent = header,
		Name = "Close",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -40, 0, 4),
		IconOnly = true,
		Icon = "close",
		IconSize = 19,
		Color = P.panelSoft,
		Accent = P.muted,
		Radius = Theme.Radius.pill,
		OnClick = function()
			self:close()
		end,
	})
	close.ZIndex = 29

	local divider = Instance.new("Frame")
	divider.BackgroundColor3 = P.stroke
	divider.BackgroundTransparency = 0.4
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, -48, 0, 1)
	divider.Position = UDim2.fromOffset(24, 92)
	divider.ZIndex = 27
	divider.Parent = card

	local body = Instance.new("ScrollingFrame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Size = UDim2.new(1, -48, 1, -160)
	body.Position = UDim2.fromOffset(24, 106)
	body.CanvasSize = UDim2.new()
	body.ScrollBarThickness = 4
	body.ScrollBarImageColor3 = P.stroke
	body.ZIndex = 26
	body.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 10)
	layout.Parent = body
	local auto = Instance.new("AutomaticCanvasSize")
	auto.SizingMode = Enum.AutomaticSize.Y
	auto.CanvasSize = UDim2.new()
	auto.Parent = body

	self.body = body
	self.sheet = dimmer

	self:refresh()
end

function Panels:close()
	if self.sheet then
		self.sheet:Destroy()
		self.sheet = nil
	end
	self.openName = nil
end

function Panels:refresh()
	if not self.sheet or not self.openName then
		return
	end

	for _, child in ipairs(self.body:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local builder = self.builder[self.openName]
	if builder then
		builder(self.body, self)
	end
	self.body.CanvasPosition = Vector2.new()
end

function Panels:setSnapshot(state: any)
	self.state = state
	if self.openName then
		self:refresh()
	end
end

function Panels:setQuestState(quests: any, rerollsLeft: number)
	self.quests = quests
	self.rerollsLeft = rerollsLeft
	if self.openName == "Quests" then
		self:refresh()
	end
end

function Panels:setLeaderboard(data: any)
	self.leaderboard = data
	if self.openName == "Ranks" then
		self:refresh()
	end
end

-- ----------------------------------------------------------------------------
-- Shared row helpers
-- ----------------------------------------------------------------------------

function Panels:setHeader(title: string, subtitle: string)
	if self.titleLabel then
		self.titleLabel.Text = title
	end
	if self.subtitleLabel then
		self.subtitleLabel.Text = subtitle
	end
end

local function sectionHeader(parent: Instance, text: string, color: Color3, order: number)
	Theme.label({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 26),
		Text = text,
		Font = Theme.Font.black,
		TextSize = 15,
		TextColor = color,
		LayoutOrder = order,
	})
end

local function infoCard(parent: Instance, text: string, color: Color3, order: number)
	local card = Theme.card({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, 46),
		Color = P.backdrop,
		Transparency = 0.25,
		Radius = Theme.Radius.medium,
		Stroke = color,
		StrokeTransparency = 0.7,
		LayoutOrder = order,
	})
	Theme.label({
		Parent = card,
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(14, 0),
		Text = text,
		TextSize = 13,
		TextWrapped = true,
		TextColor = P.muted,
	})
	return card
end

--[[
	The generic "thing you can buy" row used by the shop, eggs and the store:
	icon, title, description, a right-aligned action button and an optional
	progress line.
]]
local function actionRow(parent: Instance, options: any)
	local card = Theme.card({
		Parent = parent,
		Size = UDim2.new(1, 0, 0, options.Height or 86),
		Color = P.panelAlt,
		Transparency = 0.08,
		Radius = Theme.Radius.medium,
		Stroke = options.Color or P.stroke,
		StrokeTransparency = if options.Dim then 0.8 else 0.4,
		LayoutOrder = options.Order,
	})

	-- A tinted badge behind the icon so every row reads as "this is a thing".
	local badge = Theme.card({
		Parent = card,
		Name = "IconBadge",
		Size = UDim2.fromOffset(58, 58),
		Position = UDim2.fromOffset(12, 14),
		Color = options.Color or P.accent,
		Transparency = 0.82,
		Radius = Theme.Radius.medium,
		Stroke = options.Color or P.accent,
		StrokeTransparency = if options.Dim then 0.8 else 0.55,
	})
	-- Clean badge: the studs stay on the panel chrome so rows stay readable.
	Theme.gradient(badge, Theme.shade(options.Color or P.accent, -0.45), Theme.shade(options.Color or P.accent, 0.25), 90)

	Theme.icon(badge, options.Icon or "dot", {
		Size = 30,
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Tint = if options.Dim then P.dim else (options.Color or P.text),
		ZIndex = 3,
	})

	Theme.label({
		Parent = card,
		Name = "Title",
		Size = UDim2.new(1, -300, 0, 24),
		Position = UDim2.fromOffset(84, 12),
		Text = options.Title or "",
		Font = Theme.Font.bold,
		TextSize = 16,
		TextColor = if options.Dim then P.dim else (options.Color or P.text),
	})

	Theme.label({
		Parent = card,
		Name = "Description",
		Size = UDim2.new(1, -300, 0, 20),
		Position = UDim2.fromOffset(78, 36),
		Text = options.Description or "",
		TextSize = 12,
		TextWrapped = true,
		TextColor = P.muted,
	})

	Theme.label({
		Parent = card,
		Name = "Detail",
		Size = UDim2.new(1, -300, 0, 18),
		Position = UDim2.fromOffset(78, 58),
		Text = options.Detail or "",
		Font = Theme.Font.medium,
		TextSize = 12,
		TextColor = if options.DetailColor then options.DetailColor else P.dim,
	})

	local button = Theme.button({
		Parent = card,
		Name = "Action",
		Size = UDim2.fromOffset(options.ButtonWidth or 190, 46),
		Position = UDim2.new(1, -22, 0.5, 0),
		Text = options.ButtonText or "SELECT",
		Sub = options.ButtonSub,
		Font = Theme.Font.black,
		Color = P.panelSoft,
		Accent = options.Color or P.accent,
		Disabled = options.ButtonDisabled,
		OnClick = options.OnClick,
	})
	button.AnchorPoint = Vector2.new(1, 0.5)

	local title = button:FindFirstChild("Title") :: TextLabel
	local sub = button:FindFirstChild("Sub") :: TextLabel?
	if sub then
		title.TextScaled = false
		title.TextSize = 16
		sub.TextSize = 11
	else
		title.TextScaled = true
	end

	return card, button
end

-- ----------------------------------------------------------------------------
-- Builders
-- ----------------------------------------------------------------------------

function Panels:registerBuilders()
	-- ------------------------------------------------------------------ shop --
	self.builder.Shop = function(body, panel)
		local state = panel.state
		panel:setHeader("Upgrade Lab", "Every level makes the next one more valuable")

		if not state then
			infoCard(body, "Waiting for your save...", P.muted, 1)
			return
		end

		local coins = state.Coins
		for index, trackId in ipairs(Upgrades.Order) do
			local track = Upgrades.get(trackId)
			local info = Upgrades.describe(trackId, state.Upgrades[trackId])
			local affordable = not info.Maxed and coins >= (info.Cost or math.huge)

			local valueText = if track.Format == "mult"
				then `{Utils.formatMultiplier(info.Value)} sell value`
				elseif track.Format == "rate"
				then `{Utils.formatNumber(info.Value)} power/s`
				elseif track.Format == "luck"
				then `+{string.format("%.2f", info.Value)} luck`
				else `+{Utils.formatNumber(info.Value)} power per tap`

			local nextText = if info.Maxed
				then "MAX LEVEL"
				elseif track.Format == "mult"
				then `next {Utils.formatMultiplier(info.NextValue)}`
				elseif track.Format == "rate"
				then `next {Utils.formatNumber(info.NextValue)}/s`
				elseif track.Format == "luck"
				then `next +{string.format("%.2f", info.NextValue)} luck`
				else `next +{Utils.formatNumber(info.NextValue)} per tap`

			actionRow(body, {
				Order = index,
				Icon = track.Icon,
				Title = `{track.Name}  -  Lv{info.Level}`,
				Description = track.Description,
				Detail = `{valueText}   |   {nextText}`,
				DetailColor = P.text,
				Color = track.Color,
				Dim = info.Maxed,
				ButtonText = if info.Maxed then "MAXED" else Utils.comma(info.Cost),
				ButtonSub = if info.Maxed then nil else "coins",
				ButtonDisabled = info.Maxed or not affordable,
				OnClick = function()
					panel.hub.request("BuyUpgrade", trackId)
				end,
			})
		end

		infoCard(body, `Power per tap: {Utils.formatNumber(state.PowerPerClick)}   |   Auto-farm: {Utils.formatNumber(state.PowerPerSecond)} power/s`, P.accent, 90)
	end

	-- ------------------------------------------------------------------ eggs --
	self.builder.Eggs = function(body, panel)
		local state = panel.state
		panel:setHeader("Egg Machines", "Hatch pets to multiply everything you earn")

		if not state then
			infoCard(body, "Waiting for your save...", P.muted, 1)
			return
		end

		local luck = state.Luck
		for index, egg in ipairs(Pets.Eggs) do
			local unlocked = table.find(state.EggsUnlocked, egg.Name) ~= nil
			local signature = Pets.eggHighlight(egg.Name)
			local color = if typeof(egg.Color) == "Color3" then egg.Color else P.accent

			local odds = {}
			for _, row in ipairs(Pets.odds(egg.Name, luck)) do
				local chance = row.chance * 100
				local shown = if chance >= 1 then string.format("%.1f%%", chance) else string.format("%.2f%%", chance)
				table.insert(odds, `{row.pet.Name} {shown}`)
			end

			local card = actionRow(body, {
				Order = index,
				Height = 104,
				Icon = egg.Icon,
				Title = `{egg.Name}  -  {Utils.comma(egg.Cost)} coins`,
				Description = if unlocked
					then `Best pet: {signature.Name} ({signature.Rarity}, {Utils.formatMultiplier(signature.Mult)})`
					else `Unlocks at {egg.RebirthRequired} rebirth(s)`,
				Detail = table.concat(odds, "   "),
				Color = color,
				Dim = not unlocked,
				ButtonWidth = 210,
				ButtonText = if unlocked then "HATCH x1" else "LOCKED",
				ButtonSub = if unlocked then `x10 for {Utils.comma(egg.Cost * Pets.Settings.HatchMultiSize)}` else nil,
				ButtonDisabled = not unlocked,
				OnClick = function()
					panel.hub.request("Hatch", egg.Name, 1)
				end,
			})

			if unlocked then
				local x10 = Theme.button({
					Parent = card,
					Name = "HatchMulti",
					Size = UDim2.fromOffset(120, 46),
					Position = UDim2.new(1, -240, 0.5, 0),
					Text = "x10",
					Font = Theme.Font.black,
					Color = P.panelSoft,
					Accent = P.gold,
					Radius = Theme.Radius.medium,
					OnClick = function()
						panel.hub.request("Hatch", egg.Name, Pets.Settings.HatchMultiSize)
					end,
				})
				x10.AnchorPoint = Vector2.new(1, 0.5)
				local title = x10:FindFirstChild("Title") :: TextLabel
				title.TextScaled = false
				title.TextSize = 18
			end
		end

		infoCard(body, `Your luck bonus: +{string.format("%.2f", luck)} - it makes Legendary, Mythic and Secret pets dramatically more common.`, P.purple, 90)
	end

	-- ------------------------------------------------------------------ pets --
	self.builder.Pets = function(body, panel)
		local state = panel.state
		panel:setHeader("Pet Inventory", "Equip pets for multipliers, sell the duplicates for coins")

		if not state then
			infoCard(body, "Waiting for your save...", P.muted, 1)
			return
		end

		local equipped = {}
		for _, id in ipairs(state.Equipped) do
			equipped[id] = true
		end

		infoCard(
			body,
			`Rebirth bonus x{Utils.formatMultiplier(state.RebirthMultiplier)}  |  {#state.Equipped}/{state.PetSlots} slots used  |  {#state.Pets} pets owned`,
			P.pink,
			1
		)

		local pets = table.clone(state.Pets)
		table.sort(pets, function(a, b)
			local rankA = Pets.rank(a.Rarity)
			local rankB = Pets.rank(b.Rarity)
			if rankA ~= rankB then
				return rankA > rankB
			end
			return a.Mult > b.Mult
		end)

		local shown = math.min(#pets, 120)
		for index = 1, shown do
			local pet = pets[index]
			local isEquipped = equipped[pet.Id] == true
			local color = Pets.color(pet.Rarity)

			local card = actionRow(body, {
				Order = 10 + index,
				Icon = "pet",
				Title = `{pet.Name}   {Utils.formatMultiplier(pet.Mult)}`,
				Description = `{pet.Rarity}  -  from {pet.Egg}`,
				Detail = if isEquipped then "EQUIPPED - boosting everything" else `sells for {Utils.comma(pet.SellValue)} coins`,
				DetailColor = if isEquipped then P.green else P.dim,
				Color = color,
				ButtonWidth = 150,
				ButtonText = if isEquipped then "UNEQUIP" else "EQUIP",
				ButtonSub = if isEquipped then nil else `x{Utils.formatMultiplier(pet.Mult)}`,
				OnClick = function()
					panel.hub.request(if isEquipped then "Unequip" else "Equip", pet.Id)
				end,
			})

			local sell = Theme.button({
				Parent = card,
				Name = "Sell",
				Size = UDim2.fromOffset(96, 46),
				Position = UDim2.new(1, -180, 0.5, 0),
				Text = "SELL",
				Sub = Utils.comma(pet.SellValue),
				Font = Theme.Font.black,
				Color = P.panelSoft,
				Accent = P.gold,
				Radius = Theme.Radius.medium,
				OnClick = function()
					panel.hub.request("SellPet", pet.Id)
				end,
			})
			sell.AnchorPoint = Vector2.new(1, 0.5)
			local sellTitle = sell:FindFirstChild("Title") :: TextLabel
			sellTitle.TextScaled = false
			sellTitle.TextSize = 14

			if pet.IsNew then
				Theme.label({
					Parent = card,
					Name = "New",
					Size = UDim2.fromOffset(46, 20),
					Position = UDim2.fromOffset(86, 8),
					Text = "NEW",
					Font = Theme.Font.black,
					TextSize = 11,
					TextColor = P.gold,
				})
			end
		end

		if #pets > shown then
			infoCard(body, `Showing the {shown} best of {#pets} pets - sell some to keep the list short.`, P.muted, 900)
		end
		if #pets == 0 then
			infoCard(body, "No pets yet. Open the Eggs panel and hatch your first one!", P.green, 20)
		end
	end

	-- ---------------------------------------------------------------- quests --
	self.builder.Quests = function(body, panel)
		panel:setHeader("Daily Quests", "Three quests a day. They reset at midnight UTC.")
		local quests = panel.quests or (panel.state and panel.state.Quests)

		if not quests then
			infoCard(body, "Waiting for your quests...", P.muted, 1)
			return
		end

		for index, quest in ipairs(quests) do
			local color = if typeof(quest.Color) == "Color3" then quest.Color else P.accent
			local complete = quest.Progress >= quest.Target
			local card = actionRow(body, {
				Order = index,
				Height = 104,
				Icon = quest.Icon or "quest",
				Title = quest.Name,
				Description = `{quest.Verb}  -  {Utils.comma(quest.Progress)}/{Utils.comma(quest.Target)} {quest.Unit}`,
				Detail = `Reward: {Utils.comma(quest.Reward.Coins)} coins` .. (if quest.Reward.Luck then `  +  {quest.Reward.Luck} luck ({quest.Reward.LuckMinutes}m)` else ""),
				DetailColor = P.gold,
				Color = color,
				Dim = quest.Claimed,
				ButtonWidth = 180,
				ButtonText = if quest.Claimed then "CLAIMED" elseif complete then "CLAIM" else "IN PROGRESS",
				ButtonDisabled = quest.Claimed or not complete,
				OnClick = function()
					panel.hub.request("ClaimQuest", quest.Id)
				end,
			})

			local _, setFill = Theme.bar({
				Parent = card,
				Size = UDim2.new(1, -320, 0, 8),
				Position = UDim2.fromOffset(78, 78),
				Color = color,
			})
			setFill(quest.Progress / math.max(1, quest.Target))
		end

		local rerolls = if panel.rerollsLeft > 0 then panel.rerollsLeft else (if panel.state then panel.state.QuestRerollsLeft else 0)
		local reroll = Theme.button({
			Parent = body,
			Name = "Reroll",
			Size = UDim2.new(1, 0, 0, 48),
			Text = `REROLL QUESTS  ({rerolls} left today)`,
			Font = Theme.Font.bold,
			Icon = "reroll",
			Color = P.panelAlt,
			Accent = P.green,
			LayoutOrder = 90,
			Disabled = rerolls <= 0,
			OnClick = function()
				panel.hub.request("RerollQuests")
			end,
		})
		local rerollTitle = reroll:FindFirstChild("Title") :: TextLabel
		rerollTitle.TextScaled = false
		rerollTitle.TextSize = 15
	end

	-- ----------------------------------------------------------------- index --
	self.builder.Index = function(body, panel)
		local state = panel.state
		panel:setHeader("Pet Index", "Discover every pet to claim coins, luck and the ultimate pet")

		if not state then
			infoCard(body, "Waiting for your save...", P.muted, 1)
			return
		end

		local overall = Theme.card({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 74),
			Color = P.panelAlt,
			Gradient = { P.panelSoft, P.panelAlt },
			Radius = Theme.Radius.medium,
			Stroke = P.accent,
			StrokeTransparency = 0.4,
			LayoutOrder = 1,
		})
		Theme.label({
			Parent = overall,
			Size = UDim2.new(1, -28, 0, 26),
			Position = UDim2.fromOffset(14, 12),
			Text = `{state.IndexCount} / {state.IndexTotal} pets discovered`,
			Font = Theme.Font.black,
			TextSize = 18,
			TextColor = P.accent,
		})
		local _, setOverall = Theme.bar({
			Parent = overall,
			Size = UDim2.new(1, -28, 0, 10),
			Position = UDim2.fromOffset(14, 46),
			Color = P.accent,
		})
		setOverall(state.IndexCount / math.max(1, state.IndexTotal))

		local order = 2
		for _, progress in ipairs(state.EggProgress) do
			local egg = Pets.getEgg(progress.Egg)
			local color = if egg and typeof(egg.Color) == "Color3" then egg.Color else P.green
			local reward = Pets.IndexRewards[progress.Egg] or { Coins = 0 }
			local complete = progress.Found >= progress.Required

			actionRow(body, {
				Order = order,
				Icon = if egg then egg.Icon else "egg",
				Title = progress.Egg,
				Description = `{progress.Found}/{progress.Required} discovered` .. (if progress.Claimed then "  -  reward claimed" else ""),
				Detail = `Reward: {Utils.comma(reward.Coins)} coins` .. (if reward.Luck then `  +  {reward.Luck} luck` else ""),
				DetailColor = P.gold,
				Color = color,
				Dim = progress.Claimed,
				ButtonWidth = 170,
				ButtonText = if progress.Claimed then "CLAIMED" elseif complete then "CLAIM REWARD" else `{progress.Found}/{progress.Required}`,
				ButtonDisabled = progress.Claimed or not complete,
				OnClick = function()
					panel.hub.request("ClaimIndex", progress.Egg)
				end,
			})
			order += 1
		end

		sectionHeader(body, "FINAL REWARD", P.gold, order)
		actionRow(body, {
			Order = order + 1,
			Icon = "crown",
			Title = "The One  -  100,000x",
			Description = "Complete every non-secret entry in the index",
			Detail = `{Utils.comma(Pets.IndexFinal.Coins)} coins + {Pets.IndexFinal.Pet} + {Pets.IndexFinal.Luck} luck`,
			DetailColor = P.gold,
			Color = P.gold,
			Dim = not state.IndexComplete,
			ButtonWidth = 180,
			ButtonText = if state.IndexFinalClaimed then "CLAIMED" elseif state.IndexComplete then "CLAIM" else "LOCKED",
			ButtonDisabled = state.IndexFinalClaimed or not state.IndexComplete,
			OnClick = function()
				panel.hub.request("ClaimIndex", "__final")
			end,
		})
	end

	-- --------------------------------------------------------------- rebirth --
	self.builder.Rebirth = function(body, panel)
		local state = panel.state
		panel:setHeader("Rebirth Altar", "Trade your run for a permanent multiplier")

		if not state then
			infoCard(body, "Waiting for your save...", P.muted, 1)
			return
		end

		local nextCost = Constants.rebirthCost(state.Rebirths)
		local nextMultiplier = Constants.rebirthMultiplier(state.Rebirths + 1)
		local nextSlots = Constants.petSlots(state.Rebirths + 1)
		local affordable = state.Coins >= nextCost
		local progress = math.clamp(state.Coins / math.max(1, nextCost), 0, 1)

		local hero = Theme.card({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 150),
			Color = P.panelAlt,
			Gradient = { Color3.fromRGB(60, 35, 24), P.panel },
			Radius = Theme.Radius.medium,
			Stroke = P.orange,
			StrokeTransparency = 0.3,
			LayoutOrder = 1,
			Studded = true,
			StudColumns = 14,
			StudTransparency = 0.78,
		})
		Theme.icon(hero, "rebirth", {
			Size = 36,
			Position = UDim2.fromOffset(16, 8),
			Tint = P.orange,
			ZIndex = 3,
		})
		Theme.label({
			Parent = hero,
			Size = UDim2.new(1, -80, 0, 34),
			Position = UDim2.fromOffset(58, 10),
			Text = `REBIRTH {state.Rebirths + 1}`,
			Font = Theme.Font.black,
			TextSize = 28,
			TextColor = P.orange,
			ZIndex = 3,
		})
		Theme.label({
			Parent = hero,
			Size = UDim2.new(1, -28, 0, 22),
			Position = UDim2.fromOffset(16, 48),
			Text = `Cost: {Utils.comma(nextCost)} coins   ({Utils.comma(state.Coins)} in the bank)`,
			TextSize = 14,
			TextColor = P.text,
		})
		local _, setProgress = Theme.bar({
			Parent = hero,
			Size = UDim2.new(1, -28, 0, 12),
			Position = UDim2.fromOffset(16, 76),
			Color = if affordable then P.green else P.orange,
		})
		setProgress(progress)

		Theme.label({
			Parent = hero,
			Size = UDim2.new(1, -28, 0, 40),
			Position = UDim2.fromOffset(16, 96),
			Text = `Multiplier: {Utils.formatMultiplier(state.RebirthMultiplier)}  ->  {Utils.formatMultiplier(nextMultiplier)}     Pet slots: {state.PetSlots}  ->  {nextSlots}     Luck boost: reset`,
			TextSize = 13,
			TextWrapped = true,
			TextColor = P.muted,
		})

		sectionHeader(body, "WHAT YOU KEEP", P.green, 2)
		infoCard(body, "Pets, the entire index, redeemed codes, daily streak, lifetime earned and your quest progress all stay with you forever.", P.green, 3)

		sectionHeader(body, "WHAT RESETS", P.red, 4)
		infoCard(body, "Coins, stored power, every upgrade level and active luck boosts. That is what makes each run faster than the last.", P.red, 5)

		local armed = false
		local button = Theme.button({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 58),
			Text = if affordable then `REBIRTH NOW  -  {Utils.comma(nextCost)} coins` else `Keep earning: {Utils.comma(math.max(0, nextCost - state.Coins))} coins to go`,
			Font = Theme.Font.black,
			Color = P.panelSoft,
			Accent = if affordable then P.orange else P.dim,
			Disabled = not affordable,
			LayoutOrder = 6,
			OnClick = function()
				if not armed then
					armed = true
					button:FindFirstChild("Title").Text = "TAP AGAIN TO CONFIRM"
					Theme.paintButton(button, P.red, true)
				else
					panel.hub.request("Rebirth")
					armed = false
				end
			end,
		})
		local title = button:FindFirstChild("Title") :: TextLabel
		title.TextScaled = false
		title.TextSize = 18
	end

	-- ----------------------------------------------------------------- daily --
	self.builder.Daily = function(body, panel)
		local state = panel.state
		panel:setHeader("Daily Chest", "One claim a day - a full week earns a free pet")

		if not state then
			infoCard(body, "Waiting for your save...", P.muted, 1)
			return
		end

		local card = Theme.card({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 132),
			Color = P.panelAlt,
			Gradient = { P.panelSoft, P.panel },
			Radius = Theme.Radius.medium,
			Stroke = P.gold,
			StrokeTransparency = 0.35,
			LayoutOrder = 1,
		})

		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, -28, 0, 74)
		row.Position = UDim2.fromOffset(14, 14)
		row.Parent = card
		Theme.list(row, 8, { Horizontal = true })

		local streak = state.Daily.Streak
		for day = 1, Constants.DAILY.STREAK_MAX do
			local claimed = day <= streak or (state.Daily.Claimable and day == streak + 1 and false)
			local isNext = state.Daily.Claimable and day == streak + 1
			local color = if claimed then P.green elseif isNext then P.gold else P.dim
			local box = Theme.card({
				Parent = row,
				Size = UDim2.fromOffset(84, 74),
				Color = color,
				Transparency = if claimed or isNext then 0.82 else 0.92,
				Radius = Theme.Radius.small,
				Stroke = color,
				StrokeTransparency = if claimed or isNext then 0.3 else 0.75,
				LayoutOrder = day,
			})
			Theme.label({
				Parent = box,
				Size = UDim2.new(1, 0, 0, 22),
				Position = UDim2.fromOffset(0, 10),
				Text = `DAY {day}`,
				Font = Theme.Font.black,
				TextSize = 13,
				TextColor = color,
				XAlign = Enum.TextXAlignment.Center,
			})
			Theme.icon(box, if day == Constants.DAILY.STREAK_MAX then "pet" elseif claimed then "check" else "daily", {
				Size = 24,
				Position = UDim2.new(0.5, 0, 0, 34),
				AnchorPoint = Vector2.new(0.5, 0),
				Tint = color,
				ZIndex = 3,
			})
		end

		local claimable = state.Daily.Claimable
		local baseCoins = math.max(
			Constants.DAILY.BASE_COINS * (1 + Constants.DAILY.GROWTH_PER_STREAK * streak),
			state.CoinsPerSecond * 90
		)

		Theme.label({
			Parent = card,
			Size = UDim2.new(1, -28, 0, 24),
			Position = UDim2.fromOffset(14, 96),
			Text = if claimable
				then `Today pays about {Utils.comma(baseCoins)} coins.`
				else `Claimed today - come back tomorrow. Streak: {streak} day(s).`,
			TextSize = 13,
			TextColor = P.muted,
		})

		local claim = Theme.button({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 56),
			Text = if claimable then "CLAIM TODAY'S REWARD" else "ALREADY CLAIMED TODAY",
			Font = Theme.Font.black,
			Icon = if claimable then "daily" else "check",
			IconSize = 22,
			Color = P.panelSoft,
			Accent = P.gold,
			Disabled = not claimable,
			LayoutOrder = 2,
			OnClick = function()
				panel.hub.request("ClaimDaily")
			end,
		})
		local claimTitle = claim:FindFirstChild("Title") :: TextLabel
		claimTitle.TextScaled = false
		claimTitle.TextSize = 17
	end

	-- ----------------------------------------------------------------- codes --
	self.builder.Codes = function(body, panel)
		local state = panel.state
		panel:setHeader("Code Machine", "Codes are free rewards - case does not matter")

		local inputHolder = Theme.card({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 62),
			Color = P.backdrop,
			Transparency = 0.2,
			Radius = Theme.Radius.medium,
			Stroke = P.pink,
			StrokeTransparency = 0.5,
			LayoutOrder = 1,
		})

		local box = Instance.new("TextBox")
		box.Name = "CodeInput"
		box.BackgroundTransparency = 1
		box.ClearTextOnFocus = false
		box.PlaceholderText = "TYPE A CODE..."
		box.PlaceholderColor3 = P.dim
		box.Font = Theme.Font.black
		box.Text = ""
		box.TextColor3 = P.text
		box.TextSize = 18
		box.TextXAlignment = Enum.TextXAlignment.Left
		box.Size = UDim2.new(1, -240, 1, 0)
		box.Position = UDim2.fromOffset(18, 0)
		box.Parent = inputHolder

		local submit = Theme.button({
			Parent = inputHolder,
			Name = "Redeem",
			Size = UDim2.fromOffset(200, 46),
			Position = UDim2.new(1, -14, 0.5, 0),
			Text = "REDEEM",
			Font = Theme.Font.black,
			Color = P.panelSoft,
			Accent = P.pink,
			Radius = Theme.Radius.medium,
			OnClick = function()
				local code = box.Text
				if code and #code > 0 and #code <= Constants.LIMITS.MAX_CODE_LENGTH then
					panel.hub.request("RedeemCode", code)
					box.Text = ""
				end
			end,
		})
		submit.AnchorPoint = Vector2.new(1, 0.5)
		local submitTitle = submit:FindFirstChild("Title") :: TextLabel
		submitTitle.TextScaled = false
		submitTitle.TextSize = 17

		box.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				local code = box.Text
				if code and #code > 0 then
					panel.hub.request("RedeemCode", code)
					box.Text = ""
				end
			end
		end)

		local redeemedTotal = if state then state.CodesRedeemed else 0
		infoCard(body, `{redeemedTotal}/{Codes.count()} codes redeemed on this account. Codes are never paid twice.`, P.muted, 2)

		sectionHeader(body, "CODES SHIPPED WITH THE GAME", P.pink, 3)
		for index, entry in ipairs(Codes.List) do			actionRow(body, {
				Order = 10 + index,
				Icon = "code",
				Title = entry.Code,
				Description = Codes.describe(entry),
				Detail = if Codes.isExpired(entry) then "EXPIRED" else (entry.Note or ""),
				DetailColor = if Codes.isExpired(entry) then P.red else P.dim,
				Color = P.pink,
				Dim = Codes.isExpired(entry),
				ButtonWidth = 130,
				ButtonText = if Codes.isExpired(entry) then "EXPIRED" else "USE CODE",
				ButtonDisabled = Codes.isExpired(entry),
				OnClick = function()
					box.Text = entry.Code
					box:CaptureFocus()
				end,
			})
		end
	end

	-- ----------------------------------------------------------------- ranks --
	self.builder.Ranks = function(body, panel)
		panel:setHeader("Global Ranks", "Lifetime coins earned across every server")

		local data = panel.leaderboard
		local refresh = Theme.button({
			Parent = body,
			Size = UDim2.new(1, 0, 0, 46),
			Text = "REFRESH BOARD",
			Font = Theme.Font.bold,
			Icon = "reroll",
			Color = P.panelAlt,
			Accent = P.gold,
			LayoutOrder = 1,
			OnClick = function()
				panel.hub.request("RequestLeaderboard")
			end,
		})
		local refreshTitle = refresh:FindFirstChild("Title") :: TextLabel
		refreshTitle.TextScaled = false
		refreshTitle.TextSize = 15

		if not data then
			infoCard(body, "Opening this panel requested the latest board...", P.muted, 2)
			return
		end

		infoCard(
			body,
			if data.Live
				then `Live ranking of this server (DataStores unavailable). Your lifetime earnings: {Utils.comma(data.MyScore)} coins.`
				else `Your lifetime earnings: {Utils.comma(data.MyScore)} coins - updated {Utils.formatTime(math.max(0, os.time() - data.UpdatedAt))} ago.`,
			P.gold,
			2
		)

		if #data.Rows == 0 then
			infoCard(body, "No one has earned coins yet. Be the first name on the board!", P.muted, 3)
			return
		end

		for index, row in ipairs(data.Rows) do
			local color = if row.IsMe then P.accent elseif row.Rank == 1 then P.gold elseif row.Rank <= 3 then P.green else P.stroke
			local card = Theme.card({
				Parent = body,
				Size = UDim2.new(1, 0, 0, 46),
				Color = if row.IsMe then P.panelSoft else P.panelAlt,
				Transparency = if row.IsMe then 0 else 0.15,
				Radius = Theme.Radius.small,
				Stroke = color,
				StrokeTransparency = if row.IsMe then 0.2 else 0.7,
				LayoutOrder = 10 + index,
			})

			if row.Rank <= 3 then
				Theme.icon(card, if row.Rank == 1 then "crown" else "rank", {
					Size = 24,
					Position = UDim2.fromOffset(14, 11),
					Tint = color,
					ZIndex = 3,
				})
			end

			Theme.label({
				Parent = card,
				Size = UDim2.fromOffset(70, 46),
				Position = UDim2.fromOffset(44, 0),
				Text = `#{row.Rank}`,
				Font = Theme.Font.black,
				TextSize = 18,
				TextColor = color,
			})
			Theme.label({
				Parent = card,
				Size = UDim2.new(1, -300, 1, 0),
				Position = UDim2.fromOffset(112, 0),
				Text = if row.IsMe then `{row.Name}  (you)` else row.Name,
				Font = Theme.Font.bold,
				TextSize = 15,
				TextColor = P.text,
			})
			Theme.label({
				Parent = card,
				Size = UDim2.fromOffset(200, 46),
				Position = UDim2.new(1, -214, 0, 0),
				Text = `{Utils.comma(row.Score)} coins`,
				Font = Theme.Font.bold,
				TextSize = 15,
				TextColor = P.gold,
				XAlign = Enum.TextXAlignment.Right,
			})
		end
	end

	-- ----------------------------------------------------------------- store --
	self.builder.Store = function(body, panel)
		local player = Players.LocalPlayer
		panel:setHeader("Support the Game", "Everything here is optional - the game is complete without it")

		local state = panel.state
		local rebirths = if state then state.Rebirths else 0

		sectionHeader(body, "GAMEPASSES", P.accent, 1)

		local passOrder = { "DOUBLE_COINS", "VIP", "LUCKY", "TURBO_CLICK" }
		for index, key in ipairs(passOrder) do
			local pass = Constants.MARKETPLACE.PASSES[key]
			if pass then
				local owned = player:GetAttribute(`Pass_{key}`) == true
				local available = pass.Id > 0

				actionRow(body, {
					Order = 10 + index,
					Icon = if pass.TurboClick then "power" else "store",
					Title = pass.Name,
					Description = pass.Description,
					Detail = if owned then "OWNED - thank you!" elseif available then "One-time purchase" else "Not configured yet (set the pass Id in Constants)",
					DetailColor = if owned then P.green else P.dim,
					Color = if owned then P.green else P.accent,
					Dim = owned,
					ButtonWidth = 170,
					ButtonText = if owned then "OWNED" elseif available then "GET PASS" else "COMING SOON",
					ButtonDisabled = owned or not available,
					OnClick = function()
						panel.hub.request("PromptPass", key)
					end,
				})
			end
		end

		sectionHeader(body, "COIN PACKS", P.gold, 40)

		local productOrder = { "COINS_SMALL", "COINS_MEDIUM", "COINS_LARGE", "LUCK_BOOST" }
		for index, key in ipairs(productOrder) do
			local product = Constants.MARKETPLACE.PRODUCTS[key]
			if product then
				local available = product.Id > 0
				local description = ""
				if product.Coins then
					local scale = 1 + (product.ScalePerRebirth or 0) * rebirths
					description = `{Utils.comma(math.floor(product.Coins * scale))} coins` .. (if rebirths > 0 then `  (scales with your {rebirths} rebirths)` else "")
				elseif product.Luck then
					description = `+{product.Luck} luck for {product.LuckMinutes or 30} minutes`
				end

				actionRow(body, {
					Order = 50 + index,
					Icon = if product.Luck then "luck" else "coin",
					Title = product.Name,
					Description = description,
					Detail = if available then "Instant delivery" else "Not configured yet (set the product Id in Constants)",
					Color = P.gold,
					Dim = not available,
					ButtonWidth = 170,
					ButtonText = if available then "BUY" else "COMING SOON",
					ButtonDisabled = not available,
					OnClick = function()
						panel.hub.request("PromptProduct", key)
					end,
				})
			end
		end

		infoCard(body, "Pass and product Ids live in Constants.MARKETPLACE - set them once you create the real ones on the Roblox website and the whole store lights up.", P.muted, 90)
	end
end

return Panels
