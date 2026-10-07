--[[
    Steal An Egg Hub (BobloUI)

    Port of the recovered Steal an Egg automation pipeline to BobloUI.
    Steal - Place - Hatch - Fuse - Sell - Shop - ESP - Movement - Hop - Webhooks
]]

local GAME_NAME = "Steal an Egg"
local HEADER_CREDIT = "Made with <3 - bobloscript.com"

local genv = (getgenv and getgenv()) or _G

if type(genv.__SAE_HUB_SHUTDOWN) == "function" then
	pcall(genv.__SAE_HUB_SHUTDOWN)
	task.wait(0.1)
end
if genv.__SAE_HUB_RUNNING then
	return
end
genv.__SAE_HUB_RUNNING = true

if not game:IsLoaded() then
	game.Loaded:Wait()
end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
pcall(function()
	LocalPlayer:WaitForChild("PlayerGui", 10)
end)

-- Potassium compatibility:
-- BobloUI normally prefers gethui/CoreGui. Some Potassium callback threads
-- lose the capability required to touch hidden/CoreGui instances later.
-- Force BobloUI to mount into PlayerGui while its Env module is initialized.
local _bobloCompat = {
	gethui = rawget(genv, "gethui"),
	protect_gui = rawget(genv, "protect_gui"),
}
local _compatAssignedGetHui = pcall(function()
	genv.gethui = function()
		return LocalPlayer:WaitForChild("PlayerGui")
	end
end)
local _compatAssignedProtect = pcall(function()
	genv.protect_gui = function() end
end)

local _bobloOk, BobloUI = pcall(function()
	return loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/bobloscript/BobloUI/main/dist/BobloUI.min.lua"
	))()
end)

if _compatAssignedGetHui then
	pcall(function() genv.gethui = _bobloCompat.gethui end)
end
if _compatAssignedProtect then
	pcall(function() genv.protect_gui = _bobloCompat.protect_gui end)
end
if not _bobloOk then
	error("[Steal An Egg] BobloUI load failed: " .. tostring(BobloUI))
end

local UI = BobloUI:CreateWindow({
	Id = "steal-an-egg-hub",
	Title = "Steal An Egg",
	Subtitle = HEADER_CREDIT,
	Theme = "Light",
	Density = "Comfortable",
	HighContrast = false,
	FooterText = "",
	ConfigFolder = "StealAnEggHub",
	AutoLoad = true,
})

local hex = Color3.fromHex
local Theme = {
	Appearance = "Dark",
	Canvas = hex("120B08"),
	Background = hex("1A100C"),
	Sidebar = hex("21130E"),
	Surface = hex("2A1811"),
	SurfaceRaised = hex("352017"),
	SurfaceInset = hex("160C09"),
	SurfaceSecondary = hex("2F1B13"),
	SurfaceHover = hex("3D2419"),
	SurfaceActive = hex("4A2B1D"),
	Control = hex("352017"),
	ControlHover = hex("43271B"),
	ControlPressed = hex("512E1F"),
	ControlInset = hex("1A0F0B"),
	BorderSubtle = hex("301A12"),
	Border = hex("5B3424"),
	BorderStrong = hex("87513A"),
	Text = hex("FFF1E8"),
	TextSecondary = hex("D7B6A5"),
	TextTertiary = hex("A47B69"),
	TextDisabled = hex("735447"),
	Accent = hex("F26A2E"),
	AccentHover = hex("FF7A38"),
	AccentPressed = hex("D95520"),
	TextOnAccent = hex("1A0A04"),
	Success = hex("69D38B"),
	Warning = hex("F5A33B"),
	Error = hex("EF5B5B"),
	Info = hex("6FA8DC"),
	Scrim = hex("090403"),
	ScrimTransparency = 0.48,
}

UI:RegisterTheme("Ember", Theme)
UI:SetTheme("Ember")
pcall(function()
	if UI.Theme and UI.Theme.RememberPolarity then
		UI.Theme:RememberPolarity("Dark", "Ember")
		UI.Theme:RememberPolarity("Light", "Light")
	end
end)
pcall(function()
	UI:SaveCustomTheme("Ember", Theme)
	if UI.SetDefaultTheme then
		UI:SetDefaultTheme("Ember")
	end
end)
pcall(function()
	UI:SetDensity("Comfortable")
	UI:SetHighContrast(false)
	if UI.SetFooterText then
		UI:SetFooterText("")
	end
	if UI.SetSubtitle then
		UI:SetSubtitle(HEADER_CREDIT)
	end
end)

local H = {}

function H.notify(title, content, variant, duration)
	UI.Notify:Push({
		Title = title,
		Content = content,
		Variant = variant or "Info",
		Duration = duration or 3,
	})
end

function H.getState(id, fallback)
	local ok, v = pcall(function()
		return UI.State:Get(id)
	end)
	if ok and v ~= nil then
		return v
	end
	return fallback
end

function H.isOn(id)
	return H.getState(id, false) == true
end

function H.optionValue(id, fallback)
	local v = H.getState(id, fallback)
	if v == nil then
		return fallback
	end
	return v
end

function H.multiSelected(id)
	local value = H.getState(id, {})
	local selected = {}
	if typeof(value) ~= "table" then
		if typeof(value) == "string" and value ~= "" then
			selected[value] = true
		end
		return selected
	end
	for key, item in pairs(value) do
		if item == true then
			selected[key] = true
		elseif typeof(key) == "number" and typeof(item) == "string" then
			selected[item] = true
		end
	end
	return selected
end

function H.multiHasAny(id)
	return next(H.multiSelected(id)) ~= nil
end

function H.selectionAllows(id, value)
	if not H.multiHasAny(id) then
		return true
	end
	return H.multiSelected(id)[value] == true
end

-- ===== Module / remote bind =====
function H.requirePath(root, timeout, ...)
	local cur = root
	local names = { ... }
	for _, name in ipairs(names) do
		if not cur then
			return nil
		end
		local child = cur:FindFirstChild(name)
		if not child then
			child = cur:WaitForChild(name, timeout or 4)
		end
		cur = child
	end
	if not cur then
		return nil
	end
	local ok, mod = pcall(require, cur)
	return ok and mod or nil
end

function H.findModule(name)
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("ModuleScript") and d.Name == name then
			local ok, mod = pcall(require, d)
			if ok then
				return mod
			end
		end
	end
	return nil
end

function H.findRemote(name)
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if (d:IsA("RemoteEvent") or d:IsA("RemoteFunction")) and d.Name == name then
			return d
		end
	end
	return nil
end

function H.findRemoteContains(...)
	local parts = { ... }
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
		if d:IsA("RemoteEvent") or d:IsA("RemoteFunction") then
			local ok = true
			for _, part in ipairs(parts) do
				if not string.find(d.Name, part, 1, true) then
					ok = false
					break
				end
			end
			if ok then
				return d
			end
		end
	end
	return nil
end

function H.pickFromTable(tbl, ...)
	if typeof(tbl) ~= "table" then
		return nil
	end
	local names = { ... }
	local cur = tbl
	for _, name in ipairs(names) do
		if typeof(cur) ~= "table" then
			return nil
		end
		cur = cur[name]
	end
	return cur
end

local SaveModule = H.requirePath(ReplicatedStorage, 6, "Shared", "Save") or H.findModule("Save")
local Constants = H.requirePath(ReplicatedStorage, 4, "Shared", "Globals", "Constants") or H.findModule("Constants")
local BaseUpgradeModule = H.requirePath(ReplicatedStorage, 4, "Client", "BaseUpgrade") or H.findModule("BaseUpgrade")
local EggTypes = H.requirePath(ReplicatedStorage, 4, "Shared", "Types", "Eggs") or H.findModule("Eggs")
local AreasModule = H.requirePath(ReplicatedStorage, 4, "Data", "Areas") or H.findModule("Areas")
local AssetsData = H.requirePath(ReplicatedStorage, 4, "Data", "Assets") or H.findModule("Assets")
local GearsModule = H.requirePath(ReplicatedStorage, 4, "Data", "Gears") or H.findModule("Gears")
local TrailsModule = H.requirePath(ReplicatedStorage, 4, "Data", "Trails") or H.findModule("Trails")
local TreadmillsData = H.requirePath(ReplicatedStorage, 4, "Data", "Treadmills") or H.findModule("Treadmills")
local EggStateModule = H.requirePath(ReplicatedStorage, 6, "Client", "EggState") or H.findModule("EggState")
local PlotStateModule = H.requirePath(ReplicatedStorage, 6, "Client", "PlotState") or H.findModule("PlotState")
local SlotIdentityModule = H.requirePath(ReplicatedStorage, 4, "Shared", "Util", "AreaEggSlotIdentity") or H.findModule("AreaEggSlotIdentity")
local AssetRosterModule = H.requirePath(ReplicatedStorage, 4, "Client", "AssetRoster") or H.findModule("AssetRoster")
local AssetItemsModule = H.requirePath(ReplicatedStorage, 4, "Shared", "Util", "AssetItems") or H.findModule("AssetItems")
local FuseKernelModule = H.requirePath(ReplicatedStorage, 4, "Shared", "Util", "FuseKernel") or H.findModule("FuseKernel")
local RemotesModule = H.requirePath(ReplicatedStorage, 6, "Shared", "Remotes") or H.findModule("Remotes")

function H.pickFn(mod, ...)
	if typeof(mod) ~= "table" then
		return nil
	end
	for i = 1, select("#", ...) do
		local key = select(i, ...)
		local fn = mod[key]
		if typeof(fn) == "function" then
			return fn
		end
	end
	return nil
end

local EggApi = {
	GetAreaEggSnapshot = H.pickFn(EggStateModule, "ReadFieldEggs", "GetAreaEggSnapshot"),
	RequestAreaEggSnapshot = H.pickFn(EggStateModule, "SyncFieldEggs", "RequestAreaEggSnapshot"),
	AreaEggCarryStateChanged = EggStateModule and (EggStateModule.CarryChanged or EggStateModule.AreaEggCarryStateChanged),
	RequestCarryAreaEgg = H.pickFn(EggStateModule, "CarryFieldEgg", "RequestCarryAreaEgg"),
	RequestDropHeldAreaEgg = H.pickFn(EggStateModule, "DropFieldEgg", "RequestDropHeldAreaEgg"),
	IsLocalEggReady = H.pickFn(EggStateModule, "IsReadyToHatch", "IsLocalEggReady"),
	RequestHatchEgg = H.pickFn(EggStateModule, "BeginHatch", "RequestHatchEgg"),
	RequestCompleteHatchEgg = H.pickFn(EggStateModule, "FinishHatch", "RequestCompleteHatchEgg"),
	RequestEquipTool = H.pickFn(EggStateModule, "WearEggTool", "RequestEquipTool"),
	RequestPlaceEgg = H.pickFn(EggStateModule, "PlantEgg", "RequestPlaceEgg"),
}

local PlotApi = {
	GetRespawnPointCFrame = H.pickFn(PlotStateModule, "FindRespawnCFrame", "GetRespawnPointCFrame"),
	GetPlotData = H.pickFn(PlotStateModule, "ResolvePlot", "GetPlotData"),
	IsWorldPositionWithinLocalPlotBounds = H.pickFn(PlotStateModule, "ContainsLocalPoint", "IsWorldPositionWithinLocalPlotBounds"),
	GetSlotOwner = H.pickFn(PlotStateModule, "LookupOwner", "GetSlotOwner"),
}

local SlotIdentityApi = {
	IsFirstAreaUid = H.pickFn(SlotIdentityModule, "LooksLikeFirstAreaUid", "IsFirstAreaUid"),
	BuildSlotKey = H.pickFn(SlotIdentityModule, "SlotKey", "BuildSlotKey"),
}

local AssetRosterApi = {
	GetRuntimeSnapshot = H.pickFn(AssetRosterModule, "ReadSnapshot", "GetRuntimeSnapshot"),
}

local AssetItemsApi = {
	Deserialize = H.pickFn(AssetItemsModule, "Decode", "Deserialize"),
}

local FuseApi = {
	CanSelectPet = H.pickFn(FuseKernelModule, "MayEnterFuse", "CanSelectPet"),
	CalculateFusePrice = H.pickFn(FuseKernelModule, "PriceFor", "CalculateFusePrice"),
}

function H.remoteFrom(mod, ...)
	local inst = H.pickFromTable(mod, ...)
	if typeof(inst) == "Instance" then
		return inst
	end
	return nil
end

local Remotes = {
	Backpack = {
		EQUIP_BEST = H.remoteFrom(RemotesModule, "Haul", "WearBest")
			or H.findRemoteContains("WearBest")
			or H.findRemoteContains("EQUIP_BEST"),
	},
	Plots = {
		REQUEST_BASE_UPGRADE = H.remoteFrom(RemotesModule, "Homestead", "AskBaseTierRaise")
			or H.findRemoteContains("AskBaseTierRaise")
			or H.findRemoteContains("BaseUpgrade"),
	},
	Treadmills = {
		REQUEST_UPGRADE = H.remoteFrom(RemotesModule, "Treadmill", "AskTierRaise") or H.findRemoteContains("AskTierRaise"),
		REQUEST_EQUIP_STATIC = H.remoteFrom(RemotesModule, "Treadmill", "AskWearStill") or H.findRemoteContains("AskWearStill"),
		REQUEST_UNEQUIP = H.remoteFrom(RemotesModule, "Treadmill", "AskDoff") or H.findRemoteContains("AskDoff"),
	},
	Index = {
		REQUEST_CLAIM_ALL = H.remoteFrom(RemotesModule, "Codex", "AskRedeemAll") or H.findRemoteContains("AskRedeemAll"),
	},
	AssetInventory = {
		SELL_ASSET = H.remoteFrom(RemotesModule, "PetSatchel", "SellPet")
			or H.findRemoteContains("SellPet")
			or H.findRemoteContains("SELL_ASSET"),
	},
	OfflineAssets = {
		GET_SUMMARY = H.remoteFrom(RemotesModule, "AwayEarnings", "FetchSummary") or H.findRemoteContains("FetchSummary"),
		REQUEST_REDEEM = H.remoteFrom(RemotesModule, "AwayEarnings", "AskCollect") or H.findRemoteContains("AskCollect"),
	},
	FuseMachine = {
		COMPLETE_REVEAL = H.remoteFrom(RemotesModule, "Fusery", "FinishReveal") or H.findRemoteContains("FinishReveal"),
		ACKNOWLEDGE_INFO = H.remoteFrom(RemotesModule, "Fusery", "ConfirmBriefing") or H.findRemoteContains("ConfirmBriefing"),
		INSERT_MOB = H.remoteFrom(RemotesModule, "Fusery", "LoadPet") or H.findRemoteContains("LoadPet"),
		START_FUSE = H.remoteFrom(RemotesModule, "Fusery", "BeginFuse") or H.findRemoteContains("BeginFuse"),
	},
	Trails = {
		REQUEST_PURCHASE = H.remoteFrom(RemotesModule, "Trailwear", "AskPurchase") or H.findRemoteContains("AskPurchase"),
		REQUEST_SELECT = H.remoteFrom(RemotesModule, "Trailwear", "AskChoose") or H.findRemoteContains("AskChoose"),
		WORN_SNAPSHOT = H.remoteFrom(RemotesModule, "Trailwear", "AskWornSnapshot") or H.findRemoteContains("AskWornSnapshot"),
	},
	GroupReward = {
		CLAIM_REWARD = H.remoteFrom(RemotesModule, "GroupPerk", "RedeemPerk") or H.findRemoteContains("RedeemPerk"),
	},
}

local CarryRemote = H.findRemote("RF/EggWorld/AskFieldEggCarry") or H.findRemoteContains("AskFieldEggCarry")
local SnapshotRemote = H.findRemote("RF/EggWorld/AskFieldEggSnapshot") or H.findRemoteContains("AskFieldEggSnapshot")
local PlaceRemote = H.findRemote("RF/EggWorld/AskPlaceEgg") or H.findRemoteContains("AskPlaceEgg")

if not EggApi.RequestCarryAreaEgg and CarryRemote then
	EggApi.RequestCarryAreaEgg = function(uid, slotKey)
		if CarryRemote:IsA("RemoteFunction") then
			return CarryRemote:InvokeServer(uid, slotKey)
		end
		CarryRemote:FireServer(uid, slotKey)
		return true
	end
end
if not EggApi.RequestAreaEggSnapshot and SnapshotRemote then
	EggApi.RequestAreaEggSnapshot = function()
		if SnapshotRemote:IsA("RemoteFunction") then
			return SnapshotRemote:InvokeServer()
		end
		SnapshotRemote:FireServer()
	end
