--[[
	Theme
	The whole visual language of the UI lives here: palette, fonts, a component
	kit, the studded background and the icon renderer. Every panel is written with
	these helpers, which is why the HUD, the shop and the hatch reveal all look
	like one product.

	Style: deep navy glass, neon rims, gold for money, classic studded panels for
	the retro Roblox feel, and one bright accent per panel so the screen never
	turns into a rainbow.

	Icons: `Theme.icon(parent, "coin")` renders your Creator Store decal when
	shared/Icons.luau has an id for that name, and draws a clean vector-style mark
	when it does not (or when the asset fails to load). No emoji anywhere.
]]

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Icons = require(ReplicatedStorage.Shared.Icons)

local Theme = {}

Theme.Palette = {
	backdrop = Color3.fromRGB(9, 12, 20),
	panel = Color3.fromRGB(18, 22, 34),
	panelAlt = Color3.fromRGB(24, 29, 44),
	panelSoft = Color3.fromRGB(31, 38, 56),
	stroke = Color3.fromRGB(46, 56, 82),
	strokeSoft = Color3.fromRGB(34, 42, 62),
	text = Color3.fromRGB(236, 241, 250),
	muted = Color3.fromRGB(146, 160, 186),
	dim = Color3.fromRGB(104, 117, 142),
	accent = Color3.fromRGB(96, 196, 255),
	gold = Color3.fromRGB(255, 199, 82),
	green = Color3.fromRGB(124, 231, 158),
	pink = Color3.fromRGB(255, 118, 196),
	purple = Color3.fromRGB(178, 112, 255),
	orange = Color3.fromRGB(255, 140, 90),
	red = Color3.fromRGB(255, 112, 112),
	stud = Color3.fromRGB(84, 98, 132),
}

Theme.Font = {
	black = Enum.Font.GothamBlack,
	bold = Enum.Font.GothamBold,
	medium = Enum.Font.GothamMedium,
}

Theme.Radius = {
	small = UDim.new(0, 8),
	medium = UDim.new(0, 14),
	large = UDim.new(0, 20),
	pill = UDim.new(1, 0),
}

local TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- ----------------------------------------------------------------------------
-- Decorators
-- ----------------------------------------------------------------------------

