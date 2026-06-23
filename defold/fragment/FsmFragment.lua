-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2024
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- General implementation of FSM based fragment, that receives FSM object and can do whatever we want with it
-- local FsmFragment = require("libslovian.defold.fragment.FsmFragment")

local Fragment = require("libslovian.defold.fragment.Fragment")

local FsmFragment = Fragment:extend()

function FsmFragment:new(owner, fsmclass)
	local f = Fragment.new(self, owner)
	f.fsm = fsmclass:new(owner)
	return f
end

function FsmFragment:init(context)
	context.registerOnUpdate()
	context.registerOnMessage()
	context.registerOnInternalMsg()
	context.registerOnInput()	

	self.fsm:init(context)
end

function FsmFragment:final()
	self.fsm:final()
end

function FsmFragment:update(dt)
	-- Update logic to handle turn transitions
	self.fsm:update(dt)
end

function FsmFragment:on_message(message_id, message, sender)
	-- Handle messages relevant to turn management
	self.fsm:on_message(message_id, message, sender)
end

function FsmFragment:on_internal_message( internal_id, message )
	-- Handle messages relevant to turn management
	self.fsm:on_internal_message(internal_id, message)
end

function FsmFragment:on_input(action_id, action)
	self.fsm:on_input(action_id, action)
end

return FsmFragment
