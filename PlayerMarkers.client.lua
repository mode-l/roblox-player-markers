-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- With StreamingEnabled, only characters loaded on this client can be marked.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local oldGui = playerGui:FindFirstChild("PlayerMarkersPanel")
if oldGui then
	oldGui:Destroy()
	-- Let older versions finish their deferred cleanup before adding new markers.
	task.wait()
end

local settings = { highlight = true, names = true }
local connections = {}
local cleanups = {}
local ownedMarkers = {}
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
	for _, cleanup in ipairs(cleanups) do pcall(cleanup) end
	for _, connection in connections do connection:Disconnect() end
	-- Deferred cleanup must never destroy markers created by a newer run.
	for marker in ownedMarkers do marker:Destroy() end
	table.clear(ownedMarkers)
end))

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(720, 500)
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
	button.Position = UDim2.fromOffset(180, y)
	button.Size = UDim2.new(1, -192, 0, 48)
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

local highlightButton = makeButton("", 60)
local namesButton = makeButton("", 116)
local nav = Instance.new("ScrollingFrame")
nav.Position = UDim2.fromOffset(12, 48)
nav.Size = UDim2.new(0, 156, 1, -92)
nav.BackgroundTransparency = 1
nav.BorderSizePixel = 0
nav.ScrollBarThickness = 4
nav.AutomaticCanvasSize = Enum.AutomaticSize.Y
nav.CanvasSize = UDim2.new()
nav.Parent = panel
local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 6)
navLayout.SortOrder = Enum.SortOrder.LayoutOrder
navLayout.Parent = nav
local playersTab = makeButton("Игроки", 48)
playersTab.Parent = nav
playersTab.Size = UDim2.new(1, -6, 0, 40)
playersTab.LayoutOrder = 0
local mapTab = makeButton("Карта", 48)
mapTab.Size = playersTab.Size
mapTab.Parent = nav
mapTab.LayoutOrder = 1
local mapView = Instance.new("ScrollingFrame")
mapView.Position = UDim2.fromOffset(180, 48)
mapView.Size = UDim2.new(1, -192, 1, -92)
mapView.BackgroundTransparency = 1
mapView.BorderSizePixel = 0
mapView.ScrollBarThickness = 5
mapView.AutomaticCanvasSize = Enum.AutomaticSize.Y
mapView.CanvasSize = UDim2.new()
mapView.Visible = false
mapView.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = mapView
local function mapLine(text, heading)
	local line = Instance.new("TextLabel")
	line.Size = UDim2.new(1, -10, 0, 0)
	line.AutomaticSize = Enum.AutomaticSize.Y
	line.BackgroundTransparency = 1
	line.TextWrapped = true
	line.TextXAlignment = Enum.TextXAlignment.Left
	line.TextYAlignment = Enum.TextYAlignment.Top
	line.TextColor3 = heading and Color3.fromRGB(100, 205, 245) or Color3.fromRGB(225, 231, 240)
	line.Font = heading and Enum.Font.GothamBold or Enum.Font.Gotham
	line.TextSize = heading and 16 or 13
	line.Text = text
	line.LayoutOrder = #mapView:GetChildren()
	line.Parent = mapView
