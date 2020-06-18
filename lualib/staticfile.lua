local skynet = require "skynet"
local io = io
local root = skynet.getenv "static_path" or "./static/"

local cache = setmetatable({}, { __mode = "kv"  })

local function cachefile(_, filename)
	local v = cache[filename]
	if v then
		return v[1]
	end
	local f = io.open (root .. filename)
	if f then
		local content = f:read "a"
		f:close()
		cache[filename] = { content }
		return content
	else
		cache[filename] = {}
	end
end

local staticfile = setmetatable({}, {__index = cachefile })

return staticfile
