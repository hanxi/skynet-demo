# skynet-demo

## 编译

```
sudo apt-get install -y autoconf libssl-dev
git submodule update --init --recursive
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

~~算法类似美团的 Leaf-segment 的数据库方案~~

已删除，请采用下面的雪花算法。

## bson 支持整数 key， MongoDB 支持保存整数 key

已删除。

## 集成 zset 模块

`lualib/zset.lua`


## 集成声网 SDK

- 声网 SDK 代码 `3rd/agora` : <https://github.com/AgoraIO/Tools>
- lua 库代码 `lualib-src/lua-agora.cpp`

## 集成腾讯云 SDK

- 腾讯云 SDK 代码 `3rd/tls-sig-api-v2` : <https://github.com/tencentyun/tls-sig-api-v2-cpp>
- lua 库代码 `lualib-src/lua-tencentyun.cpp`
- 如果编译报错找不到 fmt 库，可以使用 `git submodule update --init --recursive` 命令更新相关库

测试 SDK 使用下面的指令启动 skynet:

```bash
./skynet/skynet etc/config.test-sdk
```

## 集成 lua-cjson

使用 lua 测试：

```bash
./skynet/3rd/lua/lua test/test-cjson.lua
```

skynet 中直接用这个测试服务就行：

```bash
./skynet/skynet etc/config.test
```

## 雪花算法生成唯一 ID

测试命令

```bash
./skynet/skynet etc/config.test-snowflake
```

- 4096 个服务
- 单个服务 10 毫秒内可以生成 4096 个 ID
- 支持时间跨服 174 年
- 时间回拨检查

## QQ api 接口

主要测试 http 的 get 和 post 如何使用，代码位置： `lualib/qqapi.lua`

目前就接了屏蔽字的接口： <https://developers.weixin.qq.com/miniprogram/dev/api-backend/open-api/sec-check/security.msgSecCheck.html>

测试命令：

```bash
./skynet/skynet etc/config.test-qqapi
```

如果是 https 接口，需要在配置中开启 ssl:

```lua
enablessl = true
```

当然，编译 skynet 时也需要把 tls 编译进去：

```
cd skynet && make linux TLS_MODULE=ltls
```

## 策划导表配置热更

- 使用 [ShareTable](https://github.com/cloudwu/skynet/wiki/ShareData#sharetable) 实现
- 参考这个讨论 [discussions/1429](https://github.com/cloudwu/skynet/discussions/1429)
- 代码位置: `lualib/staticdata.lua`

测试命令：

```bash
./skynet/skynet etc/config.teststaticdata
```

然后在 30 秒内修改 `data/test/data1.lua` 和 `data/test/data2.lua` 文件内容。Excel 配置文件导出可以使用工具 [hanxi/export.py](https://github.com/hanxi/export.py) 。

方案采用的是只使用 `sharetable.query` 接口更新本地引用，所以使用配置的地方都不能缓存配置数据，使用数据都需要从 root 取。

目前的方案只实现了手动调用 `staticdata.update(arrlist)` 接口实现热更配置。 可以优化成自动定时检测某个文件的时间，文件内容就是待热更的配置文件列表，以后有空再补上吧。

接口：

- `staticdata.preload()` 在 preload 中调用，用于给每个服务注册一个 debug 命令
- `staticdata.init(servicekey)` 在使用配置的服务启动时调用，用于预加载所有需要的配置，`servicekey` 用于标记服务使用了哪些配置文件，在 `data/service2datalist.lua` 中配置。
- `staticdata.loadfiles()` 在进程入口调用，用于加载所有的配置文件
- `staticdata.get(name)` 取配置数据，`name` 为配置的文件名，不能缓存在本地，每次都需要重新读取
- `staticdata.update(arrlist)` 热更配置， `arrlist` 为待热更的文件列表

## 无侵入式扩展官方的 debug_console 服务

- 无侵入式修改
- 采用 inject 的方式
- 代码路径： `lualib/debug_console_inject.lua`

使用示例：

```lua
local debug_console_inject = require "debug_console_inject"
local address = skynet.newservice("debug_console",8000)
debug_console_inject(address)
```

inject 的代码是直接以字符串的形式写的，如果需要扩展大量命令则建议采用 debug_console 的 inject 命令读取文件的方式。

比如这样：

```lua
local skynet = require "skynet"
return function(address)
    local filename = "lualib/debug_console_inject_source.lua"
    local f = io.open(filename, "rb")
    if not f then
        skynet.error("Can't open " .. filename)
        return
    end
    local source = f:read "*a"
    f:close()
    skynet.call(address, "debug", "RUN", source, filename)
end
```

### 测试

启动服务:

```bash
./skynet/skynet etc/config.test
```

连接 debug console: 

```txt
rlwrap nc 127.0.0.1 8000
Welcome to skynet console
stat
:00000004       cpu:0.000661    message:7       mqlen:0 task:0  xmem:48.40 Kb (snlua cdummy)
:00000006       cpu:0.000521    message:5       mqlen:0 task:0  xmem:44.22 Kb (snlua datacenterd)
:00000007       cpu:0.001139    message:5       mqlen:0 task:0  xmem:52.39 Kb (snlua service_mgr)
:00000009       cpu:0.001043    message:6       mqlen:0 task:1  xmem:57.96 Kb (snlua console)
:0000000a       cpu:0.00356     message:16      mqlen:0 task:1  xmem:108.73 Kb (snlua debug_console 8000)
:0000000b       cpu:0.000419    message:8       mqlen:0 task:0  xmem:44.92 Kb (snlua ws_watchdog)
:0000000c       cpu:0.001591    message:23      mqlen:0 task:0  xmem:67.62 Kb (snlua ws_gate)
:0000000d       cpu:0.00049     message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-1)
:0000000e       cpu:0.000633    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-2)
:0000000f       cpu:0.000443    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-3)
:00000010       cpu:0.000564    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-4)
:00000011       cpu:0.000518    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-5)
:00000012       cpu:0.000437    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-6)
:00000013       cpu:0.000502    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-7)
:00000014       cpu:0.000417    message:6       mqlen:0 task:0  xmem:65.76 Kb (snlua ws_gate .ws_gate .ws_gate-slave-8)
:00000015       cpu:0.000663    message:8       mqlen:0 task:0  xmem:55.67 Kb (snlua web_watchdog)
:00000016       cpu:0.000974    message:5       mqlen:0 task:0  xmem:63.23 Kb (snlua web_agent http)
<CMD OK>
```

示例中修改了 stat 命令，拼接了原有 stat 命令和 mem 命令的内容。

缘起： https://github.com/cloudwu/skynet/issues/1262

**这个方法只建议在新增命令时使用，原有命令组合能实现的还是写另外的客户端脚本执行 http 接口来组合来实现。**

## QQ 群

群号 677839887
