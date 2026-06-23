-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local DynamicModulesFragment = require("libslovian.defold.fragment.DynamicModulesFragment")
--
-- Base fragment for managing a dynamic set of child fragments at runtime.
-- Useful for modular equipment, temporary buffs, spawned modules, etc.

local Fragment = require("libslovian.defold.fragment.Fragment")

local DynamicModulesFragment = Fragment:extend()

function DynamicModulesFragment:new(owner)
	local f = Fragment.new(self, owner)
	f.mDynamicFragments = {}  -- active child fragments
	return f
end

-- 'context' is the original context provided by FragmentsCollection.
-- 'dynamicDefs' is an optional array of definitions for child fragments.
-- Each entry is a table with:
--    { class = <DynamicFragment class>, data = <module-specific init data> }
function DynamicModulesFragment:init(context, dynamicDefs)
	context.registerOnUpdate()
	context.registerOnMessage()
	context.registerOnInternalMsg()
	context.registerOnInput()

	if dynamicDefs then
		-- Minimal context template shared by all dynamic children.
		local dynamicContext = {
			getDependency = context.getDependency,
			getBlackboard = context.getBlackboard,
			modulesFragment = self,
			-- 'definition' is set per child before init.
		}

		for _, def in ipairs(dynamicDefs) do
			local frag = def.class:new(self.mOwner)
			dynamicContext.definition = def
			self:addDynamicFragment(frag, dynamicContext)
		end
	end
end

function DynamicModulesFragment:addDynamicFragment(dynamicFragment, dynamicContext)
	table.insert(self.mDynamicFragments, dynamicFragment)
	dynamicFragment:init(dynamicContext)
end

function DynamicModulesFragment:removeDynamicFragment(dynamicFragment)
	for i, frag in ipairs(self.mDynamicFragments) do
		if frag == dynamicFragment then
			table.remove(self.mDynamicFragments, i)
			frag:final()
			return true
		end
	end
	return false
end

function DynamicModulesFragment:update(dt)
	for _, frag in ipairs(self.mDynamicFragments) do
		frag:update(dt)
	end
end

function DynamicModulesFragment:on_message(message_id, message, sender)
	for _, frag in ipairs(self.mDynamicFragments) do
		frag:on_message(message_id, message, sender)
	end
end

function DynamicModulesFragment:on_internal_message(internal_id, message)
	for _, frag in ipairs(self.mDynamicFragments) do
		frag:on_internal_message(internal_id, message)
	end
end

function DynamicModulesFragment:on_input(action_id, action)
	for _, frag in ipairs(self.mDynamicFragments) do
		frag:on_input(action_id, action)
	end
end

function DynamicModulesFragment:final()
	for _, frag in ipairs(self.mDynamicFragments) do
		frag:final()
	end
	self.mDynamicFragments = {}
	DynamicModulesFragment.super.final(self)
end

return DynamicModulesFragment