end
if not EggApi.RequestPlaceEgg and PlaceRemote then
	EggApi.RequestPlaceEgg = function(uid, cframe)
		if PlaceRemote:IsA("RemoteFunction") then
			return PlaceRemote:InvokeServer(uid, cframe)
		end
		PlaceRemote:FireServer(uid, cframe)
		return true
	end
end

local modulesOk = SaveModule ~= nil and EggStateModule ~= nil
if not modulesOk then
	H.notify("Bind", "Some game modules were not found - a few features may no-op", "Warning", 5)
end

-- ===== Constants / lists =====
local RARITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Secret", "Eternal", "Divine" }
local RarityWeight = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5,
	Mythic = 6, Cosmic = 7, Secret = 8, Eternal = 9, Divine = 10,
}
local MUTATIONS = { "Golden", "Rainbow", "Silver" }
local STEAL_PRIORITIES = { "Rarest", "Nearest", "Furthest", "Biggest Size" }
local FUSE_TARGET_MODES = { "Highest Rarity", "Lowest Rarity", "Most Duplicates" }
local UPGRADE_TYPES = { "Base", "Treadmill" }
local PriorityTaskNames = { "Auto Steal Egg", "Auto Place Egg", "Auto Hatch", "Auto Treadmill" }
local PrioritySlotOptionNames = { "PrioritySlot1", "PrioritySlot2", "PrioritySlot3", "PrioritySlot4" }
local ServerHopModes = { "No Matching Eggs", "Timed Interval", "After Steal Count" }
local AREA_ORDER = { "Forest", "Lake", "Desert", "Jungle", "Snow", "Volcano", "Abyss Ocean", "Prehistoric", "Cosmic" }

local AreaNames = {}
if AreasModule and typeof(AreasModule.Directory) == "table" then
	for areaName in pairs(AreasModule.Directory) do
		table.insert(AreaNames, areaName)
	end
	table.sort(AreaNames)
else
	AreaNames = table.clone(AREA_ORDER)
end

local TrailNames = {}
local TrailIdByName = {}
local TrailPriceByName = {}
if TrailsModule and typeof(TrailsModule.Directory) == "table" then
	local trailEntries = {}
	for trailId, trailData in pairs(TrailsModule.Directory) do
		table.insert(trailEntries, {
			id = trailId,
			name = trailData.DisplayName,
			price = tonumber(trailData.Price) or 0,
		})
	end
	table.sort(trailEntries, function(a, b)
		return a.price < b.price
	end)
	for _, entry in ipairs(trailEntries) do
		table.insert(TrailNames, entry.name)
		TrailIdByName[entry.name] = entry.id
		TrailPriceByName[entry.name] = entry.price
	end
end

local GearCostByName = {}
if GearsModule then
	local gearDirectory = GearsModule.Directory or GearsModule
	if typeof(gearDirectory) == "table" then
		for _, gearData in pairs(gearDirectory) do
			if typeof(gearData) == "table" and typeof(gearData.DisplayName) == "string" then
				GearCostByName[gearData.DisplayName] = tonumber(gearData.MoneyCost) or 0
			end
		end
	end
end

local DEFAULT_STEAL_SPEED = 300
local CORRIDOR_STEP_DELAY = 0.08
local StealConfig = { GrabDelay = 0.55, ReturnPace = 0.12, ArriveDistance = 1.35, MoveTimeout = 14 }

-- ===== Runtime state =====
local running = true
local conns = {}
local statusRow
local stolenRow
local jobRow
local carryingRow
local runtimeRow
local inventoryProgress
local moneyRow
local speedRow
local rebirthRow
local petsOwnedRow

local CurrentJobId = tostring(game.JobId)
local DisplayJobId = CurrentJobId
if #DisplayJobId > 18 then
	DisplayJobId = string.sub(DisplayJobId, 1, 18) .. "..."
end

local IsCarryingEgg = false
local SessionStolenEggs = 0
local CarryStartedCallback = nil
local AutomationBusy = false
local AutomationLastRunAt = {}
local TreadmillTrainingActive = false
local ServerHopInProgress = false
local ServerHopRetryAfter = 0
local NoMatchingEggsSince = 0
local HopIntervalStartedAt = os.clock()
local LastTeleportFailure = nil
local LastEquipBestAt = 0
local NextPlacementIndex = 1
local PlotFullUntil = 0
local LastInputAt = tick()
local LastAntiAfkAt = tick()
local DisconnectHandled = false
local RenderingDisabled = false
local RenderOverlayGui = nil
local RenderOverlayLabels = {}
local FpsBoostSnapshot = nil
local FpsDescendantAddedConnection = nil
local FpsCapUnsupportedNotified = false
local AutoExecuteTeleportConnection = nil
local SessionStartedAt = os.clock()
local LastWebhookSummaryAt = os.clock()
local KnownWorldEggUids = {}
local KnownInventoryUids = {}
local WebhookTrackerInitialized = false
local LastRebirthSnapshot = nil
local LastStealCountSnapshot = 0
local SummaryStolenEggs = 0
local SummaryPetsObtained = 0
local SummaryRebirths = 0
local SpawnedEggLog = {}
local ObtainedEggLog = {}
local EspEntries = {}
local EspSeenThisPass = {}

local VisitedServerIds = {}
if getgenv then
	local history = getgenv().StealAnEggHubHopHistory
	if typeof(history) ~= "table" then
		history = {}
		getgenv().StealAnEggHubHopHistory = history
	end
	VisitedServerIds = history
end

local AreasFolder = Workspace:FindFirstChild("__OBJECTS") and Workspace.__OBJECTS:FindFirstChild("Areas")
if not AreasFolder then
	local objects = Workspace:WaitForChild("__OBJECTS", 8)
	AreasFolder = objects and objects:WaitForChild("Areas", 8)
end
local GuardAreasFolder = AreasFolder and AreasFolder:FindFirstChild("GuardAreas")
if AreasFolder and not GuardAreasFolder then
	GuardAreasFolder = AreasFolder:WaitForChild("GuardAreas", 6)
end

local AreaEggSlotsClient = Workspace:FindFirstChild("AreaEggSlotsClient")
if not AreaEggSlotsClient then
	AreaEggSlotsClient = Workspace:WaitForChild("AreaEggSlotsClient", 10)
end

local EspFolder = Instance.new("Folder")
EspFolder.Name = "BobloEggEsp"
EspFolder.Parent = Workspace

function H.track(c)
	table.insert(conns, c)
	return c
end

function H.setStatus(text, variant)
	if statusRow then
		pcall(function()
			statusRow:SetValue(text)
			if variant then
				statusRow:SetStatus(variant)
			end
		end)
	end
end

function H.setJob(text)
	if jobRow then
		pcall(function()
			jobRow:SetValue(text)
		end)
	end
end

function H.setStolen()
	if stolenRow then
		pcall(function()
			stolenRow:SetValue(tostring(SessionStolenEggs))
		end)
	end
end

function H.copyText(text, message)
	local clip = setclipboard or toclipboard
	if typeof(clip) == "function" then
		pcall(clip, text)
	end
	H.notify("Copied", message or "Copied to clipboard", "Success", 3)
end

-- ===== Generic helpers =====
function H.getHumanoid()
	local character = LocalPlayer.Character
	return character and character:FindFirstChildOfClass("Humanoid") or nil
end

function H.getRoot()
	local character = LocalPlayer.Character
	return character and character:FindFirstChild("HumanoidRootPart") or nil
end

function H.getSave()
	if not SaveModule or typeof(SaveModule.Get) ~= "function" then
		return nil
	end
	local ok, save = pcall(SaveModule.Get)
	return ok and save or nil
end

function H.netInvoke(remote, ...)
	if typeof(remote) ~= "Instance" then
		return nil
	end
	local args = table.pack(...)
	local result = nil
	local done = false
	task.spawn(function()
		if remote:IsA("RemoteFunction") then
			result = table.pack(pcall(function()
				return remote:InvokeServer(table.unpack(args, 1, args.n))
			end))
		elseif remote:IsA("RemoteEvent") then
			result = table.pack(pcall(function()
				remote:FireServer(table.unpack(args, 1, args.n))
				return true
			end))
		else
			result = table.pack(false)
		end
		done = true
	end)
	local deadline = os.clock() + 8
	while not done and os.clock() < deadline do
		task.wait(0.05)
	end
	if not done or result[1] ~= true then
		return nil
	end
	return result[2], result[3]
end

function H.netCall(remote, ...)
	if typeof(remote) == "Instance" and remote:IsA("RemoteEvent") then
		return pcall(function(...)
			remote:FireServer(...)
		end, ...)
	end
	return H.netInvoke(remote, ...)
end

function H.countTable(value)
	if typeof(value) ~= "table" then
		return 0
	end
	local count = 0
	for _ in pairs(value) do
		count += 1
	end
	return count
end

function H.formatNumber(value)
	local number = tonumber(value) or 0
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local suffixIndex = 1
	while number >= 1000 and suffixIndex < #suffixes do
		number /= 1000
		suffixIndex += 1
	end
	if suffixIndex == 1 then
		return string.format("%d", number)
	end
	return string.format("%.2f%s", number, suffixes[suffixIndex])
end

function H.formatElapsed(seconds)
	local total = math.max(0, math.floor(seconds))
	local hours = math.floor(total / 3600)
	local minutes = math.floor((total % 3600) / 60)
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", minutes)
end

function H.resolveRarity(assetCategory)
	if typeof(assetCategory) ~= "string" or not AssetsData or typeof(AssetsData.Directory) ~= "table" then
		return nil
	end
	local directoryEntry = AssetsData.Directory[assetCategory]
	local rarity = directoryEntry and directoryEntry.Rarity
	if not rarity then
		return nil
	end
	return rarity._id or rarity.DisplayName
end

function H.assetName(assetCategory)
	if AssetsData and typeof(AssetsData.Directory) == "table" then
		local entry = AssetsData.Directory[assetCategory or ""]
		if entry and entry.DisplayName then
			return entry.DisplayName
		end
	end
	return tostring(assetCategory or "Unknown")
end

function H.recordMutations(asset)
	local mutations = {}
	if typeof(asset) ~= "table" then
		return mutations
	end
	if typeof(asset.Mutations) == "table" then
		for _, mutation in pairs(asset.Mutations) do
			if typeof(mutation) == "string" then
				table.insert(mutations, mutation)
			end
		end
	end
	if typeof(asset.BaseMutation) == "string" then
		table.insert(mutations, asset.BaseMutation)
	end
	return mutations
end

function H.matchesMutationFilter(optionName, asset)
	if not H.multiHasAny(optionName) then
		return true
	end
	local selected = H.multiSelected(optionName)
	for _, mutation in ipairs(H.recordMutations(asset)) do
		if selected[mutation] then
			return true
		end
	end
	return false
end

function H.matchesEggFilters(egg, areaOptionName, rarityOptionName, mutationOptionName)
	if areaOptionName then
		local areaId = egg.AreaId
		if typeof(areaId) ~= "string" or not H.selectionAllows(areaOptionName, areaId) then
			return false
		end
	end
	local rarity = H.resolveRarity(egg.AssetCategory)
	if typeof(rarity) ~= "string" or not H.selectionAllows(rarityOptionName, rarity) then
		return false
	end
	return H.matchesMutationFilter(mutationOptionName, egg)
end

-- ===== Corridor / movement =====
function H.getLaneZ()
	if AreasFolder then
		local gameplayZ = AreasFolder:FindFirstChild("GameplayZ")
		if gameplayZ and gameplayZ:IsA("BasePart") then
			return gameplayZ.Position.Z
		end
		local separationLine = AreasFolder:FindFirstChild("SeparationLine")
		if separationLine and separationLine:IsA("BasePart") then
			return separationLine.Position.Z
		end
	end
	return -365.5
end

function H.getLaneY()
	if AreasFolder then
		local gameplayZ = AreasFolder:FindFirstChild("GameplayZ")
		if gameplayZ and gameplayZ:IsA("BasePart") then
			return gameplayZ.Position.Y + 3
		end
	end
	local root = H.getRoot()
	return root and root.Position.Y or 70
end

function H.getEntryPosition()
	if AreasFolder then
		local startArea = AreasFolder:FindFirstChild("StartArea")
		if startArea and startArea:IsA("BasePart") then
			return Vector3.new(startArea.Position.X, H.getLaneY(), H.getLaneZ())
		end
		local separationLine = AreasFolder:FindFirstChild("SeparationLine")
		if separationLine and separationLine:IsA("BasePart") then
			return Vector3.new(separationLine.Position.X, H.getLaneY(), H.getLaneZ())
		end
	end
	return Vector3.new(543.5, H.getLaneY(), H.getLaneZ())
end

function H.getZoneModel(zoneName)
	return GuardAreasFolder and GuardAreasFolder:FindFirstChild(zoneName)
end

function H.getZoneLaneCenter(zoneName)
	local zone = H.getZoneModel(zoneName)
	if not zone then
		return nil
	end
	local bounds = zone:FindFirstChild("Bounds")
	if bounds and bounds:IsA("BasePart") then
		return Vector3.new(bounds.Position.X, H.getLaneY(), H.getLaneZ())
	end
	local ok, pivot = pcall(function()
		return zone:GetBoundingBox()
	end)
	if ok and pivot then
		return Vector3.new(pivot.Position.X, H.getLaneY(), H.getLaneZ())
	end
	return nil
end

function H.getCorridorBounds()
	local minX, maxX = math.huge, -math.huge
	local minZ, maxZ = math.huge, -math.huge
	for _, zoneName in ipairs(AREA_ORDER) do
		local zone = H.getZoneModel(zoneName)
		local bounds = zone and zone:FindFirstChild("Bounds")
		if bounds and bounds:IsA("BasePart") then
			local halfX = bounds.Size.X * 0.5
			local halfZ = bounds.Size.Z * 0.5
			minX = math.min(minX, bounds.Position.X - halfX)
			maxX = math.max(maxX, bounds.Position.X + halfX)
			minZ = math.min(minZ, bounds.Position.Z - halfZ)
			maxZ = math.max(maxZ, bounds.Position.Z + halfZ)
		end
	end
	local entry = H.getEntryPosition()
	minX = math.min(minX, entry.X - 20)
	return minX, maxX, minZ, maxZ
end

function H.clampToCorridor(position, allowOutsideCorridor)
	if allowOutsideCorridor then
		return position
	end
	local minX, maxX, minZ, maxZ = H.getCorridorBounds()
	return Vector3.new(math.clamp(position.X, minX, maxX), position.Y, math.clamp(position.Z, minZ, maxZ))
end

function H.rawTeleport(position)
	local root = H.getRoot()
	if not root or typeof(position) ~= "Vector3" then
		return false
	end
	root.CFrame = CFrame.new(position) * (root.CFrame - root.CFrame.Position)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	return true
end

function H.travelTo(position, allowOutsideCorridor)
	if typeof(position) ~= "Vector3" or not running then
		return false
	end
	if not H.rawTeleport(H.clampToCorridor(position, allowOutsideCorridor == true)) then
		return false
	end
	task.wait()
	return true
end

function H.groundedY(x, z, fallbackY)
	local laneY = H.getLaneY()
	local root = H.getRoot()
	local humanoid = H.getHumanoid()
	local hipHeight = 2
	if humanoid and humanoid.HipHeight > 0 then
		hipHeight = humanoid.HipHeight
	end
	local rootHalfHeight = root and root.Size.Y * 0.5 or 1
	local characterOffset = hipHeight + rootHalfHeight
	local groundThreshold = laneY + 1.5
	local excluded = {}
	if LocalPlayer.Character then
		table.insert(excluded, LocalPlayer.Character)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local originY = laneY + 40
	local hitY = nil
	for _ = 1, 20 do
		params.FilterDescendantsInstances = excluded
		local hit = Workspace:Raycast(Vector3.new(x, originY, z), Vector3.new(0, -160, 0), params)
		if not hit then
			break
		end
		local y = hit.Position.Y
		local name = hit.Instance.Name
		local looksLikeGround = name == "Ground" or string.find(string.lower(name), "ground", 1, true) ~= nil
		if looksLikeGround or y <= groundThreshold then
			hitY = y
			break
		end
		table.insert(excluded, hit.Instance)
	end
	if hitY then
		return math.clamp(hitY + characterOffset, laneY - 2, laneY + 5)
	end
	if typeof(fallbackY) == "number" then
		return math.clamp(fallbackY, laneY - 2, laneY + 5)
	end
	return laneY + 3
