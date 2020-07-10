local skynet = require "skynet"
local qqapi = require "qqapi"
local log = require "log"

skynet.start(function()
    qqapi.check_msg("你好习近平")
end)
