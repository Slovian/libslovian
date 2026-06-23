-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Settings = require("libslovian.core.Settings")
-----------------------------------------------------------------------------------------
-- Base observable settings class.
--
-- Inherit and provide your game-specific defaults, app name and save file:
--
--   local Settings = require("libslovian.core.Settings")
--   local StateModel = require("libslovian.core.StateModel")
--
--   local GameSettings = Settings:extend()
--
--   function GameSettings:new()
--       local self = Settings.new(self, {
--           saveApp  = "my_game",
--           saveFile = "settings.json",
--           defaults = {
--               play_music  = true,
--               play_sound  = true,
--               difficulty  = 1,
--               -- any other game-specific settings
--           },
--           stateModel = StateModel, -- optional
--       })
--       return self
--   end
--
--   return GameSettings:new()

local Class = require("libslovian.core.Class")

local Settings = Class:extend()

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

Settings.__index = function(t, k)
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

Settings.__newindex = function(t, k, v)
	if v == nil then
		error("Cannot set setting to nil: " .. tostring(k))
	end

	local old = t._data[k]
	if old ~= v then
		if old == nil then
			error("Unknown setting: " .. tostring(k))
		end
		rawset(t._data, k, v)
		t:_notify(k, v, old)
	end
end

Settings.__pairs = function(t)
	return next, t._data, nil
end

-- ---------------------------------------------------------------------------
-- Constructor
-- ---------------------------------------------------------------------------

function Settings:new(config)
	local instance = Class.new(self)
	config = config or {}

	instance._saveApp      = config.saveApp  or "app"
	instance._saveFile     = config.saveFile or "settings.json"
	instance._data         = {}
	instance._listeners    = {}
	instance._nextListenerId = 0
	instance._stateModel   = config.stateModel -- optional

	-- Fill defaults without triggering listeners.
	for k, v in pairs(config.defaults or {}) do
		rawset(instance._data, k, v)
	end

	return instance
end

-- ---------------------------------------------------------------------------
-- Listener helpers
-- ---------------------------------------------------------------------------

function Settings:_notify(key, new, old)
	local list = self._listeners[key]
	if not list then return end
	for id, cb in pairs(list) do
		local ok, err = pcall(cb, new, old)
		if not ok then
			print("Settings listener error for " .. tostring(key) .. ":", err)
		end
	end
end

--- Register a callback for a specific setting.
-- @param key      Setting name.
-- @param id       Arbitrary listener id (used for removal).
-- @param fn       function(new_value, old_value)
function Settings:addListener(key, id, fn)
	local list = self._listeners[key]
	if not list then
		list = {}
		self._listeners[key] = list
	end
	list[id] = fn
end

function Settings:removeListener(key, id)
	local list = self._listeners[key]
	if list then
		list[id] = nil
	end
end

--- Convenience one-shot listener registration. Returns an unsubscribe function.
function Settings:on(key, fn)
	self._nextListenerId = self._nextListenerId + 1
	local id = self._nextListenerId
	self:addListener(key, id, fn)
	return function() self:removeListener(key, id) end
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

--- Save current settings to persistent storage.
-- Returns true if the write was accepted by the platform.
function Settings:save()
	local savePath = sys.get_save_file(self._saveApp, self._saveFile)

	if self._stateModel then
		self._data.meta = self._stateModel:to_string()
		self._stateModel:clear_dirty()
	end

	return sys.save(savePath, self._data) or false
end

--- Load settings from persistent storage.
-- Only known keys are applied; unknown keys are ignored.
-- Assignments go through __newindex so listeners fire if values change.
-- Returns true if a non-empty save was found and processed.
function Settings:load()
	local savePath = sys.get_save_file(self._saveApp, self._saveFile)
	local t = sys.load(savePath)
	if not t or next(t) == nil then
		return false
	end

	for k, _ in pairs(self._data) do
		if t[k] ~= nil then
			self[k] = t[k]
		end
	end

	if self._stateModel and self._data.meta and self._data.meta ~= "" then
		self._stateModel:from_string(self._data.meta)
	end

	return true
end

--- Direct getter (useful when you have a dynamic key).
function Settings:get(key)
	return self._data[key]
end

--- Direct setter, bypasses __newindex and fires listeners.
function Settings:set(key, value)
	if value == nil then
		error("Cannot set setting to nil: " .. tostring(key))
	end

	local old = self._data[key]
	if old == nil then
		error("Unknown setting: " .. tostring(key))
	end

	if old ~= value then
		rawset(self._data, key, value)
		self:_notify(key, value, old)
	end
	return self
end

--- Get a copy of all current settings as a plain table.
function Settings:to_table()
	local copy = {}
	for k, v in pairs(self._data) do
		copy[k] = v
	end
	return copy
end

return Settings
