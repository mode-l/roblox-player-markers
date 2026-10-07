-- ModuleScript for your own place. Pass the game's EggState and metadata helpers.
local EggSearch = {}
local RARITY_SCORE_MAP = {
	["LightDark"] = 1300, ["Light & Dark"] = 1300,
	Titan = 1100,
	Divine = 1000, Transcendent = 1000, Superior = 1000,
	Eternal = 900, Limited = 900,
	Secret = 800, Exotic = 800,
	Cosmic = 700, Exclusive = 700, Admin = 700,
	Mythic = 600, Mythical = 600, Prismatic = 600, Rainbow = 600,
	["Squishy God"] = 600, BrainrotGod = 600,
	Legendary = 500, Epic = 400, Rare = 300,
	SuperRare = 200, Celestial = 200, Uncommon = 200,
	Basic = 100, Common = 100,
}

local function rarityNumberScore(rarity)
	local number = type(rarity) == "table" and tonumber(rarity.RarityNumber)
	return number and number * 100 or nil
end

local function directRarityInfo(rarity)
	local name = type(rarity) == "table"
		and (rarity.DisplayName or rarity._id or rarity.Name or "Common")
		or tostring(rarity)
	return name, RARITY_SCORE_MAP[name] or rarityNumberScore(rarity) or 100
end

function EggSearch.GetEggRarityInfo(egg, config)
	config = config or {}
	if not egg then return "Common", 100 end
	if egg.Rarity then return directRarityInfo(egg.Rarity) end
	local category = egg.AssetCategory or egg.Category or egg.Name
	local assets = config.AssetsData
	local directory = assets and (assets.Directory or assets)
	local assetInfo = directory and category and directory[category]
	if assetInfo and assetInfo.Rarity then return directRarityInfo(assetInfo.Rarity) end

	local areas = config.AreasData
	local areasDirectory = areas and (areas.Directory or areas)
	local area = areasDirectory and egg.AreaId and areasDirectory[egg.AreaId]
	local rarity = area and area.Rarity
	local rarityId = type(rarity) == "table" and (rarity._id or rarity.DisplayName or rarity.Name)
		or (type(rarity) == "string" and rarity) or "Common"
	local rarityData = config.RarityData
	local rarities = rarityData and (rarityData.Rarities or rarityData) or {}
	local info = rarities[rarityId]
	local name = (type(info) == "table" and (info.DisplayName or info._id))
		or (type(rarity) == "table" and rarity.DisplayName) or rarityId
	return name, RARITY_SCORE_MAP[name] or RARITY_SCORE_MAP[rarityId]
		or rarityNumberScore(rarity) or 100
end

function EggSearch.IsBigEgg(egg, config)
	if not egg then return false end
	config = config or {}
	local scale = tonumber(egg.AssetScale) or 1
	if config.BigEggMode == "AssetScale" then
		return scale >= (tonumber(config.BigEggThreshold) or 1.5)
	end
	-- Default preserves Oxide's missing-NestScale behavior.
	local nestDefault = config.MissingNestScaleIsBig == false and 0 or 1
	local nestScale = tonumber(egg.NestScale) or nestDefault
	return scale >= 1.35 or nestScale >= 1.0
end

local function allowed(value, filter)
	if filter == nil then return true end
	if type(filter) == "function" then return filter(value) end
	if type(filter) ~= "table" then return value == filter end
	if filter[value] == true then return true end
	for _, entry in ipairs(filter) do
		if entry == value then return true end
	end
	return false
end

local function mutationsAllowed(mutations, egg, filter)
	if filter == nil then return true end
	if type(filter) == "function" then return filter(mutations, egg) end
	-- String/list/set filters match ANY mutation. Empty lists match nothing.
	for _, mutation in ipairs(mutations) do
		if allowed(mutation, filter) then return true end
	end
	return false
end

