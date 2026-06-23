-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /        \|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local CameraUtilz = require("libslovian.defold.camera.CameraUtilz")

local CameraUtilz = {} 

function CameraUtilz:screen2world(x, y)
	local projection = camera.get_projection(self.camera_id)
	local view       = camera.get_view(self.camera_id)
	local w, h       = window.get_size()

	local inv = vmath.inv(projection * view)
	local nx  = (2 * x / w) - 1
	local ny  = (2 * y / h) - 1
	local x1  = nx * inv.m00 + ny * inv.m01 + inv.m03
	local y1  = nx * inv.m10 + ny * inv.m11 + inv.m13
	return x1, y1
	
end

return CameraUtilz