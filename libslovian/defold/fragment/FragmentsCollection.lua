-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2024
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local FragmentsCollection = require("libslovian.defold.fragment.FragmentsCollection")
--
-- Collection of all fragments in the game object.

local MSG_POST_INIT = hash("post_init")

local FragmentsCollection = {}
FragmentsCollection.__index = FragmentsCollection

-----------------------------------------------------------------------------------------
-- Helper function to add dependencies for a fragment.
-- 'inoutList' is a lazy-initialized list of dependency records.
-- 'object' is the fragment being registered.
-- 'dependencies' is an optional list of fragments that 'object' depends on.
local function FragmentListDependencies(inoutList, object, dependencies)
	if not dependencies then
		return inoutList
	end
	
	-- For each dependency provided, add a record { dependency = <frag>, object = <frag> }.
	for _, dep in ipairs(dependencies) do
		if dep ~= nil then
			-- Lazy initialization of the dependency list.
			if not inoutList then
				inoutList = {}
			end
			table.insert(inoutList, { dependency = dep, object = object })
		end
	end
	return inoutList
end

-----------------------------------------------------------------------------------------
-- Computes dependency levels for fragments and sorts the 'list' in-place.
-- The 'dependencies' parameter is a list of dependency records, each of the form:
--   { dependency = <fragment>, object = <fragment> }
-- Each fragment's level is computed as: level = max( level(dependency) ) + 1,
-- with fragments having no dependencies defaulting to level 0.
local function FragmentListCompute(list, dependencies)
	if not dependencies then
		return
	end

	-- Memoization table for computed levels.
	local memo = {}

	-- Recursively compute the dependency level for a given fragment.
	local function computeLevel(frag)
		if memo[frag] then 
			return memo[frag] 
		end
		local maxLevel = 0
		-- Iterate over all dependency records to find those where 'frag' is the dependent.
		for _, record in ipairs(dependencies) do
			if record.object == frag then
				local depLevel = computeLevel(record.dependency)
				if depLevel + 1 > maxLevel then
					maxLevel = depLevel + 1
				end
			end
		end
		memo[frag] = maxLevel
		return maxLevel
	end

	-- Compute the level for each fragment in the list.
	for _, frag in ipairs(list) do
		computeLevel(frag)
	end

	-- Sort the list so that fragments with lower dependency levels come first.
	table.sort(list, function(a, b)
		return memo[a] < memo[b]
	end)
end

local function RegisterPostInit(context)
	if not context.post_init then
		msg.post("#script", MSG_POST_INIT)
		context.post_init = true
	end
end

-----------------------------------------------------------------------------------------
-- Constructor for FragmentsCollection.
function FragmentsCollection:new(owner)
	local i = {}
	setmetatable(i, FragmentsCollection)
	i.mOwner = owner
	i.mFragments = {}
	i.mUpdates = {}           -- List for update callbacks (plain fragment references)
	i.mMessages = {}          -- List for message callbacks
	i.mInternalMessages = {}   -- List for internal message callbacks
	i.mInputs = {}            -- List for input callbacks

	-- Provide a proxy for internal messages.
	local function internal_message(self, internal_id, message)
		i:internal_message(internal_id, message)
	end
	owner.internal_message = internal_message
	return i
end

-----------------------------------------------------------------------------------------
-- Adds a fragment to the collection.
function FragmentsCollection:addFragment(fragment)
	table.insert(self.mFragments, fragment)
end

