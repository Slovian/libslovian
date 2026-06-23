-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2020
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local ScriptFsm = require("libslovian.defold.fsm.ScriptFsm")
--
-- Script-based finite state machine.

local ScriptFsm = {}

ScriptFsm.__index = ScriptFsm

function ScriptFsm:defineFsm(startingState)
    local fsm =
    {
        -- initialize properties
        mStates = {},
        new = function(fsm, script)
            local i = {}
            -- meta
            setmetatable(i, fsm)
            -- props
            i.mCurrentState = nil
            i.mOwner = script

            local stateVars = {}
            i.mStateVariables = stateVars
            
            return i
        end
    }
    -- meta
    setmetatable(fsm, self)

    fsm.__index = fsm
    fsm.StartingState = startingState

    return fsm
end

function ScriptFsm:addInitializer(initializer, finalizer)
    self.mInitializer = initializer
    self.mFinalizer = finalizer
end

function ScriptFsm:addState(stateId, updateFunction, messageFunction, activationFunction, deactivationFunction, inputFunction, internalMessageFunction)
    local state =
    {
        update = updateFunction or function(vars, object, dt) end,
        on_message = messageFunction or function(vars, object, message_id, message, sender) end,
        on_input = inputFunction or function(vars, object, action_id, action) end,
        activate = activationFunction or function(vars, object, prevState) end,
        deactivate = deactivationFunction or function(vars, object, nextState) end,
        on_internal_message = internalMessageFunction or function(vars, object, internal_id, message) end,
    }
    self.mStates[stateId] = state
    return state
end

-- … your existing ScriptFsm code …

--------------------------------------------------------------------------------
-- “Fork” an FSM class so you can add/override without touching the original
--------------------------------------------------------------------------------
function ScriptFsm:extend(newStartingState)
    -- `self` is the FSM class you’re forking
    local ext = {}
    -- methods fall back to the base
    setmetatable(ext, { __index = self })
    -- instances fall back to ext
    ext.__index = ext
    -- shallow-copy the state-table so you can modify it locally
    ext.mStates = {}
    for id, state in pairs(self.mStates) do
        ext.mStates[id] = state
    end
    -- carry over initializer/finalizer
    ext.mInitializer = self.mInitializer
    ext.mFinalizer   = self.mFinalizer
    -- allow overriding the start state
    ext.StartingState = newStartingState or self.StartingState
    return ext
end

--------------------------------------------------------------------------------
-- Make a private copy of a single state so you can override its handlers
--------------------------------------------------------------------------------
function ScriptFsm:overrideState(stateId)
    local orig = self.mStates[stateId]
    if not orig then error(("State %s does not exist"):format(tostring(stateId))) end

    -- shallow-clone that one state
    local clone = {}
    for k,v in pairs(orig) do clone[k] = v end
    -- keep a handle on the “super” methods
    clone.super = orig

    self.mStates[stateId] = clone
    return clone
end

function ScriptFsm:setState(nextState)
    repeat
        local prevState = self.mCurrentState
        local state = nextState
        if state == prevState then
            return
        end
        nextState = nil
        if prevState then
            state = self.mStates[prevState].deactivate(self.mStateVariables, self.mOwner, state) or state
        end
        self.mCurrentState = state
        if state then
            nextState = self.mStates[state].activate(self.mStateVariables, self.mOwner, prevState)
        end
    until not nextState
end

function ScriptFsm:init(context)
    if self.mInitializer then
        self.mInitializer(self.mStateVariables, self.mOwner, context)
    end
    self:setState(self.StartingState)
end

function ScriptFsm:final()
    if self.mFinalizer then
        self.mFinalizer(self.mStateVariables, self.mOwner)
    end
end

function ScriptFsm:update(dt)
    local state = self.mCurrentState
    if state then
        local newState = self.mStates[state].update(self.mStateVariables, self.mOwner, dt)
        if newState and newState ~= state then
            self:setState(newState)
        end
    end
end

function ScriptFsm:on_message(message_id, message, sender)
    local state = self.mCurrentState
    if state then
        local newState = self.mStates[state].on_message(self.mStateVariables, self.mOwner, message_id, message, sender)
        if newState and newState ~= state then
            self:setState(newState)
        end
    end
end

function ScriptFsm:on_internal_message(internal_id, message)
    local state = self.mCurrentState
    if state then
        local newState = self.mStates[state].on_internal_message(self.mStateVariables, self.mOwner, internal_id, message)
        if newState and newState ~= state then
            self:setState(newState)
        end
    end
end

function ScriptFsm:on_input(action_id, action)
    local state = self.mCurrentState
    if state then
        local newState = self.mStates[state].on_input(self.mStateVariables, self.mOwner, action_id, action)
        if newState and newState ~= state then
            self:setState(newState)
        end
    end
end

return ScriptFsm