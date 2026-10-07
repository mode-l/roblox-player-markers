-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- With StreamingEnabled, only characters loaded on this client can be marked.

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local function markCharacter(player, character)
	if player == localPlayer then
		return
	end

	local head = character:WaitForChild("Head", 10)
	if not head or not character.Parent then
		return
	end

	if character:FindFirstChild("PlayerMarker") then
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
	highlight.Parent = character

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerName"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
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

	player.CharacterAdded:Connect(function(character)
		markCharacter(player, character)
	end)

	if player.Character then
		task.spawn(markCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(trackPlayer)

for _, player in Players:GetPlayers() do
	trackPlayer(player)
end