function EggSearch.new(config)
	config = config or {}
	local eggState = config.EggState
	if not eggState then
		local replicatedStorage = game:GetService("ReplicatedStorage")
		local client = replicatedStorage:WaitForChild("Client", 10)
		assert(client, "ReplicatedStorage.Client was not found")
		local module = client:WaitForChild("EggState", 10)
		assert(module and module:IsA("ModuleScript"), "Client.EggState ModuleScript was not found")
		eggState = require(module)
	end
	if not config.GetEggRarityInfo then
		local data = game:GetService("ReplicatedStorage"):WaitForChild("Data", 10)
		assert(data, "ReplicatedStorage.Data was not found")
		for key, name in pairs({ AssetsData = "Assets", AreasData = "Areas", RarityData = "Rarity" }) do
			if not config[key] then
				local module = data:WaitForChild(name, 10)
				assert(module and module:IsA("ModuleScript"), "Data." .. name .. " was not found")
				config[key] = require(module)
			end
		end
	end
	assert(type(eggState.ReadFieldEggs) == "function", "ReadFieldEggs is required")
	local getRarity = config.GetEggRarityInfo or function(egg)
		return EggSearch.GetEggRarityInfo(egg, config)
	end
	local isBig = config.IsBigEgg or function(egg)
		return EggSearch.IsBigEgg(egg, config)
	end
	local search = {}
	search.Areas = config.AreasData and (config.AreasData.Directory or config.AreasData) or {}
	search.Assets = config.AssetsData and (config.AssetsData.Directory or config.AssetsData) or {}

	function search.GetMatchingFieldEggs(areaFilter, rarityFilter, mutationFilter)
		local snapshot = eggState.ReadFieldEggs()
		if not snapshot or type(snapshot.Records) ~= "table" then return {} end
		local result = {}
		-- pairs supports both arrays and records keyed by Uid.
		for key, egg in pairs(snapshot.Records) do
			if type(egg) == "table" and egg.State == "Slot"
				and typeof(egg.BoundsCFrame) == "CFrame"
				and allowed(egg.AreaId, areaFilter) then
				local rarity, rarityScore = getRarity(egg)
				local mutations = egg.Mutations or {}
				if allowed(rarity, rarityFilter) and mutationsAllowed(mutations, egg, mutationFilter) then
					assert(type(rarityScore) == "number", "Rarity score must be a number")
					local bonus = 0
					for _, mutation in ipairs(mutations) do
						if mutation == "Rainbow" then bonus += 35
						elseif mutation == "Gold" or mutation == "Golden" then bonus += 20
						elseif mutation == "Silver" then bonus += 10 end
					end
					if egg.HasParasite then bonus += 800 end
					if isBig(egg) then bonus += 600 end
					table.insert(result, {
						record = egg,
						rarity = rarity,
						score = rarityScore + bonus,
						key = tostring(egg.Uid or key),
					})
				end
			end
		end
		table.sort(result, function(a, b)
			if a.score == b.score then return a.key < b.key end
			return a.score > b.score
		end)
		return result
	end
	return search
end

function EggSearch.FindEggPrompt(root, searchRoot, maxDistance)
	if not root or not root:IsA("BasePart") then return nil end
	searchRoot = searchRoot or workspace
	maxDistance = maxDistance or 14
	local nearest, nearestDistance
	for _, obj in ipairs(searchRoot:GetDescendants()) do
		if obj:IsA("ProximityPrompt") and obj.Name == "CarryAreaEgg" and obj.Enabled then
			local parent = obj.Parent
			local position
			if parent and parent:IsA("Attachment") then
				position = parent.WorldPosition
			elseif parent and parent:IsA("BasePart") then
				position = parent.Position
			elseif parent and parent:IsA("Model") then
				position = parent:GetPivot().Position
			end
			if position then
				local distance = (position - root.Position).Magnitude
				if distance < maxDistance and (not nearestDistance or distance < nearestDistance) then
					nearest, nearestDistance = obj, distance
				end
			end
		end
	end
	return nearest, nearestDistance
end

-- Sets zero hold time for normal player input; returns a restore function.
-- In Studio, run on the server if the test must apply to every client.
function EggSearch.InstantProximity(prompt)
	assert(prompt and prompt:IsA("ProximityPrompt"), "ProximityPrompt is required")
	local previous = prompt.HoldDuration
	prompt.HoldDuration = 0
	local restored = false
	return function()
		if restored then return end
		restored = true
		if prompt.Parent then prompt.HoldDuration = previous end
	end
end

return EggSearch
