-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2019
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Utils = require("libslovian.core.Utils")
--
-- Common utilities module.

local Utils = {}

local seedLocal = {}

function Utils.FlattenDefinitionsArray( defTable )
	-- TODO: uniform order
	local flatTable = {}
	for name, def in pairs( defTable ) do
		table.insert( flatTable, def )
		def.Index = table.maxn( flatTable )
		def.Name = name
	end
	flatTable.__index = defTable
	setmetatable( flatTable, flatTable )
	return flatTable
end

function Utils.seedGenerate()
	return math.random( 268435455 )
end

function Utils.seedBegin( seed )
	-- store some random
	table.insert( seedLocal, math.random( 268435455 ) )
	-- override random seed
	math.randomseed( seed )
end

function Utils.seedEnd()
	-- bring back randomness
	local topSeed = table.remove( seedLocal )
	math.randomseed( topSeed )
end

function Utils.rotateSinCosXY(sin_yaw, cos_yaw, x, y)
	local x_new = x * cos_yaw - y * sin_yaw
	local y_new = x * sin_yaw + y * cos_yaw
	return x_new, y_new
end

function Utils.rotateYawXY(yaw, x, y)
	local sin_yaw = math.sin(yaw)
	local cos_yaw = math.cos(yaw)
	local x_new = x * cos_yaw - y * sin_yaw
	local y_new = x * sin_yaw + y * cos_yaw
	return x_new, y_new
end

function Utils.yawToXY(yaw, len)
	len = len or 1.0
	local sin_yaw = math.sin(yaw)
	local cos_yaw = math.cos(yaw)
	-- returns x, y
	return len * cos_yaw, len * sin_yaw
end

function Utils.yawToQuat(yaw)
	return vmath.quat_rotation_z(yaw)
end

function Utils.clamp(x, min, max)
	if x < min then return min
	elseif x > max then return max
	else return x end
end

function Utils.permuteTable(t)
	local count = #t
	if count < 2 then
		return
	end
	for i = 1, count - 1 do
		local j = math.random(i, count)
		local x = t[i]
		t[i] = t[j]
		t[j] = x
	end
end

function Utils.isOfClass(obj, class)
	-- get the object's class (its metatable)
	local mt = getmetatable(obj)
	-- walk up the inheritance chain
	while mt do
		if mt == class then
			return true
		end
		mt = mt.super
	end
	return false
end

return Utils