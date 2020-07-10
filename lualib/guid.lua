local skynet = require "skynet"

local M = {}
local guidd

-- cfg: {
--   host = "127.0.0.1",
--   port = 27107,
--   username = nil,
--   password = nil,
--   authdb = nil,
--   dbname = "guid",
--   tblname = "guid",
--   idtypes = {"uid" = step, "teamid" = step},
-- }
function M.init(cfg)
	skynet.call(guidd, "lua", "init", cfg)
end

function M.get_guid(idtype)
	return skynet.call(guidd, "lua", "get_guid", idtype)
end

skynet.init(function()
	guidd = skynet.uniqueservice("guidd")
end)

return M