function Theme.corner(instance: Instance, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or Theme.Radius.medium
	corner.Parent = instance
	return corner
end

function Theme.stroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Theme.Palette.stroke
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function Theme.gradient(instance: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

function Theme.padding(instance: Instance, all: number, extra: { [string]: number }?): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, all + ((extra and extra.Top) or 0))
	padding.PaddingBottom = UDim.new(0, all + ((extra and extra.Bottom) or 0))
	padding.PaddingLeft = UDim.new(0, all + ((extra and extra.Left) or 0))
	padding.PaddingRight = UDim.new(0, all + ((extra and extra.Right) or 0))
	padding.Parent = instance
	return padding
end

-- Vertical list by default; pass Horizontal = true for a row.
function Theme.list(instance: Instance, spacing: number?, options: any?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = if options and options.Horizontal then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical
	layout.SortOrder = if options and options.OrderByLayout then Enum.SortOrder.LayoutOrder else (options and options.SortOrder or Enum.SortOrder.LayoutOrder)
	layout.HorizontalAlignment = (options and options.HAlign) or Enum.HorizontalAlignment.Left
	layout.VerticalAlignment = (options and options.VAlign) or Enum.VerticalAlignment.Top
	layout.Padding = UDim.new(0, spacing or 8)
	layout.Parent = instance
	return layout
end

-- A grid: pass CellSize and the layout places the children itself.
function Theme.grid(instance: Instance, cellSize: UDim2, spacing: number?, options: any?): UIGridLayout
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = cellSize
	grid.CellPadding = UDim2.fromOffset(spacing or 8, spacing or 8)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.HorizontalAlignment = (options and options.HAlign) or Enum.HorizontalAlignment.Left
	grid.Parent = instance
	return grid
end

-- Makes a ScrollingFrame size itself to its content.
function Theme.scroll(instance: ScrollingFrame, padding: number?)
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, padding or 10)
	layout.Parent = instance
	local size = Instance.new("AutomaticCanvasSize")
	size.SizingMode = Enum.AutomaticSize.Y
	size.CanvasSize = UDim2.new()
	size.Parent = instance
	return layout
end

-- ----------------------------------------------------------------------------
-- Studs: the classic raised-brick surface
-- ----------------------------------------------------------------------------

--[[
	A studded surface. It tiles your Creator Store studs texture when
	Icons.StudsTexture is set, and otherwise draws the studs itself (a grid of
	rounded, top-lit discs), so it always renders.

	options = { Columns, Rows, StudSize, Spacing, Color, Transparency, Size, Position, ZIndex }
]]
function Theme.studs(parent: Instance, options: any): Frame
	options = options or {}
	local columns = options.Columns or 9
	local rows = options.Rows or 2
	local studSize = options.StudSize or 14
	local spacing = options.Spacing or 7
	local base = options.Color or Theme.Palette.stud

	local holder = Instance.new("Frame")
	holder.Name = "Studs"
	holder.BackgroundTransparency = 1
	holder.ClipsDescendants = true
	holder.Size = options.Size or UDim2.new(1, 0, 0, rows * (studSize + spacing) + spacing)
	holder.Position = options.Position or UDim2.fromScale(0, 0)
	holder.ZIndex = options.ZIndex or 0
	holder.Parent = parent

	if Icons.StudsTexture > 0 then
		local image = Instance.new("ImageLabel")
		image.Name = "StudTexture"
		image.BackgroundTransparency = 1
		image.Size = UDim2.fromScale(1, 1)
		image.Image = `rbxassetid://{Icons.StudsTexture}`
		image.ImageColor3 = base
		image.ImageTransparency = options.Transparency or 0.7
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(studSize + spacing, studSize + spacing)
		image.Parent = holder
		return holder
	end

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(studSize, studSize)
	layout.CellPadding = UDim2.fromOffset(spacing, spacing)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder

	-- A stud reads as "raised" because it is lit from the top left.
	local lit = Theme.shade(base, -0.35)
	local shadow = Theme.shade(base, 0.35)

	for index = 1, columns * rows do
		local stud = Instance.new("Frame")
		stud.Name = "Stud"
		stud.Size = UDim2.fromOffset(studSize, studSize)
		stud.BackgroundColor3 = base
		stud.BackgroundTransparency = options.Transparency or 0.55
		stud.BorderSizePixel = 0
		stud.LayoutOrder = index
		stud.Parent = holder

		Theme.corner(stud, UDim.new(1, 0))
		Theme.gradient(stud, lit, shadow, 90)
		Theme.stroke(stud, shadow, 1.2, 0.5)
	end

	return holder
end

-- A studded band used as a panel header/footer.
function Theme.studBand(parent: Instance, options: any): Frame
	options = options or {}
	local band = Instance.new("Frame")
	band.Name = "StudBand"
	band.BackgroundColor3 = options.Color or Theme.Palette.panelSoft
	band.BackgroundTransparency = options.Transparency or 0.55
	band.BorderSizePixel = 0
	band.Size = options.Size or UDim2.new(1, 0, 0, 34)
	band.Position = options.Position or UDim2.fromScale(0, 0)
	band.ZIndex = options.ZIndex or 0
	band.ClipsDescendants = true
	band.Parent = parent
	Theme.corner(band, options.Radius or Theme.Radius.medium)

	Theme.studs(band, {
		Columns = options.Columns or 10,
		Rows = options.Rows or 1,
		StudSize = options.StudSize or 14,
		Spacing = options.Spacing or 8,
		Color = options.StudColor or Theme.Palette.stud,
		Transparency = 0.6,
		Position = UDim2.fromOffset(options.Inset or 12, 6),
		Size = UDim2.new(1, -(options.Inset or 12) * 2, 0, 20),
	})

	return band
end

-- ----------------------------------------------------------------------------
-- Icon engine
-- ----------------------------------------------------------------------------

-- amount > 0 darkens, amount < 0 lightens.
function Theme.shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		local factor = 1 - amount
		return Color3.new(color.R * factor, color.G * factor, color.B * factor)
	end
	local up = -amount
	return Color3.new(color.R + (1 - color.R) * up, color.G + (1 - color.G) * up, color.B + (1 - color.B) * up)
end

-- Marks are authored in a 100x100 design space with the origin in the center,
-- then multiplied by `unit` (icon size / 100) so one drawing fits every size.
local function shape(parent: Instance, box: any, unit: number, color: Color3, options: any)
	local frame = Instance.new("Frame")
	frame.Name = (options and options.Name) or "Shape"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 0
	frame.Size = UDim2.fromOffset(box.W * unit, box.H * unit)
	frame.Position = UDim2.fromOffset(box.X * unit, box.Y * unit)
	frame.Rotation = (options and options.Rotation) or 0
	frame.ZIndex = (options and options.ZIndex) or 1
	frame.Parent = parent

	local radius = if options and options.Radius then options.Radius else math.min(box.W, box.H) / 2
	Theme.corner(frame, UDim.new(0, radius * unit))

	if options and options.Outline then
		frame.BackgroundTransparency = 1
		Theme.stroke(frame, color, options.Outline * unit, 0)
	end

	return frame
end

local function disc(parent: Instance, x: number, y: number, d: number, unit: number, color: Color3, options: any)
	local opts = {}
	if options then
		for key, value in pairs(options) do
			opts[key] = value
		end
	end
	opts.Radius = d / 2
	opts.Name = "Disc"
	return shape(parent, { X = x, Y = y, W = d, H = d }, unit, color, opts)
end

local function bar(parent: Instance, x: number, y: number, w: number, h: number, unit: number, color: Color3, options: any)
	local opts = {}
	if options then
		for key, value in pairs(options) do
			opts[key] = value
		end
	end
	if not opts.Radius then
		opts.Radius = math.min(w, h) / 2
	end
	opts.Name = "Bar"
	return shape(parent, { X = x, Y = y, W = w, H = h }, unit, color, opts)
end

local function ring(parent: Instance, x: number, y: number, d: number, unit: number, color: Color3, thickness: number)
	return disc(parent, x, y, d, unit, color, { Outline = thickness })
end

Theme.Marks = {}

Theme.Marks.dot = function(parent: Instance, unit: number, tint: Color3)
	disc(parent, 50, 50, 66, unit, tint)
end

Theme.Marks.coin = function(parent: Instance, unit: number, tint: Color3)
	disc(parent, 50, 50, 94, unit, Theme.shade(tint, 0.5))
	disc(parent, 50, 50, 80, unit, tint)
	disc(parent, 50, 50, 34, unit, Theme.shade(tint, 0.2))
	bar(parent, 50, 50, 9, 44, unit, Theme.shade(tint, 0.45), { Radius = 4 })
end

Theme.Marks.bolt = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 62, 62, unit, Theme.shade(tint, 0.35), { Rotation = 45, Radius = 10 })
	bar(parent, 50, 50, 42, 42, unit, tint, { Rotation = 45, Radius = 8 })
