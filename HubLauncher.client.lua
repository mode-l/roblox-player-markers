-- Full upstream hubs are kept as separate programs; their UI libraries load remotely.
local player = game:GetService("Players").LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local previous = playerGui:FindFirstChild("EggHubLauncher")
if previous then previous:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "EggHubLauncher"
gui.ResetOnSpawn = false
gui.Parent = playerGui
local frame = Instance.new("Frame")
frame.AnchorPoint = Vector2.new(0.5, 0.5)
frame.Position = UDim2.fromScale(0.5, 0.5)
frame.Size = UDim2.fromOffset(330, 230)
frame.BackgroundColor3 = Color3.fromRGB(24, 28, 35)
frame.BorderSizePixel = 0
frame.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame
local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -24, 0, 46)
title.Position = UDim2.fromOffset(12, 0)
title.BackgroundTransparency = 1
title.Text = "Выбор полного интерфейса"
title.TextColor3 = Color3.new(1, 1, 1)
title.Font = Enum.Font.GothamBold
title.TextSize = 17
title.Parent = frame
local status = Instance.new("TextLabel")
status.Position = UDim2.fromOffset(12, 160)
status.Size = UDim2.new(1, -24, 0, 60)
status.BackgroundTransparency = 1
status.TextWrapped = true
status.TextSize = 12
status.TextColor3 = Color3.fromRGB(190, 200, 215)
status.Text = "Откроется оригинальная панель выбранного скрипта."
status.Parent = frame
local busy = false
for index, name in ipairs({ "Boblo", "Oxide" }) do
	local button = Instance.new("TextButton")
	button.Position = UDim2.fromOffset(12, 48 + (index - 1) * 54)
	button.Size = UDim2.new(1, -24, 0, 46)
	button.Text = name .. " — все вкладки"
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(32, 92, 118)
	button.Parent = frame
	button.Activated:Connect(function()
		if busy then return end
		busy = true
		status.Text = "Загрузка " .. name .. "…"
		task.spawn(function()
			local ok, err = pcall(function()
				local source = game:HttpGet("https://raw.githubusercontent.com/mode-l/roblox-player-markers/main/" .. name .. ".lua")
				local chunk, compileError = loadstring(source, name)
				assert(chunk, compileError)
				chunk()
			end)
			busy = false
			if gui.Parent then
				status.Text = ok and "Интерфейс запущен." or ("Ошибка " .. name .. ": " .. tostring(err))
			end
		end)
	end)
end
