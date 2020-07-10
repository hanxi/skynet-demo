local skynet = require "skynet"
local snowflake = require "snowflake"

skynet.start(function()
    for i = 1, 10 do
        local id = snowflake.snowflake()
        skynet.error("snowflake test:", id)
    end
end)