end

Theme.Marks.arrow = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 38, 40, 17, 46, unit, tint, { Rotation = -26, Radius = 9 })
	bar(parent, 62, 40, 17, 46, unit, tint, { Rotation = 26, Radius = 9 })
	bar(parent, 50, 70, 17, 40, unit, tint, { Radius = 9 })
end

Theme.Marks.cash = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 92, 60, unit, Theme.shade(tint, 0.3), { Radius = 12 })
	bar(parent, 50, 50, 80, 48, unit, tint, { Radius = 10 })
	disc(parent, 50, 50, 26, unit, Theme.shade(tint, 0.3))
end

Theme.Marks.gear = function(parent: Instance, unit: number, tint: Color3)
	ring(parent, 50, 50, 66, unit, tint, 11)
	for index = 0, 5 do
		local angle = math.rad(index * 60)
		disc(parent, 50 + math.cos(angle) * 40, 50 + math.sin(angle) * 40, 20, unit, tint)
	end
end

Theme.Marks.clover = function(parent: Instance, unit: number, tint: Color3)
	disc(parent, 34, 34, 40, unit, tint)
	disc(parent, 66, 34, 40, unit, tint)
	disc(parent, 34, 66, 40, unit, tint)
	disc(parent, 66, 66, 40, unit, tint)
	bar(parent, 54, 78, 9, 30, unit, Theme.shade(tint, 0.35), { Rotation = 18, Radius = 4 })