end

function H.anchorStealRoot(root, cf)
	root.CFrame = cf
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

function H.stealSpeed()
	return math.clamp(tonumber(H.optionValue("StealSpeed", DEFAULT_STEAL_SPEED)) or DEFAULT_STEAL_SPEED, 50, 1000)
end

function H.swapStealHumanoid()
	local character = LocalPlayer.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end
	if humanoid:GetAttribute("BobloStealHum") == true then
		return true
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("LocalScript") and string.find(descendant.Name, "PushBack") then
			pcall(function()
				descendant.Disabled = true
				descendant:Destroy()
			end)
		end
	end
	humanoid.Archivable = true
	local replacement = humanoid:Clone()
	if not replacement then
		return false
	end
	replacement:SetAttribute("BobloStealHum", true)
	replacement.Sit = false
	replacement.PlatformStand = false
	replacement.AutoRotate = true
	humanoid:Destroy()
	replacement.Parent = character
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
	end
	pcall(function()
		replacement:ChangeState(Enum.HumanoidStateType.Running)
	end)
	return character:FindFirstChildOfClass("Humanoid") ~= nil
end

function H.stealMoveTo(targetX, targetZ, keepGoing)
	local root = H.getRoot()
	if not root then
		return false
	end
	local humanoid = H.getHumanoid()
	if humanoid then
		humanoid.Sit = false
		humanoid.PlatformStand = false
	end
	local arriveDistance = StealConfig.ArriveDistance
	local deadline = tick() + StealConfig.MoveTimeout
	while tick() < deadline do
		if not running then
			return false
		end
		if keepGoing and not keepGoing() then
			return false
		end
		root = H.getRoot()
		if not root then
			return false
		end
		humanoid = H.getHumanoid()
		local y = H.groundedY(targetX, targetZ, root.Position.Y)
		local target = Vector3.new(targetX, y, targetZ)
		local delta = target - root.Position
		local distance = delta.Magnitude
		if distance <= arriveDistance then
			H.anchorStealRoot(root, CFrame.new(target))
			if humanoid then
				pcall(function()
					humanoid:ChangeState(Enum.HumanoidStateType.Running)
				end)
			end
			return true
		end
		local dt = RunService.Heartbeat:Wait()
		if typeof(dt) ~= "number" or dt <= 0 then
			dt = 1 / 60
		end
		root = H.getRoot()
		if not root then
			return false
		end
		y = H.groundedY(targetX, targetZ, root.Position.Y)
		target = Vector3.new(targetX, y, targetZ)
		delta = target - root.Position
		distance = delta.Magnitude
		if distance <= arriveDistance then
			H.anchorStealRoot(root, CFrame.new(target))
			return true
		end
		local step = math.min(distance, H.stealSpeed() * dt)
		local nextPosition = root.Position + delta.Unit * step
		nextPosition = Vector3.new(nextPosition.X, H.groundedY(nextPosition.X, nextPosition.Z, nextPosition.Y), nextPosition.Z)
		local horizontal = Vector3.new(delta.X, 0, delta.Z)
		local nextCFrame = horizontal.Magnitude > 0.05 and CFrame.lookAt(nextPosition, nextPosition + horizontal) or CFrame.new(nextPosition)
		H.anchorStealRoot(root, nextCFrame)
	end
	return false
end

function H.buildStealPath(startPosition, targetPosition)
	local laneZ = H.getLaneZ()
	local laneY = H.getLaneY()
	local waypoints = {}
	if math.abs(startPosition.Z - laneZ) > 3 then
		table.insert(waypoints, Vector3.new(startPosition.X, laneY, laneZ))
	end
	if math.abs(startPosition.X - targetPosition.X) > 2 then
		table.insert(waypoints, Vector3.new(targetPosition.X, laneY, laneZ))
	end
	table.insert(waypoints, Vector3.new(targetPosition.X, laneY, targetPosition.Z))
	return waypoints
end

function H.stealAlong(waypoints, keepGoing)
	for _, waypoint in ipairs(waypoints) do
		if keepGoing and not keepGoing() then
			return false
		end
		if not H.stealMoveTo(waypoint.X, waypoint.Z, keepGoing) then
			return false
		end
	end
	return true
end

function H.getBasePosition()
	if PlotApi.GetRespawnPointCFrame then
		local respawn = PlotApi.GetRespawnPointCFrame()
		if respawn then
			return respawn.Position
		end
	end
	if not PlotApi.GetPlotData then
		return nil
	end
	local plot = PlotApi.GetPlotData()
	if not plot then
		return nil
	end
	if plot.CenterPoint then
		return plot.CenterPoint.Position
	end
	if plot.PetArea then
		return plot.PetArea.Position
	end
	return nil
end

function H.getPetAreaStandPosition()
	if PlotApi.GetPlotData then
		local plot = PlotApi.GetPlotData()
		if plot and plot.PetArea then
			return plot.PetArea.Position + Vector3.new(0, 4, 0)
		end
	end
	return H.getBasePosition()
end

function H.isNearPlot()
	local root = H.getRoot()
	if not root then
		return false
	end
	if PlotApi.IsWorldPositionWithinLocalPlotBounds and PlotApi.IsWorldPositionWithinLocalPlotBounds(root.Position) then
		return true
	end
	local standPosition = H.getPetAreaStandPosition()
	return standPosition ~= nil and (root.Position - standPosition).Magnitude <= 30
end

function H.ensureAtPlot(keepGoing)
	if keepGoing and not keepGoing() then
		return false
	end
	if H.isNearPlot() then
		return true
	end
	local standPosition = H.getPetAreaStandPosition()
	if not standPosition then
		return false
	end
	return H.travelTo(standPosition, true)
end

function H.returnToBase(keepGoing)
	local basePosition = H.getBasePosition()
	local root = H.getRoot()
	if not basePosition or not root then
		return false
	end
	if keepGoing and not keepGoing() then
		return false
	end
	local z = root.Position.Z
	H.rawTeleport(Vector3.new(558, 71, z))
	task.wait(CORRIDOR_STEP_DELAY)
	if keepGoing and not keepGoing() then
		return false
	end
	H.rawTeleport(Vector3.new(546, 71, z))
	task.wait(CORRIDOR_STEP_DELAY)
	if keepGoing and not keepGoing() then
		return false
	end
	H.rawTeleport(Vector3.new(basePosition.X, basePosition.Y + 5, basePosition.Z))
	task.wait(0.12)
	return true
end

-- ===== Eggs / steal =====
function H.getAreaEggs()
	if not EggApi.GetAreaEggSnapshot then
		return {}
	end
	local snapshot = EggApi.GetAreaEggSnapshot()
	if typeof(snapshot) ~= "table" or typeof(snapshot.Records) ~= "table" then
		if EggApi.RequestAreaEggSnapshot then
			pcall(EggApi.RequestAreaEggSnapshot)
		end
		snapshot = EggApi.GetAreaEggSnapshot()
	end
	if typeof(snapshot) ~= "table" or typeof(snapshot.Records) ~= "table" then
		return {}
	end
	local records = {}
	for _, record in pairs(snapshot.Records) do
		if typeof(record) == "table" and typeof(record.Uid) == "string" then
			table.insert(records, record)
		end
	end
	return records
end

function H.findAreaEggRecord(uid)
	for _, record in ipairs(H.getAreaEggs()) do
		if record.Uid == uid then
			return record
		end
	end
	return nil
end

function H.getSlotEggPosition(eggInstance)
	local part = eggInstance:FindFirstChild("Hitbox")
		or eggInstance:FindFirstChild("CustomBoundingBox")
		or eggInstance:FindFirstChildOfClass("BasePart")
	if part then
		return part.Position
	end
	return eggInstance:GetPivot().Position
end

function H.isBigEgg(egg)
	if not H.isOn("StealBigEggs") then
		return false
	end
	local scale = tonumber(egg.AssetScale)
	if not scale then
		return false
	end
	return scale >= (tonumber(H.optionValue("StealBigEggScale", 1.5)) or 1.5)
end

function H.eggScore(egg)
	return RarityWeight[H.resolveRarity(egg.AssetCategory) or "Common"] or 0
end

function H.isStealCandidate(record, bypassFilters)
	if typeof(record) ~= "table" or typeof(record.Uid) ~= "string" then
		return false
	end
	if record.State ~= "Slot" and record.State ~= "Dropped" then
		return false
	end
	if bypassFilters then
		return true
	end
	if H.isBigEgg(record) and H.selectionAllows("StealZones", record.AreaId) then
		return true
	end
	if not H.isOn("AutoStealSelected") then
		return false
	end
	return H.matchesEggFilters(record, "StealZones", "StealRarities", "StealMutations")
end

function H.pickStealTarget()
	local worldEggs = AreaEggSlotsClient and AreaEggSlotsClient:GetChildren() or {}
	if #worldEggs == 0 then
		return nil
	end
	local recordsByUid = {}
	for _, record in ipairs(H.getAreaEggs()) do
		if typeof(record.Uid) == "string" then
			recordsByUid[record.Uid] = record
		end
	end
	local bypassFilters = H.isOn("AutoStealAll") and not H.isOn("AutoStealSelected")
	local root = H.getRoot()
	local priority = H.optionValue("StealPriority", "Rarest")
	local bestEgg, bestScore = nil, -math.huge
	for _, eggInstance in ipairs(worldEggs) do
		local record = recordsByUid[eggInstance.Name]
		local candidate = record and H.isStealCandidate(record, bypassFilters) or (record == nil and bypassFilters)
		if candidate then
			local position = H.getSlotEggPosition(eggInstance)
			local distance = root and position and (root.Position - position).Magnitude or math.huge
			local score
			if priority == "Nearest" then
				score = -distance
			elseif priority == "Furthest" then
				score = distance
			elseif priority == "Biggest Size" then
				score = tonumber(record and record.AssetScale) or 0
			else
				score = (record and H.eggScore(record) or 0) * 100000 - math.min(distance, 99999)
			end
			if score > bestScore then
				bestEgg = eggInstance
				bestScore = score
			end
		end
	end
	return bestEgg
end

function H.stealingEnabled()
	return H.isOn("AutoStealSelected") or H.isOn("AutoStealAll") or H.isOn("StealBigEggs")
end

function H.eggInventoryCount()
	local save = H.getSave()
	local inventory = save and save.EggInventory
	if typeof(inventory) ~= "table" then
		return 0
	end
	return H.countTable(inventory)
end

function H.eggInventoryFull()
	local capacity = EggTypes and tonumber(EggTypes.MAX_INVENTORY) or math.huge
	return H.eggInventoryCount() >= capacity
end

function H.canAutoSteal()
	return H.stealingEnabled() and not IsCarryingEgg and not H.eggInventoryFull()
end

function H.tryCarryEgg(eggInstance)
	if not eggInstance or not EggApi.RequestCarryAreaEgg then
		return false
	end
	local uid = eggInstance.Name
	local slotKey = nil
	if SlotIdentityApi.IsFirstAreaUid and SlotIdentityApi.IsFirstAreaUid(uid) then
		for _, record in ipairs(H.getAreaEggs()) do
			if record.Uid == uid and SlotIdentityApi.BuildSlotKey then
				slotKey = SlotIdentityApi.BuildSlotKey(record.AreaId, record.NestId)
				break
			end
		end
	end
	local ok, carried = pcall(function()
		return EggApi.RequestCarryAreaEgg(uid, slotKey)
	end)
	if ok and carried == true then
		return true
	end
	return IsCarryingEgg
end

function H.stealEgg(slotEgg)
	H.swapStealHumanoid()
	local targetPosition = H.getSlotEggPosition(slotEgg)
	local root = H.getRoot()
	if not root or not targetPosition then
		return false
	end
	local startX = root.Position.X
	local startZ = root.Position.Z
	local startY = H.groundedY(startX, startZ, root.Position.Y)
	if not H.stealAlong(H.buildStealPath(root.Position, targetPosition), H.stealingEnabled) then
		return false
	end
	root = H.getRoot()
	if root then
		local targetY = H.groundedY(targetPosition.X, targetPosition.Z, targetPosition.Y)
		H.anchorStealRoot(root, CFrame.new(targetPosition.X, targetY, targetPosition.Z))
	end
	if not H.stealingEnabled() then
		return false
	end
	local grabStarted = tick()
	while tick() - grabStarted < StealConfig.GrabDelay and H.stealingEnabled() do
		H.tryCarryEgg(slotEgg)
		if IsCarryingEgg then
			task.wait(0.08)
			break
		end
		task.wait(0.04)
	end
	root = H.getRoot()
	if root then
		H.stealAlong(H.buildStealPath(root.Position, Vector3.new(startX, startY, startZ)), H.stealingEnabled)
		root = H.getRoot()
		if root then
			H.anchorStealRoot(root, CFrame.new(startX, startY, startZ))
		end
	end
	task.wait(StealConfig.ReturnPace)
	return IsCarryingEgg
end

function H.runAutoSteal()
	if IsCarryingEgg or H.eggInventoryFull() then
		return false
	end
	local target = H.pickStealTarget()
	if not target then
		return false
	end
	H.setStatus("Stealing", "Warning")
	H.setJob("Auto Steal Egg")
	return H.stealEgg(target)
end

function H.runAutoDropEgg()
	if not IsCarryingEgg then
		return false
	end
	if EggApi.RequestDropHeldAreaEgg then
		return pcall(function()
			EggApi.RequestDropHeldAreaEgg("PlayerRequest")
		end)
	end
	return false
end

function H.runAutoReturn()
	if not IsCarryingEgg then
		return false
	end
	local keepReturning = function()
		return H.isOn("AutoReturn") and IsCarryingEgg
	end
	H.setStatus("Returning", "Info")
	if not H.returnToBase(keepReturning) then
		return false
	end
	local root = H.getRoot()
	if root and PlotApi.IsWorldPositionWithinLocalPlotBounds and PlotApi.IsWorldPositionWithinLocalPlotBounds(root.Position) then
		local deadline = os.clock() + 4
		while os.clock() < deadline and IsCarryingEgg and H.isOn("AutoReturn") do
			task.wait(0.15)
		end
	end
	return true
end

if EggApi.AreaEggCarryStateChanged and typeof(EggApi.AreaEggCarryStateChanged.Connect) == "function" then
	H.track(EggApi.AreaEggCarryStateChanged:Connect(function(state)
		local carryingNow = typeof(state) == "table" and state.IsCarrying == true
		local startedCarrying = carryingNow and not IsCarryingEgg
		if startedCarrying then
			SessionStolenEggs += 1
			H.setStolen()
			if CarryStartedCallback then
				CarryStartedCallback(state)
			end
		end
		IsCarryingEgg = carryingNow
	end))
end

-- ===== Place / hatch =====
function H.getUnplacedEggUids()
	local save = H.getSave()
	local eggInventory = save and save.EggInventory
	local result = {}
	if typeof(eggInventory) ~= "table" then
		return result
	end
	local bypass = H.isOn("AutoPlaceAll") and not H.isOn("AutoPlaceSelected")
	for uid, egg in pairs(eggInventory) do
		if typeof(uid) == "string" and typeof(egg) == "table" and egg.Placement == nil
			and (bypass or H.matchesEggFilters(egg, nil, "LifecycleRarities", "LifecycleMutations")) then
			table.insert(result, uid)
		end
	end
	return result
end

function H.placingEnabled()
	return H.isOn("AutoPlaceSelected") or H.isOn("AutoPlaceAll")
end

function H.isPlotFull()
	return os.clock() < PlotFullUntil
end

function H.markPlotFull()
	if not H.isPlotFull() then
		PlotFullUntil = os.clock() + 30
		H.notify("Farm", "No free egg spots left", "Warning", 4)
	end
end

function H.getPlacementLocalCFrames()
	if not PlotApi.GetPlotData then
		return {}
	end
	local plot = PlotApi.GetPlotData()
	if not plot or not plot.PetArea or not plot.CenterPoint then
		return {}
	end
	local petArea = plot.PetArea
	local centerPoint = plot.CenterPoint
	local size = petArea.Size
	local placements = {}
	for x = -size.X * 0.5 + 5, size.X * 0.5 - 5, 7 do
		for z = -size.Z * 0.5 + 5, size.Z * 0.5 - 5, 7 do
			local worldPoint = petArea.CFrame:PointToWorldSpace(Vector3.new(x, 1, z))
			table.insert(placements, centerPoint.CFrame:ToObjectSpace(CFrame.new(worldPoint)))
		end
	end
	return placements
