-----------------------------------------------------------------------------------------
--  _________.__              .__
-- /   _____/|  |   _______  _|__|____    ____  ©2025
-- \_____  \ |  |  /  _ \  \/ /  \__  \  /    \
-- /   [◕‿◕]\|  |_(  <_> )   /|  |/ __ \|   |  \
--/_______  /|____/\____/ \_/ |__(____  /___|  /
--       \/                          \/     \/
-----------------------------------------------------------------------------------------
-- local ContentManager = require("libslovian.defold.liveupdate.ContentManager")
-----------------------------------------------------------------------------------------
-- Generic Defold LiveUpdate content manager.
--
-- Usage from a script's init():
--   local ContentManager = require("libslovian.defold.liveupdate.ContentManager")
--   ContentManager.start({
--       use_liveupdate   = true,                         -- or a function returning bool
--       archive_name     = "my_liveupdate_v1",
--       app_save_dir     = "my_game_liveupdate",
--       main_content     = "_base",
--       builtin_content  = "_builtin",
--       on_ready         = function() print("ready!") end,
--       -- or:
--       -- notify_urls   = { "main:/app#script", "main:/music#script" },
--   })

local ContentManager = {}

local MSG_LIVEUPDATE_CONTENT_READY = hash("liveupdate_content_ready")

-- Build absolute URL to the zip, based on window.location (HTML5 etc.)
local function build_zip_url(zip_filename)
	if html5 and html5.run then
		local href = html5.run("window.location.href") or ""
		-- strip last path segment, keep trailing slash
		local base = href:gsub("[^/]+$", "")
		return base .. zip_filename
	else
		-- fallback: same folder as index.html
		return zip_filename
	end
end

local function notify_ready(config)
	if config.on_ready then
		local ok, err = pcall(config.on_ready)
		if not ok then
			print("LIVEUPDATE on_ready err:", err)
		end
	end

	local urls = config.notify_urls or {}
	for _, script_url in ipairs(urls) do
		local ok, err = pcall(msg.post, script_url, MSG_LIVEUPDATE_CONTENT_READY)
		if not ok then
			print("LIVEUPDATE notify err:", err)
		end
	end
end

local function mount_zip_from_path(archive_name, path_on_disk, config)
	local uri = "zip:" .. path_on_disk
	print("LIVEUPDATE: mounting zip from path:", uri)

	liveupdate.add_mount(
		archive_name,
		uri,
		10,
		function(_, name, uri2)
			print("LIVEUPDATE: add_mount cb name=", name, "uri=", uri2)
			notify_ready(config)
		end
	)
end

-- Remove all mounts except main, builtin, and current liveupdate archive.
-- Return true if liveupdate mount is present after pruning.
local function prune_and_check_mounts(archive_name, main_name, builtin_name)
	local mounts = liveupdate.get_mounts() or {}
	local has_live = false

	for _, m in ipairs(mounts) do
		local name = m.name
		if name == archive_name then
			has_live = true
		elseif name ~= main_name and name ~= builtin_name then
			print(("LIVEUPDATE: removing unexpected mount '%s' (%s)"):format(name, m.uri or ""))
			local ok, err = pcall(liveupdate.remove_mount, name)
			if not ok then
				print("LIVEUPDATE remove err:", err)
			end
		end
	end

	return has_live
end

local function ensure_archive_mounted(config)
	local archive_name = config.archive_name
	local zip_filename = archive_name .. ".zip"
	local main_name    = config.main_content or "_base"
	local builtin_name = config.builtin_content or "_builtin"

	-- 1) First prune old stuff, keep only base, builtin, and maybe our live pack
	local has_live = prune_and_check_mounts(archive_name, main_name, builtin_name)

	-- 2) If we already have our live pack mounted after pruning, we’re done
	if has_live then
		print("LIVEUPDATE: archive already mounted:", archive_name)
		notify_ready(config)
		return
	end

	-- 3) Not mounted -> download zip and mount from /data/...
	local url           = build_zip_url(zip_filename)
	local download_path = sys.get_save_file(config.app_save_dir, zip_filename)

	print("LIVEUPDATE: downloading", url, "->", download_path)

	http.request(
		url,
		"GET",
		function(_, _, resp)
			print("LIVEUPDATE: HTTP resp.status =", resp.status, "error =", resp.error or "nil")
			if (resp.status == 200 or resp.status == 304) and not resp.error then
				-- Zip is now at download_path (because we passed opts.path)
				mount_zip_from_path(archive_name, download_path, config)
			else
				print("LIVEUPDATE: download FAILED:", resp.status or "nil", resp.error or "")
				-- Fail soft: no LU, but base game works
				notify_ready(config)
			end
		end,
		nil,
		nil,
		{ path = download_path } -- IMPORTANT: store zip at this path
	)
end

--- Start the liveupdate content manager.
-- @param config See file header for supported keys.
function ContentManager.start(config)
	config = config or {}

	local use_liveupdate = config.use_liveupdate
	if type(use_liveupdate) == "function" then
		use_liveupdate = use_liveupdate()
	end

	if not use_liveupdate then
		print("LIVEUPDATE: not used on this platform, marking ready immediately")
		notify_ready(config)
		return
	end

	print("LIVEUPDATE: ContentManager.start, prune + ensure archive mounted")
	ensure_archive_mounted(config)
end

return ContentManager