end

Theme.Marks.bars = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 22, 66, 16, 40, unit, Theme.shade(tint, 0.3))
	bar(parent, 50, 52, 16, 68, unit, tint)
	bar(parent, 78, 34, 16, 104, unit, Theme.shade(tint, -0.2))
	bar(parent, 50, 92, 78, 8, unit, Theme.shade(tint, 0.4))
end

Theme.Marks.spiral = function(parent: Instance, unit: number, tint: Color3)
	ring(parent, 50, 50, 84, unit, tint, 12)
	ring(parent, 50, 50, 48, unit, Theme.shade(tint, -0.25), 11)
	disc(parent, 50, 50, 13, unit, tint)
end

Theme.Marks.egg = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 52, 62, 84, unit, tint, { Radius = 30 })
	disc(parent, 37, 32, 16, unit, Theme.shade(tint, -0.55), { Name = "Highlight" })
end

Theme.Marks.paw = function(parent: Instance, unit: number, tint: Color3)
	disc(parent, 50, 64, 44, unit, tint)
	disc(parent, 26, 36, 23, unit, tint)
	disc(parent, 43, 27, 23, unit, tint)
	disc(parent, 60, 27, 23, unit, tint)
	disc(parent, 77, 36, 23, unit, tint)
end

Theme.Marks.scroll = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 64, 82, unit, Theme.shade(tint, 0.35), { Radius = 9 })
	bar(parent, 50, 38, 38, 8, unit, Theme.shade(tint, -0.5))
	bar(parent, 50, 54, 38, 8, unit, Theme.shade(tint, -0.5))
	bar(parent, 42, 70, 22, 8, unit, Theme.shade(tint, -0.5))
end

Theme.Marks.book = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 70, 84, unit, tint, { Radius = 8 })
	bar(parent, 42, 50, 12, 84, unit, Theme.shade(tint, 0.4))
	bar(parent, 62, 36, 26, 8, unit, Theme.shade(tint, -0.5))
	bar(parent, 62, 52, 26, 8, unit, Theme.shade(tint, -0.5))
end

Theme.Marks.crown = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 70, 88, 24, unit, tint, { Radius = 7 })
	disc(parent, 24, 50, 30, unit, tint)
	disc(parent, 50, 40, 32, unit, tint)
	disc(parent, 76, 50, 30, unit, tint)
	bar(parent, 50, 88, 64, 9, unit, Theme.shade(tint, 0.35))
end

Theme.Marks.gift = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 62, 78, 62, unit, tint, { Radius = 10 })
	bar(parent, 50, 62, 14, 62, unit, Theme.shade(tint, 0.4))
	bar(parent, 50, 46, 78, 13, unit, Theme.shade(tint, 0.4))
	disc(parent, 38, 26, 22, unit, Theme.shade(tint, 0.25))
	disc(parent, 62, 26, 22, unit, Theme.shade(tint, 0.25))
end

Theme.Marks.ticket = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 90, 58, unit, tint, { Radius = 10 })
	disc(parent, 8, 50, 22, unit, Theme.shade(tint, 0.75))
	disc(parent, 92, 50, 22, unit, Theme.shade(tint, 0.75))
	bar(parent, 40, 50, 16, 7, unit, Theme.shade(tint, 0.5))
	bar(parent, 62, 50, 26, 7, unit, Theme.shade(tint, 0.5))
end

Theme.Marks.trophy = function(parent: Instance, unit: number, tint: Color3)
	ring(parent, 20, 40, 34, unit, tint, 9)
	ring(parent, 80, 40, 34, unit, tint, 9)
	bar(parent, 50, 38, 60, 30, unit, tint, { Radius = 12 })
	bar(parent, 50, 62, 46, 22, unit, tint, { Radius = 10 })
	bar(parent, 50, 76, 16, 22, unit, Theme.shade(tint, 0.25), { Radius = 6 })
	bar(parent, 50, 90, 58, 13, unit, Theme.shade(tint, 0.25), { Radius = 6 })
end

Theme.Marks.gem = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 56, 62, 62, unit, Theme.shade(tint, 0.4), { Rotation = 45, Radius = 12 })
	bar(parent, 50, 54, 40, 40, unit, tint, { Rotation = 45, Radius = 9 })
	bar(parent, 38, 44, 16, 16, unit, Theme.shade(tint, -0.5), { Rotation = 45, Radius = 4 })
