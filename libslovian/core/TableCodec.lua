-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2019
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local TableCodec = require("libslovian.core.TableCodec")
-- Serialize/deserialize Lua tables with optional obfuscating string codec.
-- Defold/LuaJIT 5.1 friendly (no deps).

local M = {}

----------------------------------------------------------------
-- Utilities: array detection, stable map ordering, value emit
----------------------------------------------------------------
local function is_integer(n) return type(n) == "number" and n == math.floor(n) end

local function is_array(t)
	local n, count = 0, 0
	for k in pairs(t) do
		count = count + 1
		if is_integer(k) and k > 0 then if k > n then n = k end else return false, 0 end
	end
	for i = 1, n do if t[i] == nil then return false, 0 end end
	return count == n, n
end

local function key_repr(k)
	local tk = type(k)
	if tk == "string" then return "[" .. string.format("%q", k) .. "]"
	elseif tk == "number" or tk == "boolean" then return "[" .. tostring(k) .. "]"
	else error("Unsupported key type: " .. tk) end
end

local function sort_keys(keys)
	table.sort(keys, function(a,b)
		local ta,tb = type(a), type(b)
		if ta ~= tb then return ta < tb end
		if ta == "number" then return a < b else return tostring(a) < tostring(b) end
	end)
end

local function encode_value(v, stack)
	local tv = type(v)
	if tv == "nil" or tv == "boolean" then return tostring(v)
	elseif tv == "number" then
		if v ~= v or v == math.huge or v == -math.huge then error("Cannot serialize NaN/Inf") end
		return tostring(v)
	elseif tv == "string" then
		return string.format("%q", v)
	elseif tv == "table" then
		if stack[v] then error("Circular reference detected") end
		stack[v] = true
		local parts = {}
		local as_array, n = is_array(v)
		if as_array then
			table.insert(parts, "{")
			for i=1,n do if i>1 then parts[#parts+1] = "," end parts[#parts+1] = encode_value(v[i], stack) end
			parts[#parts+1] = "}"
		else
			local keys = {}
			for k in pairs(v) do keys[#keys+1] = k end
			sort_keys(keys)
			parts[#parts+1] = "{"
			local first = true
			local i = 1
			while v[i] ~= nil do
				if not first then parts[#parts+1] = "," end
				first = false
				parts[#parts+1] = encode_value(v[i], stack)
				i = i + 1
			end
			for _,k in ipairs(keys) do
				if not (is_integer(k) and k > 0 and k < i) then
					if not first then parts[#parts+1] = "," end
					first = false
					parts[#parts+1] = key_repr(k) .. "=" .. encode_value(v[k], stack)
				end
			end
			parts[#parts+1] = "}"
		end
		stack[v] = nil
		return table.concat(parts)
	else
		error("Unsupported value type: " .. tv)
	end
end

----------------------------------------------------------------
-- Public table (de)serialization
----------------------------------------------------------------
function M.serialize(value, opts)
	local s = encode_value(value, {})
	if M._encode_string and not (opts and opts.raw) then
		return M._encode_string(s)
	end
	return s
end

function M.deserialize(str)
	assert(type(str) == "string", "deserialize expects a string")
	if M._decode_string then
		local ok, decoded_or_err, why = pcall(M._decode_string, str)
		if not ok then return nil, ("decode codec error: " .. tostring(decoded_or_err)) end
		if decoded_or_err == nil then return nil, why or "decode: checksum failed" end
		str = decoded_or_err
	end

	local chunk, err
	if loadstring then
		chunk, err = loadstring("return " .. str)
		if not chunk then return nil, ("deserialize syntax error: " .. tostring(err)) end
		local env = {}
		setfenv(chunk, env)
		local ok, res = pcall(chunk)
		if not ok then return nil, ("deserialize runtime error: " .. tostring(res)) end
		return res
	else
		chunk, err = load("return " .. str, "tbl", "t", {})
		if not chunk then return nil, ("deserialize syntax error: " .. tostring(err)) end
		local ok, res = pcall(chunk)
		if not ok then return nil, ("deserialize runtime error: " .. tostring(res)) end
		return res
	end
end

-- Backward-compat aliases:
M.encode = M.serialize
M.decode = M.deserialize

----------------------------------------------------------------
-- String codec API
----------------------------------------------------------------
function M.configure_string_codec(encode_fn, decode_fn)
	assert(type(encode_fn) == "function" and type(decode_fn) == "function",
	"configure_string_codec expects (function, function)")
	M._encode_string = encode_fn
	M._decode_string = decode_fn
end

----------------------------------------------------------------
-- Built-in obfuscating codec (Base64 + XOR keystream + CRC32)
-- Layout (before Base64): [ 'T','C','1', ver(1) | nonce(4) | crc32(4) | payload(N) ] XOR stream
--   * ver = 1
--   * crc32 is computed over plaintext payload only
--   * XOR stream generated via xorshift32 seeded from (nonce ⊕ keyhash)
----------------------------------------------------------------

-- tiny CRC32 (IEEE 802.3) ----------------
local bit      = bit or require("bit")
local band     = bit.band
local bor      = bit.bor
local bxor     = bit.bxor
local bnot     = bit.bnot
local lshift   = bit.lshift
local rshift   = bit.rshift

local function make_crc32_table()
	local t = {}
	for i = 0, 255 do
		local c = i
		for _ = 1, 8 do
			if band(c, 1) ~= 0 then
				c = bxor(0xEDB88320, rshift(c, 1))
			else
				c = rshift(c, 1)
			end
		end
		t[i] = c
	end
	return t
end

local CRC32_T = make_crc32_table()

local function crc32(s)
	local c = 0xFFFFFFFF
	for i = 1, #s do
		local b = s:byte(i)
		c = bxor(CRC32_T[band(bxor(c, b), 0xFF)], rshift(c, 8))
	end
	return band(bxor(c, 0xFFFFFFFF), 0xFFFFFFFF)
end

-- base64 (no deps) -----------------------
local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64LUT = {}
for i = 1, #B64 do B64LUT[B64:sub(i,i)] = i-1 end

local function b64encode(bin)
	local t, n = {}, #bin
	for i = 1, n, 3 do
		local a, b, c = bin:byte(i, i+2)
		local x = bor(lshift(a or 0, 16), lshift(b or 0, 8), (c or 0))
		local pad = (i+2>n) and 1 or 0; if (i+1>n) then pad = 2 end
		local o1 = band(rshift(x, 18), 63)
		local o2 = band(rshift(x, 12), 63)
		local o3 = band(rshift(x,  6), 63)
		local o4 = band(x, 63)
		t[#t+1] = B64:sub(o1+1,o1+1)
		t[#t+1] = B64:sub(o2+1,o2+1)
		t[#t+1] = (pad>=2) and '=' or B64:sub(o3+1,o3+1)
		t[#t+1] = (pad>=1) and '=' or B64:sub(o4+1,o4+1)
	end
	return table.concat(t)
end

local function b64decode(txt)
	txt = txt:gsub("%s","")
	local t = {}
	for i = 1, #txt, 4 do
		local a = B64LUT[txt:sub(i,i)]       or 0
		local b = B64LUT[txt:sub(i+1,i+1)]   or 0
		local cch = txt:sub(i+2,i+2); local dch = txt:sub(i+3,i+3)
		local c = (cch == '=') and nil or (B64LUT[cch] or 0)
		local d = (dch == '=') and nil or (B64LUT[dch] or 0)
		local x = bor(lshift(a,18), lshift(b,12), lshift((c or 0),6), (d or 0))
		local b1 = band(rshift(x,16), 255)
		local b2 = band(rshift(x, 8), 255)
		local b3 = band(x, 255)
		t[#t+1] = string.char(b1)
		if c then t[#t+1] = string.char(b2) end
		if d then t[#t+1] = string.char(b3) end
	end
	return table.concat(t)
end

-- xorshift32 keystream -------------------
local function xorshift32(x)
	x = bxor(x, band(lshift(x, 13), 0xFFFFFFFF))
	x = bxor(x, rshift(x, 17))
	x = bxor(x, band(lshift(x,  5), 0xFFFFFFFF))
	return band(x, 0xFFFFFFFF)
end

local function h32(s)
	-- simple Fowler–Noll–Vo (FNV-1a) 32-bit
	local h = 2166136261
	for i = 1, #s do
		h = band(bxor(h, s:byte(i)), 0xFFFFFFFF)
		h = band((h * 16777619), 0xFFFFFFFF)
	end
	return h
end

local function u32le(n)
	return string.char(band(n,255), band(rshift(n,8),255), band(rshift(n,16),255), band(rshift(n,24),255) )
end
local function leu32(s,i)
	local b1,b2,b3,b4 = s:byte(i,i+3)
	return bor(b1, lshift(b2,8), lshift(b3,16), lshift(b4,24))
end

-- Stateless default encode/decode helpers (keyed) -------------------------
function M.encode_with_key(plain, key)
	assert(type(key) == "string" and #key > 0, "encode_with_key: key must be a non-empty string")
	assert(type(plain) == "string", "encode_with_key: plain must be a string")
	local keyhash = h32(key)

	local ver   = 1
	local nonce = band(bxor(h32(tostring({})), h32(tostring(os.clock()))), 0xFFFFFFFF)
	local crc   = crc32(plain)
	local len   = #plain

	-- header (PLAINTEXT): "TC1" | ver(1) | nonce(4)
	local header = ("TC1") .. string.char(ver) .. u32le(nonce)

	-- tail (XOR'ed): CRC32(4) | LEN(4) | PAYLOAD(LEN)
	local tail   = u32le(crc) .. u32le(len) .. plain
	local seed   = band(bxor(nonce, keyhash), 0xFFFFFFFF)

	local out = { header }  -- header is not XORed
	local x = seed
	for i = 1, #tail do
		if (i-1) % 4 == 0 then x = xorshift32(x) end
		local ks = band(rshift(x, 8 * ((i-1) % 4)), 255)
		out[#out+1] = string.char(band(bxor(tail:byte(i), ks), 255))
	end

	return b64encode(table.concat(out))
end

function M.decode_with_key(cipher_b64, key)
	assert(type(key) == "string" and #key > 0, "decode_with_key: key must be a non-empty string")
	assert(type(cipher_b64) == "string", "decode_with_key: cipher must be a string")
	local keyhash = h32(key)

	local ok, frame = pcall(b64decode, cipher_b64)
	if not ok then return nil, "base64 decode failed" end
	if #frame < 8 + 8 then return nil, "frame too small" end

	-- header (PLAINTEXT)
	if frame:sub(1,3) ~= "TC1" then return nil, "bad magic" end
	local ver = frame:byte(4)
	if ver ~= 1 then return nil, "unsupported version" end
	local nonce = leu32(frame, 5)

	-- tail (XOR'ed): CRC32(4) | LEN(4) | PAYLOAD(LEN)
	local enc_tail = frame:sub(9)
	local seed = band(bxor(nonce, keyhash), 0xFFFFFFFF)

	local x = seed
	local tmp = {}
	for i = 1, #enc_tail do
		if (i-1) % 4 == 0 then x = xorshift32(x) end
		local ks = band(rshift(x, 8 * ((i-1) % 4)), 255)
		tmp[i] = string.char(band(bxor(enc_tail:byte(i), ks), 255))
	end
	local tail = table.concat(tmp)
	if #tail < 8 then return nil, "corrupt tail" end

	local crc  = leu32(tail, 1)
	local len  = leu32(tail, 5)
	if len < 0 or len > (#tail - 8) then return nil, "invalid length" end

	local payload = tail:sub(9, 8 + len)   -- **slice exactly LEN bytes**
	if crc32(payload) ~= crc then return nil, "checksum mismatch" end
	return payload
end

-- Exported helper: enable default codec with a key (global side-effect)
function M.use_default_codec(key)
	M.configure_string_codec(
		function(plain) return M.encode_with_key(plain, key) end,
		function(cipher) return M.decode_with_key(cipher, key) end
	)
end

----------------------------------------------------------------
-- Done
----------------------------------------------------------------
return M
