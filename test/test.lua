local skynet = require "skynet"
local guid = require "guid"

local cfg = {
  host = "127.0.0.1",
  port = 27017,
  username = nil,
  password = nil,
  authdb = nil,
  dbname = "guid",
  tblname = "guid",
  idtypes = {uid = 3, teamid = 4},
}

local function f()
    local uid = guid.get_guid("uid")
    skynet.error("--------------------uid:", uid)

    local teamid = guid.get_guid("teamid")
    skynet.error("--------------------teamid:", teamid)
end

skynet.init(function()
    guid.init(cfg)

    for i=1,10 do
        skynet.timeout(i*100,f)
    end
end)

skynet.start(function()
    skynet.error("start test service")
end)