end

Theme.Marks.star = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 16, 92, unit, tint, { Radius = 8 })
	bar(parent, 50, 50, 92, 16, unit, tint, { Radius = 8 })
	bar(parent, 50, 50, 13, 66, unit, Theme.shade(tint, -0.35), { Rotation = 45, Radius = 6 })
	bar(parent, 50, 50, 66, 13, unit, Theme.shade(tint, -0.35), { Rotation = 45, Radius = 6 })
	disc(parent, 50, 50, 18, unit, Theme.shade(tint, -0.6))
end

Theme.Marks.check = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 34, 60, 17, 40, unit, tint, { Rotation = -45, Radius = 8 })
	bar(parent, 62, 44, 17, 62, unit, tint, { Rotation = 45, Radius = 8 })
end

Theme.Marks.reroll = function(parent: Instance, unit: number, tint: Color3)
	ring(parent, 50, 50, 70, unit, tint, 12)
	bar(parent, 68, 24, 16, 32, unit, tint, { Rotation = 45, Radius = 7 })
	bar(parent, 84, 38, 16, 32, unit, tint, { Rotation = -45, Radius = 7 })
	disc(parent, 50, 50, 12, unit, Theme.shade(tint, 0.3))
end

Theme.Marks.alert = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 70, 70, unit, tint, { Rotation = 45, Radius = 14 })
	bar(parent, 50, 42, 13, 34, unit, Theme.shade(tint, 0.6), { Radius = 6 })
	disc(parent, 50, 70, 13, unit, Theme.shade(tint, 0.6))
end

Theme.Marks.lock = function(parent: Instance, unit: number, tint: Color3)
	ring(parent, 50, 32, 42, unit, tint, 12)
	bar(parent, 50, 66, 68, 56, unit, tint, { Radius = 12 })
	disc(parent, 50, 62, 15, unit, Theme.shade(tint, 0.55))
end

Theme.Marks.clock = function(parent: Instance, unit: number, tint: Color3)
	ring(parent, 50, 50, 84, unit, tint, 12)
	bar(parent, 50, 42, 11, 30, unit, tint, { Radius = 5 })
	bar(parent, 60, 54, 24, 11, unit, tint, { Radius = 5 })
end

Theme.Marks.close = function(parent: Instance, unit: number, tint: Color3)
	bar(parent, 50, 50, 88, 17, unit, tint, { Rotation = 45, Radius = 8 })
	bar(parent, 50, 50, 88, 17, unit, tint, { Rotation = -45, Radius = 8 })
end

--[[
	Draws one mark into a box of `size` pixels.
]]
function Theme.mark(parent: Instance, markName: string, tint: Color3, size: number?)
	local unit = (size or 32) / 100
	local draw = Theme.Marks[markName] or Theme.Marks.dot
	draw(parent, unit, tint)
end

--[[
	An icon. Returns the box so callers can move it around.
	options = { Size, Position, AnchorPoint, Tint, ZIndex, LayoutOrder }
]]
function Theme.icon(parent: Instance, name: string, options: any): Frame
	options = options or {}
	local size = options.Size or 32

	local box = Instance.new("Frame")
	box.Name = `Icon_{name}`
	box.BackgroundTransparency = 1
	box.Size = UDim2.fromOffset(size, size)
	box.Position = options.Position or UDim2.fromScale(0, 0)
	box.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	box.LayoutOrder = options.LayoutOrder or 0
	box.ZIndex = options.ZIndex or 2
	box.Parent = parent

	local tint = options.Tint or Icons.tint(name)
	local id = Icons.id(name)

	if id <= 0 then
		Theme.mark(box, Icons.mark(name), tint, size)
		return box
	end

	local image = Instance.new("ImageLabel")
	image.Name = "Asset"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.Image = `rbxassetid://{id}`
	image.ImageColor3 = tint
	image.ScaleType = Enum.ScaleType.Fit
	image.Parent = box

	-- If the decal cannot load (deleted, moderated, typo), draw the mark instead
	-- of leaving a broken image in the UI.
	task.spawn(function()
		pcall(function()
			ContentProvider:PreloadAsync({ image })
		end)
		if not image.IsLoaded then
			image:Destroy()
			Theme.mark(box, Icons.mark(name), tint, size)
		end
	end)

	return box
