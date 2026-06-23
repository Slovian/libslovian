-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2024
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- Generic membership collection with versioning.
--
-- Real-world uses in void-vector:
--   * Global spawn-point registry: markers register by go.get_id() with { tags = {...} };
--     managers iterate the collection to pick a weighted random "player_spawn" point.
--   * Squadron / movement / affiliation registries: every agent registers itself so
--     gameplay systems can iterate all active squads, members, or faction groups.
--
-- Example:
--   local Collection = require("libslovian.defold.fragment.collections.BaseCollection")
--   local coll = Collection:new()
--   coll:registerMember(go.get_id(), { hp = 100 })
--   for id, props in coll:iterateMembers() do ... end
--   coll:unregisterMember(go.get_id())
--   if coll:getCurrentVersion() ~= lastVersion then ... end   -- detect changes

local Class = require("libslovian.core.Class")

local Collection = Class:extend()

function Collection:new()
	local ins = Class.new(self)
	ins.mMembers = {}
	ins.mVersion = 0
	return ins
end

function Collection:registerMember(member, properties)
	self.mMembers[member] = properties
	self.mVersion = self.mVersion + 1
end

function Collection:unregisterMember(member)
	self.mMembers[member] = nil
	self.mVersion = self.mVersion + 1
end

function Collection:getCurrentVersion()
	return self.mVersion
end

function Collection:iterateMembers()
	return pairs(self.mMembers)
end

function Collection:queryMember(member)
	return self.mMembers[member]
end

return Collection
