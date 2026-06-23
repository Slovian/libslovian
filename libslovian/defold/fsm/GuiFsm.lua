-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local GuiFsm = require("libslovian.defold.fsm.GuiFsm")
--
-- GUI-focused FSM; handlers receive STATE as `self`.
-- Requires: local Class = require("libslovian.core.Class")

local Class = require("libslovian.core.Class")

local GuiFsm = {}

-- Schema builder: define states once, instantiate per gui_script.
function GuiFsm.defineFsm(initial_state_id)
	assert(initial_state_id ~= nil, "GuiFsm: initial state id required")

	-- Base State "class" (for mixin helpers on state instances)
	local StateBase = Class:extend()
	function StateBase:id() return self._id end
	function StateBase:owner() return self._fsm.owner end
	function StateBase:vars() return self._fsm.vars end
	function StateBase:flag(name, default)
		local f = self.flags
		if f and f[name] ~= nil then return f[name] end
		return default
	end
	function StateBase:goTo(state_id) self._fsm:_request_goTo(state_id) end

	-- FSM Class (instance per GUI)
	local FsmClass = Class:extend()
	FsmClass._states_proto = {}     -- id -> state prototype (metatable)
	FsmClass._initial = initial_state_id
	FsmClass.initializer = nil      -- function(vars)
	FsmClass.finalizer = nil        -- function(vars)

	-- Optional global init/final hooks
	function FsmClass:addInitializer(init_fn, final_fn)
		self.initializer = init_fn
		self.finalizer = final_fn
		return self
	end

	-- Add a state and get its prototype to attach handlers/flags.
	-- Handlers (all optional), called with STATE as `self`:
	--   function State:activate(prev_id) -> next_id?
	--   function State:deactivate(next_id)
	--   function State:update(dt) -> next_id?
	--   function State:on_input(action_id, action) -> next_id?
	--   function State:on_message(message_id, message, sender) -> next_id?
	--   function State:on_internal_message(internal_id, message) -> next_id?
	function FsmClass:addState(state_id, state_proto)
		assert(state_id ~= nil, "GuiFsm:addState requires id")
		state_proto = state_proto or {}
		-- Inherit helper methods
		setmetatable(state_proto, StateBase)
		state_proto.__index = state_proto
		state_proto.flags = state_proto.flags or nil
		self._states_proto[state_id] = state_proto
		return state_proto
	end

	-- Construct a live FSM instance bound to a GUI `self` (owner)
	function FsmClass:new(owner)
		local inst = Class.new(self)
		inst.owner = owner
		inst.vars = { owner = owner } -- shared bag if you need it
		inst._state_id = self._initial
		inst._next_state_id = nil
		inst._in_handler = false
		inst._states = {} -- id -> state INSTANCE (with its own locals)

		-- Create state instances (so each can hold its own locals)
		for id, proto in pairs(self._states_proto) do
			local s = setmetatable({ _id = id }, proto)
			s._fsm = inst
			inst._states[id] = s
		end

		return inst
	end

	-- Public API -------------------------------------------------------------

	function FsmClass:state_id() return self._state_id end
	function FsmClass:state() return assert(self._states[self._state_id]) end
	function FsmClass:flag(name, default) return self:state():flag(name, default) end

	function FsmClass:init()
		if self.initializer then self.initializer(self.vars) end
		self:_enter(self._state_id, nil)
	end

	function FsmClass:final()
		self:_leave(self._state_id, nil)
		if self.finalizer then self.finalizer(self.vars) end
	end

	function FsmClass:goTo(state_id) self:_transition(state_id) end

	function FsmClass:update(dt) self:_dispatch("update", dt) end
	function FsmClass:on_input(action_id, action) self:_dispatch("on_input", action_id, action) end
	function FsmClass:on_message(message_id, message, sender) self:_dispatch("on_message", message_id, message, sender) end

	function FsmClass:internal_message(internal_id, message)
		self:_dispatch("on_internal_message", internal_id, message)
	end

	-- Internals -------------------------------------------------------------

	function FsmClass:_request_goTo(state_id)
		if not state_id or state_id == self._state_id then return end
		if self._in_handler then
			self._next_state_id = state_id
		else
			self:_transition(state_id)
		end
	end

	function FsmClass:_enter(to_id, from_id)
		local st = assert(self._states[to_id], ("GuiFsm: unknown state '%s'"):format(tostring(to_id)))
		if st.activate then
			local next_id = st:activate(from_id)
			if next_id and next_id ~= to_id then
				self:_transition(next_id)
			end
		end
	end

	function FsmClass:_leave(from_id, to_id)
		local st = self._states[from_id]
		if st and st.deactivate then st:deactivate(to_id) end
	end

	function FsmClass:_transition(to_id)
		if not to_id or to_id == self._state_id then return end
		local from_id = self._state_id
		self:_leave(from_id, to_id)
		self._state_id = to_id
		self:_enter(to_id, from_id)
	end

	function FsmClass:_dispatch(method, ...)
		local st = self:state()
		local handler = st[method]
		if not handler then return end

		self._in_handler = true
		local next_id = handler(st, ...)
		self._in_handler = false

		if next_id and next_id ~= self._state_id then
			self:_transition(next_id)
		end

		if self._next_state_id then
			local queued = self._next_state_id
			self._next_state_id = nil
			self:_transition(queued)
		end
	end

	return FsmClass
end

return GuiFsm
