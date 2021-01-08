# skynet-demo

## 编译

```
git submodule update --init
make build
```

## websocket watchdog gate agent

fork from https://github.com/xzhovo/skynet-websocket-gate

编译 skynet:

```
git submodule update --init
cd skynet
make linux
```

启动命令：

```
./skynet/skynet etc/config.cfg
```

默认是 `ws` 协议，如果要改成 `wss` 协议，采用下面指令编译

```
make linux TLS_MODULE=tls
```

生成 `wss` 所需的密钥

```lua
-- gen cert and key
-- openssl req -x509 -newkey rsa:2048 -days 3650 -nodes -keyout server-key.pem -out server-cert.pem
```

修改 `service/main.lua` 里的 `protocol`

```lua
local protocol = "wss"
```


方案跟 [xzhovo/skynet-websocket-gate](https://github.com/xzhovo/skynet-websocket-gate) 有点不同，为了支持 `wss`, 采用了转发的模式推送数据给客户端

往 `gate` 发送 `response` 数据后， `gate` 会转发给客户端。

```lua
skynet.send(gate, "lua", "response", fd, msg)
```

[xzhovo/skynet-websocket-gate](https://github.com/xzhovo/skynet-websocket-gate) 的方案有个隐患， `agent` 引用了 `websocket.lua`, 需要维护好 `ws_pool` 。


根据 [mikewu86](https://github.com/mikewu86) 的提议 [issues#1](https://github.com/hanxi/skynet-demo/issues/1) ，已经将 ws_gate 扩展为 master/slave 模式。

## guid 模块

算法类似美团的 Leaf-segment 的数据库方案

测试命令：

```
./skynet/skynet etc/config.test
```

详细讲解见： https://blog.hanxi.info/?p=48

## bson 支持整数 key， MongoDB 支持保存整数 key

- 整数 key 将加前缀 `_i_` 保存到数据库
- 加载数据库数据遇到 key 的字段前缀为 `_i_` 时，删除前缀然后转为整数 key
- 需要打包数组的 table 时，需要特殊处理

```lua
local bson_array_mt = {
    __len = function (a)
        return rawlen(a)
    end,
}

-- 设置坐标
function M.set_location(uid, longitude, latitude)
    local location = {longitude, latitude}
    setmetatable(location, bson_array_mt)
    local ret = user_tbl:findAndModify({query = {uid = uid}, update = {["$set"] = {location = location}}})
    local result = math.floor(ret.ok)
    if result ~= 1 then
        return false
    end
    return true
end

-- 查找附加的人
function M.get_near_player(longitude, latitude, limit)
    local pipeline = {
        {
            ["$geoNear"] = {
                near = setmetatable({ longitude, latitude }, bson_array_mt),
                distanceField = "location",
                maxDistance = 2000,
                query = {location = {["$exists"] = true}},
            },
        },
        {
            ["$project"] = {
                uid = 1,
                _id = 0,
            },
        },
        {
            ["$limit"] = limit or 10,
        },
    }
    setmetatable(pipeline, bson_array_mt)
    local ret = db:runCommand("aggregate", "user", "pipeline", pipeline, "cursor", {})
    log.debug("get_near_player:", util_table.tostring(ret))
    if ret then
        return ret.cursor.firstBatch
    end
end
```

测试命令：

```
./skynet/skynet etc/config.test3
```

## 集成 zset 模块

`lualib/zset.lua`



## QQ 群

群号 677839887
