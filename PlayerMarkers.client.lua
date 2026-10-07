-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- With StreamingEnabled, only characters loaded on this client can be marked.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("PlayerMarkersPanel")
if oldGui then
	oldGui:Destroy()
end

local settings = { highlight = true, names = true }
local connections = {}
local active = true
local gui = Instance.new("ScreenGui")
gui.Name = "PlayerMarkersPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local function updateMarkers()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player ~= localPlayer and character then
			local highlight = character:FindFirstChild("PlayerMarker")
			local names = character:FindFirstChild("PlayerName")
			if highlight then highlight.Enabled = settings.highlight end
			if names then names.Enabled = settings.names end
		end
	end
end

table.insert(connections, gui.Destroying:Connect(function()
	active = false
	for _, connection in connections do connection:Disconnect() end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player ~= localPlayer and character then
			for _, name in { "PlayerMarker", "PlayerName" } do
				local marker = character:FindFirstChild(name)
				if marker then marker:Destroy() end
			end
		end
	end
end))

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(272, 202)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(24, 28, 35)
panel.BorderSizePixel = 0
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -56, 0, 48)
title.Position = UDim2.fromOffset(16, 0)
title.BackgroundTransparency = 1
title.Text = "Метки игроков"
title.TextColor3 = Color3.fromRGB(240, 244, 250)
title.Font = Enum.Font.GothamBold
title.TextSize = 18
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = panel
title.Active = true

local dragInput
local dragStart
local panelStart
table.insert(connections, title.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
		dragStart = input.Position
		panelStart = panel.Position
	end
end))
table.insert(connections, UserInputService.InputChanged:Connect(function(input)
	if not dragInput then return end
	if input == dragInput or (dragInput.UserInputType == Enum.UserInputType.MouseButton1
		and input.UserInputType == Enum.UserInputType.MouseMovement) then
		local delta = input.Position - dragStart
		panel.Position = UDim2.new(panelStart.X.Scale, panelStart.X.Offset + delta.X,
			panelStart.Y.Scale, panelStart.Y.Offset + delta.Y)
	end
end))
table.insert(connections, UserInputService.InputEnded:Connect(function(input)
	if input == dragInput then dragInput = nil end
end))
table.insert(connections, UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		panel.Visible = not panel.Visible
		dragInput = nil
	end
end))

local function makeButton(text, y)
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(12, y)
	button.Size = UDim2.new(1, -24, 0, 48)
	button.BorderSizePixel = 0
	button.Text = text
	button.TextColor3 = Color3.fromRGB(240, 244, 250)
	button.Font = Enum.Font.GothamMedium
	button.TextSize = 16
	button.Parent = panel
	local radius = Instance.new("UICorner")
	radius.CornerRadius = UDim.new(0, 6)
	radius.Parent = button
	return button
end

local highlightButton = makeButton("", 52)
local namesButton = makeButton("", 108)
local function renderButtons()
	for _, item in { { highlightButton, "Подсветка", settings.highlight }, { namesButton, "Имена", settings.names } } do
		item[1].Text = item[2] .. (item[3] and "  •  ВКЛ" or "  •  ВЫКЛ")
		item[1].BackgroundColor3 = item[3] and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(48, 53, 62)
	end
end
highlightButton.Activated:Connect(function()
	settings.highlight = not settings.highlight
	updateMarkers()
	renderButtons()
end)
namesButton.Activated:Connect(function()
	settings.names = not settings.names
	updateMarkers()
	renderButtons()
end)
renderButtons()

local collapse = Instance.new("TextButton")
collapse.Size = UDim2.fromOffset(40, 40)
collapse.Position = UDim2.new(1, -44, 0, 4)
collapse.BackgroundTransparency = 1
collapse.Text = "−"
collapse.TextColor3 = Color3.fromRGB(240, 244, 250)
collapse.Font = Enum.Font.GothamBold
collapse.TextSize = 24
collapse.Parent = panel
local footer = Instance.new("TextLabel")
footer.Position = UDim2.fromOffset(12, 166)
footer.Size = UDim2.new(1, -24, 0, 24)
footer.BackgroundTransparency = 1
footer.Text = "Right Shift — скрыть / показать"
footer.TextColor3 = Color3.fromRGB(172, 183, 198)
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.Parent = panel
collapse.Activated:Connect(function()
	local expanded = not highlightButton.Visible
	highlightButton.Visible = expanded
	namesButton.Visible = expanded
	footer.Visible = expanded
	panel.Size = UDim2.fromOffset(272, expanded and 202 or 48)
	collapse.Text = expanded and "−" or "+"
end)

local function markCharacter(player, character)
	if player == localPlayer then
		return
	end

	local head = character:WaitForChild("Head", 10)
	if not active or not head or not character.Parent or player.Character ~= character then
		return
	end

	if character:FindFirstChild("PlayerMarker") then
		updateMarkers()
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "PlayerMarker"
	highlight.Adornee = character
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(70, 180, 255)
	highlight.FillTransparency = 0.6
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.OutlineTransparency = 0
	highlight.Enabled = settings.highlight
	highlight.Parent = character

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerName"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = settings.names
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = player.DisplayName .. " (@" .. player.Name .. ")"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.Parent = billboard
end

local function trackPlayer(player)
	if player == localPlayer then
		return
	end

	if not active then return end
	table.insert(connections, player.CharacterAdded:Connect(function(character)
		markCharacter(player, character)
	end))

	if player.Character then
		task.spawn(markCharacter, player, player.Character)
	end
end

table.insert(connections, Players.PlayerAdded:Connect(trackPlayer))

for _, player in Players:GetPlayers() do
	trackPlayer(player)
end
