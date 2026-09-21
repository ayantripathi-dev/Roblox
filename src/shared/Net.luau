--[[
	Net
	Single source of truth for every remote event name.
	The server creates the whole set at boot (no Studio wiring needed) and the
	client waits for exactly the same list, so the two sides can never drift.

	Rule of thumb: the server is authoritative. The client only ever *asks*.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

Net.FOLDER = "Events"

-- Client -> server
Net.REQUESTS = {
	"Click", -- ()
	"Sell", -- ()
	"BuyUpgrade", -- (trackId)
	"Hatch", -- (eggName, count)
	"Equip", -- (petId)
	"Unequip", -- (petId)
	"SellPet", -- (petId)
	"Rebirth", -- ()
	"RedeemCode", -- (code)
	"ClaimQuest", -- (questId)
	"RerollQuests", -- ()
	"ClaimDaily", -- ()
	"ClaimIndex", -- (eggName)
	"RequestState", -- ()
	"RequestLeaderboard", -- ()
	"PromptPass", -- (passKey)
	"PromptProduct", -- (productKey)
}

-- Server -> client
Net.SIGNALS = {
	"Notify", -- ({ text, kind, icon })
	"Reward", -- ({ title, subtitle, coins, power, luck, pet, rarity })
	"HatchResult", -- ({ results, best, isNew, eggName })
	"SaleResult", -- ({ power, coins })
	"StateSnapshot", -- (full inventory + quests + stats)
	"QuestUpdate", -- (quest list)
	"LeaderboardData", -- ({ rows, updatedAt })
	"Celebrate", -- ({ kind = "rebirth", rebirths, multiplier })
	"OfflineReward", -- ({ coins, seconds })
	"OpenPanel", -- (panelName) - sent when a player activates a world prompt
}

Net.ALL = {}
for _, name in ipairs(Net.REQUESTS) do
	table.insert(Net.ALL, name)
end
for _, name in ipairs(Net.SIGNALS) do
	table.insert(Net.ALL, name)
end

local function folder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(Net.FOLDER)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = Net.FOLDER
	created.Parent = ReplicatedStorage
	return created
end

--[[
	Server: create (or repair) every remote and return name -> RemoteEvent.
	Old builds of the place may already contain some of these; they are reused.
]]
function Net.ensure(): { [string]: RemoteEvent }
	local parent = folder()
	local remotes: { [string]: RemoteEvent } = {}
	for _, name in ipairs(Net.ALL) do
		local existing = parent:FindFirstChild(name)
		if existing and not existing:IsA("RemoteEvent") then
			existing:Destroy()
			existing = nil
		end
		local remote = existing :: RemoteEvent?
		if not remote then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = parent
		end
		remotes[name] = remote
	end
	return remotes
end

--[[
	Client: wait for the server to publish the remote set.
]]
function Net.waitForAll(timeout: number?): { [string]: RemoteEvent }
	local parent = ReplicatedStorage:WaitForChild(Net.FOLDER, timeout or 30)
	local remotes: { [string]: RemoteEvent } = {}
	if type(parent) ~= "Instance" then
		warn("[Net] Events folder never replicated - is the server running?")
		return remotes
	end
	for _, name in ipairs(Net.ALL) do
		local remote = parent:WaitForChild(name, 15)
		if remote and remote:IsA("RemoteEvent") then
			remotes[name] = remote
		else
			warn(`[Net] Missing remote: {name}`)
		end
	end
	return remotes
end

return Net
