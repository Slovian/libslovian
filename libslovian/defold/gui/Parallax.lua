-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local Parallax = require("libslovian.defold.gui.Parallax")
--
-- Parallax scrolling helper for GUI nodes.

local Parallax = {}

function Parallax.init(parallaxTable, parallaxConfig)
	for _, entry in ipairs(parallaxTable) do
		local pos = gui.get_position(entry.Node)
		entry.BasePosition = pos
		entry.AppliedPosition = vmath.vector3(pos.x, pos.y, pos.z)
	end
end

function Parallax.update(parallaxTable, parallaxConfig, screenX, screenY)
	local sizeX, sizeY = gui.get_width(), gui.get_height()
	local ratioX = (screenX / sizeX) * 2.0 - 1.0		-- [-1..1]
	local ratioY = (screenY / sizeY) * 2.0 - 1.0		-- [-1..1]
	ratioX = math.max(math.min(ratioX, 1), -1)
	ratioY = math.max(math.min(ratioY, 1), -1)
	local shiftX = ratioX *  parallaxConfig.MaxX
	local shiftY = ratioY *  parallaxConfig.MaxY
	for _, entry in ipairs(parallaxTable) do
		local basePos = entry.BasePosition
		local currPos = entry.AppliedPosition
		currPos.x = basePos.x + shiftX * entry.Ratio
		currPos.y = basePos.y + shiftY * entry.Ratio
		gui.set_position(entry.Node, currPos)
	end

	-- return parallax shift, as it might be usable by other effects as well
	return shiftX, shiftY
end

return Parallax