-- Renders the imported feature controls inside our existing panel.
local Controls = {}
local UIS = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

function Controls.mount(host, engine)
	local state, handles, subscriptions, pages, connections = {}, {}, {}, {}, {}
	local alive = true
	local function notify(data)
		host.notify((data.Title or engine) .. ": " .. tostring(data.Content or ""))
	end
	local function call(callback, ...)
		if not callback or not alive then return end
		local args = table.pack(...)
		task.spawn(function()
			local ok, err = pcall(callback, table.unpack(args, 1, args.n))
			if not ok then notify({ Title = "Ошибка", Content = tostring(err) }) end
		end)
	end
	local function track(signal, callback)
		local connection = signal:Connect(callback)
		table.insert(connections, connection)
		return connection
	end
	local function instance(class, parent, properties)
		local object = Instance.new(class)
		for key, value in pairs(properties) do object[key] = value end
		object.Parent = parent
		return object
	end
	local function text(parent, value, size)
		return instance("TextLabel", parent, {
			BackgroundTransparency = 1, Text = tostring(value or ""), TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
			TextColor3 = Color3.fromRGB(231, 237, 245), Font = Enum.Font.Gotham,
			TextSize = size or 14, Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(8, 0),
		})
	end
	local function button(parent, caption)
		return instance("TextButton", parent, {
			Text = caption, TextColor3 = Color3.fromRGB(240, 244, 250), Font = Enum.Font.GothamMedium,
			TextSize = 13, BackgroundColor3 = Color3.fromRGB(32, 92, 118), BorderSizePixel = 0,
			Size = UDim2.new(1, -16, 0, 32), Position = UDim2.fromOffset(8, 30),
		})
	end
	local function row(parent, title, height)
		local frame = instance("Frame", parent, {
			BackgroundColor3 = Color3.fromRGB(36, 41, 50), BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, height or 70), LayoutOrder = #parent:GetChildren(),
		})
		local label = text(frame, title)
		return frame, label
	end

	local library = {}
	local window = { State = {} }
	function window.State:Get(id) return state[id] end
	function window.State:Set(id, value)
		if handles[id] then handles[id]:Set(value) else state[id] = value end
	end
	function window.State:OnChanged(id, callback)
		subscriptions[id] = subscriptions[id] or {}
		table.insert(subscriptions[id], callback)
		return { Disconnect = function()
			local index = table.find(subscriptions[id], callback)
			if index then table.remove(subscriptions[id], index) end
		end }
	end
	local function addControl(parent, kind, config)
		config = config or {}
		local id = config.Id or config.Flag or (kind .. tostring(#parent:GetChildren()))
		local title = config.Title or config.Name or kind
		if kind == "Slider" then title ..= " (" .. tostring(config.Min or 0) .. "–" .. tostring(config.Max or 100) .. ")" end
		local value = config.Default
		if value == nil then value = config.Value end
		if kind == "Toggle" and value == nil then value = false end
		if kind == "MultiDropdown" or config.Multi then value = value or {} end
		state[id] = value
		local frame, label = row(parent, title)
		local handle = { value = value }
		local redraw = function() end
		function handle:Get() return self.value end
		function handle:Set(newValue)
			self.value = newValue
			state[id] = newValue
			redraw()
			call(config.Callback, newValue)
			for _, fn in ipairs(subscriptions[id] or {}) do call(fn, newValue) end
		end
		handle.SetValue = handle.Set
		function handle:OnChanged(fn) return window.State:OnChanged(id, fn) end
		function handle:SetTitle(value) title = tostring(value); label.Text = title end
		function handle:SetDescription(value) config.Description = value end
		function handle:SetStatus(value) config.Status = value end
		function handle:SetVisible(value) frame.Visible = value end
		function handle:SetOptions(options) config.Options = options; redraw() end
		handles[id] = handle
		if kind == "Toggle" then
			local toggle = button(frame, "")
			redraw = function()
				toggle.Text = handle.value and "ВКЛ" or "ВЫКЛ"
				toggle.BackgroundColor3 = handle.value and Color3.fromRGB(32, 92, 118) or Color3.fromRGB(56, 62, 73)
			end
			track(toggle.Activated, function() handle:Set(not handle.value) end)
		elseif kind == "Button" then
			local action = button(frame, config.Text or "Выполнить")
			track(action.Activated, function() call(config.Callback) end)
		elseif kind == "Input" or kind == "Slider" or kind == "Keybind" then
			local input = instance("TextBox", frame, {
				Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 32),
				BackgroundColor3 = Color3.fromRGB(24, 28, 35), TextColor3 = Color3.new(1, 1, 1),
				Font = Enum.Font.Gotham, TextSize = 14, ClearTextOnFocus = false, Text = "",
			})
			redraw = function()
				input.Text = typeof(handle.value) == "EnumItem" and handle.value.Name or tostring(handle.value or "")
			end
			track(input.FocusLost, function()
				local nextValue = input.Text
				if kind == "Slider" then
					nextValue = tonumber(nextValue)
					if not nextValue then redraw(); return end
					local step = config.Step or config.Increment
					if step then nextValue = math.round(nextValue / step) * step end
					nextValue = math.clamp(nextValue, config.Min or 0, config.Max or 100)
				elseif kind == "Keybind" then
					local ok, key = pcall(function() return Enum.KeyCode[nextValue] end)
					if not ok or not key then redraw(); return end
					nextValue = key
				end
				handle:Set(nextValue)
			end)
			if kind == "Keybind" then
				track(UIS.InputBegan, function(input, processed)
					if not processed and not UIS:GetFocusedTextBox() and input.KeyCode == handle.value then call(config.OnPress) end
				end)
			end
		elseif kind == "Dropdown" or kind == "MultiDropdown" then
			local multi = kind == "MultiDropdown" or config.Multi
			local picker = button(frame, "")
			local optionsFrame = instance("Frame", frame, {
				Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 0),
				BackgroundTransparency = 1, Visible = false,
			})
			local selected = {}
			local function selection()
				table.clear(selected)
				if type(handle.value) == "table" then
					for key, entry in pairs(handle.value) do
						if entry == true then selected[key] = true else selected[entry] = true end
					end
				end
			end
			local function rebuild()
				selection()
				for _, child in optionsFrame:GetChildren() do child:Destroy() end
				local options = config.Options or config.Values or {}
				local count = 0
				for _, option in ipairs(options) do
					local optionValue = type(option) == "table" and (option.Value or option.Id or option.Title) or option
					local caption = type(option) == "table" and (option.Label or option.Title or option.Name or optionValue) or option
					local choice = button(optionsFrame, (multi and (selected[optionValue] and "☑ " or "☐ ") or "") .. tostring(caption))
					choice.Position = UDim2.fromOffset(0, count * 34)
					choice.Size = UDim2.new(1, 0, 0, 32)
					count += 1
					choice.Activated:Connect(function()
						if multi then
							selected[optionValue] = not selected[optionValue]
							local list = {}
							for _, entry in ipairs(options) do
								local key = type(entry) == "table" and (entry.Value or entry.Id or entry.Title) or entry
								if selected[key] then table.insert(list, key) end
								end
							handle:Set(list)
						else
							optionsFrame.Visible = false
							handle:Set(optionValue)
						end
					end)
				end
				optionsFrame.Size = UDim2.new(1, -16, 0, count * 34)
				frame.Size = UDim2.new(1, -8, 0, optionsFrame.Visible and 74 + count * 34 or 70)
			end
			redraw = function()
				picker.Text = type(handle.value) == "table" and (#handle.value .. " выбрано ▾") or (tostring(handle.value or "Выбрать") .. " ▾")
				rebuild()
			end
			track(picker.Activated, function() optionsFrame.Visible = not optionsFrame.Visible; rebuild() end)
		else
			frame.Size = UDim2.new(1, -8, 0, kind == "Divider" and 34 or 80)
			local content = text(frame, config.Content or config.Value or "", 12)
			content.Position = UDim2.fromOffset(8, 28)
			content.Size = UDim2.new(1, -16, 0, 46)
			if kind == "Paragraph" then
				frame.AutomaticSize = Enum.AutomaticSize.Y
				content.AutomaticSize = Enum.AutomaticSize.Y
				content.Size = UDim2.new(1, -16, 0, 46)
			end
			redraw = function() content.Text = tostring(handle.value or config.Content or "") end
		end
		redraw()
		return handle
	end

	local function container(page, prefix)
		local api = {}
		for _, kind in ipairs({ "Toggle", "Button", "Slider", "Dropdown", "MultiDropdown", "Input", "Keybind", "Paragraph", "Divider", "Status" }) do
			api["Add" .. kind] = function(_, config) return addControl(page, kind, config) end
		end
		function api:AddSection(config)
			addControl(page, "Divider", config)
			return container(page, prefix)
		end
		function api:AddSubTab(name)
			local child = host.addPage(engine .. " / " .. prefix .. " / " .. tostring(name))
			table.insert(pages, child)
			return container(child, prefix .. " / " .. tostring(name))
		end
		return api
	end
	function window:AddTab(config)
		local name = config.Title or config.Name or config.Id
		local page = host.addPage(engine .. " / " .. name)
		table.insert(pages, page)
		return container(page, name)
	end
	local notifier = setmetatable({ Push = function(_, data) notify(data) end }, {
		__call = function(_, _, data) notify(data) end,
	})
	window.Notify = notifier
	window.Dialog = { Confirm = function(_, data)
		local result
		local page = host.addPage(engine .. " / Подтверждение")
		addControl(page, "Paragraph", data)
		addControl(page, "Button", { Title = "Подтвердить", Callback = function() result = true; host.removePage(page) end })
		addControl(page, "Button", { Title = "Отмена", Callback = function() result = false; host.removePage(page) end })
		return { Await = function()
			while result == nil and alive do task.wait() end
			return result == true
		end }
	end }
	function window:Toggle() host.toggle() end
	function window:Unload()
		if not alive then return end
		alive = false
		for _, connection in ipairs(connections) do connection:Disconnect() end
		for _, page in ipairs(pages) do host.removePage(page) end
	end
	window.Destroy = window.Unload
	-- Upstream themes are deliberately replaced by this panel's own styling.
	for _, method in ipairs({ "RegisterTheme", "SetTheme", "SaveCustomTheme", "SetDefaultTheme", "SetDensity", "SetHighContrast", "SetFooterText", "SetSubtitle" }) do
		window[method] = function() end
	end
	function library:CreateWindow() return window end
	local env = (getgenv and getgenv()) or _G
	local function configPath(name)
		assert(tostring(name):match("^[%w_%-]+$"), "Use letters, numbers, hyphen or underscore for config names")
		return "EggPanel_" .. engine .. "_" .. name .. ".json"
	end
	function library:SaveConfig(name)
		return pcall(function()
			assert(env.writefile or writefile, "writefile is unavailable")
			local values = {}
			for id, value in pairs(state) do
				values[id] = typeof(value) == "EnumItem" and { keyCode = value.Name } or value
			end
			(env.writefile or writefile)(configPath(name), HttpService:JSONEncode(values))
		end)
	end
	function library:LoadConfig(name)
		return pcall(function()
			assert(env.readfile or readfile, "readfile is unavailable")
			local values = HttpService:JSONDecode((env.readfile or readfile)(configPath(name)))
			for id, value in pairs(values) do
				if type(value) == "table" and value.keyCode then value = Enum.KeyCode[value.keyCode] end
				if handles[id] then handles[id]:Set(value) end
			end
		end)
	end
	function library:ListConfigs()
		return env.listfiles and env.listfiles("") or {}
	end
	local configPage = host.addPage(engine .. " / Конфигурации")
	table.insert(pages, configPage)
	local configName = "default"
	addControl(configPage, "Input", { Title = "Название конфигурации", Default = configName,
		Callback = function(value) configName = value end })
	addControl(configPage, "Button", { Title = "Сохранить конфигурацию", Callback = function()
		local ok, err = library:SaveConfig(configName)
		notify({ Title = "Конфигурация", Content = ok and "Сохранена" or tostring(err) })
	end })
	addControl(configPage, "Button", { Title = "Загрузить конфигурацию", Callback = function()
		local ok, err = library:LoadConfig(configName)
		notify({ Title = "Конфигурация", Content = ok and "Загружена" or tostring(err) })
	end })
	host.onCleanup(function() window:Unload() end)
	return library
end

return Controls
