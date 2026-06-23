-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local RPGStatsBook = require("libslovian.core.rpg.RPGStatsBook")
--
-- Aggregates multiple named RPGStatsSheet instances with optional parent inheritance.
-- Useful when an entity has a base stat sheet plus dynamic modifiers from equipment,
-- buffs, or temporary effects.
--
-- Real-world use cases:
--   * Ship stats: Base sheet + engine/shield/weapon modifier sheets.
--   * Character stats: Base + equipment + buffs.
--   * Weapon modules: Module-specific stats combined with the ship's global stats.
--
-- Example:
--   local base = RPGStatsSheet:new({ HP_max = 100, Damage = 10 })
--   local book = RPGStatsBook:new({ Base = base })
--   book:addSheet("EngineBoost", RPGStatsSheet:new({ Speed = 50 }))
--   print(book:get("Speed"))  -- 50 (plus parent if set)

local Class = require("libslovian.core.Class")

local RPGStatsBook = Class:extend()

function RPGStatsBook:new(baseSheets, parent)
	local sc = Class.new(self)
	sc.mParent = parent
	sc.mList = {}

	if baseSheets then
		for sheetName, sheet in pairs(baseSheets) do
			sc.mList[sheetName] = sheet
		end
	end

	return sc
end

function RPGStatsBook:getComponents(stat)
	local add = 0.0
	local mul = 1.0

	for _, sheet in pairs(self.mList) do
		local a, m = sheet:getComponents(stat)
		add = add + a
		mul = mul * m
	end

	if self.mParent then
		local a, m = self.mParent:getComponents(stat)
		add = add + a
		mul = mul * m
	end

	return add, mul
end

function RPGStatsBook:get(stat)
	local add, mul = self:getComponents(stat)
	return add * mul
end

function RPGStatsBook:addSheet(sheetName, sheet)
	self.mList[sheetName] = sheet
end

function RPGStatsBook:removeSheet(sheetName)
	self.mList[sheetName] = nil
end

return RPGStatsBook
