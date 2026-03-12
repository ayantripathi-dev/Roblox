local DataStoreService = game:GetService("DataStoreService")
local PlayerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local DataManager = {}
local sessionData = {}

function DataManager.loadData(player)
	local success, result = pcall(function()
		return PlayerDataStore:GetAsync(tostring(player.UserId))
	end)

	if success then
		sessionData[player.UserId] = result or {
			Power = Constants.INITIAL_POWER,
			Coins = Constants.INITIAL_COINS,
			Rebirths = Constants.INITIAL_REBIRTHS,
			Upgrades = {Power = 1, Coins = 1},
			Pets = {},
			EquippedPets = {}
		}
		return sessionData[player.UserId]
	else
		warn("Failed to load data for player " .. player.Name .. ": " .. tostring(result))
		return nil
	end
end

function DataManager.saveData(player)
	if sessionData[player.UserId] then
		local success, result = pcall(function()
			PlayerDataStore:UpdateAsync(tostring(player.UserId), function(oldData)
				return sessionData[player.UserId]
			end)
		end)
		if not success then
			warn("Failed to save data for player " .. player.Name .. ": " .. tostring(result))
		end
	end
end

game:BindToClose(function()
	for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
		DataManager.saveData(player)
	end
end)

function DataManager.get(player, key)
	if sessionData[player.UserId] then
		return sessionData[player.UserId][key]
	end
end

function DataManager.set(player, key, value)
	if sessionData[player.UserId] then
		sessionData[player.UserId][key] = value
	end
end

function DataManager.increment(player, key, amount)
	if sessionData[player.UserId] then
		sessionData[player.UserId][key] = (sessionData[player.UserId][key] or 0) + amount
	end
end

game:GetService("Players").PlayerRemoving:Connect(function(player)
	DataManager.saveData(player)
	sessionData[player.UserId] = nil
end)

return DataManager
