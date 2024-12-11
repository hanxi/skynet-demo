local dirtydoc = require "dirtydoc"
local log = require "log"
local schema = require "schema"
local util_table = require "util.table"

local M = {}

local alldirty = {}
function M.need_schema(flag)
    dirtydoc.need_schema = flag
end

function M.new(schema_name, dirty_data, save_cb)
    local obj = dirtydoc.new(schema[schema_name], dirty_data)
    alldirty[obj] = save_cb
    return obj
end

local function save_obj(obj)
    save_cb = alldirty[obj]
    local dirty, result = dirtydoc.commit_mongo(obj)
    if dirty then
        log.debug("save_obj", obj, util_table.tostring(result))
        save_cb(result)
    end
end

function M.remove(obj)
    save_obj(obj)
    alldirty[obj] = nil
end

-- 脏数据落地
function M.save_dirty()
    for obj, save_cb in pairs(alldirty) do
        log.debug("save_dirty", obj, save_cb)
        save_obj(obj)
    end
end

return M
