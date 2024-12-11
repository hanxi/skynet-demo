local log = require "log"
local qqapi = require "qqapi"
local skynet = require "skynet"

skynet.start(function()
    qqapi.check_msg "你好习近平"
end)