end

function H.canAutoPlace()
	return H.placingEnabled() and not IsCarryingEgg and not H.isPlotFull() and #H.getUnplacedEggUids() > 0
end

function H.runAutoPlaceEggs(forceRun)
	if IsCarryingEgg or not EggApi.RequestPlaceEgg then
		return
	end
	local function canContinue()
		return (forceRun == true or H.placingEnabled()) and not IsCarryingEgg
	end
	local unplaced = H.getUnplacedEggUids()
	if #unplaced == 0 or not H.ensureAtPlot(canContinue) then
		return
	end
	local placements = H.getPlacementLocalCFrames()
	if #placements == 0 then
		return
	end
	H.setJob("Auto Place Egg")
	local placedAny = false
	for _, uid in ipairs(unplaced) do
		if not running or not canContinue() then
			return placedAny
		end
		if not H.isNearPlot() and not H.ensureAtPlot(canContinue) then
			return placedAny
		end
		if EggApi.RequestEquipTool then
			pcall(EggApi.RequestEquipTool, uid)
		end
		task.wait(0.15)
		local placedThisEgg = false
		for offset = 0, #placements - 1 do
			local placementIndex = (NextPlacementIndex + offset - 1) % #placements + 1
			local success = false
			pcall(function()
				success = EggApi.RequestPlaceEgg(uid, placements[placementIndex]) == true
			end)
			if success then
				NextPlacementIndex = placementIndex + 1
				placedThisEgg = true
				placedAny = true
				task.wait(0.25)
				break
			end
		end
		if not placedThisEgg then
			H.markPlotFull()
			return placedAny
		end
		PlotFullUntil = 0
	end
	return placedAny
end

function H.canAutoHatch()
	return H.isOn("AutoOpenReadyEggs") and not IsCarryingEgg
end

function H.runAutoOpenReadyEggs()
	local save = H.getSave()
	local eggInventory = save and save.EggInventory
	if typeof(eggInventory) ~= "table" then
		return
	end
	H.setJob("Auto Hatch")
	local hatchedAny = false
	for uid, egg in pairs(eggInventory) do
		if not running or not H.isOn("AutoOpenReadyEggs") then
			return hatchedAny
		end
		if typeof(uid) == "string" and typeof(egg) == "table" and egg.Placement ~= nil
			and H.matchesEggFilters(egg, nil, "LifecycleRarities", "LifecycleMutations") then
			local ready = false
			if EggApi.IsLocalEggReady then
				pcall(function()
					ready = EggApi.IsLocalEggReady(uid) == true
				end)
			end
			if ready and EggApi.RequestHatchEgg then
				local hatchStarted = false
				pcall(function()
					hatchStarted = EggApi.RequestHatchEgg(uid) == true
				end)
				if hatchStarted then
					hatchedAny = true
					if EggApi.RequestCompleteHatchEgg then
						pcall(EggApi.RequestCompleteHatchEgg, uid)
					end
					task.wait(0.35)
				end
			end
		end
	end
	return hatchedAny
end

-- ===== Pets / fuse / sell =====
function H.getPetItemData(serializedPet)
	if not AssetItemsApi.Deserialize then
		return nil
	end
	local ok, itemData = pcall(AssetItemsApi.Deserialize, serializedPet)
	if not ok or typeof(itemData) ~= "table" then
		return nil
	end
	return itemData
end

function H.findToolByUid(uid)
	local containers = { LocalPlayer.Character, LocalPlayer:FindFirstChildOfClass("Backpack") }
	for _, container in ipairs(containers) do
		if container then
			for _, child in ipairs(container:GetChildren()) do
				if child:IsA("Tool") and child:GetAttribute("UID") == uid then
					return child
				end
			end
		end
	end
	return nil
end

function H.holdUid(uid)
	local character = LocalPlayer.Character
	local humanoid = H.getHumanoid()
	if not character or not humanoid then
		return false
	end
	local tool = H.findToolByUid(uid)
	if not tool then
		return false
	end
	if tool.Parent == character then
		return true
	end
	pcall(function()
		humanoid:EquipTool(tool)
	end)
	local deadline = os.clock() + 1
	while os.clock() < deadline do
		if tool.Parent == LocalPlayer.Character then
			return true
		end
		task.wait(0.05)
	end
	return false
end

function H.sellUid(uid)
	if not H.holdUid(uid) then
		return false
	end
	H.netCall(Remotes.AssetInventory.SELL_ASSET, uid)
	local deadline = os.clock() + 2
	while os.clock() < deadline do
		local save = H.getSave()
		if save then
			local inventory = save.Inventory or {}
			local eggInventory = save.EggInventory or {}
			if inventory[uid] == nil and eggInventory[uid] == nil then
				return true
			end
		end
		task.wait(0.1)
	end
	return false
end