end

-- ----------------------------------------------------------------------------
-- Components
-- ----------------------------------------------------------------------------

--[[
	A glass card. Pass a gradient for the hero panels, nothing for plain rows.
	props = { Parent, Size, Position, LayoutOrder, Radius, Color, Stroke, Gradient = {Top, Bottom}, Studded }
]]
function Theme.card(props: any): Frame
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Card"
	frame.Size = props.Size or UDim2.new(1, 0, 0, 60)
	frame.Position = props.Position or UDim2.fromScale(0, 0)
	frame.BackgroundColor3 = props.Color or Theme.Palette.panelAlt
	frame.BackgroundTransparency = props.Transparency or 0.08
	frame.BorderSizePixel = 0
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.ClipsDescendants = props.Clips or false

	Theme.corner(frame, props.Radius or Theme.Radius.medium)
	Theme.stroke(frame, props.Stroke or Theme.Palette.stroke, props.StrokeThickness or 1.4, props.StrokeTransparency or 0.25)

	if props.Gradient then
		Theme.gradient(frame, props.Gradient[1], props.Gradient[2])
	end

	if props.Studded then
		Theme.studs(frame, {
			Columns = props.StudColumns or 8,
			Rows = props.StudRows or 1,
			StudSize = props.StudSize or 13,
			Spacing = props.StudSpacing or 7,
			Transparency = props.StudTransparency or 0.5,
			Position = UDim2.fromOffset(props.StudInset or 12, props.StudInset or 8),
			Size = UDim2.new(1, -(props.StudInset or 12) * 2, 0, props.StudSize or 13),
			ZIndex = 0,
		})
	end

	if props.Parent then
		frame.Parent = props.Parent
	end

	return frame
end

--[[
	A text label. Font defaults to the medium weight; pass Font = Theme.Font.black
	for headings.
]]
function Theme.label(props: any): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.Size = props.Size or UDim2.new(1, 0, 0, 24)
	label.Position = props.Position or UDim2.fromScale(0, 0)
	label.Font = props.Font or Theme.Font.medium
	label.Text = props.Text or ""
	label.TextSize = props.TextSize or 16
	label.TextScaled = props.Scaled or false
	label.TextWrapped = props.Wrapped or false
	label.RichText = props.Rich or false
	label.TextXAlignment = props.XAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = props.YAlign or Enum.TextYAlignment.Center
	label.TextColor3 = props.TextColor or Theme.Palette.text
	label.TextTransparency = props.TextTransparency or 0
	label.TextStrokeTransparency = if props.Stroke == false then 1 else 0.6
	label.LayoutOrder = props.LayoutOrder or 0
	label.ZIndex = props.ZIndex or 1

	if props.Parent then
		label.Parent = props.Parent
	end

	return label
end

