-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2020
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Class = require("libslovian.core.Class")
--
-- Base polimorphism module.

local Class = {}

Class.__index = Class

function Class:extend()
	local subclass = {}

	setmetatable( subclass, self )
	subclass.__index = subclass
	subclass.super = self

	return subclass
end

function Class:new()
	local o = {}

	setmetatable( o, self )

	return o
end

return Class