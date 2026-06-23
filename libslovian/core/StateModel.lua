-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local StateModel = require("libslovian.core.StateModel")
--
-- Base observable game-meta state class.
--
-- Similar to Settings, but intended for progression/state rather than user
-- preferences. Inherit and define your game-specific defaults, validators and
-- save target:
--
--   local StateModel = require("libslovian.core.StateModel")
--
--   local GameMeta = StateModel:extend()
--
--   function GameMeta:new()
--       local self = StateModel.new(self, {
--           saveTarget = msg.url("main:/app#script"),
--           codecKey   = "my_secret_key",      -- optional, configures TableCodec
--           defaults   = {
--               crowns       = 0,
--               currentLevel = 1,
--               battles      = {},
--               skins        = {},
--           },
--           validators = {
--               crowns       = function(v) return type(v) == "number" and v >= 0 end,
--               currentLevel = function(v) return type(v) == "number" and v >= 1 end,
--           },
--       })
--       return self
--   end
--
--   return GameMeta:new()

local Class      = require("libslovian.core.Class")
local TableCodec = require("libslovian.core.TableCodec")

local StateModel = Class:extend()

-- ---------------------------------------------------------------------------
-- Metamethods (class-level, shared by all instances and subclasses)
-- ---------------------------------------------------------------------------

local function lookup_method(cls, k)
	while cls do
		local v = rawget(cls, k)
		if v ~= nil then return v end
		cls = cls.super
	end
	return nil
end

StateModel.__index = function(t, k)
	-- Prevent instances from accidentally touching class machinery.
	if k == "new" or k == "extend" or k == "super" then
		return nil
	end

	-- 1) Look for an instance method in the class hierarchy.
	local cls = getmetatable(t)
	local v = lookup_method(cls, k)
	if v ~= nil then return v end

	-- 2) Fall back to stored data.
	return t._data[k]
end

StateModel.__newindex = function(t, k, v)
	if v == nil then
		error("Cannot set state field to nil: " .. tostring(k))
	end

	-- Known data key OR explicitly allowing unknown keys?
	if t._data[k] ~= nil or t._allow_unknown then
		t:set(k, v)
	else
		error("Unknown state field: " .. tostring(k))
	end
end

StateModel.__pairs = function(t)
	return next, t._data, nil
end

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function StateModel:new(config)
	local instance = Class.new(self)
	config = config or {}

	instance._data          = {}
	instance._codec         = config.codec or TableCodec
	instance._codecKey      = config.codecKey
	instance._validators    = config.validators or {}
	instance._allow_unknown = config.allowUnknown or false
	instance.save_target    = config.saveTarget -- optional msg.url

	-- If a per-instance key was supplied, create a private codec wrapper so we
	-- don't pollute the global TableCodec/Codec module.
	if instance._codecKey and instance._codec.encode_with_key and instance._codec.decode_with_key then
		local key = instance._codecKey
		local base = instance._codec
		instance._codec = {
			encode = function(_, value)
				local plain = base.serialize(value, { raw = true })
				return base.encode_with_key(plain, key)
			end,
			decode = function(_, str)
				local plain, why = base.decode_with_key(str, key)
				if not plain then return nil, why end
				return base.deserialize(plain)
			end,
		}
	end

	-- Fill defaults without triggering dirty flag.
	for k, v in pairs(config.defaults or {}) do
		rawset(instance._data, k, v)
	end

	instance._dirty = false
	return instance
end

-- ---------------------------------------------------------------------------
-- Dirty tracking
-- ---------------------------------------------------------------------------

function StateModel:mark_dirty()
	if self._dirty then return end
	self._dirty = true
	if self.save_target then
		msg.post(self.save_target, hash("save_progress"))
	end
end

function StateModel:is_dirty()
	return self._dirty
end

function StateModel:clear_dirty()
	self._dirty = false
end

-- ---------------------------------------------------------------------------
-- Data access
-- ---------------------------------------------------------------------------

function StateModel:get(key)
	return self._data[key]
end

function StateModel:set(key, value)
	if value == nil then
		error("Cannot set state field to nil: " .. tostring(key))
	end

	local validator = self._validators[key]
	if validator and not validator(value) then
		error("Invalid state value for " .. tostring(key))
	end

	local old = self._data[key]
	if old ~= value then
		rawset(self._data, key, value)
		self:mark_dirty()
	end

	return self
end

--- Get a copy of all current state as a plain table.
function StateModel:to_table()
	local copy = {}
	for k, v in pairs(self._data) do
		copy[k] = v
	end
	return copy
end

-- ---------------------------------------------------------------------------
-- Serialization
-- ---------------------------------------------------------------------------

local function codec_encode(codec, value)
	if codec.encode then
		return codec:encode(value)
	end
	return codec.serialize(value)
end

local function codec_decode(codec, str)
	if codec.decode then
		return codec:decode(str)
	end
	return codec.deserialize(str)
end

function StateModel:to_string()
	local ok, out = pcall(codec_encode, self._codec, self._data)
	if not ok then
		print("StateModel.to_string error:", out)
		return nil, false
	end

	return out, true
end

function StateModel:from_string(s)
	if type(s) ~= "string" or #s == 0 then return false end

	local ok, decoded = pcall(codec_decode, self._codec, s)
	if not ok or decoded == nil or type(decoded) ~= "table" then
		if not ok then print("StateModel.from_string decode error:", decoded) end
		return false
	end

	-- Validate all known keys that are present in the payload.
	for key, validator in pairs(self._validators) do
		if decoded[key] ~= nil and not validator(decoded[key]) then
			print("StateModel.from_string validation failed for:", key)
			return false
		end
	end

	-- Import only known keys atomically.
	for key, _ in pairs(self._data) do
		if decoded[key] ~= nil then
			rawset(self._data, key, decoded[key])
		end
	end

	self._dirty = false
	return true
end

return StateModel
