# SuperSimulator

A complete, working Roblox simulator — not a starter template. Tap the cube, sell power,
buy upgrades, hatch pets, complete the index, rebirth, repeat. Everything is server
authoritative, save data survives crashes, the UI is built from code, and the balance is
tested in a terminal instead of by playing for an hour.

Built with [Rojo](https://rojo.space) + Luau. No paid assets, no plugins, no Studio wiring
to do by hand.

```
src/
  shared/    config + pure helpers (replicated to the client)
             Constants, Upgrades, Pets, Quests, Codes, Net, Icons, Utils
  server/    services: data, economy, requests, world
  client/    UI: HUD, panels, followers, theme (studs + icons)
tests/       headless Luau tests + a progression simulation
docs/        BALANCE.md - every number, and how to retune it
```

## Play it

```bash
rojo serve            # then in Roblox Studio: Rojo plugin -> Connect -> Play
```

The plaza, the power cube, the sell pad, the egg pedestals, the kiosks and the leaderboard
board are all built from code at server start (`src/server/World.luau`), so an empty
Baseplate is enough. Local play works with DataStores disabled (Studio falls back to a
transient save and tells you in the UI).

To regenerate the place file from the project:

```bash
rojo build -o SuperSimulator.rbxlx
```

> The committed `SuperSimulator.rbxlx` / `.rbxmx` are older builds from before the
> gameplay rework — rebuild them with the command above before opening them.

## Look and feel: studded surfaces, real icons

The UI uses the classic raised-brick **stud** surface for its chrome - the HUD bar,
panel headers and footers, the loading screen and the in-world kiosk screens - and every
icon is an `ImageLabel` driven by one registry (`src/shared/Icons.luau`).

There are **no emojis anywhere in the project**, and no icon can render broken:

| Situation | What you see |
| --- | --- |
| `Id = 0` for an icon (the default) | the icon is **drawn** as clean vector-style shapes (coin, paw, egg, trophy, gem...) |
| You paste a Creator Store id | the decal is used instead, tinted to match the theme |
| The id is wrong, deleted or moderated | it falls back to the drawn icon automatically |

Swapping in Creator Store art takes one edit per icon:

1. Open the decal/image on `create.roblox.com` - the id is the number in the URL
2. Paste it in `src/shared/Icons.luau`:

```lua
coin = { Id = 1234567890, Tint = Color3.fromRGB(255, 199, 82), Mark = "coin" },
```

3. Same for the studs texture if you prefer an image over the drawn studs:

```lua
Icons.StudsTexture = 1234567890 -- tileable studs image
```

Icons are referenced by **name** everywhere else (`Icon = "coin"`, `Notifier.toast(player,
msg, "gold", "pet")`, `track.Icon`), so the game logic never knows or cares whether an icon
is a decal or a drawing. The test suite fails if any config references an icon name that
does not exist, or a mark that the client cannot draw.

## Run the tests

```bash
lune run tests/run.luau
```

[Lune](https://lune-org.github.io/docs) is a standalone Luau runtime (one binary, no
Roblox needed). The suite loads the real `src/shared` files and checks:

- number formatting, commas, time and multiplier strings
- upgrade curves, rebirth costs, pet slots and luck math
- pet data integrity, odds that sum to 100%, luck moving odds toward rarity, deterministic rolls
- quest generation, code redemption rules, remote-name safety
- the icon registry: every icon referenced by the configs exists, and every mark has a drawing
- that **every file in `src/` compiles** (a fast syntax net for the server and client code)
- an hour-long **progression simulation**: time to first rebirth, coins per checkpoint,
  whether greedy play hits the save cap

`docs/BALANCE.md` explains every tuning knob, the one invariant that keeps the economy from
running away, and the pacing targets the simulation checks.

## What is in the game

**Core loop** — tap the floating power cube (or the on-screen button / space bar), sell on
the neon pad, buy upgrades, hatch pets, rebirth. Chain taps inside 1.5s to build a combo
multiplier up to 3x.

**Pets** — 5 eggs (gated behind rebirths), 7 rarities, weighted odds that luck bends toward
Legendary/Mythic/Secret. Equipped pets orbit your character and are visible to every other
player. The pet index pays out per completed egg and again for a full collection.

**Progression** — 4 upgrade tracks, rebirths for a permanent +25% multiplier and extra pet
slots, daily quests (3/day, scaled to your income), a 7-day daily streak with a free pet on
day 7, redeemable codes, offline income at 35% for up to 8 hours.

**Monetization** — 4 gamepasses and 4 developer products are already wired with receipt
handling, idempotent purchases (a purchase id is saved *before* granting) and pass bonuses
that flow into the economy. Every Id is `0` until you create the real ones, and the game is
fully playable in the meantime.

**Anti-exploit** — token-bucket rate limits per action, strike-based kicks, argument
validation on every remote, saves sanitized on load (unknown pets deleted, multipliers
recomputed from config, numbers clamped), session locks so two servers can't own one save.

## Architecture

| Server | Responsibility |
| --- | --- |
| `init.server.luau` | boot order, remote wiring, player lifecycle |
| `DataManager` | DataStores, session locks, autosave, defaults, sanitizing, replication |
| `Economy` | the only place multipliers are computed; publishes attributes |
| `GameService` | request layer for tapping, selling, pets, index, daily, offline income |
| `PetService` | hatching, equipping, selling, granting, follower replication |
| `QuestService` / `RebirthService` / `CodeService` | daily quests, prestige, codes |
| `LeaderboardService` | cross-server top 50 (OrderedDataStore) with a live fallback |
| `MarketplaceManager` / `Passes` | products, receipts, gamepass ownership and bonuses |
| `Notifier` | the single channel every message goes out on |
| `RateLimiter` | per-player token buckets |
| `World` | builds the plaza and forwards world interactions to the same handlers |

| Client | Responsibility |
| --- | --- |
| `init.client.luau` | waits for remotes + save, then routes signals into the UI |
| `HUD` | currencies, rates, tap/combos, dock, toasts, floats, reward + hatch modals |
| `Panels` | shop, eggs, pets, quests, index, rebirth, daily, codes, ranks, store |
| `Followers` | renders every player's equipped pets, distance-culled |
| `Theme` | palette, studs, icons, marks and the component builders |

| Shared | Responsibility |
| --- | --- |
| `Constants` | every tuning number |
| `Upgrades` / `Pets` / `Quests` / `Codes` | content and curves |
| `Icons` | the icon registry (name -> Creator Store id + drawn mark + tint) |
| `Net` | the remote contract the server and client both build from |

The client never invents state: it renders player attributes and `StateSnapshot` payloads.
Two players always see the same numbers, and a modified client can only *ask*.

## Configure it for your game

1. **Balance** — edit `src/shared/Constants.luau`, `Upgrades.luau`, `Pets.luau`,
   `Quests.luau`, then run `lune run tests/run.luau` and read the pacing table.
2. **Codes** — append a line to `src/shared/Codes.luau`. `Coins`, `Power`, `Luck` (+
   minutes), `Pet` and an optional `Expires` are supported.
3. **Passes and products** — create them on the Roblox website, then set their `Id` in
   `Constants.MARKETPLACE`. The store panel lights up automatically, and anything still at
   `0` stays hidden and refuses to grant.
4. **Leaderboard** — `Constants.LEADERBOARD` publishes lifetime coins every 3 minutes and
   shows the top 10 on the physical board in the plaza.

## Ideas for the next pass

- Sound design: tap/hatch/rebirth cues (`SoundService` + a few asset ids) — currently silent
- Egg opening animation with a spinning shell before the reveal
- A second zone whose sell pad pays more, unlocked by rebirths
- Trading between players (needs a two-sided confirmation UI + escrow in `DataManager`)
- Roblox game page assets: thumbnails, icon, badges for rebirth milestones
- Analytics for the funnel (first tap → first hatch → first rebirth)
