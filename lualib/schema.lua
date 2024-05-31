-- Auto generate from proto/db.proto

local schema_base = require("schema_base")
local number = schema_base.number
local string = schema_base.string
local boolean = schema_base.boolean

local role, role_type = {}, {}

setmetatable(role_type, {
    __tostring = function()
        return "schema_role"
    end,
})
role.uid = number
role.acc = string
role.sign_cnt = number
role._check_k = schema_base.check_k
role._check_kv = schema_base.check_kv
setmetatable(role, {
    __metatable = role_type,
})

return {
    role = role,
}
