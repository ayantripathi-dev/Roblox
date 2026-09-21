# Balance

Every number in the game comes from two config files:

| File | Owns |
| --- | --- |
| `src/shared/Constants.luau` | the loop: tap power, combos, sell cooldown, auto-farm, rebirth costs, offline income, caps |
| `src/shared/Upgrades.luau` | the four upgrade curves (cost + value per level) |
| `src/shared/Pets.luau` | egg prices, pet weights, pet multipliers, index rewards |
| `src/shared/Quests.luau` | quest targets per tier and reward sizing |

Nothing else hardcodes gameplay math. `src/server/Economy.luau` is the only place that
combines them, and it is the same formula the UI reads, so a rebalance can never make the
screen lie.

## The loop

```
powerPerTap  = 1 * TapPower(level) * petMultiplier * rebirthMultiplier * combo
sellValue    = 1 * SellValue(level) * petMultiplier * rebirthMultiplier * passCoins
autoRate     = AutoFarm(level) * petMultiplier * rebirthMultiplier      (power / second)
income       = autoRate * sellValue                                    (coins / second)
luck         = LuckUpgrade(level) + passLuck + activeBoost
eggOdds      = weight * (1 + luck * rarity.luckScale)
```

So the game has three multipliers that stack: **upgrades** (linear-ish, reset by rebirth),
**pets** (exponential, permanent) and **rebirths** (+25% each, permanent). Upgrades are the
early game, pets are the engine that breaks walls, and rebirths are the price ladder you
climb with pets.

## Upgrade curves

```
cost(level)  = floor(BaseCost * CostGrowth ^ (level - 1))
value(level) = BaseValue * Growth ^ (level - 1)
```

**The one invariant that matters: `CostGrowth > Growth`.**

If a level's value grew faster than its cost, every purchase would pay for itself
instantly and buying levels would compound forever — the economy runs away and slams into
`Constants.LIMITS.MAX_NUMBER` inside one session, at which point the save clamp starts
eating income and the game feels broken. `tests/run.luau` asserts this for every track
(`"{track}: cost outgrows value"`), and the simulation reports whether an hour of play hits
the cap.

| Track | Base cost | CostGrowth | Growth | Max level | Level 30 costs |
| --- | --- | --- | --- | --- | --- |
| Tap Power | 75 | 1.70 | 1.50 | 30 | ~2.3e8 coins |
| Sell Value | 150 | 1.68 | 1.45 | 30 | ~3.9e8 coins |
| Auto-Farm | 500 | 1.66 | 1.42 | 30 | ~1.0e9 coins |
| Lucky | 25,000 | 1.75 | +0.25 luck/level | 25 | ~2.4e9 coins |

A track ending at level 30 is deliberate: a run finishes with a *finished shop* and the
next rebirth turns it back into a 30 second shopping spree. Endless upgrade levels are
what makes idle games feel like they have no shape.

## Rebirth ladder

```
cost(n)       = floor(25,000 * 3.4 ^ n)
multiplier(n) = 1 + 0.25 * n
petSlots(n)   = 3 + floor(n / 3)          (capped at 10)
```

Costs grow 3.4x per rebirth while earnings grow only 1.25x, so after the first ~15
rebirths each step needs better pets, not more tapping. That is the intended wall: it is
what makes hatching, the index and the secret pets matter.

The ladder's ceiling is `Constants.LIMITS.MAX_NUMBER` (currently 1e30). Change the cap and
the ladder length together — the test suite prints how far an hour of play gets.

## Measured pacing

`lune run tests/run.luau` simulates a player who taps 4 times a second, sells every 5
seconds, and buys the cheapest affordable upgrade forever (no combos, no pets — worst
case). Current output:

| Milestone | No pets | With 3x pets |
| --- | --- | --- |
| first rebirth (25k coins) | ~2m 55s | ~35s |
| coins at 5 minutes | 2.66T | — |
| coins at 60 minutes | 86.5T | — |
| upgrades after an hour | 30 / 30 / 30 / 25 | — |
| hits the 1e30 save cap | no | — |

Targets to keep in mind when you retune:

- **first rebirth under 5 minutes** — new players must feel progress before they decide to stay
- **an hour of play stays under the save cap** — otherwise the clamp silently eats income
- **the shop finishes in a session** — every track reaches `MaxLevel` within ~1 hour of greedy play
- **pets are a real multiplier** — a 3x pet bonus must measurably shorten the early game

## Pets

Odds use `weight * (1 + luck * rarity.luckScale)`, so luck mostly moves the tail:

| Rarity | luckScale |
| --- | --- |
| Common | 0 |
| Uncommon | 0.25 |
| Rare | 0.5 |
| Epic | 0.75 |
| Legendary | 1.0 |
| Mythic | 1.25 |
| Secret | 1.5 |

Pet multipliers step up inside every egg (the tests assert this), and eggs gate behind
rebirths (0, 0, 1, 3, 6), so the egg list is also the difficulty curve. Pet sell value is
`mult * 250 * (1 + 0.25 * rebirths)` — selling a duplicate is always a small refund, never
a shortcut.

## Offline + daily income

- Offline income pays `incomePerSecond * seconds away * 0.35`, capped at 8 hours, and only
  after 90 seconds away (`Constants.OFFLINE`).
- Daily rewards pay the greater of a base amount scaled by streak, or 90 seconds of the
  player's current income (`Constants.DAILY`), so the reward stays relevant at every stage.
- Quest rewards are expressed in *seconds of income* with a flat floor, so they never
  become worthless (`Rewards.celebrate` in `src/shared/Quests.luau`).

## How to retune

1. Change numbers in the config files only.
2. Run `lune run tests/run.luau`.
3. Read the pacing table and the two cap checks (`an hour of play stays under the save cap`,
   `first rebirth lands inside 5 minutes`).

The simulation is the fastest way to feel a change: an hour of play takes about a second to
evaluate, so you can try five versions of a curve before touching Roblox Studio.