-----------------------------------------------------------------------------------------
-- Initialize all fragments and compute the ordered callback lists.
-- @param definition   Table passed to each fragment as context.definition.
-- @param options      Optional table. Supported keys:
--                     spawnProperties - table (or function returning a table)
--                                       made available as context.spawnProperties.
function FragmentsCollection:init(definition, options)
	local fragmentsList = self.mFragments
	local updatesList = self.mUpdates
	local messagesList = self.mMessages
	local internalMsgList = self.mInternalMessages
	local inputsList = self.mInputs
	local processedFragment
	local processedFragmentIndex
	local context

	options = options or {}
	local spawnProperties = options.spawnProperties
	if type(spawnProperties) == "function" then
		spawnProperties = spawnProperties()
	end

	-- Function to retrieve a dependency fragment given its class.
	local funGetDependency = function(fragmentClass)
		for _, fragment in ipairs(fragmentsList) do
			if fragment.__index == fragmentClass then
				return fragment
			end
		end
		return nil
	end

	-- Initialization dependency support
	local initDependencies
	local funRegisterInitDependency = function(fragmentClass)
		local fragmentsCount = #fragmentsList
		if processedFragmentIndex < fragmentsCount then
			for i = processedFragmentIndex+1, #fragmentsList do
				if fragmentsList[i].__index == fragmentClass and (not initDependencies or initDependencies[i] == nil) then
					fragmentsList[i]:init(context)
					initDependencies = initDependencies or {}
					initDependencies[i] = true
				end
			end
		end
		
	end

	-- Dependency lists for each type of callback.
	local dependenciesOnUpdate
	local funRegisterOnUpdate = function(deplist)
		table.insert(updatesList, processedFragment)
		dependenciesOnUpdate = FragmentListDependencies(dependenciesOnUpdate, processedFragment, deplist)
	end

	local dependenciesOnMessage
	local funRegisterOnMessage = function(deplist)
		table.insert(messagesList, processedFragment)
		dependenciesOnMessage = FragmentListDependencies(dependenciesOnMessage, processedFragment, deplist)
	end

	local dependenciesInternalMessage
	local funRegisterInternalMessage = function(deplist)
		table.insert(internalMsgList, processedFragment)
		dependenciesInternalMessage = FragmentListDependencies(dependenciesInternalMessage, processedFragment, deplist)
	end

	local dependenciesOnInput
	local funRegisterOnInput = function(deplist)
		table.insert(inputsList, processedFragment)
		dependenciesOnInput = FragmentListDependencies(dependenciesOnInput, processedFragment, deplist)
	end

	-- Lazy initialization for a shared blackboard.
	local blackboard
	local function getBlackboard()
		if not blackboard then
			blackboard = {}
			self.mBlackboard = blackboard
		end
		return blackboard
	end

	-- Create the context to be passed to each fragment.
	context =
	{
		definition = definition,
		getBlackboard = getBlackboard,
		getDependency = funGetDependency,
		initDependency = funRegisterInitDependency,
		registerOnUpdate = funRegisterOnUpdate,
		registerOnMessage = funRegisterOnMessage,
		registerOnInternalMsg = funRegisterInternalMessage,
		registerOnInput = funRegisterOnInput,
		registerPostInit = RegisterPostInit,
		spawnProperties = spawnProperties,
	}

	-- Initialize each fragment with the shared context.
	for i, fragment in ipairs(fragmentsList) do
		processedFragment = fragment
		processedFragmentIndex = i
		fragment:init(context)
	end

	-- Compute the final sorted order for each callback list based on dependencies.
	FragmentListCompute(updatesList, dependenciesOnUpdate)
	FragmentListCompute(messagesList, dependenciesOnMessage)
	FragmentListCompute(internalMsgList, dependenciesInternalMessage)
	FragmentListCompute(inputsList, dependenciesOnInput)
end

-----------------------------------------------------------------------------------------
-- Calls the final method on each fragment.
function FragmentsCollection:final()
	for _, fragment in ipairs(self.mFragments) do
		fragment:final()
	end
end

-----------------------------------------------------------------------------------------
-- Iterates over the update callback list and calls update(dt) on each fragment.
function FragmentsCollection:update(dt)
	for _, fragment in ipairs(self.mUpdates) do
		fragment:update(dt)
	end
end

-----------------------------------------------------------------------------------------
-- Iterates over the message callback list and calls on_message on each fragment.
function FragmentsCollection:on_message(message_id, message, sender)
	for _, fragment in ipairs(self.mMessages) do
		fragment:on_message(message_id, message, sender)
	end
end

-----------------------------------------------------------------------------------------
-- Iterates over the internal message callback list and calls internal_message on each fragment.
function FragmentsCollection:internal_message(internal_id, message)
	for _, fragment in ipairs(self.mInternalMessages) do
		fragment:on_internal_message(internal_id, message)
	end
end

-----------------------------------------------------------------------------------------
-- Iterates over the input callback list and calls on_input on each fragment.
function FragmentsCollection:on_input(action_id, action)
	for _, fragment in ipairs(self.mInputs) do
		fragment:on_input(action_id, action)
	end
end

return FragmentsCollection
