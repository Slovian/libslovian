-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local RPGStatsSheet = require("libslovian.core.rpg.RPGStatsSheet")
--
-- A single sheet of additive and multiplicative stat modifiers.
--
-- Real-world use cases:
--   * Base ship definition: Base = RPGStatsSheet:new({ HP_max = 100, Damage = 10 })
--   * Temporary buff:      Buff = RPGStatsSheet:new({ Damage = 5 }, { Damage = 1.2 })
--   * Parent chain:        ChildBuffSheet = RPGStatsSheet:new({...}, {...}, baseSheet)
--
-- Example:
--   local base = RPGStatsSheet:new({ HP_max = 100, Speed = 200 })
--   local buff = RPGStatsSheet:new({ Speed = 50 }, { Speed = 1.25 })
--   base:combine(buff)
--   print(base:get("Speed"))  -- (200 + 50) * 1.25 = 312.5

local RPGStatsSheet = {}
RPGStatsSheet.__index = RPGStatsSheet

function RPGStatsSheet:new(additives, multipliers, parent)
	local sc = {}
	setmetatable(sc, self)

	sc.parent = parent
	sc.mAdditives = {}
	sc.mMultipliers = {}

	if additives then
		for k, v in pairs(additives) do
			sc.mAdditives[k] = v
		end
	end
	if multipliers then
		for k, v in pairs(multipliers) do
			sc.mMultipliers[k] = v
		end
	end

	return sc
end

function RPGStatsSheet:getComponents(stat)
	local add = self.mAdditives[stat] or 0
	local mul = self.mMultipliers[stat] or 1

	if self.parent then
		local parentAdd, parentMul = self.parent:getComponents(stat)
		add = add + parentAdd
		mul = mul + parentMul
	end

	return add, mul
end

function RPGStatsSheet:get(stat)
	local add, mul = self:getComponents(stat)
	return add * mul
end

function RPGStatsSheet:setAdd(stat, value)
	self.mAdditives[stat] = value
end

function RPGStatsSheet:setMultiplier(stat, value)
	self.mMultipliers[stat] = value
end

function RPGStatsSheet:combine(other)
	for k, v in pairs(other.mAdditives) do
		self.mAdditives[k] = (self.mAdditives[k] or 0) + v
	end
	for k, v in pairs(other.mMultipliers) do
		self.mMultipliers[k] = (self.mMultipliers[k] or 1) * v
	end
end

function RPGStatsSheet:combinedWith(other)
	local combined = RPGStatsSheet:new()

	for k, v in pairs(self.mAdditives) do
		combined.mAdditives[k] = v
	end
	for k, v in pairs(other.mAdditives) do
		combined.mAdditives[k] = (combined.mAdditives[k] or 0) + v
	end

	for k, v in pairs(self.mMultipliers) do
		combined.mMultipliers[k] = v
	end
	for k, v in pairs(other.mMultipliers) do
		combined.mMultipliers[k] = (combined.mMultipliers[k] or 1) * v
	end

	return combined
end

return RPGStatsSheet
