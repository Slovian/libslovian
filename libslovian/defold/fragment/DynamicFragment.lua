-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- Base class for fragments that can be added and removed during an object's lifetime.
-- Typically managed by a DynamicModulesFragment.
--
-- local DynamicFragment = require("libslovian.defold.fragment.DynamicFragment")

local Fragment = require("libslovian.defold.fragment.Fragment")

local DynamicFragment = Fragment:extend()

function DynamicFragment:new(owner)
	local f = Fragment.new(self, owner)
	return f
end

function DynamicFragment:init(context, definition)
	-- Forward only the shared context to the base Fragment initializer.
	DynamicFragment.super.init(self, context)
	-- `definition` is optional and usually provided by the host DynamicModulesFragment.
end

return DynamicFragment
