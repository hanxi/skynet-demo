local skynet = require "skynet"
local mongo = require "skynet.db.mongo"

local CMD = {}

--{
--   [idtype] = {
--     blocks = {
--        [start_idx] = len,  -- 有效数据, 表示从某段开始, 长度为len, 使用时段内自减
--     },
--     cur_idx = 0,  -- 记录当前在使用的段ID, 当某段不足 step/10 时, 自动申请, 优先使用低段位
--     step = step,  -- 每次从 db 取的 id 数量
--     ids_cnt = 0,  -- 当前ID总数
--   }
--}
local block_datas

-- 生产协程
local creator
local is_busy = false

local db_guid
local tbl_guid

local function new_db_id(idtype, step)
    local ret = tbl_guid:findAndModify({query = {idtype = idtype}, update = {["$inc"] = {nextid = step}}, upsert = true})

    local result = math.floor(ret.ok)
    if result ~= 1 then
        skynet.error("new_db_id not ret. idtype:", idtype, ",step:", step, ",msg:", ret.errmsg)
        return
    end

    if not ret.value.nextid then
        skynet.error("new_db_id failed. ignore first step. idtype:", idtype, ",step:", step)
        return
    end

    return ret.value.nextid
end

local function init_generator(idtype, step)
    local id = new_db_id(idtype, step)
    if not id then
        return
    end

    skynet.error("get new id block. start:", id, ", step:", step)
    block_datas[idtype].blocks[id] = step
end

local function update_generator(idtype, update_cache)
    local info = block_datas[idtype]
    if not update_cache then
        local cnt = 0
        for idx, size in pairs(info.blocks) do
            cnt = cnt + size
        end

        local step = info.step
        if cnt < step/10 then
            if not init_generator(idtype, step) then
                skynet.error("cannot get new id. idtype:", idtype)
            end
        end
    end

    local old_block = info.cur_idx or 0
    local cnt = 0
    for idx, size in pairs(info.blocks) do
        if not info.cur_idx then
            info.cur_idx = idx
        elseif info.cur_idx > idx then
            info.cur_idx = idx
        end
        cnt = cnt + size
    end

    info.ids_cnt = cnt
    if old_block ~= info.cur_idx then
        skynet.error("switch id block. idtype:", idtype, ",cur:", info.cur_idx, ",old:", old_block, ",ids_cnt:", cnt)
    end
end

local function get_new_id(idtype)
    local info = block_datas[idtype]

    if not info.cur_idx then
        if info.ids_cnt > 0 then
            update_generator(idtype, true)
            if not info.cur_idx then
                skynet.error("new guid too busy. idtype:", idtype)
                return
            end
        else
            skynet.error("id pool null. idtype:", idtype)
            return
        end
    end

    local cur_idx = info.cur_idx
    local diff = info.blocks[cur_idx]
    if diff <= 0 then
        --本段已经消耗完，正在切段
        skynet.error("id block all used. idtype:", idtype)
        return
    end

    local new_id = diff + cur_idx
    if diff == 1 then
        skynet.error("id block used. cur:", cur_idx)
        info.blocks[cur_idx] = nil
        info.cur_idx = nil
    else
        info.blocks[cur_idx] = diff - 1
    end
    info.ids_cnt = info.ids_cnt - 1

    -- 当存量低于阀值
    if not is_busy and info.ids_cnt < info.step/10 then
        is_busy = true
        skynet.wakeup(creator)
    end

    skynet.error("consume ok. guid:", new_id)
    return new_id
end

local function create_new_ids()
    while true do
        for idtype,info in pairs(block_datas) do
            skynet.error("creator going to check id space. idtype:", idtype)
            if info.ids_cnt < info.step/10 then
                skynet.error("creator start update id space. idtype:", idtype)
                update_generator(idtype)
                skynet.error("creator update id space ok. idtype:", idtype)
            else
                skynet.error("not need create new ids. idtype:", idtype)
            end
        end
        is_busy = false
        skynet.wait()
    end
end

-- cfg: {
--   host = "127.0.0.1",
--   port = 27107,
--   username = nil,
--   password = nil,
--   authdb = nil,
--   dbname = "guid",
--   tblname = "guid",
--   idtypes = {uid = step, teamid = step},
-- }
function CMD.init(cfg)
    local db = mongo.client(cfg)
    db_guid = db[cfg.dbname]
    tbl_guid = db_guid[cfg.tblname]
    tbl_guid:createIndex({{idtype = 1}, unique = true})

    block_datas = {}
    for idtype,step in pairs(cfg.idtypes) do
        block_datas[idtype] = {
            blocks = {},
            step = step,
        }
        update_generator(idtype)
    end

    creator = skynet.fork(create_new_ids)
end

function CMD.get_guid(idtype)
    assert(block_datas[idtype], "Unknow idtype. idtype:" .. idtype)
    return get_new_id(idtype)
end

skynet.start(function()
	skynet.dispatch("lua", function(_, _, cmd, ...)
		local f = assert(CMD[cmd])
        skynet.ret(skynet.pack(f(...)))
	end)
end)