end
local selectedTab = "players"
local expanded = true
local extraPages = {}
local search
local refreshing = false
local function refreshMap()
	if refreshing then return end
	refreshing = true
	for _, child in mapView:GetChildren() do
		if child:IsA("TextLabel") then child:Destroy() end
	end
	mapLine("Загрузка карты…")
	task.spawn(function()
		local ok, result = pcall(function()
			if not search then
				local module = game:GetService("ReplicatedStorage"):FindFirstChild("EggSearch")
				local library
				if module and module:IsA("ModuleScript") then
					library = require(module)
				else
					library = loadstring(game:HttpGet("https://raw.githubusercontent.com/mode-l/roblox-player-markers/main/EggSearch.lua"))()
				end
				search = library.new()
			end
			return search.GetMatchingFieldEggs()
		end)
		refreshing = false
		if not active or not gui.Parent then return end
		for _, child in mapView:GetChildren() do
			if child:IsA("TextLabel") then child:Destroy() end
		end
		if not ok then mapLine("Не удалось прочитать карту:\n" .. tostring(result)); return end
		for _, warning in ipairs(search.Diagnostics or {}) do
			mapLine("Каталог недоступен; данные могут быть неполными:\n" .. warning)
		end
		local groups = {}
		for id, area in pairs(search.Areas) do
			groups[tostring(id)] = { name = type(area) == "table" and (area.DisplayName or area.Name) or tostring(id), eggs = {} }
		end
		for _, item in ipairs(result) do
			local id = tostring(item.record.AreaId or "Без зоны")
			groups[id] = groups[id] or { name = id, eggs = {} }
			table.insert(groups[id].eggs, item)
		end
		local ids = {}
		for id in pairs(groups) do table.insert(ids, id) end
		table.sort(ids)
		if #ids == 0 then mapLine("Локации и яйца не найдены") end
		for _, id in ipairs(ids) do
			local group = groups[id]
			mapLine(tostring(group.name) .. " · " .. #group.eggs .. " яиц", true)
			if #group.eggs == 0 then mapLine("Нет доступных яиц") end
			for _, item in ipairs(group.eggs) do
				local egg = item.record
				local category = egg.AssetCategory or egg.Category or egg.Name
				local asset = category and search.Assets[category]
				local name = type(asset) == "table" and (asset.DisplayName or asset.Name) or category
				local mutations = table.concat(egg.Mutations or {}, ", ")
				mapLine("Entity: " .. tostring(name or "Неизвестно") .. "\nПредмет: яйцо · " .. item.rarity
					.. " · баллы: " .. item.score .. (mutations ~= "" and "\nМутации: " .. mutations or ""))
			end
		end
	end)
end
local function showTab()
	highlightButton.Visible = expanded and selectedTab == "players"
	namesButton.Visible = highlightButton.Visible
	mapView.Visible = expanded and selectedTab == "map"
	playersTab.Visible = expanded
	mapTab.Visible = expanded
	nav.Visible = expanded
	for page, item in pairs(extraPages) do
		page.Visible = expanded and selectedTab == item.id
		item.button.BackgroundColor3 = selectedTab == item.id and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(48, 53, 62)
	end
	playersTab.BackgroundColor3 = selectedTab == "players" and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(48, 53, 62)
	mapTab.BackgroundColor3 = selectedTab == "map" and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(48, 53, 62)
end
playersTab.Activated:Connect(function() selectedTab = "players"; showTab() end)
mapTab.Activated:Connect(function() selectedTab = "map"; showTab(); refreshMap() end)
showTab()
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
footer.Position = UDim2.new(0, 12, 1, -32)
footer.Size = UDim2.new(1, -24, 0, 24)
footer.BackgroundTransparency = 1
footer.Text = "Right Shift — скрыть / показать"
footer.TextColor3 = Color3.fromRGB(172, 183, 198)
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.Parent = panel
collapse.Activated:Connect(function()
	expanded = not expanded
	showTab()
	footer.Visible = expanded
	panel.Size = UDim2.fromOffset(720, expanded and 500 or 48)
	collapse.Text = expanded and "−" or "+"
end)

local function markCharacter(player, character)
	if player == localPlayer then
		return
	end

	local head = character:WaitForChild("Head", 10)
	if not active or not gui.Parent or not head or not character.Parent or player.Character ~= character then
		return
	end

	for _, name in { "PlayerMarker", "PlayerName" } do
		local previous = character:FindFirstChild(name)
		if previous and ownedMarkers[previous] then return end
		if previous then previous:Destroy() end
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
	ownedMarkers[highlight] = true
	highlight.Destroying:Once(function() ownedMarkers[highlight] = nil end)

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PlayerName"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(200, 40)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Enabled = settings.names
	billboard.Parent = character
	ownedMarkers[billboard] = true
	billboard.Destroying:Once(function() ownedMarkers[billboard] = nil end)

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

-- Import feature engines through our UI adapter; no upstream windows are created.
local environment = (getgenv and getgenv()) or _G
local libraries = {}
environment.__EggPanelLibraries = libraries
table.insert(cleanups, function()
	if environment.__EggPanelLibraries == libraries then environment.__EggPanelLibraries = nil end
end)
local pageCounter = 1
local host = {
	notify = function(message)
		if gui.Parent then footer.Text = tostring(message); footer.TextWrapped = true end
		warn("[EggPanel] " .. tostring(message))
	end,
	toggle = function() panel.Visible = not panel.Visible end,
	onCleanup = function(callback) table.insert(cleanups, callback) end,
}
function host.addPage(name)
	pageCounter += 1
	local page = Instance.new("ScrollingFrame")
	page.Position = mapView.Position
	page.Size = mapView.Size
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 5
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.CanvasSize = UDim2.new()
	page.Visible = false
	page.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 8)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = page
	local tab = makeButton(name, 0)
	tab.Parent = nav
	tab.Size = UDim2.new(1, -6, 0, 48)
	tab.TextSize = 12
	tab.TextWrapped = true
	tab.LayoutOrder = pageCounter
	local id = "feature" .. pageCounter
	extraPages[page] = { id = id, button = tab }
	tab.Activated:Connect(function() selectedTab = id; showTab() end)
	return page
end
function host.removePage(page)
	local item = extraPages[page]
	if item then
		item.button:Destroy()
		extraPages[page] = nil
		if selectedTab == item.id then selectedTab = "players"; showTab() end
	end
	page:Destroy()
end
task.spawn(function()
	local ok, err = pcall(function()
		local adapterSource = game:HttpGet("https://raw.githubusercontent.com/mode-l/roblox-player-markers/main/PanelControls.lua")
		local adapterChunk, compileError = loadstring(adapterSource, "PanelControls")
		assert(adapterChunk, compileError)
		local adapter = adapterChunk()
		if not active or not gui.Parent then return end
		for _, name in ipairs({ "Boblo", "Oxide" }) do
			libraries[name] = adapter.mount(host, name)
			task.spawn(function()
				local loaded, failure = pcall(function()
					local source = game:HttpGet("https://raw.githubusercontent.com/mode-l/roblox-player-markers/main/" .. name .. "Integrated.lua")
					local chunk, compileError = loadstring(source, name .. "Features")
					assert(chunk, compileError)
					if active and gui.Parent then chunk() end
					local shutdown = name == "Boblo" and environment.__SAE_HUB_SHUTDOWN
						or (name == "Oxide" and _G.OxideStealAnEgg and _G.OxideStealAnEgg.Unload)
					if shutdown then
						if active and gui.Parent then table.insert(cleanups, shutdown) else pcall(shutdown) end
					end
				end)
				if not loaded then host.notify(name .. ": " .. tostring(failure)) end
			end)
		end
	end)
	if not ok then host.notify(tostring(err)) end
end)
