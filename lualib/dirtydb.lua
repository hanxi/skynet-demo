local M = {}

local dirtydoc = require("dirtydoc")
local schema = require("schema")

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
		save_obj(obj)
	end
end

return M
