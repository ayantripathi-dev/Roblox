--[[
	Notifier
	Every piece of player-facing feedback goes through here so the client has a
	single set of payload shapes to render:

		toast()      - small message in the corner
		reward()     - big celebration popup (daily, index, code rewards...)
		hatch()      - egg reveal animation
		sale()       - coins flying into the HUD
		state()      - full inventory snapshot for the panels
		quests()     - quest list (progress / claim states)
		leaderboard()- global top rows
		celebrate()  - full screen moment (rebirth)
		offline()    - "welcome back" popup
	panel()      - asks the client to open a panel (world prompts)

	Toast kinds: "info" | "good" | "bad" | "gold" | "luck"
]]

local Notifier = {}

local remotes = nil

function Notifier.setup(remoteMap: { [string]: RemoteEvent })
	remotes = remoteMap
end

local function fire(name: string, player: Player, payload: any)
	if not remotes then
		warn("[Notifier] setup() was never called")
		return
	end
	local remote = remotes[name]
	if not remote then
		warn(`[Notifier] missing remote: {name}`)
		return
	end
	remote:FireClient(player, payload)
end

function Notifier.toast(player: Player, text: string, kind: string?, icon: string?)
	fire("Notify", player, {
		Text = text,
		Kind = kind or "info",
		Icon = icon,
	})
end

function Notifier.reward(player: Player, payload: any)
	payload.Title = payload.Title or "Reward"
	payload.Kind = payload.Kind or "gold"
	fire("Reward", player, payload)
end

function Notifier.hatch(player: Player, payload: any)
	fire("HatchResult", player, payload)
end

function Notifier.sale(player: Player, power: number, coins: number)
	fire("SaleResult", player, { Power = power, Coins = coins })
end

function Notifier.state(player: Player, payload: any)
	fire("StateSnapshot", player, payload)
end

function Notifier.quests(player: Player, quests: any, rerollsLeft: number)
	fire("QuestUpdate", player, { Quests = quests, RerollsLeft = rerollsLeft })
end

function Notifier.leaderboard(player: Player, payload: any)
	fire("LeaderboardData", player, payload)
end

function Notifier.celebrate(player: Player, payload: any)
	payload.Kind = payload.Kind or "rebirth"
	fire("Celebrate", player, payload)
end

function Notifier.offline(player: Player, coins: number, seconds: number)
	fire("OfflineReward", player, { Coins = coins, Seconds = seconds })
end

-- Asks the client to open one of its panels (used by world kiosks/prompts).
function Notifier.panel(player: Player, panelName: string)
	fire("OpenPanel", player, panelName)
end

-- Useful while building the game: watch rewards flow in the output window.
function Notifier.debug(player: Player, text: string)
	print(`[Notify] {player.Name}: {text}`)
end

return Notifier