--[[
	The workhorse button: optional icon, title, optional subtitle, a hover lift and
	a press squash. Returns the TextButton so callers can recolor it later.

	props = { Parent, Size, Position, Text, Sub, Icon, IconOnly, Color, Accent,
	          Disabled, OnClick, LayoutOrder, TextSize, Radius }
]]
function Theme.button(props: any): TextButton
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.Size = props.Size or UDim2.new(1, 0, 0, 52)
	button.Position = props.Position or UDim2.fromScale(0, 0)
	button.BackgroundColor3 = props.Color or Theme.Palette.panelSoft
	button.BackgroundTransparency = 0
	button.AutoButtonColor = false
	button.Text = ""
	button.BorderSizePixel = 0
	button.LayoutOrder = props.LayoutOrder or 0
	button.ZIndex = props.ZIndex or 2

	local accent = props.Accent or Theme.Palette.accent
	Theme.corner(button, props.Radius or Theme.Radius.medium)
	local stroke = Theme.stroke(button, accent, 1.6, 0.55)
	Theme.gradient(button, Color3.new(1, 1, 1), Color3.new(0.72, 0.76, 0.86), 90)

	local scale = Instance.new("UIScale")
	scale.Parent = button

	local iconSize = props.IconSize or 22
	local iconInset = if props.Icon then (if props.IconOnly then 0 else 12) else 0
	local textLeft = if props.Icon then iconInset + iconSize + 8 else 10

	if props.Icon then
		Theme.icon(button, props.Icon, {
			Size = iconSize,
			Position = if props.IconOnly
				then UDim2.fromScale(0.5, 0.5)
				else UDim2.fromOffset(iconInset, 0),
			AnchorPoint = if props.IconOnly then Vector2.new(0.5, 0.5) else Vector2.new(0, 0),
			Tint = props.IconTint or accent,
			ZIndex = 3,
		})
	end

	if not props.IconOnly then
		Theme.label({
			Parent = button,
			Name = "Title",
			Size = if props.Sub then UDim2.new(1, -(textLeft + 8), 0, 22) else UDim2.new(1, -(textLeft + 8), 1, 0),
			Position = if props.Sub then UDim2.fromOffset(textLeft, 7) else UDim2.fromOffset(textLeft, 0),
			Text = props.Text or "Button",
			Font = props.Font or Theme.Font.bold,
			TextSize = props.TextSize or 17,
			Scaled = props.Sub == nil and props.Scaled ~= false,
			TextColor = props.TextColor or accent,
			XAlign = Enum.TextXAlignment.Left,
			ZIndex = 3,
		})

		if props.Sub then
			Theme.label({
				Parent = button,
				Name = "Sub",
				Size = UDim2.new(1, -(textLeft + 8), 0, 16),
				Position = UDim2.fromOffset(textLeft, 28),
				Text = props.Sub,
				TextSize = 12,
				TextColor = Theme.Palette.muted,
				XAlign = Enum.TextXAlignment.Left,
				ZIndex = 3,
			})
		end
	end

	local hovering = false

	local function paint(active: boolean)
		button.BackgroundTransparency = if props.Disabled then 0.35 elseif active then 0 else 0.08
		stroke.Transparency = if props.Disabled then 0.75 elseif active then 0.15 else 0.5
	end

	paint(false)

	if props.Disabled then
		for _, child in ipairs(button:GetChildren()) do
			if child:IsA("TextLabel") then
				child.TextTransparency = 0.45
			elseif child.Name:sub(1, 5) == "Icon_" then
				child.Visible = true
				for _, part in ipairs(child:GetChildren()) do
					if part:IsA("GuiObject") then
						part.BackgroundTransparency = math.min(1, part.BackgroundTransparency + 0.4)
					end
				end
			end
		end
	else
		button.MouseEnter:Connect(function()
			hovering = true
			paint(true)
			TweenService:Create(scale, TWEEN, { Scale = 1.03 }):Play()
		end)
		button.MouseLeave:Connect(function()
			hovering = false
			paint(false)
			TweenService:Create(scale, TWEEN, { Scale = 1 }):Play()
		end)
		button.MouseButton1Down:Connect(function()
			TweenService:Create(scale, TWEEN, { Scale = 0.96 }):Play()
		end)
		button.MouseButton1Up:Connect(function()
			TweenService:Create(scale, TWEEN, { Scale = if hovering then 1.03 else 1 }):Play()
		end)
	end

	if props.OnClick then
		button.MouseButton1Click:Connect(function()
			if not props.Disabled then
				props.OnClick()
			end
		end)
	end

	if props.Parent then
		button.Parent = props.Parent
	end

	return button
end

-- Recolors a button built by Theme.button (affordable / not-yet states).
function Theme.paintButton(button: TextButton, accent: Color3, enabled: boolean)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = if enabled then accent else Theme.Palette.strokeSoft
		stroke.Transparency = if enabled then 0.35 else 0.7
	end
	button.BackgroundTransparency = if enabled then 0 else 0.3
	for _, child in ipairs(button:GetChildren()) do
		if child:IsA("TextLabel") then
			child.TextColor3 = if child.Name == "Title" then (if enabled then accent else Theme.Palette.dim) else Theme.Palette.muted
			child.TextTransparency = if enabled then 0 else 0.35
		end
	end
end

