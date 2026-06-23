-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local TraitsCollection = require("libslovian.defold.fragment.collections.TraitsCollection")
-- local collection = TraitsCollection:new()
--
-- Mirrors baseCollection, plus fast trait-aware queries:
--   :registerMember(member, {"fighter","fast"})   -- strings or numeric ids
--   :unregisterMember(member)
--   :iterateMembers()                              -- pairs iterator
--   :queryMember(member)                           -- original traits array
--   :getCurrentVersion()
--   :byTrait("fighter")                            -- fast single-trait iterator
--   :matchAll({"fighter","cloaked"})               -- members with ALL traits

local Class  = require("libslovian.core.Class")
local Traits = require("libslovian.core.Traits")

-----------------------------------------------------------
-- Tiny utilities
-----------------------------------------------------------
local function weak_set() return setmetatable({}, {__mode="k"}) end

local function make_sig_from_ids(ids)
	local sig = {}
	for i = 1, #ids do
		local id  = ids[i]
		local w   = math.floor((id - 1) / 32) + 1
		local bp  = bit.band(id - 1, 31)
		sig[w]    = bit.bor(sig[w] or 0, bit.lshift(1, bp))
	end
	return sig
end

local function has_trait(sig, id)
	local w  = math.floor((id - 1) / 32) + 1
	local bp = bit.band(id - 1, 31)
	local v  = sig[w]
	return v and bit.band(v, bit.lshift(1, bp)) ~= 0
end

local function sig_match(sig, want)
	for w, mask in pairs(want) do
		if bit.band(sig[w] or 0, mask) ~= mask then return false end
	end
	return true
end

-----------------------------------------------------------
-- Minimal treap
-----------------------------------------------------------
local function rot_left(p)  local r=p.right; p.right=r.left; r.left=p; return r end
local function rot_right(p) local l=p.left;  p.left =l.right; l.right=p; return l end

local function tr_insert(node, obj, sig, ids, leafMax)
	if not node then
		local root = { objects = weak_set(), count = 0, priority = math.random() }
		root.objects[obj] = true
		root.count = 1
		return root
	end
	if node.objects then
		node.objects[obj] = true
		node.count = node.count + 1
		if node.count > leafMax then
			node.pivot = ids[1]
			node.left  = { objects = weak_set(), count = 0, priority = math.random() }
			node.right = { objects = weak_set(), count = 0, priority = math.random() }
			for o in pairs(node.objects) do
				local tgt = has_trait(o.__sig, node.pivot) and node.left or node.right
				tgt.objects[o] = true
				tgt.count = tgt.count + 1
			end
			node.objects = nil
		end
		return node
	end
	local goLeft = has_trait(sig, node.pivot)
	if goLeft then node.left  = tr_insert(node.left,  obj, sig, ids, leafMax)
	else           node.right = tr_insert(node.right, obj, sig, ids, leafMax) end
	node.count = node.count + 1
	if     node.left  and node.left.priority  < node.priority then node = rot_right(node)
	elseif node.right and node.right.priority < node.priority then node = rot_left(node) end
	return node
end

local function tr_remove(node, obj, sig)
	if not node then return nil end
	if node.objects then
		if node.objects[obj] then
			node.objects[obj] = nil
			node.count = node.count - 1
			if node.count == 0 then return nil end
		end
		return node
	end
	local goLeft = has_trait(sig, node.pivot)
	if goLeft then node.left  = tr_remove(node.left,  obj, sig)
	else           node.right = tr_remove(node.right, obj, sig) end
	node.count = (node.left  and node.left.count  or 0) +
	             (node.right and node.right.count or 0)
	if node.count == 0 then return nil end
	return node
end

local function tr_collect(node, wantSig, out)
	if not node then return end
	if node.objects then
		for o in pairs(node.objects) do
			if sig_match(o.__sig, wantSig) then out[#out+1] = o end
		end
	else
		if has_trait(wantSig, node.pivot) then tr_collect(node.left,  wantSig, out) end
		tr_collect(node.right, wantSig, out)
	end
end

-----------------------------------------------------------
-- TraitsCollection proper
-----------------------------------------------------------
local TraitsCollection = Class:extend()

function TraitsCollection:new()
	local ins = Class.new(self)
	ins.mMembers = {}
	ins.mVersion = 0
	ins._rev     = {}     -- id → weak set
	ins._root    = nil    -- treap root
	ins._leafMax = 64
	return ins
end

local function traits_to_ids(traits)
	local ids = {}
	if #traits > 0 and type(traits[1]) == "number" then
		for i = 1, #traits do ids[i] = traits[i] end
	else
		for i = 1, #traits do ids[i] = Traits(traits[i]) end
	end
	return ids
end

function TraitsCollection:registerMember(member, traits)
	if self.mMembers[member] then self:unregisterMember(member) end

	local ids = traits_to_ids(traits)
	local sig = make_sig_from_ids(ids)
	member.__sig = sig

	for i = 1, #ids do
		local id  = ids[i]
		local set = self._rev[id] or weak_set(); self._rev[id] = set
		set[member] = true
	end

	self._root    = tr_insert(self._root, member, sig, ids, self._leafMax)
	self.mMembers[member] = { traits = traits, ids = ids }
	self.mVersion = self.mVersion + 1
end

function TraitsCollection:unregisterMember(member)
	local rec = self.mMembers[member]; if not rec then return end
	for _, id in ipairs(rec.ids) do
		local set = self._rev[id]; if set then set[member] = nil end
	end
	self._root    = tr_remove(self._root, member, member.__sig)
	member.__sig  = nil
	self.mMembers[member] = nil
	self.mVersion = self.mVersion + 1
end

function TraitsCollection:getCurrentVersion() return self.mVersion end
function TraitsCollection:iterateMembers()    return pairs(self.mMembers) end
function TraitsCollection:queryMember(m)      return self.mMembers[m] and self.mMembers[m].traits end

function TraitsCollection:byTrait(key)
	local id = type(key) == "number" and key or Traits._registry.name2id[key]
	local set = id and self._rev[id]
	return set and pairs(set) or function() end
end

function TraitsCollection:matchAll(list)
	local ids = {}
	for i = 1, #list do
		local v = list[i]
		local id = type(v) == "number" and v or Traits._registry.name2id[v]
		if not id then return function() end end
		ids[i] = id
	end
	local wantSig = make_sig_from_ids(ids)
	local buf, idx = {}, 0
	tr_collect(self._root, wantSig, buf)
	return function()
		idx = idx + 1
		local m = buf[idx]
		if m then return m, self.mMembers[m] end
	end
end

return TraitsCollection
