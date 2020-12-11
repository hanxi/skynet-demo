local skynet = require "skynet"
local guid = require "guid"
local db = require "db"
local config = require "config"

local function test_db()
    local query = {
        acc = "test1",
    }
    local uid, user_data = db.call_load_user(query)
    assert(uid > 0)

    local longitude, latitude = -73.99279 , 40.719296
    local ret = db.set_location(uid, longitude, latitude)
    assert(ret)
    db.get_near_player(longitude, latitude)
end

skynet.start(function()
    local cfg = config.get_db_conf()
    cfg.dbname = config.get("guid_db_name")
    cfg.tblname = config.get("guid_tbl_name")
    cfg.idtypes = config.get_tbl("guid_idtypes")
    guid.init(cfg)
    db.init_db()
    test_db()
end)
