local skynet = require "skynet"

local M = {}

function M.debug(...)
    skynet.error("[DEBUG]", ...)
end

function M.info(...)
    skynet.error("[INFO]", ...)
end

function M.warn(...)
    skynet.error("[WARN]", ...)
end

function M.error(...)
    skynet.error("[ERROR]", ...)
    skynet.error("[ERROR]", debug.traceback())
end

return M
