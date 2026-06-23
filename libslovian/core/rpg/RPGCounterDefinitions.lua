-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- EXAMPLE counter definitions for use with RPGCounters.
--
-- Copy this file into your own project and edit it, or pass a similar table
-- directly to RPGCounters:new(). The library does not force any specific
-- counter names.
--
-- Definition fields:
--   max_stat      - stat name used as the counter's maximum value
--   regen_stat    - stat name that provides regeneration per second
--   degen_stat    - stat name that provides degeneration per second
--   initial_value - number, or "max" to start at stats:get(max_stat)
--
-- Example:
--   local MyDefinitions = {
--       HP       = { max_stat = "HP_max",       regen_stat = "HP_regen",       degen_stat = "HP_degen",       initial_value = "max" },
--       Energy   = { max_stat = "Energy_max",   regen_stat = "Energy_regen",   degen_stat = "Energy_degen",   initial_value = "max" },
--       Ammo     = { max_stat = "Ammo_max",     regen_stat = "Ammo_regen",     degen_stat = "Ammo_degen",     initial_value = "max" },
--       Default  = { initial_value = 0 },
--   }

local RPGCounterDefinitions = {
	Default = { initial_value = 0 },
}

return RPGCounterDefinitions
