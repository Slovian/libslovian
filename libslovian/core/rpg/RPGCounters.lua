-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local RPGCounters = require("libslovian.core.rpg.RPGCounters")
--
-- Time-based resource counters backed by an RPGStats provider.
-- Typical uses: HP, energy, ammo, shield charge, heat, etc.
--
-- Real-world use cases:
--   * Ship HP / Energy: counters capped by *_max stats, regenerated per second.
--   * Weapon ammo: subtract on fire, regenerate or reload over time.
--   * Destructible objects: subtract HP on damage, destroy when zero.
--
-- Example:
--   local defs = {
--       HP = { max_stat = "HP_max", regen_stat = "HP_regen", degen_stat = "HP_degen", initial_value = "max" },
--   }
--   local counters = RPGCounters:new({ "HP" }, stats, defs)
--   counters:subtract("HP", 20)
--   counters:update(dt)
--   print(counters:get("HP"))

local DefaultDefinitions = require("libslovian.core.rpg.RPGCounterDefinitions")

local RPGCounters = {}
RPGCounters.__index = RPGCounters

local function get_def(definitions, name)
	return (definitions and definitions[name]) or DefaultDefinitions[name] or DefaultDefinitions.Default
end

local function resolve_initial(def, stats, override)
	if override ~= nil then
		return override
	end
	if def.initial_value == "max" then
		return stats:get(def.max_stat) or 0
	end
	return def.initial_value or 0
end

-- @param counterNames  Array of counter names to create (e.g. {"HP", "Energy"}).
-- @param stats         Object with :get(stat) -> number (RPGStatsSheet/Book or similar).
-- @param definitions   Optional counter-definition table. If a name is missing,
--                      falls back to the project's RPGCounterDefinitions or Default.
-- @param overrides     Optional table of initial values per counter name.
function RPGCounters:new(counterNames, stats, definitions, overrides)
	local cvals = {}
	for _, name in ipairs(counterNames) do
		local def = get_def(definitions, name)
		cvals[name] = resolve_initial(def, stats, overrides and overrides[name])
	end

	local rc = setmetatable({}, self)
	rc.mStats = stats
	rc.mCounters = cvals
	rc.mDefinitions = definitions
	return rc
end

function RPGCounters:addCounter(name, stats, definitions, initial)
	local def = get_def(definitions or self.mDefinitions, name)
	self.mCounters[name] = resolve_initial(def, stats or self.mStats, initial)
end

function RPGCounters:add(name, amount)
	local value = self.mCounters[name]
	if value ~= nil then
		local def = get_def(self.mDefinitions, name)
		local max_value = self.mStats:get(def.max_stat) or math.huge
		self.mCounters[name] = math.min(value + amount, max_value)
	end
end

function RPGCounters:subtract(name, amount)
	local value = self.mCounters[name]
	if value ~= nil then
		self.mCounters[name] = math.max(value - amount, 0)
	end
end

function RPGCounters:modify(name, amount)
	if amount >= 0 then
		self:add(name, amount)
	else
		self:subtract(name, -amount)
	end
end

function RPGCounters:update(dt)
	local counters = self.mCounters
	local stats = self.mStats
	for name, value in pairs(counters) do
		local def = get_def(self.mDefinitions, name)
		local max = stats:get(def.max_stat) or math.huge

		if value < max then
			local regen = stats:get(def.regen_stat) or 0
			if regen > 0 then
				value = math.min(value + regen * dt, max)
			end
		end

		if value > 0 then
			local degen = stats:get(def.degen_stat) or 0
			if degen > 0 then
				value = math.max(value - degen * dt, 0)
			end
		end

		counters[name] = value
	end
end

function RPGCounters:get(name)
	return self.mCounters[name]
end

return RPGCounters
