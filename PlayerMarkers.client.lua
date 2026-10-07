-- Place this LocalScript in StarterPlayer > StarterPlayerScripts.
-- With StreamingEnabled, only characters loaded on this client can be marked.

-- User-supplied runtime patch; executor APIs are required.
for _, obj in getgc(true) do
	if typeof(obj) ~= "table" or getrawmetatable(obj) then continue end
	local mainrun = false
	for _, v in obj do
		if v == obj then mainrun = true break end
	end
	if not mainrun then continue end
	for _, v in obj do
		if typeof(v) == "number" and v >= 1 and v <= 3 and obj[v] == nil then
			setmetatable(obj, { __newindex = function() end })
			break
		end
	end
end

local rigUtility
do
	rigUtility = {
		Players = game:GetService("Players"),
		ReplicatedStorage = game:GetService("ReplicatedStorage"),
		disabled = {},
	}
	function rigUtility.GetConnections(object, signalName)
		local ok, result = pcall(function() return getconnections(object[signalName]) end)
		if ok and type(result) == "table" then return result end
		warn("failed to getconnections: " .. tostring(result))
		return nil
	end
	function rigUtility:SetPaused(paused)
		local patched = 0
		local conns = paused and self:init() or self.disabled
		if not conns then return false end
		for key, connection in pairs(conns) do
			local ok, err = pcall(function()
				if paused then
					if connection.Enabled == false then return end
					connection:Disable()
					self.disabled[connection] = connection
				else
					connection:Enable()
					self.disabled[key] = nil
				end
				patched += 1
			end)
			if not ok then warn("failed to toggle RigSync: " .. tostring(err)) end
		end
		return not paused or patched > 0
	end
	function rigUtility:init()
		self.LocalPlayer = self.Players.LocalPlayer
		if not self.LocalPlayer then warn("failed to get localplayer"); return end
		if type(getconnections) ~= "function" then
			warn("Unsupported executor: missing getconnections")
			return
		end
		local packages = self.ReplicatedStorage:FindFirstChild("Packages")
		if not packages then warn("failed to get Packages"); return end
		local networking = packages:FindFirstChild("Networking")
		if not networking then warn("failed to get Networking"); return end
		local remote = networking:FindFirstChild("RE/RigSync/Refresh")
		if not remote or not remote:IsA("RemoteEvent") then
			warn("failed to get RE/RigSync/Refresh RemoteEvent")
			return
		end
		local conns = self.GetConnections(remote, "OnClientEvent")
		return conns
	end
end

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

local settings = { highlight = true }
local connections = {}
local cleanups = {}
table.insert(cleanups, function() rigUtility:SetPaused(false) end)
local speedControl = { enabled = false, speed = 500, installed = false, originals = setmetatable({}, { __mode = "k" }) }
function speedControl:Install()
	if self.installed then return true end
	local missing = {}
	for name, fn in pairs({ hookmetamethod = hookmetamethod or false, hookfunction = hookfunction or false,
		getgc = getgc or false, islclosure = islclosure or false }) do
		if type(fn) ~= "function" then table.insert(missing, name) end
	end
	if type(debug) ~= "table" or type(debug.info) ~= "function" or type(debug.getupvalues) ~= "function" then
		table.insert(missing, "debug.info/getupvalues")
	end
	if #missing > 0 then warn("[Speed] missing: " .. table.concat(missing, ", ")); return false end
	local controller = self
	local previousIndex
	local indexWrapper = function(object, key, value)
		local character = localPlayer.Character
		if controller.enabled and key == "WalkSpeed" and value ~= controller.speed
			and character and object == character:FindFirstChildOfClass("Humanoid") then return end
		return previousIndex(object, key, value)
	end
	if type(newcclosure) == "function" then indexWrapper = newcclosure(indexWrapper) end
	local installed, err = pcall(function() previousIndex = hookmetamethod(game, "__newindex", indexWrapper) end)
	if not installed then warn("[Speed] " .. tostring(err)); return false end
	local patched = 0
	for _, fn in next, getgc() do
		if typeof(fn) == "function" and islclosure(fn) then
			local sourceOK, source = pcall(debug.info, fn, "s")
			if sourceOK and type(source) == "string" and source:find("ContentCatalog%.Runtime") then
				local argsOK, args = pcall(debug.info, fn, "a")
				local upsOK, ups = pcall(debug.getupvalues, fn)
				if argsOK and args == 3 and upsOK and type(ups) == "table" and #ups == 5 then
					local original
					local wrapper = function(a, b, c)
						local sample = original(a, b, c)
						if controller.enabled and type(sample) == "table" and sample.WalkSpeed and sample.Position and sample.Timestamp then
							sample.WalkSpeed = 100000
						end
						return sample
					end
					if type(newlclosure) == "function" then wrapper = newlclosure(wrapper) end
					local hooked = pcall(function() original = hookfunction(fn, wrapper) end)
					if hooked and type(original) == "function" then patched += 1 end
				end
			end
	end
	end
	self.installed = true
	warn("[Speed] patched sampler functions: " .. patched)
	return true