function H.getSellablePets()
	local save = H.getSave()
	local inventory = save and save.Inventory
	local result = {}
	if typeof(inventory) ~= "table" then
		return result
	end
	local equipped = save.EquippedAssets or {}
	local maxScale = tonumber(H.optionValue("SellMaxScale", 10)) or 10
	local keepMutated = H.isOn("SellKeepMutated")
	local keepEquipped = H.isOn("SellKeepEquipped")
	local selectedMutations = H.multiSelected("SellMutations")
	local filterMutations = H.multiHasAny("SellMutations")
	local selectedRarities = H.multiSelected("SellRarities")
	local filterRarities = H.multiHasAny("SellRarities")
	for uid, asset in pairs(inventory) do
		if typeof(uid) == "string" and typeof(asset) == "table" then
			local itemData = H.getPetItemData(asset)
			local isEquipped = table.find(equipped, uid) ~= nil
			local protected = not itemData or itemData.IsFavorite == true or itemData.InFuse == true or (keepEquipped and isEquipped)
			if not protected then
				local mutations = H.recordMutations(asset)
				local mutationAllowed = not (keepMutated and #mutations > 0)
				if mutationAllowed and filterMutations then
					mutationAllowed = false
					for _, mutation in ipairs(mutations) do
						if selectedMutations[mutation] then
							mutationAllowed = true
							break
						end
					end
				end
				local scale = tonumber(asset.Scale) or 0
				local rarity = H.resolveRarity(asset.Category)
				local rarityAllowed = not filterRarities or (typeof(rarity) == "string" and selectedRarities[rarity] == true)
				if mutationAllowed and scale <= maxScale and rarityAllowed then
					table.insert(result, uid)
				end
			end
		end
	end
	return result
end

function H.runAutoSellPets()
	for _, uid in ipairs(H.getSellablePets()) do
		if not running or not H.isOn("AutoSellPets") or IsCarryingEgg then
			return
		end
		H.sellUid(uid)
		task.wait(0.15)
	end
end

function H.getSellableEggUids()
	local save = H.getSave()
	local eggInventory = save and save.EggInventory
	local result = {}
	if typeof(eggInventory) ~= "table" then
		return result
	end
	local useRarityFilter = H.multiHasAny("SellEggRarities")
	local selectedRarities = H.multiSelected("SellEggRarities")
	for uid, egg in pairs(eggInventory) do
		if typeof(uid) == "string" and typeof(egg) == "table" and egg.Placement == nil then
			local rarity = H.resolveRarity(egg.AssetCategory)
			if not useRarityFilter or (typeof(rarity) == "string" and selectedRarities[rarity] == true) then
				table.insert(result, uid)
			end
		end
	end
	return result
end

function H.runAutoSellEggs()
	for _, uid in ipairs(H.getSellableEggUids()) do
		if not running or not H.isOn("AutoSellEggs") or IsCarryingEgg then
			return
		end
		if EggApi.RequestEquipTool then
			pcall(EggApi.RequestEquipTool, uid)
		end
		task.wait(0.15)
		H.sellUid(uid)
		task.wait(0.15)
	end
end

function H.fuseGroups(save)
	local inventory = save and save.Inventory
	local groups = {}
	if typeof(inventory) ~= "table" then
		return groups
	end
	local equipped = save.EquippedAssets or {}
	local keepEquipped = H.isOn("FuseKeepEquipped")
	local keepMutated = H.isOn("FuseKeepMutated")
	local maxScale = tonumber(H.optionValue("FuseMaxScale", 10)) or 10
	local filterMutations = H.multiHasAny("FuseMutations")
	local selectedMutations = H.multiSelected("FuseMutations")
	for uid, pet in pairs(inventory) do
		if typeof(uid) == "string" and typeof(pet) == "table" then
			local category = pet.Category
			local selectable = false
			if typeof(category) == "string" and FuseApi.CanSelectPet then
				pcall(function()
					selectable = FuseApi.CanSelectPet(uid, pet, category, false) == true
				end)
			end
			if selectable and not (keepEquipped and table.find(equipped, uid) ~= nil) then
				local mutations = H.recordMutations(pet)
				local mutationAllowed = not (keepMutated and #mutations > 0)
				if mutationAllowed and filterMutations then
					mutationAllowed = false
					for _, mutation in ipairs(mutations) do
						if selectedMutations[mutation] then
							mutationAllowed = true
							break
						end
					end
				end
				local rarity = H.resolveRarity(category)
				local scale = tonumber(pet.Scale) or 0
				local rarityAllowed = rarity == nil or H.selectionAllows("FuseRarities", rarity)
				if mutationAllowed and scale <= maxScale and rarityAllowed then
					groups[category] = groups[category] or {}
					table.insert(groups[category], { uid = uid, scale = scale })
				end
			end
		end
	end
	return groups
end

function H.pickFuseGroup(save)
	local groups = H.fuseGroups(save)
	local keepPerCategory = math.floor(tonumber(H.optionValue("FuseKeepPerCategory", 0)) or 0)
	local targetMode = H.optionValue("FuseTarget", "Highest Rarity")
	local selectedCategory, selectedScore = nil, -math.huge
	for category, pets in pairs(groups) do
		table.sort(pets, function(a, b)
			return a.scale < b.scale
		end)
		if #pets - keepPerCategory >= 3 then
			local rarityScore = RarityWeight[H.resolveRarity(category) or "Common"] or 0
			local score = rarityScore
			if targetMode == "Most Duplicates" then
				score = #pets
			elseif targetMode == "Lowest Rarity" then
				score = -rarityScore
			end
			if score > selectedScore then
				selectedCategory = category
				selectedScore = score
			end
		end
	end
	if not selectedCategory then
		return nil
	end
	local pets = groups[selectedCategory]
	return { pets[1].uid, pets[2].uid, pets[3].uid }
end

function H.fusePrice(save, petUids)
	local inventory = save and save.Inventory
	if typeof(inventory) ~= "table" or not FuseApi.CalculateFusePrice then
		return nil
	end
	local itemData = {}
	for index, uid in ipairs(petUids) do
		local pet = inventory[uid]
		local decoded = pet and H.getPetItemData(pet)
		if not decoded then
			return nil
		end
		itemData[index] = decoded
	end
	local ok, price = pcall(FuseApi.CalculateFusePrice, itemData)
	return ok and tonumber(price) or nil
end

function H.getFuseMachinePosition()
	local objects = Workspace:FindFirstChild("__OBJECTS")
	local machines = objects and objects:FindFirstChild("Machines")
	local fuseMachine = machines and machines:FindFirstChild("FuseMachine")
	if not fuseMachine then
		return nil
	end
	local ok, pivot = pcall(function()
		return fuseMachine:GetPivot()
	end)
	if not ok or not pivot then
		return nil
	end
	return pivot.Position + Vector3.new(0, 4, 0)
end

function H.runAutoFusePets(forceRun)
	local save = H.getSave()
	if not save then
		return
	end
	local function canContinue()
		return forceRun == true or H.isOn("AutoFusePets")
	end
	if save.FusionLocked == true then
		if H.isOn("FuseAutoReveal") or forceRun == true then
			H.netInvoke(Remotes.FuseMachine.COMPLETE_REVEAL)
		end
		return
	end
	local petUids = H.pickFuseGroup(save)
	if not petUids then
		return
	end
	local price = H.fusePrice(save, petUids)
	if price and (tonumber(save.Money) or 0) < price then
		return
	end
	local fusePosition = H.getFuseMachinePosition()
	if fusePosition and not H.travelTo(fusePosition, true) then
		return
	end
	if save.FusionInfoAcknowledged ~= true then
		H.netInvoke(Remotes.FuseMachine.ACKNOWLEDGE_INFO)
	end
	for _, uid in ipairs(petUids) do
		if not running or not canContinue() then
			return
		end
		H.netInvoke(Remotes.FuseMachine.INSERT_MOB, uid)
		task.wait(0.2)
	end
	H.netInvoke(Remotes.FuseMachine.START_FUSE)
	return true
end

function H.runAutoEquipBest()
	local now = Workspace:GetServerTimeNow()
	if now - LastEquipBestAt < 5 then
		return
	end
	LastEquipBestAt = now
	H.netCall(Remotes.Backpack.EQUIP_BEST)
end

function H.runAutoEquipBestTrail()
	local save = H.getSave()
	local ownedTrails = save and save.TrailInventory
	if typeof(ownedTrails) ~= "table" then
		return false
	end
	local bestTrailId, bestPrice = nil, -1
	for _, trailName in ipairs(TrailNames) do
		local trailId = TrailIdByName[trailName]
		if trailId and ownedTrails[trailId] then
			local price = TrailPriceByName[trailName] or 0
			if price > bestPrice then
				bestPrice = price
				bestTrailId = trailId
			end
		end
	end
	local wornSnapshot = H.netInvoke(Remotes.Trails.WORN_SNAPSHOT)
	local wornTrailId = typeof(wornSnapshot) == "table" and wornSnapshot[tostring(LocalPlayer.UserId)] or nil
	if not bestTrailId or wornTrailId == bestTrailId then
		return false
	end
	H.netInvoke(Remotes.Trails.REQUEST_SELECT, bestTrailId)
	return true
end

function H.gearBaseName(name)
	return tostring(name):gsub("%s*%[X%d+%]%s*$", "")
end

function H.runAutoEquipBestGear()
	local character = LocalPlayer.Character
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	local humanoid = H.getHumanoid()
	if not character or not backpack or not humanoid then
		return
	end
	local best, bestCost = nil, -1
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local cost = GearCostByName[H.gearBaseName(tool.Name)]
			if cost and cost > bestCost then
				bestCost = cost
				best = tool
			end
		end
	end
	for _, tool in ipairs(character:GetChildren()) do
		if tool:IsA("Tool") then
			local cost = GearCostByName[H.gearBaseName(tool.Name)]
			if cost and cost >= bestCost then
				return
			end
		end
	end
	if best then
		pcall(function()
			humanoid:EquipTool(best)
		end)
	end
end

function H.runAutoBuyTrail()
	local save = H.getSave()
	if not save or not H.multiHasAny("TrailWanted") then
		return false
	end
	local wanted = H.multiSelected("TrailWanted")
	local owned = save.TrailInventory or {}
	local boughtAny = false
	for _, trailName in ipairs(TrailNames) do
		if wanted[trailName] then
			local trailId = TrailIdByName[trailName]
			if trailId and not owned[trailId] then
				local price = TrailPriceByName[trailName] or 0
				if save.Money >= price then
					H.netCall(Remotes.Trails.REQUEST_PURCHASE, trailId)
					boughtAny = true
					task.wait(0.35)
					save = H.getSave() or save
					owned = save.TrailInventory or owned
				end
			end
		end
	end
	return boughtAny
end

function H.runAutoUpgrades()
	local selected = H.multiSelected("UpgradeTypes")
	if not H.multiHasAny("UpgradeTypes") then
		selected = { Base = true, Treadmill = true }
	end
	local save = H.getSave()
	if not save then
		return false
	end
	local upgraded = false
	if selected.Base and BaseUpgradeModule and typeof(BaseUpgradeModule.IsNextTierAffordable) == "function" then
		if BaseUpgradeModule.IsNextTierAffordable(save) then
			H.netCall(Remotes.Plots.REQUEST_BASE_UPGRADE)
			upgraded = true
			task.wait(0.35)
		end
	end
	if selected.Treadmill and TreadmillsData and typeof(TreadmillsData.GetByUpgradeLevel) == "function" then
		local currentLevel = tonumber(save.TreadmillUpgradeLevel) or 0
		local nextUpgrade = TreadmillsData.GetByUpgradeLevel(currentLevel + 1)
		if nextUpgrade then
			local price = tonumber(nextUpgrade.Price) or math.huge
			if save.Money >= price then
				H.netCall(Remotes.Treadmills.REQUEST_UPGRADE, nextUpgrade._id)
				upgraded = true
				task.wait(0.35)
			end
		end
	end
	return upgraded
end

function H.runAutoClaimIndex()
	H.netCall(Remotes.Index.REQUEST_CLAIM_ALL)
end

function H.runClaimOfflineEarnings()
	local summary = H.netInvoke(Remotes.OfflineAssets.GET_SUMMARY)
	if typeof(summary) ~= "table" then
		return false
	end
	if (tonumber(summary.ClaimableAmount) or 0) <= 0 then
		return false
	end
	H.netCall(Remotes.OfflineAssets.REQUEST_REDEEM)
	return true
end

function H.runAutoClaimGroupReward()
	local save = H.getSave()
	if save and save.ClaimedGroupReward == true then
		return false
	end
	local isInGroup = false
	pcall(function()
		isInGroup = Constants and Constants.GROUP_ID and LocalPlayer:IsInGroupAsync(Constants.GROUP_ID) == true
	end)
	H.netInvoke(Remotes.GroupReward.CLAIM_REWARD, isInGroup)
	return true
end

function H.deleteOwnPetRenders()
	local renderedAssets = Workspace:FindFirstChild("ClientRenderedAssets")
	if not renderedAssets then
		return
	end
	for _, renderedAsset in ipairs(renderedAssets:GetChildren()) do
		if renderedAsset:GetAttribute("OwnerUserId") == LocalPlayer.UserId then
			pcall(function()
				renderedAsset:Destroy()
			end)
		end
	end
end

-- ===== Treadmill =====
function H.getTreadmillStand()
	if not PlotApi.GetPlotData then
		return nil
	end
	local plot = PlotApi.GetPlotData()
	local plotFolder = plot and plot.PlotFolder
	local treadmill = plotFolder and plotFolder:FindFirstChild("TreadmillBottom")
	if not treadmill or not treadmill:IsA("BasePart") then
		return nil
	end
	return treadmill.Position + Vector3.new(0, 4, 0)
end

function H.isDoubleSpeedVisible()
	local ok, visible = pcall(function()
		local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
		local elements = playerGui and playerGui:FindFirstChild("Elements")
		local left = elements and elements:FindFirstChild("Left")
		local tools = left and left:FindFirstChild("Tools")
		local doubleSpeed = tools and tools:FindFirstChild("DoubleYourSpeed")
		return doubleSpeed ~= nil and doubleSpeed.Visible == true
	end)
	return ok and visible == true
end

function H.dismountTreadmill()
	pcall(function()
		local input = game:GetService("VirtualInputManager")
		input:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
		task.wait(0.05)
		input:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
	end)
	local humanoid = H.getHumanoid()
	if humanoid then
		humanoid.Jump = true
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

function H.stopTreadmillTraining()
	TreadmillTrainingActive = false
	pcall(function()
		H.netInvoke(Remotes.Treadmills.REQUEST_UNEQUIP)
	end)
	if H.isDoubleSpeedVisible() then
		H.dismountTreadmill()
		task.wait(0.1)
		if H.isDoubleSpeedVisible() then
			H.dismountTreadmill()
		end
	end
end

function H.canAutoTreadmill()
	return H.isOn("AutoTreadmill") and not IsCarryingEgg
end

function H.runAutoTreadmillTraining()
	local treadmillPosition = H.getTreadmillStand()
	if not treadmillPosition then
		return
	end
	local root = H.getRoot()
	if not root then
		return
	end
	if (root.Position - treadmillPosition).Magnitude > 12 then
		if not H.travelTo(treadmillPosition, true) then
			return
		end
	end
	H.netInvoke(Remotes.Treadmills.REQUEST_EQUIP_STATIC)
	TreadmillTrainingActive = true
	return true
end

-- ===== Waypoints =====
local WaypointNames = { "Base", "Pet Area", "Treadmill", "Fuse Machine", "Lobby Entry" }
for _, zoneName in ipairs(AREA_ORDER) do
	table.insert(WaypointNames, zoneName)
end

function H.resolveWaypoint(name)
	if typeof(name) ~= "string" then
		return nil
	end
	if name == "Base" then
		return H.getBasePosition()
	elseif name == "Pet Area" then
		return H.getPetAreaStandPosition()
	elseif name == "Treadmill" then
		return H.getTreadmillStand()
	elseif name == "Fuse Machine" then
		return H.getFuseMachinePosition()
	elseif name == "Lobby Entry" then
		return H.getEntryPosition()
	end
	return H.getZoneLaneCenter(name)
end

-- ===== ESP =====
function H.espDistanceLimit()
	return tonumber(H.optionValue("EspDistance", 2000)) or 2000
end

function H.withinEspRange(position)
	local root = H.getRoot()
	return root ~= nil and (root.Position - position).Magnitude <= H.espDistanceLimit()
end

function H.espColorFor(rarity)
	local weight = RarityWeight[rarity or ""] or 0
	if weight >= 9 then
		return Color3.fromRGB(255, 120, 255)
	elseif weight >= 7 then
		return Color3.fromRGB(255, 90, 90)
	elseif weight >= 5 then
		return Color3.fromRGB(255, 190, 80)
	elseif weight >= 3 then
		return Color3.fromRGB(110, 195, 255)
	end
	return Color3.fromRGB(190, 200, 215)
end

function H.ensureEspEntry(id, color)
	local existing = EspEntries[id]
	if existing then
		return existing
	end
	local anchor = Instance.new("Part")
	anchor.Name = "EspAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = EspFolder
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "EspLabel"
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(220, 34)
	billboard.StudsOffset = Vector3.new(0, 2.5, 0)
	billboard.Adornee = anchor
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextStrokeTransparency = 0.4
	label.TextColor3 = color
	label.Parent = billboard
	local entry = { anchor = anchor, billboard = billboard, label = label, highlight = nil }
	EspEntries[id] = entry
	return entry
end

function H.drawEspAt(id, position, text, color, adornee)
	local entry = H.ensureEspEntry(id, color)
	entry.anchor.CFrame = CFrame.new(position)
	entry.label.Text = text
	entry.label.TextColor3 = color
	if adornee and adornee.Parent then
		if not entry.highlight then
			local highlight = Instance.new("Highlight")
			highlight.FillTransparency = 0.6
			highlight.OutlineTransparency = 0
			highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			highlight.Parent = EspFolder
			entry.highlight = highlight
		end
		entry.highlight.Adornee = adornee
		entry.highlight.FillColor = color
		entry.highlight.OutlineColor = color
	elseif entry.highlight then
		entry.highlight:Destroy()
		entry.highlight = nil
	end
	EspSeenThisPass[id] = true
end

function H.releaseEsp(id)
	local entry = EspEntries[id]
	if not entry then
		return
	end
	if entry.highlight then
		entry.highlight:Destroy()
	end
	if entry.billboard then
		entry.billboard:Destroy()
	end
	if entry.anchor then
		entry.anchor:Destroy()
	end
	EspEntries[id] = nil
end

function H.clearAllEsp()
	for id in pairs(EspEntries) do
		H.releaseEsp(id)
	end
end

function H.collectEggEsp()
	local showWorldEggs = H.isOn("EspWorldEggs")
	local showCarriedEggs = H.isOn("EspCarriedEggs")
	if not showWorldEggs and not showCarriedEggs then
		return
	end
	for _, egg in ipairs(H.getAreaEggs()) do
		local cframe = egg.BottomCFrame or egg.BoundsCFrame
		if cframe then
			local state = egg.State
			local shouldShow = (state == "Slot" and showWorldEggs) or ((state == "Dropped" or state == "Carried") and showCarriedEggs)
			if shouldShow and H.withinEspRange(cframe.Position) then
				local rarity = H.resolveRarity(egg.AssetCategory)
				local label = string.format("%s [%s]", H.assetName(egg.AssetCategory), tostring(rarity or "?"))
				if state == "Dropped" or state == "Carried" then
					label = string.format("%s\n%s", label, tostring(state))
				end
				H.drawEspAt("egg_" .. egg.Uid, cframe.Position, label, H.espColorFor(rarity), nil)
			end
		end
	end
end

function H.collectGuardEsp()
	if not H.isOn("EspGuards") or not GuardAreasFolder then
		return
	end
	for _, guardArea in ipairs(GuardAreasFolder:GetChildren()) do
		local guard = guardArea:FindFirstChild("Guard")
		local ok, pivot = pcall(function()
			return guard and guard:GetPivot() or nil
		end)
		if ok and pivot and H.withinEspRange(pivot.Position) then
			H.drawEspAt(
				"guard_" .. guardArea.Name,
				pivot.Position,
				string.format("Guard %s\n%s", guardArea.Name, tostring(guard:GetAttribute("GuardState") or "Idle")),
				Color3.fromRGB(255, 140, 90),
				guard
			)
		end
	end
end

function H.collectPetEsp()
	if not H.isOn("EspPets") then
		return
	end
	local renderedAssets = Workspace:FindFirstChild("ClientRenderedAssets")
	if not renderedAssets then
		return
	end
	local save = H.getSave()
	local inventory = save and save.Inventory or {}
	local runtimeByUid = {}
	pcall(function()
		if AssetRosterApi.GetRuntimeSnapshot then
			local snapshot = AssetRosterApi.GetRuntimeSnapshot() or {}
			for _, group in pairs(snapshot) do
				if typeof(group) == "table" and typeof(group.Records) == "table" then
					for uid, record in pairs(group.Records) do
						runtimeByUid[uid] = record
					end
				end
			end
		end
	end)
	for _, renderedPet in ipairs(renderedAssets:GetChildren()) do
		local uid = renderedPet:GetAttribute("UID")
		local ok, pivot = pcall(function()
			return renderedPet:GetPivot()
		end)
		if typeof(uid) == "string" and ok and pivot and H.withinEspRange(pivot.Position) then
			local category = nil
			local moneyPerSecond = nil
			local savedPet = inventory[uid]
			if typeof(savedPet) == "table" then
				category = savedPet.Category
			end
			local runtimeRecord = runtimeByUid[uid]
			if typeof(runtimeRecord) == "table" then
				if not category and runtimeRecord.ItemData then
					category = runtimeRecord.ItemData.Category
				end
				moneyPerSecond = tonumber(runtimeRecord.MoneyPerSecond)
			end
			local rarity = H.resolveRarity(category)
			local label = string.format("%s [%s]", H.assetName(category), tostring(rarity or "?"))
			if moneyPerSecond then
				label = string.format("%s\n%s/s", label, H.formatNumber(moneyPerSecond))
			end
			H.drawEspAt("pet_" .. renderedPet.Name, pivot.Position, label, H.espColorFor(rarity), renderedPet)
		end
	end
end

function H.collectPlayerEsp()
	if not H.isOn("EspPlayers") then
		return
	end
	local localRoot = H.getRoot()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and H.withinEspRange(root.Position) then
				local distance = localRoot and (localRoot.Position - root.Position).Magnitude or 0
				H.drawEspAt(
					"player_" .. player.Name,
					root.Position,
					string.format("%s\n%d studs", player.DisplayName, math.floor(distance)),
					Color3.fromRGB(120, 190, 255),
					character
				)
			end
		end
	end
end

function H.collectMachineEsp()
	if not H.isOn("EspMachines") then
		return
	end
	local objects = Workspace:FindFirstChild("__OBJECTS")
	local machines = objects and objects:FindFirstChild("Machines")
	if not machines then
		return
	end
	for _, machine in ipairs(machines:GetChildren()) do
		local ok, pivot = pcall(function()
			return machine:GetPivot()
		end)
		if ok and pivot and H.withinEspRange(pivot.Position) then
			H.drawEspAt("machine_" .. machine.Name, pivot.Position, machine.Name, Color3.fromRGB(230, 200, 120), machine)
		end
	end
end

function H.collectPlotEsp()
	if not H.isOn("EspPlots") then
		return
	end
	local plots = Workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	for _, plot in ipairs(plots:GetChildren()) do
		local anchor = plot:FindFirstChild("PlotSign") or plot:FindFirstChild("CenterPoint")
		if anchor and anchor:IsA("BasePart") and H.withinEspRange(anchor.Position) then
			local ownerUserId = nil
			pcall(function()
				if PlotApi.GetSlotOwner then
					ownerUserId = PlotApi.GetSlotOwner(tonumber(plot.Name))
				end
			end)
			local ownerText = "Empty"
			local numericUserId = tonumber(ownerUserId)
			if numericUserId then
				local owner = Players:GetPlayerByUserId(numericUserId)
				if owner then
					ownerText = owner.DisplayName
					if owner == LocalPlayer then
						ownerText ..= " (You)"
					end
				else
					ownerText = "User " .. tostring(numericUserId)
				end
			end
			H.drawEspAt("plot_" .. plot.Name, anchor.Position, string.format("Plot %s\n%s", plot.Name, ownerText), Color3.fromRGB(200, 170, 255), nil)
		end
	end
end

function H.runEsp()
	table.clear(EspSeenThisPass)
	H.collectEggEsp()
	H.collectGuardEsp()
	H.collectPetEsp()
	H.collectPlayerEsp()
	H.collectMachineEsp()
	H.collectPlotEsp()
	for id in pairs(EspEntries) do
		if not EspSeenThisPass[id] then
			H.releaseEsp(id)
		end
	end
end

-- ===== Server hop =====
function H.rememberVisited(serverId)
	if typeof(serverId) ~= "string" or serverId == "" then
		return
	end
	if H.countTable(VisitedServerIds) >= 300 then
		table.clear(VisitedServerIds)
	end
	VisitedServerIds[serverId] = true
end

H.rememberVisited(tostring(game.JobId))

H.track(TeleportService.TeleportInitFailed:Connect(function(player, result, errorMessage)
	if player == LocalPlayer then
		LastTeleportFailure = tostring(errorMessage or result)
	end
end))

function H.fetchServerPage(cursor)
	local url = string.format(
		"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&excludeFullGames=true&limit=100",
		game.PlaceId
	)
	if cursor then
		url = url .. "&cursor=" .. cursor
	end
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if not ok or typeof(body) ~= "string" then
		return nil
	end
	local decodedOk, page = pcall(function()
		return HttpService:JSONDecode(body)
	end)
	if not decodedOk or typeof(page) ~= "table" or typeof(page.data) ~= "table" then
		return nil
	end
	return page
end

function H.pickHopTargets()
	local cursor = nil
	local candidates = {}
	for _ = 1, 4 do
		local page = H.fetchServerPage(cursor)
		if not page then
			break
		end
		for _, server in ipairs(page.data) do
			if typeof(server) == "table" and typeof(server.id) == "string"
				and server.id ~= game.JobId and not VisitedServerIds[server.id] then
				local playing = tonumber(server.playing) or 0
				local maxPlayers = tonumber(server.maxPlayers) or 0
				if maxPlayers > 0 and playing < maxPlayers then
					table.insert(candidates, { id = server.id, playing = playing })
				end
			end
		end
		cursor = typeof(page.nextPageCursor) == "string" and page.nextPageCursor or nil
		if not cursor or #candidates >= 40 then
			break
		end
		task.wait(0.25)
	end
	table.sort(candidates, function(a, b)
		return a.playing < b.playing
	end)
	return candidates
end

function H.tryTeleportTo(serverId)
	LastTeleportFailure = nil
	local started = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, serverId, LocalPlayer)
	end)
	if not started then
		return false
	end
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		if LastTeleportFailure then
			return false
		end
		if not running then
			return true
		end
		task.wait(0.25)
	end
	return true
end


