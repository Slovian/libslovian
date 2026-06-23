-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2020
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Fragment = require("libslovian.defold.fragment.Fragment")
--
-- Common base fragment class.

local Class = require("libslovian.core.Class")

local Fragment = Class:extend()

function Fragment:new( owner )
	local f = Class.new( self )
	f.mOwner = owner
	return f
end

function Fragment:init(context)
end

function Fragment:final()
end

function Fragment:update(dt)
end

function Fragment:on_message( message_id, message, sender )
end

function Fragment:on_internal_message( internal_id, message )
end

function Fragment:internal_message( internal_id, message )
	self.mOwner:internal_message( internal_id, message )
end

function Fragment:on_input( action_id, action )
end

return Fragment