# RPG Stats System

The RPG module separates **where stats come from** from **how they are used**. Instead of hardcoding `+5 damage` bonuses in your game logic, you compose stat sheets. The system resolves additive and multiplicative modifiers for you, and automatically drives time-based resource counters (HP, energy, ammo, etc.) from those stats.

## Concepts

- **RPGStatsSheet** — a single set of additive and/or multiplicative stat values.
  - Additives are summed: `{ Damage = 10 }` + `{ Damage = 5 }` → `15`.
  - Multipliers are multiplied: `{ Damage = 1.2 }` × `{ Damage = 1.5 }` → `1.8`.
  - Final value: `(base + additives) × multipliers`.
  - Sheets can have a parent sheet, so a child sheet inherits and stacks on top of the parent.

- **RPGStatsBook** — a named collection of sheets that acts as a single stat source.
  - Useful for `Base + Equipment + Buffs` style setups.
  - `book:get("Damage")` resolves every sheet inside the book.
  - Sheets can be added/removed at runtime.
  - A book can also have a parent book, so a weapon module can read from the ship's global stats plus its own modifiers.

- **RPGCounters** — automatically managed resource counters backed by a stat source.
  - `max_stat` caps the counter.
  - `regen_stat` adds value per second while below max.
  - `degen_stat` subtracts value per second while above zero.
  - Initial value can be a number or `"max"` to start at the current max stat.

## Quick example

```lua
local RPGStatsSheet = require("libslovian.core.rpg.RPGStatsSheet")
local RPGStatsBook  = require("libslovian.core.rpg.RPGStatsBook")
local RPGCounters   = require("libslovian.core.rpg.RPGCounters")

-- 1. Define base stats as a sheet.
local base = RPGStatsSheet:new({
    HP_max      = 100,
    HP_regen    = 2,      -- 2 HP per second
    Damage      = 10,
})

-- 2. Put it in a book.
local stats = RPGStatsBook:new({ Base = base })

-- 3. Add a temporary buff as another sheet.
stats:addSheet("Rage", RPGStatsSheet:new({ Damage = 5 }, { Damage = 1.25 }))

print(stats:get("Damage"))  -- (10 + 5) * 1.25 = 18.75

-- 4. Drive HP with a counter.
local defs = {
    HP = { max_stat = "HP_max", regen_stat = "HP_regen", degen_stat = "HP_degen", initial_value = "max" },
}
local counters = RPGCounters:new({ "HP" }, stats, defs)

-- Later, in update(dt):
counters:subtract("HP", 20)   -- take damage
counters:update(dt)
print(counters:get("HP"))     -- regenerates automatically
```

## Adding regeneration

Regeneration/degeneration is purely stats-driven. To make a character regenerate HP faster, just add an `HP_regen` modifier:

```lua
stats:addSheet("RegenBuff", RPGStatsSheet:new({ HP_regen = 5 }))
```

No counter logic changes.

## Combining sheets without mutation

`combine` mutates the caller. `combinedWith` returns a new sheet:

```lua
local merged = base:combinedWith(buff)
```

## Sheets as definitions, sheets as runtime buffs

A common pattern is to keep **constant definition sheets** (the raw numbers from a database or config) and **runtime sheets** (active buffs/debuffs) separate:

```lua
local definition = RPGStatsSheet:new(shipDef.stats)
local runtime    = RPGStatsBook:new({ Definition = definition })

-- Apply buffs by adding runtime sheets:
runtime:addSheet("Poisoned", RPGStatsSheet:new({ Speed = -20 }))
```

## Counters with multiple resources

```lua
local defs = {
    HP      = { max_stat = "HP_max",      regen_stat = "HP_regen",      initial_value = "max" },
    Energy  = { max_stat = "Energy_max",  regen_stat = "Energy_regen",  initial_value = "max" },
    Ammo    = { max_stat = "Ammo_max",    regen_stat = "Ammo_regen",    initial_value = "max" },
}

local counters = RPGCounters:new({ "HP", "Energy", "Ammo" }, stats, defs)
counters:subtract("Ammo", 1)   -- fire
counters:subtract("Energy", 5) -- boost
counters:update(dt)
```
