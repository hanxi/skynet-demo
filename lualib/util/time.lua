local skynet = require "skynet"

local M = {}

function M.now()
	return math.floor(skynet.time())
end

return M
