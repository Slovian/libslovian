-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local BehaviorTree = require("libslovian.core.BehaviorTree")
-----------------------------------------------------------------------------------------
-- General hierarchical behavior-tree resolver for grid/tactical games.
--
-- Supports nested nodes:
--   - { steps = { <node|step>... }, shuffle = { {idxs}... }, chance=?, mirror_x=? }
--   - { one_of = { <node|step>{ weight=? }... }, chance=?, mirror_x=? }
--   - primitive step (any table with optional `from`/`to` point tables):
--       { from={x=5,y=2}, to={x=5,y=4}, chance=?, ... }
--
-- Notes:
--   • Any node can set mirror_x=true to flip X in its whole subtree.
--   • mirrorY is taken from the context.
--   • chance on a node drops the entire subtree with probability 1-chance.
--
-- Usage:
--   local steps = BehaviorTree.resolve(root, {
--       mirrorX = false, mirrorY = false,
--       xMin = 1, xMax = 8, yMin = 1, yMax = 8,
--   })

local BehaviorTree = {}

-- -------------------- utils
local function parse_sq(s)
	if type(s) == "table" then return s.x, s.y end
	if type(s) ~= "string" or #s < 2 then return nil end
	local file = s:sub(1,1):lower()
	local rank = tonumber(s:sub(2))
	if not rank then return nil end
	local fx = string.byte(file) - string.byte('a') + 1
	return fx, rank
end

local function sq(x,y) return {x=x,y=y} end

