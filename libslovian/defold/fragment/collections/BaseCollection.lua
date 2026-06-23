-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2024
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- Generic membership collection with versioning.
-- local Collection = require("libslovian.defold.fragment.collections.BaseCollection")
-- local myColl = Collection:new()

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
