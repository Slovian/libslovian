-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Bevel = require("libslovian.defold.gui.Bevel")
--
-- Utility helpers for Defold GUI panels that use the packed‑constant bevel
-- material ("/libslovian/defold/gui/Bevel.material").
--
-- The material exposes four user constants:
--   base_color   : vec4 – RGBA fill
--   border_color : vec4 – RGBA rim
--   edge_data    : vec4 – x = round_px, y = border_px, z = bevel_px
--   size         : vec4 – x = width,    y = height                  (z,w unused)
--
-- This module applies the material, packs/unpacks edge_data, and keeps both
-- constants in sync whenever a node is resized.
--
-- Minimal example:
--   local Bevel = require "libslovian.defold.gui.Bevel"
--
--   function init(self)
--       self.panel = Bevel.new_panel(vmath.vector3(0,0,0), vmath.vector3(240,120,0), {
--           base       = vmath.vector4(0.25,0.30,0.90,1.0),
--           border     = vmath.vector4(0.08,0.10,0.45,1.0),
--           round_px   = 12,
--           border_px  = 3,
--           bevel_px   = 2,
--       })
--   end
--
--   function on_gui_update(self, dt)
--       -- Call this only if you animate width/height:
--       Bevel.refresh(self.panel)
--   end
--
-- Save this file as /libslovian/defold/gui/Bevel.lua and adjust DEFAULT_MATERIAL
-- if your material path differs.

local Bevel = {}

-- Constant hashes ------------------------------------------------------------
local BASE_COLOR   = hash("base_color")
local BORDER_COLOR = hash("border_color")
local EDGE_DATA    = hash("edge_data")
local SIZE_CONST   = hash("panel_size")

-- Public defaults ------------------------------------------------------------
Bevel.DEFAULT_MATERIAL       = hash("/libslovian/defold/gui/Bevel.material")
Bevel.DEFAULT_BASE_COLOR     = vmath.vector4(0.6, 0.6, 0.6, 1.0)
Bevel.DEFAULT_BORDER_COLOR   = vmath.vector4(0.2, 0.2, 0.2, 1.0)
Bevel.DEFAULT_ROUND_PX       = 8
Bevel.DEFAULT_BORDER_PX      = 2
Bevel.DEFAULT_BEVEL_PX       = 2

-- Internal helpers -----------------------------------------------------------
local function _set_edge_data(node, round_px, border_px, bevel_px)
	gui.set(node, EDGE_DATA, vmath.vector4(round_px, border_px, bevel_px, 0))
end

local function _set_size(node, w, h)
	gui.set(node, SIZE_CONST, vmath.vector4(w, h, 0, 0))
end

-- Public API -----------------------------------------------------------------

--- Apply bevel material and constants to an existing BOX node.
-- opts: { material, base, border, round_px, border_px, bevel_px }
function Bevel.apply(node, opts)
	opts = opts or {}

	gui.set_material(node, opts.material or Bevel.DEFAULT_MATERIAL)

	gui.set(node, BASE_COLOR,   opts.base   or Bevel.DEFAULT_BASE_COLOR)
	gui.set(node, BORDER_COLOR, opts.border or Bevel.DEFAULT_BORDER_COLOR)

	local size = gui.get_size(node)
	_set_size(node, size.x, size.y)
	_set_edge_data(node,
	opts.round_px  or Bevel.DEFAULT_ROUND_PX,
	opts.border_px or Bevel.DEFAULT_BORDER_PX,
	opts.bevel_px  or Bevel.DEFAULT_BEVEL_PX)

	return node
end

--- Create a new bevel panel (box node + material already set).
-- pos  : vmath.vector3 – node position
-- size : vmath.vector3 – node size (x,y; z ignored)
-- opts : same keys as apply (except size)
function Bevel.new_panel(pos, size, opts)
	local node = gui.new_box_node(pos, size)
	return Bevel.apply(node, opts)
end

--- Refresh width/height in the shader (call if node size changes).
function Bevel.refresh(node)
	local size = gui.get_size(node)
	_set_size(node, size.x, size.y)
end

--- Bulk setter: update any subset of parameters.
-- Pass nil to leave a field unchanged.
function Bevel.set(node, round_px, border_px, bevel_px, color_base, color_border)
	local size = gui.get_size(node)
	local k = gui.get_constant(node, EDGE_DATA)

	_set_size(node, size.x, size.y)
	_set_edge_data(node,
		round_px  or k.x,
		border_px or k.y,
		bevel_px  or k.z)

	if color_base then
		gui.set(node, BASE_COLOR, color_base)
	end
	if color_border then
		gui.set(node, BORDER_COLOR, color_border)
	end
end

--- Individual setters --------------------------------------------------------

function Bevel.set_base_color(node, color)
	gui.set(node, BASE_COLOR, color)
end

function Bevel.set_border_color(node, color)
	gui.set(node, BORDER_COLOR, color)
end

function Bevel.set_round_px(node, px)
	local k = gui.get_constant(node, EDGE_DATA)
	_set_edge_data(node, px, k.y, k.z)
end

function Bevel.set_border_px(node, px)
	local k = gui.get_constant(node, EDGE_DATA)
	_set_edge_data(node, k.x, px, k.z)
end

function Bevel.set_bevel_px(node, px)
	local k = gui.get_constant(node, EDGE_DATA)
	_set_edge_data(node, k.x, k.y, px)
end

return Bevel