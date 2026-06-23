-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Codec = require("libslovian.core.Codec")
--
-- Configurable obfuscation + integrity codec for Lua tables.
--
-- Usage:
--   local Codec = require "libslovian.core.Codec"
--   Codec.configure({
--       prefix    = "MYGAME1",           -- format/version tag
--       pepper    = "change_me_per_build", -- secret salt
--       validator = function(t) return type(t) == "table" end, -- optional
--   })
--   local s, ok = Codec.encode(meta_table)
--   local t, ok = Codec.decode(s)

local Codec = {}

-- Default config. You MUST call Codec.configure before encode/decode in production.
local _config = {
	prefix    = "SLV1",
	pepper    = "",
	validator = nil,
}

--- Configure the codec.
-- @param config table with optional keys:
--   prefix    - format/version tag embedded in the output string
--   pepper    - secret salt used for checksum and keystream seed
--   validator - function(t) returning true if decoded table is acceptable
function Codec.configure(config)
	config = config or {}
	if config.prefix    ~= nil then _config.prefix    = config.prefix end
	if config.pepper    ~= nil then _config.pepper    = config.pepper end
	if config.validator ~= nil then _config.validator = config.validator end
end

-- Utilities -------------------------------------------------------------------
local function tohex32(n)  return string.format("%08x", bit.band(n, 0xffffffff)) end
local function fromhex32(h) return tonumber(h, 16) end

-- FNV-1a 32-bit (keyed checksum)
local function fnv1a32(str, seed)
	local h = seed or 2166136261
	for i = 1, #str do
		h = bit.bxor(h, str:byte(i))
		h = bit.tobit(h * 16777619)
	end
	return bit.band(h, 0xffffffff)
end

-- xorshift32 PRNG → byte stream for XOR
local function make_xs32(seed)
	local x = bit.band(seed, 0xffffffff)
	return function()
		x = bit.bxor(x, bit.lshift(x, 13))
		x = bit.bxor(x, bit.rshift(x, 17))
		x = bit.bxor(x, bit.lshift(x, 5))
		return bit.band(x, 0xffffffff)
	end
end

local function xor_stream_bytes(s, seed)
	local next32 = make_xs32(seed)
	local out, key, kpos = {}, 0, 0
	for i = 1, #s do
		if kpos == 0 then key, kpos = next32(), 4 end
		local kbyte = bit.band(bit.rshift(key, (kpos - 1) * 8), 0xff)
		out[i] = string.char(bit.bxor(s:byte(i), kbyte))
		kpos = kpos - 1
	end
	return table.concat(out)
end

-- Tiny Base64 (pure Lua, standard alphabet)
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64_IDX = {}
for i = 1, #B64 do B64_IDX[B64:sub(i,i)] = i - 1 end

local function b64_encode(data)
	local bytes = { data:byte(1, #data) }
	local out, pad = {}, ({ "", "==", "=" })[#bytes % 3 + 1]
	for i = 1, #bytes, 3 do
		local a = bytes[i]     or 0
		local b = bytes[i + 1] or 0
		local c = bytes[i + 2] or 0
		local n = a * 65536 + b * 256 + c
		local s1 = math.floor(n / 262144) % 64
		local s2 = math.floor(n / 4096)   % 64
		local s3 = math.floor(n / 64)     % 64
		local s4 = n % 64
		out[#out+1] = B64:sub(s1+1, s1+1)
		out[#out+1] = B64:sub(s2+1, s2+1)
		out[#out+1] = B64:sub(s3+1, s3+1)
		out[#out+1] = B64:sub(s4+1, s4+1)
	end
	if pad ~= "" then
		out[#out] = pad == "==" and "=" or out[#out]
		out[#out-1] = "="
	end
	return table.concat(out)
end

local function b64_decode(data)
	data = data:gsub("[^%w%+/=]", "")
	local out = {}
	for i = 1, #data, 4 do
		local c1 = B64_IDX[data:sub(i, i)]           or 0
		local c2 = B64_IDX[data:sub(i+1, i+1)]       or 0
		local c3 = B64_IDX[data:sub(i+2, i+2)]       or 0
		local c4 = B64_IDX[data:sub(i+3, i+3)]       or 0
		local n = c1 * 262144 + c2 * 4096 + c3 * 64 + c4
		local a = math.floor(n / 65536) % 256
		local b = math.floor(n / 256)   % 256
		local c = n % 256
		out[#out+1] = string.char(a)
		out[#out+1] = string.char(b)
		out[#out+1] = string.char(c)
	end
	local eq = (data:sub(-2) == "==") and 2 or (data:sub(-1) == "=" and 1 or 0)
	if eq > 0 then out[#out] = nil end
	if eq > 1 then out[#out] = nil end
	return table.concat(out)
end

-- IV generator (32-bit) — mix time, address entropy, and a counter
local _ctr = 0
local function gen_iv()
	_ctr = (_ctr + 1) % 0x7fffffff
	local addr = tostring({}):match("0x(%x+)") or "0"
	local seed = tostring(os.time()) .. "|" .. addr .. "|" .. tostring(_ctr)
	return bit.band(fnv1a32(seed), 0xffffffff)
end

-- Public API ------------------------------------------------------------------

--- Encode a Lua table → opaque integrity-protected string.
-- Returns (string, true) on success or (nil, false) on failure.
function Codec.encode(t)
	local ok, payload = pcall(json.encode, t)
	if not ok or type(payload) ~= "string" then return nil, false end

	local iv     = gen_iv()
	local iv_hex = tohex32(iv)
	local pepper = _config.pepper

	local chk = fnv1a32(pepper .. iv_hex .. payload)
	local chk_hex = tohex32(chk)

	local seed = fnv1a32(pepper .. iv_hex)
	local cipher = xor_stream_bytes(payload, seed)
	local blob   = b64_encode(cipher)

	local out = table.concat({ _config.prefix, iv_hex, chk_hex, blob }, ":")
	return out, true
end

--- Decode opaque string → Lua table.
-- Returns (table, true) on success or (nil, false) on failure.
function Codec.decode(s)
	if type(s) ~= "string" then return nil, false end

	local p, iv_hex, chk_hex, b64 = s:match("^(" .. _config.prefix .. "):([0-9a-fA-F]{8}):([0-9a-fA-F]{8}):(.+)$")
	if p ~= _config.prefix or not iv_hex or not chk_hex or not b64 then
		return nil, false
	end

	local iv  = fromhex32(iv_hex)
	local chk = fromhex32(chk_hex)
	if not iv or not chk then return nil, false end

	local cipher = b64_decode(b64)
	if #cipher == 0 then return nil, false end

	local pepper = _config.pepper
	local seed = fnv1a32(pepper .. iv_hex)
	local plaintext = xor_stream_bytes(cipher, seed)

	local chk_now = fnv1a32(pepper .. iv_hex .. plaintext)
	if chk_now ~= chk then return nil, false end

	local ok, t = pcall(json.decode, plaintext)
	if not ok then return nil, false end

	if _config.validator and not _config.validator(t) then
		return nil, false
	end

	return t, true
end

-- Backward-compatible aliases
Codec.to_string = Codec.encode
Codec.from_string = Codec.decode

return Codec