function H.serverHop(reason)
	if ServerHopInProgress or os.clock() < ServerHopRetryAfter then
		return false
	end
	ServerHopInProgress = true
	local targets = H.pickHopTargets()
	if typeof(targets) ~= "table" or #targets == 0 then
		ServerHopRetryAfter = os.clock() + 30
		ServerHopInProgress = false
		H.notify("Hop", "No candidates, retrying in 30s", "Warning", 4)
		return false
	end
	H.notify("Hop", tostring(reason or "requested"), "Info", 3)
	if H.isOn("WebhookEnabled") and H.sendSummary then
		H.sendSummary()
		task.wait(0.6)
	end
	for attempt = 1, 3 do
		if attempt > 1 then
			targets = H.pickHopTargets()
			if typeof(targets) ~= "table" or #targets == 0 then
				ServerHopRetryAfter = os.clock() + 10
				ServerHopInProgress = false
				H.notify("Hop", "Failed, retrying in 10s", "Warning", 4)
				return false
			end
		end
		for index = 1, math.min(#targets, 10) do
			if not running then
				ServerHopInProgress = false
				return false
			end
			local target = targets[index]
			H.rememberVisited(target.id)
			if H.tryTeleportTo(target.id) then
				ServerHopInProgress = false
				return true
			end
			task.wait(0.5)
		end
	end
	ServerHopRetryAfter = os.clock() + 10
	ServerHopInProgress = false
	H.notify("Hop", "Failed, retrying in 10s", "Warning", 4)
	return false
end

function H.runServerHop()
	if IsCarryingEgg or ServerHopInProgress then
		return
	end
	local mode = H.optionValue("HopMode", ServerHopModes[1])
	local threshold = tonumber(H.optionValue("HopValue", 15)) or 15
	local now = os.clock()
	if mode == "Timed Interval" then
		if now - HopIntervalStartedAt >= threshold * 60 then
			H.serverHop("Interval reached")
		end
		return
	end
	if mode == "After Steal Count" then
		if SessionStolenEggs >= threshold then
			H.serverHop(string.format("Stole %d eggs", SessionStolenEggs))
		end
		return
	end
	if H.pickStealTarget() ~= nil then
		NoMatchingEggsSince = 0
		return
	end
	if NoMatchingEggsSince == 0 then
		NoMatchingEggsSince = now
	elseif now - NoMatchingEggsSince >= threshold then
		NoMatchingEggsSince = 0
		H.serverHop("No matching eggs in this server")
	end
end

function H.rejoinServer()
	local ok = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
	if not ok then
		pcall(function()
			TeleportService:Teleport(game.PlaceId, LocalPlayer)
		end)
	end
end

-- ===== Webhooks =====
function H.webhookPing()
	local numericId = tostring(H.optionValue("WebhookPingId", "") or ""):gsub("%D", "")
	if numericId == "" then
		return nil
	end
	return string.format("<@%s>", numericId)
end

function H.httpPost(payload)
	local requestFn = (syn and syn.request) or (http and http.request) or http_request or request
	if typeof(requestFn) ~= "function" then
		return false
	end
	local webhookUrl = tostring(H.optionValue("WebhookUrl", "") or "")
	if webhookUrl == "" then
		return false
	end
	local encodedBody
	local encoded = pcall(function()
		encodedBody = HttpService:JSONEncode(payload)
	end)
	if not encoded then
		return false
	end
	return pcall(requestFn, {
		Url = webhookUrl,
		Method = "POST",
		Headers = { ["Content-Type"] = "application/json" },
		Body = encodedBody,
	})
end

function H.sendWebhookEmbed(embed, includePing)
	if not H.isOn("WebhookEnabled") then
		return false
	end
	local payload = { username = "Steal An Egg Hub", embeds = { embed } }
	if includePing then
		payload.content = H.webhookPing()
	end
	return H.httpPost(payload)
end

function H.embedField(name, value, inline)
	return { name = name, value = value, inline = inline ~= false }
end

CarryStartedCallback = function(eventData)
	if typeof(eventData) ~= "table" then
		return
	end
	local record = typeof(eventData.Uid) == "string" and H.findAreaEggRecord(eventData.Uid) or nil
	local category = record and record.AssetCategory or eventData.AssetCategory
	local parts = { string.format("**%s** `%s`", H.assetName(category), tostring(H.resolveRarity(category) or "?")) }
	local areaId = record and record.AreaId or eventData.AreaId
	if typeof(areaId) == "string" then
		table.insert(parts, areaId)
	end
	if record then
		local scale = tonumber(record.AssetScale)
		if scale then
			table.insert(parts, string.format("x%.2f", scale))
		end
		local mutations = H.recordMutations(record)
		if #mutations > 0 then
			table.insert(parts, table.concat(mutations, ", "))
		end
	end
	if #ObtainedEggLog < 100 then
		table.insert(ObtainedEggLog, table.concat(parts, " | "))
	end
end

function H.trackWebhookEvents()
	local save = H.getSave()
	if not save then
		return
	end
	if not WebhookTrackerInitialized then
		WebhookTrackerInitialized = true
		for uid in pairs(save.Inventory or {}) do
			KnownInventoryUids[uid] = true
		end
		for _, egg in ipairs(H.getAreaEggs()) do
			KnownWorldEggUids[egg.Uid] = true
		end
		LastRebirthSnapshot = tonumber(save.Rebirth) or 0
		LastStealCountSnapshot = SessionStolenEggs
		return
	end
	SummaryStolenEggs += math.max(0, SessionStolenEggs - LastStealCountSnapshot)
	LastStealCountSnapshot = SessionStolenEggs
	for uid in pairs(save.Inventory or {}) do
		if KnownInventoryUids[uid] == nil then
			KnownInventoryUids[uid] = true
			SummaryPetsObtained += 1
		end
	end
	local rebirths = tonumber(save.Rebirth) or 0
	if LastRebirthSnapshot and rebirths > LastRebirthSnapshot then
		SummaryRebirths += rebirths - LastRebirthSnapshot
	end
	LastRebirthSnapshot = rebirths
	local currentWorldEggs = {}
	local logSpawns = H.isOn("WebhookEggSpawns")
	for _, egg in ipairs(H.getAreaEggs()) do
		currentWorldEggs[egg.Uid] = true
		if KnownWorldEggUids[egg.Uid] == nil then
			KnownWorldEggUids[egg.Uid] = true
			local rarity = H.resolveRarity(egg.AssetCategory)
			if logSpawns and H.selectionAllows("WebhookRarities", rarity or "") and #SpawnedEggLog < 60 then
				table.insert(SpawnedEggLog, {
					rank = RarityWeight[rarity or ""] or 0,
					order = #SpawnedEggLog,
					text = string.format("**%s** `%s` in %s", H.assetName(egg.AssetCategory), tostring(rarity or "?"), tostring(egg.AreaId)),
				})
			end
		end
	end
	for uid in pairs(KnownWorldEggUids) do
		if not currentWorldEggs[uid] then
			KnownWorldEggUids[uid] = nil
		end
	end
end

function H.buildSummaryEmbed()
	local save = H.getSave()
	local fields = {}
	if save then
		table.insert(fields, H.embedField("Money", "`" .. H.formatNumber(save.Money) .. "`"))
		table.insert(fields, H.embedField("Speed Power", "`" .. H.formatNumber(save.SpeedPower) .. "`"))
		table.insert(fields, H.embedField("Rebirth", "`" .. tostring(save.Rebirth or 0) .. "`"))
		table.insert(fields, H.embedField("Pets Owned", "`" .. tostring(H.countTable(save.Inventory)) .. "`"))
	end
	table.insert(fields, H.embedField(
		"Since Last Summary",
		string.format("Eggs stolen: **%d**\nPets obtained: **%d**\nRebirths: **%d**", SummaryStolenEggs, SummaryPetsObtained, SummaryRebirths),
		false
	))
	return {
		author = { name = GAME_NAME .. " | bobloscript" },
		title = "Session Summary",
		description = string.format(
			"**Player** `%s`\n**Server** `%s`\n**Runtime** `%s`",
			LocalPlayer.Name,
			DisplayJobId,
			H.formatElapsed(os.clock() - SessionStartedAt)
		),
		color = 5793266,
		fields = fields,
		footer = { text = "bobloscript.com" },
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
	}
end

H.sendSummary = function()
	local sent = H.sendWebhookEmbed(H.buildSummaryEmbed(), true)
	if sent then
		SummaryStolenEggs = 0
		SummaryPetsObtained = 0
		SummaryRebirths = 0
		table.clear(SpawnedEggLog)
		table.clear(ObtainedEggLog)
	end
	return sent
end

function H.runWebhookSummary()
	local interval = (tonumber(H.optionValue("WebhookInterval", 15)) or 15) * 60
	if os.clock() - LastWebhookSummaryAt < interval then
		return false
	end
	LastWebhookSummaryAt = os.clock()
	return H.sendSummary()
end

-- ===== Performance / movement extras =====
function H.applyAntiGameplayPause(enabled)
	pcall(function()
		GuiService:SetGameplayPausedNotificationEnabled(not enabled)
	end)
	pcall(function()
		local notification = CoreGui:FindFirstChild("RobloxNetworkPauseNotification")
		if notification then
			notification.Enabled = not enabled
		end
	end)
	if enabled then
		pcall(function()
			if sethiddenproperty then
				sethiddenproperty(LocalPlayer, "GameplayPaused", false)
			else
				LocalPlayer.GameplayPaused = false
			end
		end)
	end
end

function H.destroyRenderOverlay()
	if RenderOverlayGui then
		pcall(function()
			RenderOverlayGui:Destroy()
		end)
	end
	RenderOverlayGui = nil
	table.clear(RenderOverlayLabels)
end

function H.buildRenderOverlay()
	if RenderOverlayGui and RenderOverlayGui.Parent then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "BobloRenderInfo"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 500
	gui.Parent = (gethui and gethui()) or CoreGui
	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(10, 10, 12)
	background.BorderSizePixel = 0
	background.Parent = gui
	local title = Instance.new("TextLabel")
	title.AnchorPoint = Vector2.new(0.5, 1)
	title.Position = UDim2.fromScale(0.5, 0.5)
	title.Size = UDim2.fromOffset(400, 30)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamMedium
	title.TextSize = 24
	title.TextColor3 = Color3.fromRGB(226, 230, 238)
	title.Text = "Steal An Egg Hub"
	title.Parent = background
	local credit = Instance.new("TextLabel")
	credit.AnchorPoint = Vector2.new(0.5, 0)
	credit.Position = UDim2.new(0.5, 0, 0.5, 6)
	credit.Size = UDim2.fromOffset(400, 22)
	credit.BackgroundTransparency = 1
	credit.Font = Enum.Font.Code
	credit.TextSize = 15
	credit.TextColor3 = Color3.fromRGB(120, 200, 150)
	credit.Text = HEADER_CREDIT
	credit.Parent = background
	RenderOverlayGui = gui
end

function H.applyRendering(disableRendering)
	local ok = pcall(function()
		RunService:Set3dRenderingEnabled(not disableRendering)
	end)
	if ok then
		RenderingDisabled = disableRendering
	end
	if disableRendering then
		H.buildRenderOverlay()
	else
		H.destroyRenderOverlay()
	end
end

local FpsEffectClasses = { ParticleEmitter = true, Trail = true, Smoke = true, Fire = true, Sparkles = true }

function H.setEffectEnabled(inst, enabled)
	pcall(function()
		inst.Enabled = enabled
	end)
end

function H.enableFpsBoost()
	if FpsBoostSnapshot then
		return
	end
	local terrain = Workspace:FindFirstChildOfClass("Terrain")
	local qualityLevel = nil
	pcall(function()
		qualityLevel = settings().Rendering.QualityLevel
	end)
	FpsBoostSnapshot = {
		QualityLevel = qualityLevel,
		GlobalShadows = Lighting.GlobalShadows,
		FogEnd = Lighting.FogEnd,
		Terrain = terrain,
		WaterWaveSize = terrain and terrain.WaterWaveSize or nil,
		WaterReflectance = terrain and terrain.WaterReflectance or nil,
		Effects = {},
	}
	pcall(function()
		settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
	end)
	Lighting.GlobalShadows = false
	Lighting.FogEnd = 1000000
	if terrain then
		terrain.WaterWaveSize = 0
		terrain.WaterReflectance = 0
	end
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if FpsEffectClasses[descendant.ClassName] and descendant.Enabled then
			table.insert(FpsBoostSnapshot.Effects, descendant)
			H.setEffectEnabled(descendant, false)
		end
	end
	FpsDescendantAddedConnection = Workspace.DescendantAdded:Connect(function(descendant)
		if FpsEffectClasses[descendant.ClassName] and H.isOn("FpsBoost") then
			H.setEffectEnabled(descendant, false)
		end
	end)
end

function H.disableFpsBoost()
	if FpsDescendantAddedConnection then
		FpsDescendantAddedConnection:Disconnect()
		FpsDescendantAddedConnection = nil
	end
	local snapshot = FpsBoostSnapshot
	if not snapshot then
		return
	end
	FpsBoostSnapshot = nil
	if snapshot.QualityLevel then
		pcall(function()
			settings().Rendering.QualityLevel = snapshot.QualityLevel
		end)
	end
	Lighting.GlobalShadows = snapshot.GlobalShadows
	Lighting.FogEnd = snapshot.FogEnd
	if snapshot.Terrain and snapshot.Terrain.Parent then
		snapshot.Terrain.WaterWaveSize = snapshot.WaterWaveSize
		snapshot.Terrain.WaterReflectance = snapshot.WaterReflectance
	end
	for _, effect in ipairs(snapshot.Effects) do
		H.setEffectEnabled(effect, true)
	end
end

function H.applyFpsCap(value)
	local setCap = setfpscap or (syn and syn.set_fps_cap)
	if typeof(setCap) ~= "function" then
		if not FpsCapUnsupportedNotified then
			FpsCapUnsupportedNotified = true
			H.notify("FPS", "FPS cap is not supported by your executor", "Warning", 4)
		end
		return false
	end
	return pcall(setCap, math.clamp(tonumber(value) or 60, 15, 360))
end

function H.handleDisconnect(reason)
	if DisconnectHandled then
		return
	end
	DisconnectHandled = true
	if H.isOn("WebhookDisconnectAlerts") then
		H.sendWebhookEmbed({
			author = { name = GAME_NAME .. " | bobloscript" },
			title = "Disconnected",
			description = string.format("**Player** `%s`\n**Reason** %s", LocalPlayer.Name, tostring(reason or "Connection lost")),
			color = 15158332,
			footer = { text = "bobloscript.com" },
			timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		}, true)
	end
	if H.isOn("AutoReconnect") then
		task.delay(2, H.rejoinServer)
	end
end

-- ===== Scheduler =====
local AutomationJobs = {
	["Auto Steal Egg"] = { Ready = H.canAutoSteal, Run = H.runAutoSteal, Interval = 0.25 },
	["Auto Place Egg"] = { Ready = H.canAutoPlace, Run = H.runAutoPlaceEggs, Interval = 0.45 },
	["Auto Hatch"] = { Ready = H.canAutoHatch, Run = H.runAutoOpenReadyEggs, Interval = 0.55 },
	["Auto Treadmill"] = { Ready = H.canAutoTreadmill, Run = H.runAutoTreadmillTraining, Interval = 1.2 },
}

function H.priorityOrder()
	local used = {}
	local order = {}
	for _, optionName in ipairs(PrioritySlotOptionNames) do
		local jobName = H.optionValue(optionName, nil)
		if AutomationJobs[jobName] and not used[jobName] then
			used[jobName] = true
			table.insert(order, jobName)
		end
	end
	for _, jobName in ipairs(PriorityTaskNames) do
		if not used[jobName] then
			used[jobName] = true
			table.insert(order, jobName)
		end
	end
	return order
end

local function buildUI()

	local Home = UI:AddTab({ Id = "home", Title = "Home", Icon = "home" })
	local Farm = UI:AddTab({ Id = "farm", Title = "Farm", Icon = "egg" })
	local Pets = UI:AddTab({ Id = "pets", Title = "Pets", Icon = "paw-print" })
	local Progress = UI:AddTab({ Id = "progress", Title = "Progress", Icon = "arrow-big-up" })
	local Player = UI:AddTab({ Id = "player", Title = "Player", Icon = "eye" })
	local System = UI:AddTab({ Id = "system", Title = "System", Icon = "settings-2" })

	-- ===== Home =====
	local SessionSec = Home:AddSection({ Title = "Session", Icon = "activity" })
	local AccountSec = Home:AddSection({ Title = "Account", Icon = "user" })
	local QuickSec = Home:AddSection({ Title = "Quick Actions", Icon = "zap" })
	local HelpSec = Home:AddSection({ Title = "Quick Start", Icon = "book-open" })

	statusRow = SessionSec:AddStatus({ Title = "Automation", Value = "Ready", Status = "Success" })
	jobRow = SessionSec:AddStatus({ Title = "Current Job", Value = "Idle", Status = "Neutral" })
	stolenRow = SessionSec:AddStatus({ Title = "Stolen Eggs", Value = "0", Status = "Neutral" })
	carryingRow = SessionSec:AddStatus({ Title = "Carrying Egg", Value = "No", Status = "Neutral" })
	runtimeRow = SessionSec:AddStatus({ Title = "Runtime", Value = "0m", Status = "Neutral" })
	SessionSec:AddStatus({ Title = "Server", Value = DisplayJobId, Status = "Neutral" })

	local eggCapacity = EggTypes and tonumber(EggTypes.MAX_INVENTORY) or 100
	inventoryProgress = AccountSec:AddStatus({
		Title = "Egg Inventory",
		Value = tostring(H.eggInventoryCount()),
		Status = "Neutral",
		Icon = "egg",
	})
	moneyRow = AccountSec:AddStatus({ Title = "Money", Value = "0", Status = "Neutral" })
	speedRow = AccountSec:AddStatus({ Title = "Speed Power", Value = "0", Status = "Neutral" })
	rebirthRow = AccountSec:AddStatus({ Title = "Rebirths", Value = "0", Status = "Neutral" })
	petsOwnedRow = AccountSec:AddStatus({ Title = "Pets Owned", Value = "0", Status = "Neutral" })

	QuickSec:AddButton({
		Title = "Return to Base",
		Text = "Return",
		Icon = "home",
		Callback = function()
			task.spawn(function()
				local base = H.getBasePosition()
				if not base or not H.travelTo(base, true) then
					H.notify("Return", "Base is not available right now", "Warning", 3)
				end
			end)
		end,
	})
	QuickSec:AddButton({
		Title = "Place Eggs",
		Text = "Place",
		Icon = "package",
		Callback = function()
			task.spawn(function()
				H.runAutoPlaceEggs(true)
			end)
		end,
	})

	QuickSec:AddButton({
		Title = "Server Hop",
		Text = "Hop",
		Icon = "server",
		Callback = function()
			task.spawn(function()
				ServerHopRetryAfter = 0
				H.serverHop("Manual hop")
			end)
		end,
	})
	QuickSec:AddButton({
		Title = "Fuse Now",
		Text = "Fuse",
		Icon = "combine",
		Callback = function()
			task.spawn(function()
				H.runAutoFusePets(true)
			end)
		end,
	})

	HelpSec:AddParagraph({
		Title = "Farm flow",
		Content = "1) Open Farm -> Steal.  2) Pick areas / rarities only when you want filters.  3) Enable Auto Steal Selected or Auto Steal All.  4) Keep Auto Return on so stolen eggs come back to your plot.",
		Icon = "play",
	})
	HelpSec:AddParagraph({
		Title = "Filters",
		Content = "Empty multi-select filters mean everything matches. Related settings stay visible so Potassium does not trigger BobloUI dependency reflow.",
		Icon = "filter",
	})

	-- ===== Farm =====
	local StealSec = Farm:AddSection({ Title = "Steal Eggs", Icon = "hand-grab", Description = "Main egg farming controls" })
	local LifeSec = Farm:AddSection({ Title = "Egg Handling", Icon = "refresh-cw", Description = "Place, hatch and sell eggs" })
	local ServerSec = Farm:AddSection({ Title = "Server Hop", Icon = "server" })
	local PrioritySec = Farm:AddSection({ Title = "Task Order", Icon = "list-ordered" })

	StealSec:AddParagraph({
		Content = "Use Selected for filtered farming. Use All to ignore rarity / mutation filters. Big Eggs can run by itself or together with either mode.",
		Icon = "info",
	})
	StealSec:AddToggle({
		Id = "AutoStealSelected",
		Title = "Auto Steal Selected",
		Description = "Use area / rarity / mutation filters below",
		Keywords = { "egg", "steal", "farm", "filtered", "autofarm" },
		Icon = "filter",
		Default = false,
	})
	StealSec:AddToggle({
		Id = "AutoStealAll",
		Title = "Auto Steal All",
		Description = "Ignore rarity and mutation filters",
		Keywords = { "egg", "steal", "all", "farm", "autofarm" },
		Icon = "bot",
		Default = false,
	})
	StealSec:AddToggle({ Id = "StealBigEggs", Title = "Steal Big Eggs", Icon = "maximize", Default = false })
	StealSec:AddDivider({
		Title = "Target filters",
	})
	StealSec:AddDropdown({
		Id = "StealZones",
		Title = "Areas",
		Description = "Empty = all areas",
		Options = AreaNames,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	StealSec:AddDropdown({
		Id = "StealRarities",
		Title = "Rarities",
		Description = "Empty = all rarities",
		Options = RARITIES,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	StealSec:AddDropdown({
		Id = "StealMutations",
		Title = "Mutations",
		Description = "Empty = all mutations",
		Options = MUTATIONS,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	StealSec:AddDropdown({
		Id = "StealPriority",
		Title = "Target Priority",
		Options = STEAL_PRIORITIES,
		Default = "Rarest",
	})
	StealSec:AddSlider({
		Id = "StealSpeed",
		Title = "Steal Speed",
		Min = 50,
		Max = 1000,
		Default = 300,
		Step = 10,
		ValueInput = true,
	})
	StealSec:AddSlider({
		Id = "StealBigEggScale",
		Title = "Minimum Big Egg Size",
		Min = 1,
		Max = 50,
		Default = 1.5,
		Step = 0.1,
		Suffix = "x",
	})
	StealSec:AddDivider({ Title = "Carry behavior" })
	StealSec:AddToggle({ Id = "AutoReturn", Title = "Auto Return to Base", Icon = "home", Default = true })
	StealSec:AddToggle({ Id = "AutoDropEgg", Title = "Auto Drop Held Egg", Icon = "package-x", Default = false })

	LifeSec:AddToggle({ Id = "AutoPlaceSelected", Title = "Auto Place Selected", Icon = "package", Default = false })
	LifeSec:AddToggle({ Id = "AutoPlaceAll", Title = "Auto Place All", Icon = "boxes", Default = false })
	LifeSec:AddToggle({ Id = "AutoOpenReadyEggs", Title = "Auto Hatch Ready", Icon = "egg", Default = false })
	LifeSec:AddDropdown({
		Id = "LifecycleRarities",
		Title = "Lifecycle Rarities",
		Description = "Used by filtered placement and hatch",
		Options = RARITIES,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	LifeSec:AddDropdown({
		Id = "LifecycleMutations",
		Title = "Lifecycle Mutations",
		Options = MUTATIONS,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	LifeSec:AddDivider({ Title = "Egg selling" })
	LifeSec:AddToggle({ Id = "AutoSellEggs", Title = "Auto Sell Eggs", Icon = "egg", Default = false })
	LifeSec:AddDropdown({
		Id = "SellEggRarities",
		Title = "Sell Rarities",
		Options = RARITIES,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	LifeSec:AddSlider({
		Id = "SellEggInterval",
		Title = "Sell Interval",
		Min = 1,
		Max = 120,
		Default = 8,
		Step = 1,
		Suffix = " s",
	})

	ServerSec:AddToggle({ Id = "AutoServerHop", Title = "Auto Server Hop", Icon = "server", Default = false })
	local hopModeControl = ServerSec:AddDropdown({
		Id = "HopMode",
		Title = "Hop When",
		Options = ServerHopModes,
		Default = "No Matching Eggs",
	})
	local hopValueControl = ServerSec:AddSlider({
		Id = "HopValue",
		Title = "Wait Before Hop",
		Description = "Seconds without a matching egg",
		Min = 1,
		Max = 200,
		Default = 15,
		Step = 1,
		ValueInput = true,
	})
	local function refreshHopCopy(mode)
		if mode == "Timed Interval" then
			hopValueControl:SetTitle("Hop Every")
			hopValueControl:SetDescription("Minutes between server hops")
		elseif mode == "After Steal Count" then
			hopValueControl:SetTitle("Hop After")
			hopValueControl:SetDescription("Number of stolen eggs before hopping")
		else
			hopValueControl:SetTitle("Wait Before Hop")
			hopValueControl:SetDescription("Seconds without a matching egg")
		end
	end
	refreshHopCopy(H.optionValue("HopMode", "No Matching Eggs"))
	hopModeControl:OnChanged(refreshHopCopy)
	ServerSec:AddButton({
		Title = "Hop Now",
		Text = "Hop",
		Icon = "shuffle",
		Keywords = { "server", "hop", "switch", "new server" },
		Callback = function()
			task.spawn(function()
				ServerHopRetryAfter = 0
				H.serverHop("Manual hop")
			end)
		end,
	})

	PrioritySec:AddParagraph({
		Content = "When several automation jobs are ready at the same time, the scheduler runs the first available task in this order.",
		Icon = "list-ordered",
	})
	for index, optionName in ipairs(PrioritySlotOptionNames) do
		PrioritySec:AddDropdown({
			Id = optionName,
			Title = string.format("Priority %d", index),
			Options = PriorityTaskNames,
			Default = PriorityTaskNames[index],
		})
	end

	-- ===== Pets =====
	local PetsOverview = Pets:AddSection({ Title = "Pets", Icon = "paw-print" })
	local FuseSec = Pets:AddSection({ Title = "Auto Fuse", Icon = "combine" })
	local SellPetSec = Pets:AddSection({ Title = "Auto Sell Pets", Icon = "tags" })

	PetsOverview:AddToggle({ Id = "AutoEquipBest", Title = "Auto Equip Best Pets", Icon = "sparkles", Default = false })
	PetsOverview:AddToggle({
		Id = "AutoDeleteOwnPets",
		Title = "Hide Own Pet Renders",
		Description = "Removes your own pet models locally to reduce clutter",
		Default = false,
	})

	FuseSec:AddToggle({ Id = "AutoFusePets", Title = "Auto Fuse Pets", Icon = "combine", Default = false })
	FuseSec:AddDropdown({
		Id = "FuseRarities",
		Title = "Fuse Rarities",
		Options = RARITIES,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	FuseSec:AddDropdown({
		Id = "FuseMutations",
		Title = "Fuse Mutations",
		Options = MUTATIONS,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	FuseSec:AddDropdown({
		Id = "FuseTarget",
		Title = "Pick Group By",
		Options = FUSE_TARGET_MODES,
		Default = "Highest Rarity",
	})
	FuseSec:AddToggle({ Id = "FuseKeepMutated", Title = "Never Fuse Mutated", Default = true })
	FuseSec:AddToggle({ Id = "FuseKeepEquipped", Title = "Never Fuse Equipped", Default = true })
	FuseSec:AddToggle({ Id = "FuseAutoReveal", Title = "Auto Complete Reveal", Default = true })
	FuseSec:AddSlider({ Id = "FuseMaxScale", Title = "Maximum Scale to Fuse", Min = 0, Max = 10, Default = 10, Step = 0.1 })
	FuseSec:AddSlider({ Id = "FuseKeepPerCategory", Title = "Keep Per Pet Type", Min = 0, Max = 20, Default = 0, Step = 1 })
	FuseSec:AddSlider({ Id = "FuseInterval", Title = "Fuse Interval", Min = 1, Max = 120, Default = 8, Step = 1, Suffix = " s" })
	FuseSec:AddButton({
		Title = "Fuse Now",
		Text = "Fuse",
		Icon = "combine",
		Callback = function()
			task.spawn(function()
				H.runAutoFusePets(true)
			end)
		end,
	})

	SellPetSec:AddToggle({ Id = "AutoSellPets", Title = "Auto Sell Pets", Icon = "tags", Default = false })
	SellPetSec:AddDropdown({
		Id = "SellRarities",
		Title = "Sell Rarities",
		Options = RARITIES,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	SellPetSec:AddDropdown({
		Id = "SellMutations",
		Title = "Sell Mutations",
		Options = MUTATIONS,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	SellPetSec:AddToggle({ Id = "SellKeepMutated", Title = "Never Sell Mutated", Default = true })
	SellPetSec:AddToggle({ Id = "SellKeepEquipped", Title = "Never Sell Equipped", Default = true })
	SellPetSec:AddSlider({ Id = "SellMaxScale", Title = "Maximum Scale to Sell", Min = 0, Max = 10, Default = 10, Step = 0.1 })
	SellPetSec:AddSlider({ Id = "SellInterval", Title = "Sell Interval", Min = 1, Max = 120, Default = 6, Step = 1, Suffix = " s" })

	-- ===== Progress =====
	local UpgradesSec = Progress:AddSection({ Title = "Upgrades", Icon = "arrow-big-up" })
	local RewardsSec = Progress:AddSection({ Title = "Rewards", Icon = "coins" })
	local EquipmentSec = Progress:AddSection({ Title = "Equipment", Icon = "shopping-bag" })
	local TrainingSec = Progress:AddSection({ Title = "Training", Icon = "dumbbell" })

	UpgradesSec:AddToggle({ Id = "AutoUpgrades", Title = "Auto Buy Upgrades", Icon = "arrow-big-up", Default = false })
	UpgradesSec:AddDropdown({
		Id = "UpgradeTypes",
		Title = "Upgrade Types",
		Options = UPGRADE_TYPES,
		Multi = true,
		Searchable = true,
		Default = { "Base", "Treadmill" },
	})

	RewardsSec:AddToggle({ Id = "AutoClaimIndex", Title = "Auto Claim Index", Icon = "book-check", Default = false })
	RewardsSec:AddToggle({ Id = "AutoClaimGroupReward", Title = "Auto Claim Group Reward", Icon = "users", Default = false })
	RewardsSec:AddToggle({ Id = "AutoClaimOffline", Title = "Claim Offline Earnings", Icon = "wallet", Default = false })

	EquipmentSec:AddToggle({ Id = "AutoBuyTrail", Title = "Auto Buy Trail", Icon = "shopping-bag", Default = false })
	EquipmentSec:AddDropdown({
		Id = "TrailWanted",
		Title = "Trails",
		Options = TrailNames,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	EquipmentSec:AddToggle({ Id = "AutoEquipBestTrail", Title = "Auto Equip Best Trail", Icon = "sparkles", Default = false })
	EquipmentSec:AddToggle({ Id = "AutoEquipBestGear", Title = "Auto Equip Best Gear", Icon = "sword", Default = false })

	TrainingSec:AddToggle({ Id = "AutoTreadmill", Title = "Auto Treadmill Training", Icon = "dumbbell", Default = false })

	-- ===== Player =====
	local EspSec = Player:AddSection({ Title = "ESP", Icon = "eye" })
	local MoveSec = Player:AddSection({ Title = "Movement", Icon = "move" })
	local TeleportSec = Player:AddSection({ Title = "Teleports", Icon = "map-pin" })

	EspSec:AddToggle({ Id = "EspWorldEggs", Title = "World Egg ESP", Icon = "egg", Default = false })
	EspSec:AddToggle({ Id = "EspCarriedEggs", Title = "Carried and Dropped Egg ESP", Default = false })
	EspSec:AddToggle({ Id = "EspGuards", Title = "Guard ESP", Default = false })
	EspSec:AddToggle({ Id = "EspPets", Title = "Pet ESP", Default = false })
	EspSec:AddToggle({ Id = "EspPlayers", Title = "Player ESP", Default = false })
	EspSec:AddToggle({ Id = "EspMachines", Title = "Machine ESP", Default = false })
	EspSec:AddToggle({ Id = "EspPlots", Title = "Plot ESP", Default = false })
	EspSec:AddSlider({
		Id = "EspDistance",
		Title = "Render Distance",
		Min = 100,
		Max = 6000,
		Default = 2000,
		Step = 50,
		Suffix = " studs",
		ValueInput = true,
	})

	MoveSec:AddToggle({ Id = "WalkSpeedEnabled", Title = "Walk Speed Override", Default = false })
	MoveSec:AddSlider({ Id = "WalkSpeed", Title = "Walk Speed", Min = 16, Max = 500, Default = 32, Step = 1, ValueInput = true })
	MoveSec:AddToggle({ Id = "JumpPowerEnabled", Title = "Jump Power Override", Default = false })
	MoveSec:AddSlider({ Id = "JumpPower", Title = "Jump Power", Min = 10, Max = 500, Default = 50, Step = 1, ValueInput = true })
	MoveSec:AddToggle({ Id = "InfJump", Title = "Infinite Jump", Default = false })
	MoveSec:AddToggle({ Id = "NoClip", Title = "NoClip", Default = false })
	MoveSec:AddDivider({ Title = "Fly" })
	MoveSec:AddToggle({
		Id = "Fly",
		Title = "Fly",
		Default = false,
		Callback = function(v)
			if not v then
				local humanoid = H.getHumanoid()
				if humanoid then
					humanoid.PlatformStand = false
				end
			end
		end,
	})
	MoveSec:AddSlider({ Id = "FlySpeed", Title = "Fly Speed", Min = 10, Max = 400, Default = 60, Step = 1, ValueInput = true })

	TeleportSec:AddDropdown({
		Id = "WaypointTarget",
		Title = "Waypoint",
		Options = WaypointNames,
		Searchable = true,
		Default = "Base",
	})
	TeleportSec:AddButton({
		Title = "Teleport to Waypoint",
		Text = "Teleport",
		Icon = "map-pin",
		Callback = function()
			task.spawn(function()
				local position = H.resolveWaypoint(H.optionValue("WaypointTarget", "Base"))
				if not position then
					H.notify("Waypoint", "Not available right now", "Warning", 3)
					return
				end
				if not H.travelTo(position, true) then
					H.notify("Waypoint", "Teleport failed", "Error", 3)
				end
			end)
		end,
	})

	-- ===== System =====
	local SessionSysSec = System:AddSection({ Title = "Session", Icon = "refresh-cw" })
	local PerformanceSec = System:AddSection({ Title = "Performance", Icon = "gauge" })
	local WebhookSec = System:AddSection({ Title = "Webhooks", Icon = "webhook" })
	local AboutSec = System:AddSection({ Title = "About", Icon = "info" })

	SessionSysSec:AddToggle({ Id = "AntiAfk", Title = "Anti-AFK", Icon = "shield-check", Default = true })
	SessionSysSec:AddToggle({
		Id = "AntiGameplayPause",
		Title = "No Gameplay Paused",
		Default = true,
		Callback = function(v)
			H.applyAntiGameplayPause(v)
		end,
	})
	SessionSysSec:AddToggle({ Id = "AutoReconnect", Title = "Auto Reconnect", Default = false })
	SessionSysSec:AddButton({
		Title = "Rejoin Server",
		Text = "Rejoin",
		Icon = "refresh-cw",
		Confirm = "Rejoin the current server?",
		Callback = function()
			H.rejoinServer()
		end,
	})
	SessionSysSec:AddButton({
		Title = "Copy Join Script",
		Text = "Copy",
		Icon = "clipboard",
		Callback = function()
			H.copyText(
				string.format(
					'game:GetService("TeleportService"):TeleportToPlaceInstance(%d, "%s", game:GetService("Players").LocalPlayer)',
					game.PlaceId,
					CurrentJobId
				),
				"Copied join script"
			)
		end,
	})

	PerformanceSec:AddToggle({
		Id = "FpsBoost",
		Title = "FPS Boost",
		Default = false,
		Callback = function(v)
			if v then
				H.enableFpsBoost()
			else
				H.disableFpsBoost()
			end
		end,
	})
	PerformanceSec:AddToggle({
		Id = "DisableRendering",
		Title = "Disable 3D Rendering",
		Default = false,
		Callback = function(v)
			H.applyRendering(v)
		end,
	})
	PerformanceSec:AddSlider({
		Id = "FpsCap",
		Title = "FPS Cap",
		Min = 15,
		Max = 360,
		Default = 60,
		Step = 1,
		Suffix = " fps",
		ValueInput = true,
		Callback = function(v)
			H.applyFpsCap(v)
		end,
	})

	WebhookSec:AddToggle({ Id = "WebhookEnabled", Title = "Enable Webhooks", Icon = "webhook", Default = false })
	WebhookSec:AddInput({
		Id = "WebhookUrl",
		Title = "Webhook URL",
		Placeholder = "https://discord.com/api/webhooks/...",
		Default = "",
	})
	WebhookSec:AddInput({
		Id = "WebhookPingId",
		Title = "Ping User ID",
		Placeholder = "123456789012345678",
		Default = "",
	})
	WebhookSec:AddSlider({
		Id = "WebhookInterval",
		Title = "Summary Interval",
		Min = 1,
		Max = 180,
		Default = 15,
		Step = 1,
		Suffix = " min",
	})
	WebhookSec:AddToggle({ Id = "WebhookEggSpawns", Title = "List Spawned Eggs", Default = true })
	WebhookSec:AddDropdown({
		Id = "WebhookRarities",
		Title = "Rarities",
		Options = RARITIES,
		Multi = true,
		Searchable = true,
		Default = {},
	})
	WebhookSec:AddToggle({ Id = "WebhookDisconnectAlerts", Title = "Disconnect Alerts", Default = false })
	WebhookSec:AddButton({
		Title = "Send Summary Now",
		Text = "Send",
		Icon = "send",
		Callback = function()
			task.spawn(function()
				local sent = H.sendSummary()
				H.notify("Webhook", sent and "Summary sent" or "Send failed", sent and "Success" or "Error", 3)
			end)
		end,
	})

	AboutSec:AddParagraph({ Title = "Script Dev", Content = "bobloscript", Icon = "user" })
	AboutSec:AddParagraph({ Title = "UI Library", Content = "BobloUI", Icon = "layout-dashboard" })
	AboutSec:AddParagraph({ Title = "Library Dev", Content = "bobloscript.com", Icon = "globe" })
	AboutSec:AddParagraph({
		Title = "Search",
		Content = "Use the header search or Ctrl+K to find controls, tabs, commands, configs and favorites without digging through the sidebar.",
		Icon = "search",
	})

	function H.unload()
		if not running then
			return
		end
		running = false
		pcall(H.stopTreadmillTraining)
		pcall(function()
			H.applyAntiGameplayPause(false)
		end)
		pcall(function()
			H.applyRendering(false)
		end)
		pcall(H.disableFpsBoost)
		pcall(H.destroyRenderOverlay)
		pcall(H.clearAllEsp)
		if EspFolder then
			pcall(function()
				EspFolder:Destroy()
			end)
		end
		if AutoExecuteTeleportConnection then
			pcall(function()
				AutoExecuteTeleportConnection:Disconnect()
			end)
		end
		for _, c in ipairs(conns) do
			pcall(function()
				if typeof(c) == "RBXScriptConnection" then
					c:Disconnect()
				end
			end)
		end
		table.clear(conns)
		pcall(function()
			UI:Unload()
		end)
		genv.__SAE_HUB_RUNNING = nil
		genv.__SAE_HUB_SHUTDOWN = nil
	end

	genv.__SAE_HUB_SHUTDOWN = H.unload

	AboutSec:AddDivider({ Title = "Danger Zone" })
	AboutSec:AddButton({
		Title = "Unload Script",
		Text = "Unload",
		Icon = "power",
		Variant = "Danger",
		Callback = function()
			local dialog = UI.Dialog:Confirm({
				Title = "Unload?",
				Content = "Stops automation and closes the menu.",
				Danger = true,
			})
			task.spawn(function()
				if dialog:Await() then
					H.unload()
				end
			end)
		end,
	})
end
buildUI()

local function refreshHomeDashboard()
	if not running then
		return
	end
	pcall(function()
		if carryingRow then
			carryingRow:SetValue(IsCarryingEgg and "Yes" or "No")
			carryingRow:SetStatus(IsCarryingEgg and "Warning" or "Neutral")
		end
		if runtimeRow then
			runtimeRow:SetValue(H.formatElapsed(os.clock() - SessionStartedAt))
		end
		if inventoryProgress then
			inventoryProgress:SetValue(string.format("%d / %s", H.eggInventoryCount(), tostring(EggTypes and EggTypes.MAX_INVENTORY or "?")))
		end
		local save = H.getSave()
		if save then
			if moneyRow then
				moneyRow:SetValue(H.formatNumber(save.Money))
			end
			if speedRow then
				speedRow:SetValue(H.formatNumber(save.SpeedPower))
			end
			if rebirthRow then
				rebirthRow:SetValue(tostring(save.Rebirth or 0))
			end
			if petsOwnedRow then
				petsOwnedRow:SetValue(tostring(H.countTable(save.Inventory)))
			end
		end
	end)
end

refreshHomeDashboard()
task.spawn(function()
	while running do
		task.wait(1)
		refreshHomeDashboard()
	end
end)

-- ===== Connections / workers =====
pcall(function()
	for _, connection in ipairs(getconnections(LocalPlayer.Idled)) do
		pcall(function()
			connection:Disable()
		end)
	end
end)

H.track(RunService.Stepped:Connect(function()
	if not running or not H.isOn("NoClip") then
		return
	end
	local character = LocalPlayer.Character
	if not character then
		return
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.CanCollide then
			descendant.CanCollide = false
		end
	end
end))

H.track(UserInputService.JumpRequest:Connect(function()
	if not running or not H.isOn("InfJump") then
		return
	end
	local humanoid = H.getHumanoid()
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

H.track(RunService.RenderStepped:Connect(function(dt)
	if not running then
		return
	end
	if H.isOn("WalkSpeedEnabled") then
		local humanoid = H.getHumanoid()
		if humanoid then
			humanoid.WalkSpeed = tonumber(H.optionValue("WalkSpeed", 32)) or 32
		end
	end
	if H.isOn("JumpPowerEnabled") then
		local humanoid = H.getHumanoid()
		if humanoid then
			humanoid.UseJumpPower = true
			humanoid.JumpPower = tonumber(H.optionValue("JumpPower", 50)) or 50
		end
	end
	if H.isOn("Fly") then
		local root = H.getRoot()
		local humanoid = H.getHumanoid()
		local cam = Workspace.CurrentCamera
		if root and humanoid and cam then
			humanoid.PlatformStand = true
			local direction = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				direction += cam.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				direction -= cam.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				direction -= cam.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				direction += cam.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				direction += Vector3.new(0, 1, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
				direction -= Vector3.new(0, 1, 0)
			end
			root.AssemblyLinearVelocity = Vector3.zero
			if direction.Magnitude > 0 then
				root.CFrame += direction.Unit * (tonumber(H.optionValue("FlySpeed", 60)) or 60) * dt
			end
		end
	end
end))

H.track(UserInputService.InputBegan:Connect(function()
	LastInputAt = tick()
end))
H.track(UserInputService.InputChanged:Connect(function(input)
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseMovement or inputType == Enum.UserInputType.Gamepad1 then
		LastInputAt = tick()
	end
end))

H.track(LocalPlayer.CharacterAdded:Connect(function()
	if not running then
		return
	end
	task.wait(0.35)
	if H.stealingEnabled() then
		H.swapStealHumanoid()
	end
end))

H.track(UserInputService.InputBegan:Connect(function(input, gp)
	if not gp and input.KeyCode == Enum.KeyCode.End then
		H.unload()
	end
end))

task.spawn(function()
	while running do
		task.wait(0.2)
		if not AutomationBusy then
			for _, jobName in ipairs(H.priorityOrder()) do
				local job = AutomationJobs[jobName]
				local ready = job.Ready()
				if ready then
					local lastRun = AutomationLastRunAt[jobName] or 0
					ready = os.clock() - lastRun >= job.Interval
				end
				if ready then
					AutomationLastRunAt[jobName] = os.clock()
					if jobName ~= "Auto Treadmill" and (TreadmillTrainingActive or H.isDoubleSpeedVisible()) then
						pcall(H.stopTreadmillTraining)
					end
					AutomationBusy = true
					local ok, didWork = pcall(job.Run)
					AutomationBusy = false
					if ok and didWork then
						break
					end
				end
			end
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(0.2)
		if not AutomationBusy then
			if H.isOn("AutoDropEgg") and IsCarryingEgg then
				AutomationBusy = true
				pcall(H.runAutoDropEgg)
				AutomationBusy = false
			elseif H.isOn("AutoReturn") and IsCarryingEgg then
				AutomationBusy = true
				pcall(H.runAutoReturn)
				AutomationBusy = false
			end
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(0.2)
		if H.stealingEnabled() then
			H.swapStealHumanoid()
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(0.1)
		if H.stealingEnabled() then
			local root = H.getRoot()
			local humanoid = H.getHumanoid()
			if root and humanoid and humanoid:GetAttribute("BobloStealHum") == true then
				local laneY = H.getLaneY()
				local velocity = root.AssemblyLinearVelocity
				if root.Position.Y > laneY + 12 then
					local grounded = H.groundedY(root.Position.X, root.Position.Z, laneY)
					root.CFrame = CFrame.new(root.Position.X, grounded, root.Position.Z)
					root.AssemblyLinearVelocity = Vector3.zero
					root.AssemblyAngularVelocity = Vector3.zero
				elseif math.abs(velocity.Y) > 4 then
					root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
				end
			end
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(5)
		if H.isOn("AutoEquipBest") and not AutomationBusy then
			pcall(H.runAutoEquipBest)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(5)
		if H.isOn("AutoEquipBestTrail") then
			pcall(H.runAutoEquipBestTrail)
		end
		if H.isOn("AutoEquipBestGear") then
			pcall(H.runAutoEquipBestGear)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(tonumber(H.optionValue("FuseInterval", 8)) or 8)
		if H.isOn("AutoFusePets") and not AutomationBusy and not IsCarryingEgg then
			AutomationBusy = true
			pcall(H.runAutoFusePets)
			AutomationBusy = false
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(tonumber(H.optionValue("SellInterval", 6)) or 6)
		if H.isOn("AutoSellPets") and not AutomationBusy and not IsCarryingEgg then
			pcall(H.runAutoSellPets)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(tonumber(H.optionValue("SellEggInterval", 8)) or 8)
		if H.isOn("AutoSellEggs") and not AutomationBusy and not IsCarryingEgg then
			AutomationBusy = true
			pcall(H.runAutoSellEggs)
			AutomationBusy = false
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(2)
		if H.isOn("AutoUpgrades") and not IsCarryingEgg then
			pcall(H.runAutoUpgrades)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(8)
		if H.isOn("AutoClaimIndex") then
			pcall(H.runAutoClaimIndex)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(20)
		if H.isOn("AutoClaimGroupReward") then
			pcall(H.runAutoClaimGroupReward)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(15)
		if H.isOn("AutoClaimOffline") then
			pcall(H.runClaimOfflineEarnings)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(6)
		if H.isOn("AutoBuyTrail") and not IsCarryingEgg then
			pcall(H.runAutoBuyTrail)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(1)
		if TreadmillTrainingActive or H.isDoubleSpeedVisible() then
			if not H.isOn("AutoTreadmill") then
				pcall(H.stopTreadmillTraining)
			end
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(1)
		if H.isOn("AutoDeleteOwnPets") then
			pcall(H.deleteOwnPetRenders)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(0.4)
		local anyEsp = H.isOn("EspWorldEggs") or H.isOn("EspCarriedEggs") or H.isOn("EspGuards")
			or H.isOn("EspPets") or H.isOn("EspPlayers") or H.isOn("EspMachines") or H.isOn("EspPlots")
		if anyEsp then
			pcall(H.runEsp)
		elseif next(EspEntries) ~= nil then
			pcall(H.clearAllEsp)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(3)
		if H.isOn("AutoServerHop") and not AutomationBusy then
			pcall(H.runServerHop)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(5)
		if H.isOn("WebhookEnabled") then
			pcall(H.trackWebhookEvents)
			pcall(H.runWebhookSummary)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(2)
		if H.isOn("AntiAfk") then
			local idleFor = tick() - LastInputAt
			local sinceLastTap = tick() - LastAntiAfkAt
			if (idleFor >= 300 and sinceLastTap >= 60) or (idleFor < 300 and sinceLastTap >= 300) then
				pcall(function()
					local camera = Workspace.CurrentCamera
					if camera then
						VirtualUser:Button2Down(Vector2.new(0, 0), camera.CFrame)
						task.wait(0.1)
						VirtualUser:Button2Up(Vector2.new(0, 0), camera.CFrame)
						LastAntiAfkAt = tick()
					end
				end)
			end
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(1)
		if H.isOn("AntiGameplayPause") then
			H.applyAntiGameplayPause(true)
		end
		if H.isOn("AutoReconnect") or H.isOn("WebhookDisconnectAlerts") then
			local promptGui = CoreGui:FindFirstChild("RobloxPromptGui")
			local overlay = promptGui and promptGui:FindFirstChild("promptOverlay")
			if overlay then
				for _, child in ipairs(overlay:GetChildren()) do
					if child.Name:find("ErrorPrompt") and child.Visible then
						H.handleDisconnect("Roblox error prompt")
						break
					end
				end
			end
		end
	end
end)

if H.isOn("AntiGameplayPause") then
	H.applyAntiGameplayPause(true)
end
if H.isOn("FpsBoost") then
	H.enableFpsBoost()
end
H.applyFpsCap(H.optionValue("FpsCap", 60))

H.notify("Steal An Egg Hub", "Ready - see FAQ", "Success", 4)
H.setStatus("Ready", "Success")