end
function speedControl:Apply()
	local character = localPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if self.originals[humanoid] == nil then self.originals[humanoid] = humanoid.WalkSpeed end
		if humanoid.WalkSpeed ~= self.speed then humanoid.WalkSpeed = self.speed end
	end
end
function speedControl:SetEnabled(value)
	if value then
		if not self:Install() then return false end
		self.enabled = true
		self:Apply()
		if not self.connection then
			self.connection = game:GetService("RunService").Heartbeat:Connect(function()
				if active and self.enabled then self:Apply() end
			end)
		end
	else
		self.enabled = false
		if self.connection then self.connection:Disconnect(); self.connection = nil end
		for humanoid, speed in pairs(self.originals) do pcall(function() humanoid.WalkSpeed = speed end) end
		table.clear(self.originals)
	end
	return true
end
table.insert(cleanups, function() speedControl:SetEnabled(false) end)
local ownedMarkers = {}
local active = true
local gui = Instance.new("ScreenGui")
gui.Name = "PlayerMarkersPanel"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local utility = {
	ProximityPromptService = game:GetService("ProximityPromptService"),
	Players = Players,
	conns = {},
	originalDurations = setmetatable({}, { __mode = "k" }),
}
function utility:bind(signal, callback)
	local ok, connection = pcall(function() return signal:Connect(callback) end)
	if not ok then warn("failed to bind connection: " .. tostring(connection)); return nil end
	self.conns[connection] = true
	return connection
end
function utility:unbind(connection)
	if not self.conns[connection] then return false end
	local ok, err = pcall(function() connection:Disconnect() end)
	if not ok then warn("failed to unbind: " .. tostring(err)); return false end
	self.conns[connection] = nil
	return true
end
function utility:init()
	self.LocalPlayer = self.Players.LocalPlayer
	if not self.LocalPlayer then warn("failed to get localplayer"); return nil end
	if self.connection then self:unbind(self.connection) end
	self.connection = self:bind(self.ProximityPromptService.PromptButtonHoldBegan, function(prompt, player)
		if active and player == self.LocalPlayer and prompt.Name == "CarryAreaEgg" then
			if self.originalDurations[prompt] == nil then self.originalDurations[prompt] = prompt.HoldDuration end
			prompt.HoldDuration = 0
		end
	end)
	return self.connection
end
table.insert(cleanups, function()
	for connection in pairs(utility.conns) do utility:unbind(connection) end
	for prompt, duration in pairs(utility.originalDurations) do
		pcall(function() prompt.HoldDuration = duration end)
	end
end)
utility:init()

