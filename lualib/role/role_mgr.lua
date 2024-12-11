local dirtydb = require "dirtydb"
local role_cls = require "role.role_cls"
local role_db = require "role.role_db"

local M = {}

local roles = {}
local acc2uid = {}
function M.find_create_role(acc)
    if acc2uid[acc] then
        return M.get_role(acc2uid[acc])
    end

    local role_data = role_db.load_role(acc)
    if not role_data then
        return
    end

    if acc2uid[acc] then
        return M.get_role(acc2uid[acc])
    end

    uid = role_data.uid
    local dirty_data = dirtydb.new("role", role_data, role_db.get_save_cb(uid))
    acc2uid[acc] = uid
    local role = role_cls.new(uid, dirty_data)
    roles[uid] = role
    return role
end

function M.get_role(uid)
    if roles[uid] then
        return roles[uid]
    end

    local role_data = role_db.load_role_by_uid(uid)
    if not role_data then
        return
    end

    if roles[uid] then
        return roles[uid]
    end

    local acc = role_data.acc
    local dirty_data = dirtydb.new("role", role_data, role_db.get_save_cb(uid))
    acc2uid[acc] = uid
    local role = role_cls.new(uid, dirty_data)
    roles[uid] = role
    return role
end

function M.unload_role(uid)
    local role = roles[uid]
    if not role then
        return
    end

    dirtydb.remove(role:get_dirty_data())
    local acc = role:get_acc()
    acc2uid[acc] = nil
    roles[uid] = nil
end

return M