--[[
	Small rounded stat chip: icon on the left, value + caption on the right.
	props = { Parent, Size, Position, Icon = "<name>", Text, Caption, Accent, ... }
]]
function Theme.chip(props: any): Frame
	local chip = Theme.card({
		Name = props.Name or "Chip",
		Parent = props.Parent,
		Size = props.Size or UDim2.fromOffset(150, 46),
		Position = props.Position,
		Color = props.Color or Theme.Palette.panel,
		Gradient = props.Gradient,
		Radius = Theme.Radius.pill,
		Stroke = props.Stroke or Theme.Palette.strokeSoft,
		StrokeTransparency = 0.35,
		LayoutOrder = props.LayoutOrder,
	})

	Theme.icon(chip, props.Icon or "dot", {
		Size = props.IconSize or 26,
		Position = UDim2.new(0, 13, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Tint = props.Accent or Theme.Palette.accent,
	})

	local textHolder = Instance.new("Frame")
	textHolder.BackgroundTransparency = 1
	textHolder.Size = UDim2.new(1, -50, 1, 0)
	textHolder.Position = UDim2.fromOffset(46, 0)
	textHolder.Parent = chip

	Theme.label({
		Parent = textHolder,
		Name = "Value",
		Size = UDim2.new(1, -8, 0, 22),
		Position = UDim2.fromOffset(0, 5),
		Text = props.Text or "0",
		Font = Theme.Font.black,
		TextSize = 17,
		TextColor = props.Accent or Theme.Palette.text,
	})

	Theme.label({
		Parent = textHolder,
		Name = "Caption",
		Size = UDim2.new(1, -8, 0, 15),
		Position = UDim2.fromOffset(0, 26),
		Text = props.Caption or "",
		TextSize = 11,
		TextColor = Theme.Palette.muted,
	})

	return chip
end

--[[
	A progress bar: returns the track plus a set(alpha) function.
]]
function Theme.bar(props: any)
	local track = Theme.card({
		Name = props.Name or "Track",
		Parent = props.Parent,
		Size = props.Size or UDim2.new(1, 0, 0, 14),
		Position = props.Position,
		Color = Theme.Palette.backdrop,
		Radius = Theme.Radius.pill,
		Stroke = nil,
		Transparency = 0.1,
		LayoutOrder = props.LayoutOrder,
	})

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = props.Color or Theme.Palette.accent
	fill.BorderSizePixel = 0
	fill.Parent = track
	Theme.corner(fill, Theme.Radius.pill)
	Theme.gradient(fill, Theme.shade(props.Color or Theme.Palette.accent, -0.25), props.Color or Theme.Palette.accent, 0)

	local function set(alpha: number)
		local clamped = math.clamp(alpha or 0, 0, 1)
		TweenService:Create(fill, TweenInfo.new(0.22, Enum.EasingStyle.Quad), {
			Size = UDim2.fromScale(clamped, 1),
		}):Play()
	end

	return track, set
end

-- A small labeled pill (used for tags like NEW / MAXED).
function Theme.pill(parent: Instance, text: string, color: Color3, layoutOrder: number?): Frame
	local holder = Theme.card({
		Parent = parent,
		Size = UDim2.fromOffset(math.max(70, #text * 9 + 26), 30),
		Color = color,
		Transparency = 0.82,
		Radius = Theme.Radius.pill,
		Stroke = color,
		StrokeTransparency = 0.45,
		LayoutOrder = layoutOrder,
	})

	Theme.label({
		Parent = holder,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		Font = Theme.Font.bold,
		TextSize = 13,
		TextColor = color,
		XAlign = Enum.TextXAlignment.Center,
	})

	return holder
end

-- Diagonal shine used on hero cards so they do not read as flat rectangles.
function Theme.shine(instance: Instance)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	shine.BackgroundTransparency = 0.93
	shine.BorderSizePixel = 0
	shine.Size = UDim2.fromScale(0.5, 1.6)
	shine.Position = UDim2.fromScale(-0.1, -0.3)
	shine.Rotation = 18
	shine.ZIndex = 3
	shine.Parent = instance
	Theme.corner(shine, Theme.Radius.large)
end

function Theme.tween(instance: Instance, properties: any, info: TweenInfo?): Tween
	local tween = TweenService:Create(instance, info or TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), properties)
	tween:Play()
	return tween
end

return Theme