local function rand_pick(list, weight_field)
	if not list or #list == 0 then return nil end
	if not weight_field then return list[math.random(#list)] end
	local total = 0
	for _,v in ipairs(list) do total = total + (v[weight_field] or 1) end
	local r = math.random() * total
	for _,v in ipairs(list) do
		r = r - (v[weight_field] or 1)
		if r <= 0 then return v end
	end
	return list[#list]
end

local function deepcopy(t)
	if type(t) ~= "table" then return t end
	local r = {}
	for k,v in pairs(t) do r[k] = deepcopy(v) end
	return r
end

local function clone_arr(a)
	local r = {}
	for i=1,#a do r[i]=a[i] end
	return r
end

local function shuffle_inplace(a)
	for i = #a, 2, -1 do
		local j = math.random(i)
		a[i], a[j] = a[j], a[i]
	end
end

-- -------------------- board / orientation
local function mirror_x(x, xMin, xMax) return xMin + xMax - x end
local function mirror_y(y, yMin, yMax) return yMin + yMax - y end

-- -------------------- normalization & transforms
local function maybe_drop(chance)
	if chance == nil then return false end
	return math.random() > chance
end

local function normalize_step_pick_targets(step)
	-- If "to" is a list → pick one at random
	if type(step.to) == "table" and #step.to > 0 and step.to[1] and type(step.to[1]) == "table" then
		step.to = deepcopy(rand_pick(step.to))
	end
	return step
end

local function normalize_squares(st)
	if st.from and type(st.from) ~= "table" then
		local fx, fy = parse_sq(st.from); st.from = fx and sq(fx,fy) or nil
	end
	if st.to and type(st.to) ~= "table" then
		local tx, ty = parse_sq(st.to); st.to = tx and sq(tx,ty) or nil
	end
	return st
end

local function apply_mirroring(st, mirrorX, mirrorY, xMin,xMax, yMin,yMax)
	if mirrorX then
		if st.from then st.from.x = mirror_x(st.from.x, xMin, xMax) end
		if st.to   then st.to.x   = mirror_x(st.to.x,   xMin, xMax) end
	end
	if mirrorY then
		if st.from then st.from.y = mirror_y(st.from.y, yMin, yMax) end
		if st.to   then st.to.y   = mirror_y(st.to.y,   yMin, yMax) end
	end
	return st
end

-- -------------------- node resolution (recursive)
-- Context tracks cumulative transforms
local function apply_shuffle_groups(steps, groups)
	if not groups or #groups == 0 then return steps end
	local ordered = clone_arr(steps)
	for _, grp in ipairs(groups) do
		local items, idxs = {}, {}
		for _, i in ipairs(grp) do
			if ordered[i] then
				table.insert(items, ordered[i])
				table.insert(idxs,  i)
			end
		end
		if #items > 1 then shuffle_inplace(items) end
		for k=1,#idxs do ordered[idxs[k]] = items[k] end
	end
	return ordered
end

-- A "primitive step" is something that has a `from` and `to`
local function is_primitive_step(node)
	return type(node) == "table" and node.from ~= nil and node.to ~= nil
end

-- Resolve a subtree to a flat array of primitive, normalized, mirrored steps.
local function resolve_node(node, ctx, acc, xMin,xMax,yMin,yMax)
	if not node or type(node) ~= "table" then return end

	-- chance on a node drops the whole subtree
	if maybe_drop(node.chance) then return end

	-- mirror_x on a node toggles X mirror for the whole subtree
	local mirrorX = ctx.mirrorX or false
	if node.mirror_x == true then mirrorX = not mirrorX end

	-- 1) ONE OF
	if node.one_of and type(node.one_of) == "table" then
		local choice = rand_pick(node.one_of, "weight")
		if choice then
			resolve_node(choice, { mirrorX = mirrorX, mirrorY = ctx.mirrorY }, acc, xMin,xMax,yMin,yMax)
		end
		return
	end

	-- 2) STEPS (sequence). Entries can be nodes or primitive steps.
	if node.steps and type(node.steps) == "table" then
		local staged = node.steps
		-- allow local shuffle (works on this node's step indices)
		if node.shuffle then staged = apply_shuffle_groups(node.steps, node.shuffle) end
		for _, child in ipairs(staged) do
			if is_primitive_step(child) then
				local s = deepcopy(child)
				if not maybe_drop(s.chance) then
					normalize_step_pick_targets(s)
					normalize_squares(s)
					apply_mirroring(s, mirrorX, ctx.mirrorY, xMin,xMax,yMin,yMax)
					table.insert(acc, s)
				end
			else
				resolve_node(child, { mirrorX = mirrorX, mirrorY = ctx.mirrorY }, acc, xMin,xMax,yMin,yMax)
			end
		end
		return
	end

	-- 3) FALLBACK: if this table looks like a step (after resolving from/to strings)
	if node.from or node.to then
		local s = deepcopy(node)
		if not maybe_drop(s.chance) then
			normalize_step_pick_targets(s)
			normalize_squares(s)
			apply_mirroring(s, mirrorX, ctx.mirrorY, xMin,xMax,yMin,yMax)
			table.insert(acc, s)
		end
	end
end

-- Normalize various root shapes into a single root node
local function normalize_root_node(root)
	-- 1) If someone passed { Opening = {...} }, unwrap it
	if root.Opening and type(root.Opening) == "table" then
		root = root.Opening
	end

	-- 2) If already a node (has steps or one_of), keep it
	if type(root) == "table" and (root.steps or root.one_of) then
		return root
	end

	-- 3) If it's a bare array of steps, wrap into { steps = ... }
	if type(root) == "table" and root[1] then
		return { steps = root }
	end

	-- 4) Otherwise, produce an empty sequence
	return { steps = {} }
end

--- Resolve a behavior tree into a flat array of primitive steps.
-- @param root The root node (see file header for supported shapes).
-- @param ctx Optional context table:
--   mirrorX  - start with X mirroring (default false)
--   mirrorY  - start with Y mirroring (default false)
--   xMin,xMax,yMin,yMax - grid bounds for mirroring (default 1,8,1,8)
-- @return Array of resolved primitive step tables.
function BehaviorTree.resolve(root, ctx)
	ctx = ctx or {}
	local acc = {}
	resolve_node(
		normalize_root_node(deepcopy(root)),
		{ mirrorX = ctx.mirrorX or false, mirrorY = ctx.mirrorY or false },
		acc,
		ctx.xMin or 1, ctx.xMax or 8,
		ctx.yMin or 1, ctx.yMax or 8
	)
	return acc
end

return BehaviorTree
