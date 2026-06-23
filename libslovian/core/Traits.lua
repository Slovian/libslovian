-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- Trait utilities: string↔id interner and bit-set signature builder.
--
-- local Traits = require("libslovian.core.Traits")
-- local id  = Traits("bomber")
-- local ids = Traits.ids("fighter", "fast")
-- local sig = Traits.sig("fighter", "fast", "cloaked")

local Traits = {}

local REG = { next = 1, name2id = {}, id2name = {} }

local function intern(name)
	local id = REG.name2id[name]
	if not id then
		id = REG.next
		REG.next = id + 1
		REG.name2id[name] = id
		REG.id2name[id] = name
	end
	return id
end

-- Traits("bomber") → id
setmetatable(Traits, {
	__call = function(_, name) return intern(name) end
})

-- Traits.ids("a", "b") → {idA, idB}
function Traits.ids(...)
	local n, out = select("#", ...), {}
	for i = 1, n do
		out[i] = intern(select(i, ...))
	end
	return out
end

-- Traits.sig("a", "b", "c") → sparse bit-set signature
function Traits.sig(...)
	local sig = {}
	for _, id in ipairs(Traits.ids(...)) do
		local w  = math.floor((id - 1) / 32) + 1
		local bp = bit.band(id - 1, 31)
		sig[w]   = bit.bor(sig[w] or 0, bit.lshift(1, bp))
	end
	return sig
end

-- Expose registry for debugging / editor tooling
Traits._registry = REG

return Traits
