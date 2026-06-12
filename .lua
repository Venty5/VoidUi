local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local Library = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	SearchRegistry = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(20, 20, 22),
			Second = Color3.fromRGB(30, 30, 32),
			Stroke = Color3.fromRGB(60, 60, 65),
			Divider = Color3.fromRGB(40, 40, 45),
			Text = Color3.fromRGB(240, 240, 245),
			TextDark = Color3.fromRGB(160, 160, 165),
			MainTransparency = 0.1,
			SecondTransparency = 0.15,
			FrameTransparency = 0.2
		}
	},
	SelectedTheme = "Default",
	Font = Enum.Font.Gotham,
	UserConfig = {},
	ConfigFile = nil
}

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

function Library:LoadConfig()
	if not self.ConfigFile then return end
	if isfile and isfile(self.ConfigFile) then
		local success, data = pcall(function()
			return HttpService:JSONDecode(readfile(self.ConfigFile))
		end)
		if success and data then
			self.UserConfig = data
			for flag, value in pairs(self.UserConfig) do
				if self.Flags[flag] then
					if self.Flags[flag].Type == "Colorpicker" then
						self.Flags[flag]:Set(UnpackColor(value))
					else
						self.Flags[flag]:Set(value)
					end
				end
			end
		end
	end
end

function Library:SaveConfig()
	if not self.ConfigFile or not writefile then return end
	pcall(function()
		writefile(self.ConfigFile, HttpService:JSONEncode(self.UserConfig))
	end)
end

local function GetIcon(IconName)
	return nil
end

function Library:CleanupInstance()
	for _, instance in pairs(game:GetService("CoreGui"):GetChildren()) do
		if instance:IsA("ScreenGui") and instance.Name:match("^[A-Z]%d%d%d$") then
			instance:Destroy()
		end
	end
end

Library:CleanupInstance()
local Container = Instance.new("ScreenGui")
Container.Name = string.char(math.random(65, 90))..tostring(math.random(100, 999))
Container.DisplayOrder = 2147483647
Container.Parent = game:GetService("CoreGui")

function Library:IsRunning()
	return Container and Container.Parent == game:GetService("CoreGui")
end

local function AddConnection(Signal, Function)
	if not Library:IsRunning() then return end
	local SignalConnect = Signal:Connect(Function)
	table.insert(Library.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while Library:IsRunning() do wait() end
	for _, Connection in next, Library.Connections do
		Connection:Disconnect()
	end
end)

local function MakeDraggable(DragPoint, Main)
	local IsResizing = false
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		DragPoint.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				if not IsResizing then
					Dragging = true
					MousePos = Input.Position
					FramePos = Main.Position
				end
				Input.Changed:Connect(function()
					if Input.UserInputState == Enum.UserInputState.End then Dragging = false end
				end)
			end
		end)
		DragPoint.InputChanged:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
				DragInput = Input
			end
		end)
		UserInputService.InputChanged:Connect(function(Input)
			if Input == DragInput and Dragging and not IsResizing then
				local Delta = Input.Position - MousePos
				TweenService:Create(Main, TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
					Position = UDim2.new(FramePos.X.Scale, FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
				}):Play()
			end
		end)
	end)
	return function(resizing)
		IsResizing = resizing
		if resizing then Dragging = false end
	end
end

local function MakeResizable(ResizeButton, Main, MinSize, MaxSize, SetResizingCallback)
	pcall(function()
		local Resizing = false
		local StartSize, StartPos
		ResizeButton.InputBegan:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Resizing = true
				if SetResizingCallback then SetResizingCallback(true) end
				StartSize = Main.Size
				StartPos = Vector2.new(Mouse.X, Mouse.Y)
			end
		end)
		ResizeButton.InputEnded:Connect(function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
				Resizing = false
				if SetResizingCallback then SetResizingCallback(false) end
			end
		end)
		UserInputService.InputChanged:Connect(function()
			if Resizing then
				local CurrentPos = Vector2.new(Mouse.X, Mouse.Y)
				local Delta = CurrentPos - StartPos
				local NewWidth = math.clamp(StartSize.X.Offset + Delta.X, MinSize.X, MaxSize.X)
				local NewHeight = math.clamp(StartSize.Y.Offset + Delta.Y, MinSize.Y, MaxSize.Y)
				Main.Size = UDim2.new(0, NewWidth, 0, NewHeight)
			end
		end)
	end)
end

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do Object[i] = v end
	for i, v in next, Children or {} do v.Parent = Object end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	Library.Elements[ElementName] = function(...) return ElementFunction(...) end
end

local function MakeElement(ElementName, ...)
	return Library.Elements[ElementName](...)
end

local function SetProps(Element, Props)
	table.foreach(Props, function(Property, Value) Element[Property] = Value end)
	return Element
end

local function SetChildren(Element, Children)
	table.foreach(Children, function(_, Child) Child.Parent = Element end)
	return Element
end