local function updateMarkers()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if player ~= localPlayer and character then
			local highlight = character:FindFirstChild("PlayerMarker")
			if highlight then highlight.Enabled = settings.highlight end
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
local rigPaused = false
local rigButton = makeButton("RigSync: ВКЛ", 116)
rigButton.BackgroundColor3 = Color3.fromRGB(32, 92, 118)
rigButton.Activated:Connect(function()
	local nextState = not rigPaused
	if rigUtility:SetPaused(nextState) then
		rigPaused = nextState
		rigButton.Text = rigPaused and "RigSync: ВЫКЛ" or "RigSync: ВКЛ"
		rigButton.BackgroundColor3 = rigPaused and Color3.fromRGB(56, 62, 73) or Color3.fromRGB(32, 92, 118)
	else
		warn("RigSync was not paused; check executor support and console")
	end
end)
local speedButton = makeButton("Скорость: ВЫКЛ", 172)
speedButton.BackgroundColor3 = Color3.fromRGB(56, 62, 73)
local speedInput = Instance.new("TextBox")
speedInput.Position = UDim2.fromOffset(180, 228)
speedInput.Size = UDim2.new(1, -192, 0, 42)
speedInput.BackgroundColor3 = Color3.fromRGB(36, 41, 50)
speedInput.TextColor3 = Color3.new(1, 1, 1)
speedInput.Font = Enum.Font.Gotham
speedInput.TextSize = 16
speedInput.ClearTextOnFocus = false
speedInput.Text = "500"
speedInput.PlaceholderText = "Скорость: 16–500"
speedInput.Parent = panel
speedInput.FocusLost:Connect(function()
	local number = tonumber(speedInput.Text)
	if number and number == number and math.abs(number) < math.huge then
		speedControl.speed = math.clamp(number, 16, 500)
	end
	speedInput.Text = tostring(speedControl.speed)
	if speedControl.enabled then speedControl:Apply() end
end)
speedButton.Activated:Connect(function()
	local ok, result = pcall(function() return speedControl:SetEnabled(not speedControl.enabled) end)
	if not ok then speedControl:SetEnabled(false); warn("[Speed] " .. tostring(result)) end
	speedButton.Text = speedControl.enabled and "Скорость: ВКЛ" or "Скорость: ВЫКЛ"
	speedButton.BackgroundColor3 = speedControl.enabled and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(56, 62, 73)
end)
local analyticsButton = makeButton("Загрузить аналитику rscripts", 282)
analyticsButton.BackgroundColor3 = Color3.fromRGB(56, 62, 73)
local analyticsLoaded = false
analyticsButton.Activated:Connect(function()
	if analyticsLoaded then return end
	analyticsLoaded = true
	analyticsButton.Text = "Аналитика: загрузка…"
	task.spawn(function()
		local ok, err = pcall(function()
			loadstring(game:HttpGet("https://rscripts.net/api/telemetry/client.lua?s=6a9ff8e74bf460fa95f2819b"))()
		end)
		if analyticsButton.Parent then analyticsButton.Text = ok and "Аналитика загружена" or "Ошибка загрузки аналитики" end
		if not ok then analyticsLoaded = false; warn("[Analytics] " .. tostring(err)) end
	end)
end)
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
					library = loadstring(game:HttpGet("https://raw.githubusercontent.com/mode-l/roblox-player-markers/8f5b4fc588bcd7e8bb79e73d1b814b5d534267f5/EggSearch.lua"))()
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
	rigButton.Visible = highlightButton.Visible
	speedButton.Visible = highlightButton.Visible
	speedInput.Visible = highlightButton.Visible
	analyticsButton.Visible = highlightButton.Visible
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
	for _, item in { { highlightButton, "Подсветка", settings.highlight } } do
		item[1].Text = item[2] .. (item[3] and "  •  ВКЛ" or "  •  ВЫКЛ")
		item[1].BackgroundColor3 = item[3] and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(48, 53, 62)
	end
end
highlightButton.Activated:Connect(function()
	settings.highlight = not settings.highlight
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