local function Round(Number, Factor)
	if not Factor or Factor == 0 then return Number end
	local Result = math.floor(Number / Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") then return "BackgroundColor3" end
	if Object:IsA("ScrollingFrame") then return "ScrollBarImageColor3" end
	if Object:IsA("UIStroke") then return "Color" end
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then return "TextColor3" end
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then return "ImageColor3" end
end

local function AddThemeObject(Object, Type)
	if not Library.ThemeObjects[Type] then Library.ThemeObjects[Type] = {} end
	table.insert(Library.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Type]
	return Object
end

local function SetTheme()
	for Name, Type in pairs(Library.ThemeObjects) do
		for _, Object in pairs(Type) do
			Object[ReturnProperty(Object)] = Library.Themes[Library.SelectedTheme][Name]
		end
	end
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3, Enum.UserInputType.Touch}
local BlacklistedKeys = {Enum.KeyCode.Unknown, Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Left, Enum.KeyCode.Down, Enum.KeyCode.Right, Enum.KeyCode.Slash, Enum.KeyCode.Tab, Enum.KeyCode.Backspace, Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in next, Table do
		if v == Key then return true end
	end
end

CreateElement("Corner", function(Scale, Offset)
	return Create("UICorner", {CornerRadius = UDim.new(Scale or 0, Offset or 12)})
end)

CreateElement("Stroke", function(Color, Thickness)
	return Create("UIStroke", {Color = Color or Color3.fromRGB(255,255,255), Thickness = Thickness or 0.5})
end)

CreateElement("List", function(Scale, Offset)
	return Create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(Scale or 0, Offset or 0)})
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	return Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft   = UDim.new(0, Left   or 4),
		PaddingRight  = UDim.new(0, Right  or 4),
		PaddingTop    = UDim.new(0, Top    or 4)
	})
end)

CreateElement("TFrame", function()
	return Create("Frame", {BackgroundTransparency = 1})
end)

CreateElement("Frame", function(Color)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255,255,255), BorderSizePixel = 0})
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	return Create("Frame", {BackgroundColor3 = Color or Color3.fromRGB(255,255,255), BorderSizePixel = 0}, {
		Create("UICorner", {CornerRadius = UDim.new(Scale, Offset)})
	})
end)

CreateElement("Button", function()
	local Button = Create("TextButton", {Text = "", AutoButtonColor = false, BackgroundTransparency = 1, BorderSizePixel = 0})
	Button.MouseButton1Click:Connect(function()
		local sound = Instance.new("Sound")
		sound.SoundId = "rbxassetid://6895079853"
		sound.Volume = 0.5
		sound.Parent = game:GetService("SoundService")
		sound:Play()
		game:GetService("Debris"):AddItem(sound, 1)
	end)
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	return Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color,
		BorderSizePixel = 0,
		ScrollBarThickness = Width,
		CanvasSize = UDim2.new(0,0,0,0)
	})
end)

CreateElement("Image", function(ImageID)
	local ImageNew = Create("ImageLabel", {Image = ImageID, BackgroundTransparency = 1})
	if GetIcon(ImageID) ~= nil then ImageNew.Image = GetIcon(ImageID) end
	return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
	return Create("ImageButton", {Image = ImageID, BackgroundTransparency = 1})
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	return Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240,240,240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 15,
		Font = Enum.Font.GothamSemibold,
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 5)
	})
}), {
	Position = UDim2.new(1, -25, 1, -25),
	Size = UDim2.new(0, 300, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent = Container
})

function Library:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name    = NotificationConfig.Name    or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Image   = NotificationConfig.Image   or "rbxassetid://4384403532"
		NotificationConfig.Time    = NotificationConfig.Time    or 15

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(25,25,25), 0, 10), {
			Parent = NotificationParent,
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, 0, 0, 0),
			BackgroundTransparency = 0.15,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", Color3.fromRGB(93,93,93), 1.2),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 20, 0, 20),
				ImageColor3 = Color3.fromRGB(240,240,240),
				Name = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
				Size = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 30, 0, 0),
				Font = Enum.Font.FredokaOne,
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.FredokaOne,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = Color3.fromRGB(200,200,200),
				TextWrapped = true
			})
		})

		TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0,0,0,0)}):Play()
		wait(NotificationConfig.Time)
		TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {Position = UDim2.new(1,0,0,0)}):Play()
		wait(0.8)
		NotificationParent:Destroy()
	end)
end

function Library:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local Loaded = false
	local UIHidden = false

	WindowConfig = WindowConfig or {}
	WindowConfig.Name            = WindowConfig.Name            or "Void Menu"
	WindowConfig.HidePremium     = WindowConfig.HidePremium     or false
	WindowConfig.SaveConfig      = WindowConfig.SaveConfig      or false
	WindowConfig.ConfigFile      = WindowConfig.ConfigFile      or WindowConfig.Name .. ".json"
	if WindowConfig.IntroEnabled == nil then WindowConfig.IntroEnabled = true end
	WindowConfig.IntroToggleIcon = WindowConfig.IntroToggleIcon or "rbxassetid://123912257208121"
	WindowConfig.IntroText       = WindowConfig.IntroText       or "Launching Void Menu..."
	WindowConfig.CloseCallback   = WindowConfig.CloseCallback   or function() end
	WindowConfig.ShowIcon        = WindowConfig.ShowIcon        or false
	WindowConfig.Icon            = WindowConfig.Icon            or "rbxassetid://123912257208121"
	WindowConfig.IntroIcon       = WindowConfig.IntroIcon       or "rbxassetid://1239122572
